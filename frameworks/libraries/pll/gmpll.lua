-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    gatemate.lua
    ------------
    Lua reimplementation of a PLL generator for the Cologne Chip GateMate A1
    and A2 FPGAs (CCGM1A1 / CCGM1A2), targeting the CC_PLL primitive with a
    CC_BUFG global-buffer on the primary output clock.

    Depends on: allpll.lua  (must be on the Lua path or in the same directory)

    The GateMate CC_PLL primitive is fundamentally different from the iCE40 and
    ECP5 PLLs: the user does NOT specify divider ratios.  Instead, the toolchain
    (Cologne Chip P&R or nextpnr-himbaechel) derives all internal divider values
    from two real-valued string parameters, REF_CLK and OUT_CLK.  The primitive
    has a single solver inside the toolchain, so this generator only validates
    the requested frequencies against the documented hardware limits and formats
    the correct Verilog instantiation.

    CC_PLL outputs four fixed phase-shifted copies of the output clock:
        CLK0   - 0 deg   (primary, routed through CC_BUFG onto the global mesh)
        CLK90  - 90 deg
        CLK180 - 180 deg
        CLK270 - 270 deg

    Performance modes and their VCO / output frequency limits
    (source: DS1001 GateMate FPGA Datasheet, Table 4.6):
        LOWPOWER  - output  10 - 320 MHz
        ECONOMY   - output  10 - 450 MHz  (default)
        SPEED     - output  10 - 800 MHz

    Input frequency range: 1 - 400 MHz (all modes)

    Usage:
        local gatemate = require("gatemate")
        local verilog, err = gatemate("-i 10 -o 50")
        if verilog then print(verilog) else io.stderr:write(err.."\n") end

    Flags:
        -i <MHz>              Input clock frequency in MHz          (required)
        -o <MHz>              Output clock frequency in MHz         (required)
        -n <name>          Module name                           (default: "pll")
        -c <name>          Input clock port name                 (default: "clock_in")
        -g <name>          Output clock port name (CLK0 + BUFG)  (default: "clock_out")
        --perf <mode>         Performance mode: LOWPOWER, ECONOMY, SPEED
                              (default: ECONOMY)
        --no-low-jitter       Disable the low-jitter PLL mode      (default: enabled)
        --no-bufg             Omit the CC_BUFG global buffer on CLK0
        --clk90  <name>    Also expose CLK90  output with this port name
        --clk180 <name>    Also expose CLK180 output with this port name
        --clk270 <name>    Also expose CLK270 output with this port name
        --p <deg>            Phase of the primary output clock in degrees.
                              The CC_PLL only supports four fixed phases: 0, 90,
                              180, 270.  Selecting a non-zero phase routes the
                              matching CC_PLL output through CC_BUFG instead of
                              CLK0.  Any other value is an error.
                              (default: 0)
                              Note: the CC_PLL produces a single output frequency
                              with four fixed phase copies; it cannot generate two
                              independent frequencies simultaneously.
        -h / --help           Print this help (returned as the error string)

    Returns:
        On success: verilog_string, nil
        On failure: nil, error_string

    Generated module structure (default, all optional outputs omitted):

        module pll (
            input  clock_in,
            output clock_out,       // CLK0 via CC_BUFG -> global mesh
            output locked
            );

        wire clk0_w;                // raw CLK0 before the global buffer

        CC_PLL #(
            .REF_CLK("<i> MHz"),
            .OUT_CLK("<o> MHz"),
            .PERF_MD("ECONOMY"),
            .LOW_JITTER(1),
            .CI_FILTER_CONST(2),
            .CP_FILTER_CONST(4)
        ) pll_inst (
            .CLK_REF(clock_in),
            .CLK_FEEDBACK(1'b0),
            .USR_CLK_REF(1'b0),
            .USR_LOCKED_STDY_RST(1'b0),
            .CLK0(clk0_w),
            .CLK90(),
            .CLK180(),
            .CLK270(),
            .CLK_REF_OUT(),
            .USR_PLL_LOCKED_STDY(),
            .USR_PLL_LOCKED(locked)
        );

        CC_BUFG bufg_inst (
            .I(clk0_w),
            .O(clock_out)
        );

        endmodule
--]]

-- Load allpll from the same directory as this file, regardless of whether
-- this file was loaded via require() or dofile().
local allpll = (function()
    if package.loaded["allpll"] then return package.loaded["allpll"] end
    local src = debug.getinfo(1, "S").source
    local dir = (src:sub(1,1) == "@" and src:sub(2) or src):match("^(.*[/\\])") or "./"
    local m = dofile(dir .. "allpll.lua")
    package.loaded["allpll"] = m
    return m
end)()

local parse_args = allpll.parse_args
local fmt        = allpll.fmt

-- -- GateMate CC_PLL frequency constraints ------------------------------------
-- Source: DS1001 GateMate FPGA Datasheet, Table 4.6 "PLL characteristics"

local INPUT_MIN = 1.0    -- MHz  (all modes)
local INPUT_MAX = 400.0  -- MHz

local OUTPUT_MIN = 10.0  -- MHz  (all modes)
-- Per-mode output maximums:
local OUTPUT_MAX = {
    LOWPOWER = 320.0,
    ECONOMY  = 450.0,
    SPEED    = 800.0,
}

-- Valid PERF_MD strings (as required by the primitive parameter)
local VALID_PERF = { LOWPOWER = true, ECONOMY = true, SPEED = true }

-- -- Public function -----------------------------------------------------------

--- Generate a GateMate CC_PLL Verilog module from a CLI argument string.
---
--- @param  args_string  string  CLI-style arguments (see module header)
--- @return               string  Verilog source on success
--- @return               nil, string  on failure
function gmpll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_in       = nil
    local f_out      = nil
    local mod_name   = "pll"
    local clk_in     = "clock_in"
    local clk_out    = "clock_out"
    local perf_md    = "ECONOMY"
    local low_jitter = true
    local use_bufg   = true
    local p0_phase   = 0        -- primary output phase: 0 | 90 | 180 | 270
    -- Optional extra phase outputs; nil = not exposed
    local name_90    = nil
    local name_180   = nil
    local name_270   = nil

    -- Argument parsing
    local i = 1
    while i <= #args do
        local a = args[i]

        if a == "-i" then
            i = i + 1
            f_in = tonumber(args[i])
            if not f_in then return nil, "gatemate: invalid value for -i" end

        elseif a == "-o" then
            i = i + 1
            f_out = tonumber(args[i])
            if not f_out then return nil, "gatemate: invalid value for -o" end

        elseif a == "-n" then
            i = i + 1; mod_name = args[i] or mod_name

        elseif a == "-c" then
            i = i + 1; clk_in = args[i] or clk_in

        elseif a == "-g" then
            i = i + 1; clk_out = args[i] or clk_out

        elseif a == "--perf" then
            i = i + 1
            local v = (args[i] or ""):upper()
            if not VALID_PERF[v] then
                return nil, "gatemate: --perf must be LOWPOWER, ECONOMY or SPEED"
            end
            perf_md = v

        elseif a == "--no-low-jitter" then
            low_jitter = false

        elseif a == "--no-bufg" then
            use_bufg = false

        elseif a == "--clk90" then
            i = i + 1; name_90  = args[i] or "clk90"

        elseif a == "--clk180" then
            i = i + 1; name_180 = args[i] or "clk180"

        elseif a == "--clk270" then
            i = i + 1; name_270 = args[i] or "clk270"

        elseif a == "--p" then
            i = i + 1
            local v = tonumber(args[i])
            if not v then return nil, "gatemate: --p requires an integer degree value" end
            -- Normalise to 0-359 so e.g. -90 or 360 are caught cleanly
            v = math.floor(v + 0.5) % 360
            if v ~= 0 and v ~= 90 and v ~= 180 and v ~= 270 then
                return nil, fmt(
                    "gatemate: --p %d is not a feasible phase. " ..
                    "The CC_PLL only supports fixed phases: 0, 90, 180, 270 degrees. " ..
                    "Arbitrary phase shifting is not possible with this primitive.",
                    math.floor(tonumber(args[i]) + 0.5))
            end
            p0_phase = v

        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "gatemate - GateMate A1/A2 CC_PLL Verilog generator",
                "  -i <MHz>          Input clock frequency in MHz (required)",
                "  -o <MHz>          Output clock frequency in MHz (required)",
                "  -n <name>      Module name (default: pll)",
                "  -c <name>      Input clock port name (default: clock_in)",
                "  -g <name>      Output clock port name (default: clock_out)",
                "  --perf <mode>     LOWPOWER / ECONOMY / SPEED (default: ECONOMY)",
                "  --no-low-jitter   Disable low-jitter PLL mode",
                "  --no-bufg         Omit CC_BUFG global buffer on CLK0",
                "  --clk90  <name>   Expose CLK90  output with given port name",
                "  --clk180 <name>   Expose CLK180 output with given port name",
                "  --clk270 <name>   Expose CLK270 output with given port name",
                "  --p <deg>        Primary output phase in degrees.",
                "                    Feasible values: 0, 90, 180, 270 (default: 0).",
                "                    The CC_PLL has no arbitrary phase-shift capability;",
                "                    only these four fixed taps are available.",
                "                    Note: the CC_PLL generates one output frequency only.",
            }, "\n")

        else
            return nil, "gatemate: unknown option: " .. a
        end
        i = i + 1
    end

    -- Validate required arguments
    if not f_in  then return nil, "gatemate: input frequency (-i) is required"  end
    if not f_out then return nil, "gatemate: output frequency (-o) is required" end

    -- Frequency range checks (errors, not just warnings, since the toolchain
    -- will reject out-of-range values at implementation time)
    if f_in < INPUT_MIN or f_in > INPUT_MAX then
        return nil, fmt("gatemate: input %.3f MHz is outside the allowed range %.0f-%.0f MHz",
                        f_in, INPUT_MIN, INPUT_MAX)
    end

    local out_max = OUTPUT_MAX[perf_md]
    if f_out < OUTPUT_MIN or f_out > out_max then
        return nil, fmt(
            "gatemate: output %.3f MHz is outside the allowed range %.0f-%.0f MHz for PERF_MD=%s",
            f_out, OUTPUT_MIN, out_max, perf_md)
    end

    -- Warn if the requested frequency is unlikely to be achievable exactly,
    -- since the hardware can only hit discrete VCO frequencies.  The toolchain
    -- will pick the closest realizable frequency, so this is advisory only.
    print(fmt("gatemate: note: the toolchain will choose the closest achievable frequency to %.3f MHz", f_out))

    -- -- Verilog generation ----------------------------------------------------

    -- Map p0_phase to the CC_PLL output pin name that feeds the primary output.
    -- The four taps are hardwired inside the primitive; no other angles exist.
    local phase_pin = ({[0]="CLK0", [90]="CLK90", [180]="CLK180", [270]="CLK270"})[p0_phase]

    -- The internal CLK0 wire only exists when we interpose a CC_BUFG.
    -- Without the buffer the selected phase pin connects straight to the output port.
    local clk0_wire = use_bufg and "clk0_w" or clk_out

    local L = {}
    local function e(s) L[#L + 1] = s end

    -- Header comment
    e("/**")
    e(" * PLL configuration")
    e(" *")
    e(" * This Verilog module was generated automatically")
    e(" * using the gatemate pll generator.")

    e(" *")
    e(fmt(" * Target device:              GateMate A1/A2 (CCGM1A1/CCGM1A2)"))
    e(fmt(" * Given input frequency:      %8.3f MHz", f_in))
    e(fmt(" * Requested output frequency: %8.3f MHz", f_out))
    e(fmt(" * Performance mode:           %s", perf_md))
    e(fmt(" * Primary output phase:       %d deg  (routed from %s)", p0_phase, phase_pin))
    e(" *")
    e(" * Note: the toolchain resolves REF_CLK/OUT_CLK to the closest")
    e(" * achievable divider settings at implementation time.")
    e(" */")
    e("")

    -- Module ports
    e(fmt("module %s (", mod_name))
    e(fmt("    input  %s,", clk_in))
        e(fmt("    output %s,", clk_out))  -- CLK0 (possibly through CC_BUFG)
    if name_90  then e(fmt("    output %s,", name_90))  end
    if name_180 then e(fmt("    output %s,", name_180)) end
    if name_270 then e(fmt("    output %s,", name_270)) end
    e("    output locked,")
    e("    output reset")
    e("    );")
    e("")
    e("assign reset = ~locked;")
    e("")

    -- Internal wire for the selected phase tap (only needed with CC_BUFG)
    if use_bufg then
        e(fmt("wire %s; // %s (%d deg) before the global buffer", clk0_wire, phase_pin, p0_phase))
        e("")
    end

    -- CC_PLL instantiation
    -- REF_CLK and OUT_CLK are passed as real-valued strings (MHz); the
    -- Cologne Chip toolchain converts these to internal divider settings.
    e("CC_PLL #(")
    e(fmt("    .REF_CLK(\"%.6g\"),  // input  clock in MHz", f_in))
    e(fmt("    .OUT_CLK(\"%.6g\"),  // output clock in MHz", f_out))
    e(fmt("    .PERF_MD(\"%s\"),", perf_md))
    e(fmt("    .LOW_JITTER(%d),  // 0: disable, 1: enable low-jitter mode", low_jitter and 1 or 0))
    e("    .CI_FILTER_CONST(2),  // optional: charge-pump filter constant")
    e("    .CP_FILTER_CONST(4)   // optional: charge-pump filter constant")
    e(") pll_inst (")
    e(fmt("    .CLK_REF(%s),", clk_in))
    e("    .CLK_FEEDBACK(1'b0),")
    e("    .USR_CLK_REF(1'b0),")
    e("    .USR_LOCKED_STDY_RST(1'b0),")

    -- Route each phase tap: the selected primary tap goes to clk0_wire (or
    -- straight to the output port when --no-bufg is used); optional named
    -- outputs go to their port wires; everything else is left open.
    local function phase_conn(pin, opt_name)
        if pin == phase_pin then return clk0_wire end
        return opt_name or ""
    end
    e(fmt("    .CLK0(%s),",   phase_conn("CLK0",   nil)))
    e(fmt("    .CLK90(%s),",  phase_conn("CLK90",  name_90)))
    e(fmt("    .CLK180(%s),", phase_conn("CLK180", name_180)))
    e(fmt("    .CLK270(%s),", phase_conn("CLK270", name_270)))

    e("    .CLK_REF_OUT(),")
    e("    .USR_PLL_LOCKED_STDY(),")
    e("    .USR_PLL_LOCKED(locked)")
    e(");")
    e("")

    -- CC_BUFG: routes the selected phase tap onto the global mesh for low-skew distribution
    if use_bufg then
        e(fmt("// CC_BUFG drives %s (%d deg) onto the GateMate global clock mesh", phase_pin, p0_phase))
        e("CC_BUFG bufg_inst (")
        e(fmt("    .I(%s),", clk0_wire))
        e(fmt("    .O(%s)",  clk_out))
        e(");")
        e("")
    end

    e("endmodule")

    return table.concat(L, "\n")
end
