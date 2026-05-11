-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    xilpll.lua
    --------
    Generates a Verilog wrapper module instantiating the Xilinx 7-series
    PLLE2_BASE or MMCME2_BASE clock primitive, suitable for both Vivado
    and the F4PGA / nextpnr-xilinx open-source toolchain.

    Depends on: allpll.lua  (must be on the Lua path or in the same directory)

    Supported board examples:
        arty-a7-35   Digilent Arty A7-35T  (XC7A35TICSG324-1L,  100 MHz)
        arty-a7-100  Digilent Arty A7-100T (XC7A100TCSG324-1,   100 MHz)

    The same primitive (PLLE2_BASE) works across the entire 7-series family:
        Artix-7, Kintex-7, Virtex-7, Zynq-7000.
    MMCME2_BASE is selected with --mmcm and uses a wider VCO range.

    Frequency relationships (UG472 section 3):
        fVCO = fIN * CLKFBOUT_MULT / DIVCLK_DIVIDE
        fOUT = fVCO / CLKOUTn_DIVIDE

    Parameter constraints for Artix-7 / Kintex-7 / Zynq (7-series):
        PLLE2_BASE:
            CLKFBOUT_MULT   : 2..64   (integer)
            DIVCLK_DIVIDE   : 1..56   (integer)
            CLKOUTn_DIVIDE  : 1..128  (integer)
            VCO             : 800..1600 MHz
            fIN             : 19..800  MHz
            CLKOUTn_PHASE   : 0.0..360.0 degrees (1.0-degree steps)

        MMCME2_BASE  (--mmcm):
            CLKFBOUT_MULT_F : 2..64   (real, 0.125 steps; we use integers here)
            DIVCLK_DIVIDE   : 1..106  (integer)
            CLKOUTn_DIVIDE  : 1..128  (integer)
            VCO             : 600..1200 MHz
            fIN             : 10..800  MHz
            CLKOUTn_PHASE   : 0.0..360.0 degrees (finer steps for MMCM)

    The output clock is always routed through a BUFG global buffer, which is
    the standard and required practice for driving FPGA fabric clocks.
    The feedback path uses CLKFBOUT -> BUFG -> CLKFBIN (internal feedback,
    matching Vivado Clocking Wizard output).

    Up to four output clocks are supported (CLKOUT0..CLKOUT3). All outputs
    share a single VCO (common M / D); each has its own integer output
    divider and phase. CLKOUT4 and CLKOUT5 are always left unconnected.

    Usage:
        dofile('allpll.lua')
        dofile('xilpll.lua')

        -- Single output (original behaviour):
        print(xilpll('-i 100 -o 200 -p 90 -n my_pll'))

        -- Two outputs: 200 MHz (0°) and 25 MHz (90°):
        print(xilpll('-i 100 -o 200 --o1 25 --p1 90 -n my_pll'))

        -- Four outputs with custom port names:
        print(xilpll('-i 100 -o 200 --o1 100 --o2 50 --p2 180 --o3 25 --p3 270 -n my_pll'))

        -- MMCM variant:
        print(xilpll('-i 100 -o 200 -n my_pll --mmcm'))

    Flags:
        -i <MHz>          Input clock frequency in MHz                 (required)
        -o <MHz>          Primary output frequency in MHz  (CLKOUT0)   (required)
        -p <deg>          Primary output phase in degrees  (default: 0.0)
        -g <name>         Primary output clock port name   (default: clock_out)

        --o1 <MHz>        Second output frequency in MHz   (CLKOUT1)   (optional)
        --p1 <deg>        Second output phase in degrees   (default: 0.0)
        --g1 <name>       Second output clock port name    (default: clock_out1)

        --o2 <MHz>        Third  output frequency in MHz   (CLKOUT2)   (optional)
        --p2 <deg>        Third  output phase in degrees   (default: 0.0)
        --g2 <name>       Third  output clock port name    (default: clock_out2)

        --o3 <MHz>        Fourth output frequency in MHz   (CLKOUT3)   (optional)
        --p3 <deg>        Fourth output phase in degrees   (default: 0.0)
        --g3 <name>       Fourth output clock port name    (default: clock_out3)

        --mmcm            Use MMCME2_BASE instead of PLLE2_BASE
                          (wider VCO range, lower minimum fIN)
        -n <name>         Verilog module name                (default: pll)
        -c <name>         Input clock port name              (default: clock_in)

        -h / --help       Print this help (returned as error string)

    Notes:
        * Phase values must be in the range 0.0 to 360.0 degrees.
        * For PLLE2_BASE, phase is quantised to 1/8 of the VCO period (UG472
          Table 3-9), so the achieved phase may differ slightly from the
          requested value.  The generator writes the requested value verbatim
          into CLKOUTn_PHASE; Vivado will round it during implementation.
        * All outputs share one VCO.  The solver minimises the sum of squared
          relative frequency errors across all requested outputs, so a
          combination that satisfies all clocks approximately is preferred over
          one that is exact for the primary clock but poor for the others.

    Returns:
        On success: verilog_string, nil
        On failure: nil, error_string
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
local round      = allpll.round
local fmt        = allpll.fmt

-- ---- Primitive constraints --------------------------------------------------
-- Source: Xilinx UG472 (7 Series Clocking Resources), Table 3-9 / 3-10,
-- and device data sheets for Artix-7 speed grade -1.

local PLLE2 = {
    name        = "PLLE2_BASE",
    vco_min     = 800.0,    -- MHz
    vco_max     = 1600.0,   -- MHz
    fin_min     = 19.0,     -- MHz
    fin_max     = 800.0,    -- MHz
    mult_min    = 2,
    mult_max    = 64,
    div_min     = 1,        -- DIVCLK_DIVIDE
    div_max     = 56,
    odiv_min    = 1,        -- CLKOUTn_DIVIDE
    odiv_max    = 128,
    max_outputs = 4,        -- CLKOUT0..3 exposed; CLKOUT4..5 unused
}

local MMCME2 = {
    name        = "MMCME2_BASE",
    vco_min     = 600.0,
    vco_max     = 1200.0,
    fin_min     = 10.0,
    fin_max     = 800.0,
    mult_min    = 2,
    mult_max    = 64,
    div_min     = 1,
    div_max     = 106,
    odiv_min    = 1,
    odiv_max    = 128,
    max_outputs = 4,        -- CLKOUT0..3 exposed; CLKOUT4..5 unused
}

-- ---- Solver -----------------------------------------------------------------
--
-- Find integer (CLKFBOUT_MULT M, DIVCLK_DIVIDE D) and, for each requested
-- output clock k, an integer output divider O[k] such that:
--
--   fVCO      = fIN * M / D          in [vco_min, vco_max]
--   fOUT[k]   = fVCO / O[k]          as close as possible to targets[k]
--
-- Scoring: minimise the sum of squared *relative* frequency errors across
-- all outputs (equal weight per output).  Ties are broken by preferring a
-- VCO frequency near the midpoint of the VCO range (better jitter).
--
-- Parameters:
--   f_in    : input frequency (MHz)
--   targets : array of { freq = MHz } for each desired output (1-indexed)
--   prim    : primitive constraints table
--
-- Returns on success:
--   { fout, O }[] (one entry per target),  M,  D
-- Returns on failure:
--   nil

local function solve(f_in, targets, prim)
    local n_out  = #targets
    local vco_mid = (prim.vco_min + prim.vco_max) / 2.0

    local best_score = math.huge
    local best_m, best_d
    local best_divs   -- array of best O values
    local best_fouts  -- array of achieved frequencies

    for d = prim.div_min, prim.div_max do
        for m = prim.mult_min, prim.mult_max do
            local f_vco = f_in * m / d
            if f_vco >= prim.vco_min and f_vco <= prim.vco_max then

                -- For each output, find the best integer divider
                local divs  = {}
                local fouts = {}
                local score = 0.0

                for k = 1, n_out do
                    local f_target = targets[k].freq
                    local o_ideal  = f_vco / f_target

                    local best_o_err  = math.huge
                    local best_o_val  = nil
                    local best_o_fout = nil

                    -- Check floor and ceil, clamped to valid range
                    for _, o in ipairs({
                        math.max(prim.odiv_min, math.floor(o_ideal)),
                        math.min(prim.odiv_max, math.ceil(o_ideal)),
                    }) do
                        if o >= prim.odiv_min and o <= prim.odiv_max then
                            local fout    = f_vco / o
                            local rel_err = math.abs(fout - f_target) / f_target
                            if rel_err < best_o_err then
                                best_o_err  = rel_err
                                best_o_val  = o
                                best_o_fout = fout
                            end
                        end
                    end

                    if not best_o_val then
                        score = math.huge
                        break
                    end

                    divs[k]  = best_o_val
                    fouts[k] = best_o_fout
                    score    = score + best_o_err * best_o_err
                end

                -- Tiebreak: prefer VCO near midpoint (lower jitter)
                local vco_penalty = math.abs(f_vco - vco_mid) / vco_mid * 1e-9

                if score + vco_penalty < best_score then
                    best_score = score + vco_penalty
                    best_m     = m
                    best_d     = d
                    best_divs  = divs
                    best_fouts = fouts
                end
            end
        end
    end

    if not best_m then return nil end
    return best_fouts, best_m, best_d, best_divs
end

-- ---- Public function --------------------------------------------------------

function xilpll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_in     = nil
    local use_mmcm = false
    local mod_name = "pll"
    local clk_in   = "clock_in"

    -- Per-output configuration: index 0 = primary (CLKOUT0), 1..3 = extra
    -- Each entry: { freq=MHz, phase=deg, port=name, idx=0..3 }
    -- We store them in a flat array indexed 0..3 for easy Verilog generation.
    local out_freq  = {}   -- out_freq[0..3]  MHz  (nil = not used)
    local out_phase = {}   -- out_phase[0..3] deg  (default 0.0)
    local out_port  = {}   -- out_port[0..3]  port name

    -- Defaults for port names
    out_port[0] = "clock_out"
    out_port[1] = "clock_out1"
    out_port[2] = "clock_out2"
    out_port[3] = "clock_out3"

    -- Default phases
    for k = 0, 3 do out_phase[k] = 0.0 end

    -- ---- Argument parsing ---------------------------------------------------
    local i = 1
    while i <= #args do
        local a = args[i]

        if a == "-i" then
            i = i + 1
            f_in = tonumber(args[i])
            if not f_in then return nil, "xilpll: invalid value for -i" end

        elseif a == "-o" then
            i = i + 1
            out_freq[0] = tonumber(args[i])
            if not out_freq[0] then return nil, "xilpll: invalid value for -o" end

        elseif a == "-p" then
            i = i + 1
            local ph = tonumber(args[i])
            if not ph then return nil, "xilpll: invalid value for -p" end
            out_phase[0] = ph

        -- Extra output frequencies: --o1, --o2, --o3
        elseif a == "--o1" or a == "--o2" or a == "--o3" then
            local k = tonumber(a:sub(4))          -- 1, 2, or 3
            i = i + 1
            out_freq[k] = tonumber(args[i])
            if not out_freq[k] then
                return nil, fmt("xilpll: invalid value for %s", a)
            end

        -- Extra output phases: --p1, --p2, --p3
        elseif a == "--p1" or a == "--p2" or a == "--p3" then
            local k = tonumber(a:sub(4))          -- 1, 2, or 3
            i = i + 1
            local ph = tonumber(args[i])
            if not ph then
                return nil, fmt("xilpll: invalid value for %s", a)
            end
            out_phase[k] = ph

        -- Extra output port names: --g1, --g2, --g3
        elseif a == "--g1" or a == "--g2" or a == "--g3" then
            local k = tonumber(a:sub(4))          -- 1, 2, or 3
            i = i + 1
            out_port[k] = args[i] or out_port[k]

        elseif a == "--mmcm" then use_mmcm = true

        elseif a == "-n" then i = i + 1; mod_name    = args[i] or mod_name
        elseif a == "-c" then i = i + 1; clk_in      = args[i] or clk_in
        elseif a == "-g" then i = i + 1; out_port[0] = args[i] or out_port[0]

        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "xilpll - Xilinx 7-series PLLE2_BASE / MMCME2_BASE Verilog generator",
                "",
                "  -i <MHz>        Input clock frequency in MHz (required)",
                "  -o <MHz>        Primary output frequency, CLKOUT0 (required)",
                "  -p <deg>        Primary output phase in degrees    (default: 0.0)",
                "  -g <name>       Primary output port name (default: clock_out)",
                "",
                "  --o1 <MHz>      Second  output frequency, CLKOUT1 (optional)",
                "  --p1 <deg>      Second  output phase in degrees    (default: 0.0)",
                "  --g1 <name>     Second  output port name           (default: clock_out1)",
                "",
                "  --o2 <MHz>      Third   output frequency, CLKOUT2 (optional)",
                "  --p2 <deg>      Third   output phase in degrees    (default: 0.0)",
                "  --g2 <name>     Third   output port name           (default: clock_out2)",
                "",
                "  --o3 <MHz>      Fourth  output frequency, CLKOUT3 (optional)",
                "  --p3 <deg>      Fourth  output phase in degrees    (default: 0.0)",
                "  --g3 <name>     Fourth  output port name           (default: clock_out3)",
                "",
                "  --mmcm          Use MMCME2_BASE instead of PLLE2_BASE",
                "  -n <name>       Module name (default: pll)",
                "  -c <name>       Input clock port name (default: clock_in)",
            }, "\n")

        else
            return nil, "xilpll: unknown option: " .. a
        end
        i = i + 1
    end

    -- ---- Validation ---------------------------------------------------------

    if not f_in      then return nil, "xilpll: input frequency (-i) is required"  end
    if not out_freq[0] then return nil, "xilpll: primary output frequency (-o) is required" end

    local prim = use_mmcm and MMCME2 or PLLE2

    -- Input frequency range
    if f_in < prim.fin_min or f_in > prim.fin_max then
        return nil, fmt("xilpll: input %.3f MHz is outside allowed range %.0f-%.0f MHz for %s",
                        f_in, prim.fin_min, prim.fin_max, prim.name)
    end

    -- Determine which output slots are active (0 = primary, 1..3 = optional)
    local active = { 0 }                         -- always includes slot 0
    for k = 1, 3 do
        if out_freq[k] then active[#active+1] = k end
    end

    -- Count of active outputs must not exceed primitive limit
    -- (PLLE2 has CLKOUT0..5; we expose CLKOUT0..3 = 4 outputs maximum)
    if #active > prim.max_outputs then
        return nil, fmt("xilpll: %s supports at most %d configurable outputs in this generator",
                        prim.name, prim.max_outputs)
    end

    -- Output frequency range and phase checks
    local f_out_min = prim.vco_min / prim.odiv_max
    local f_out_max = prim.vco_max
    for _, k in ipairs(active) do
        local f = out_freq[k]
        if f < f_out_min or f > f_out_max then
            return nil, fmt(
                "xilpll: output%s %.3f MHz is outside achievable range %.3f-%.0f MHz for %s",
                k == 0 and "" or tostring(k), f, f_out_min, f_out_max, prim.name)
        end
        local ph = out_phase[k]
        if ph < 0.0 or ph > 360.0 then
            return nil, fmt("xilpll: phase for output%s must be 0..360 degrees, got %.3f",
                            k == 0 and "" or tostring(k), ph)
        end
    end

    -- ---- Solve for VCO parameters -------------------------------------------
    -- Build a targets array (1-indexed) mapped from the active output list.

    local targets = {}
    for idx, k in ipairs(active) do
        targets[idx] = { freq = out_freq[k], slot = k }
    end

    local fouts_achieved, M, D, divs = solve(f_in, targets, prim)
    if not fouts_achieved then
        return nil, fmt("xilpll: no valid %s configuration found for the requested frequencies",
                        prim.name)
    end

    -- Map solver results back onto per-slot tables
    local slot_fout = {}
    local slot_div  = {}
    for idx, k in ipairs(active) do
        slot_fout[k] = fouts_achieved[idx]
        slot_div[k]  = divs[idx]
    end

    local f_vco = f_in * M / D

    -- Warn for any output where the exact frequency is not achievable
    for _, k in ipairs(active) do
        local err = math.abs(slot_fout[k] - out_freq[k])
        if err > 0.001 then
            print(fmt(
                "xilpll: note: output%s exact frequency not achievable; closest is %.6f MHz (error %.6f MHz)",
                k == 0 and "" or tostring(k), slot_fout[k], err))
        end
    end

    -- CLKIN1_PERIOD in nanoseconds
    local clkin1_period = fmt("%.3f", 1000.0 / f_in)

    -- ---- Verilog generation -------------------------------------------------

    local L = {}
    local function e(s) L[#L+1] = s end

    -- ---- Header comment
    e("/**")
    e(" * PLL configuration")
    e(" *")
    e(" * This Verilog module was generated automatically")
    e(fmt(" * using the xilpll generator for Xilinx 7-series FPGAs (%s).", prim.name))
    e(" *")
    e(fmt(" * Primitive:                  %s", prim.name))
    e(fmt(" * Given input frequency:      %8.3f MHz", f_in))
    e(fmt(" * VCO frequency:              %8.3f MHz", f_vco))
    e(fmt(" * CLKFBOUT_MULT=%d  DIVCLK_DIVIDE=%d", M, D))
    e(" *")
    for _, k in ipairs(active) do
        e(fmt(" * CLKOUT%d: requested %8.3f MHz  achieved %8.3f MHz  phase %.1f deg  divide %d",
              k, out_freq[k], slot_fout[k], out_phase[k], slot_div[k]))
    end
    e(" */")
    e("")

    -- ---- Module declaration
    e(fmt("module %s (", mod_name))
    e(fmt("    input  %s,", clk_in))
    for _, k in ipairs(active) do
        e(fmt("    output %s,", out_port[k]))   -- comma always required: locked/reset follow
    end
    -- locked and reset always present
    e(fmt("    output locked,"))
    e(fmt("    output reset"))
    e("    );")
    e("")
    e("assign reset = ~locked;")
    e("")

    -- ---- Internal wires
    e("// Internal clock wires")
    e("wire clkfbout;       // feedback output from PLL")
    e("wire clkfbout_buf;   // feedback after BUFG")
    for _, k in ipairs(active) do
        e(fmt("wire clkout%d;        // raw CLKOUT%d output from PLL", k, k))
    end
    e("")

    -- ---- Feedback BUFG
    e("// Feedback BUFG: required for internal feedback mode")
    e("BUFG bufg_fb (")
    e("    .I (clkfbout),")
    e("    .O (clkfbout_buf)")
    e(");")
    e("")

    -- ---- PLL / MMCM primitive
    e(fmt("%s #(", prim.name))
    e(fmt("    .BANDWIDTH      (\"OPTIMIZED\"),"))
    e(fmt("    .CLKFBOUT_MULT  (%d),         // VCO = %.3f MHz", M, f_vco))
    e(fmt("    .CLKFBOUT_PHASE (0.0),"))
    e(fmt("    .CLKIN1_PERIOD  (%s),       // fIN = %.3f MHz", clkin1_period, f_in))

    -- Emit parameters for CLKOUT0..3; active outputs get real values, others defaults
    for k = 0, 3 do
        if slot_div[k] then
            -- Active output
            e(fmt("    .CLKOUT%d_DIVIDE     (%d),         // %.3f MHz", k, slot_div[k], slot_fout[k]))
            e(fmt("    .CLKOUT%d_DUTY_CYCLE (0.5),", k))
            e(fmt("    .CLKOUT%d_PHASE      (%.3f),", k, out_phase[k]))
        else
            -- Unused output: emit harmless defaults (divide=1, duty=0.5, phase=0.0)
            e(fmt("    .CLKOUT%d_DIVIDE     (1),", k))
            e(fmt("    .CLKOUT%d_DUTY_CYCLE (0.5),", k))
            e(fmt("    .CLKOUT%d_PHASE      (0.0),", k))
        end
    end

    e(fmt("    .DIVCLK_DIVIDE  (%d),", D))
    e(fmt("    .REF_JITTER1    (0.010),"))
    e(fmt("    .STARTUP_WAIT   (\"FALSE\")"))
    e(fmt(") pll_inst ("))
    e(fmt("    .CLKIN1    (%s),", clk_in))
    e(fmt("    .CLKFBOUT  (clkfbout),"))
    e(fmt("    .CLKFBIN   (clkfbout_buf),"))

    -- Connect CLKOUT0..3 to wires or leave open
    for k = 0, 3 do
        if slot_div[k] then
            e(fmt("    .CLKOUT%d   (clkout%d),", k, k))
        else
            e(fmt("    .CLKOUT%d   (),", k))
        end
    end
    -- CLKOUT4 and CLKOUT5 always left unconnected
    e(fmt("    .CLKOUT4   (),"))
    e(fmt("    .CLKOUT5   (),"))
    e(fmt("    .LOCKED    (locked),"))
    e(fmt("    .RST       (1'b0),"))
    e(fmt("    .PWRDWN    (1'b0)"))
    e(fmt(");"))
    e("")

    -- ---- Output BUFGs
    e("// Output BUFGs: drive PLL outputs onto the global clock network")
    for _, k in ipairs(active) do
        e(fmt("BUFG bufg_out%d (", k))
        e(fmt("    .I (clkout%d),", k))
        e(fmt("    .O (%s)", out_port[k]))
        e(fmt(");"))
        e("")
    end

    e("endmodule")

    return table.concat(L, "\n")
end
