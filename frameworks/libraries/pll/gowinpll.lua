-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    gowinpll.lua
    ------------
    Lua reimplementation of a PLL generator for the Gowin FPGA family
    (GW1N, GW1NR, GW1NS, GW2A, etc.), targeting the rPLL primitive as
    supported by the Apicula / nextpnr-himbaechel open-source toolchain.

    Depends on: allpll.lua  (must be on the Lua path or in the same directory)

    The rPLL (rational PLL) is the main PLL primitive available on all Gowin
    devices supported by Apicula. It produces two primary outputs:
        CLKOUT  - main output at fCLKOUT (0 deg phase, always the reference)
        CLKOUTP - phase-shifted copy of CLKOUT (phase set via PSDA_SEL)

    IMPORTANT HARDWARE CONSTRAINTS on phase:
        - CLKOUT is always the phase reference; its phase cannot be shifted.
          Therefore -p (phase for CLKOUT) must be 0.
        - CLKOUTP is always at the SAME FREQUENCY as CLKOUT.  Therefore -o1
          must equal -o.  It is only the phase that differs.
        - The phase of CLKOUTP relative to CLKOUT is set by PSDA_SEL (4-bit,
          0-15).  The achievable phase step is:
              step = 360 / ODIV_SEL   (degrees)
          So the achievable phases are: 0, step, 2*step, …, 15*step.
          Only phases that are exact multiples of this step are valid.
          If the requested phase is not achievable exactly, an error is
          returned together with the list of valid phases for the chosen
          ODIV_SEL.

    And one optional divided output:
        CLKOUTD - CLKOUT divided by DYN_SDIV_SEL (2..128)

    Frequency relationships (UG286 section 5.1):
        fPFD    = fCLKIN / IDIV          IDIV  = IDIV_SEL  + 1  (1..64)
        fCLKOUT = fCLKIN * FBDIV / IDIV  FBDIV = FBDIV_SEL + 1  (1..64)
        fVCO    = fCLKOUT * ODIV         ODIV  = ODIV_SEL (must be one of
                                          2,4,8,16,32,48,64,80,96,112,128)

    Constraints (compiler-enforced values used by Apicula/nextpnr):
        PFD   :   3 MHz - 400 MHz
        VCO   : 600 MHz - 1200 MHz
        CLKOUT: ~4.7 MHz - 600 MHz

    The DEVICE parameter is required by the primitive and must match the
    actual target device string (e.g. "GW1N-9C", "GW2A-18", "GW1N-1").

    Usage:
        dofile('allpll.lua')
        dofile('gowinpll.lua')
        -- Basic use (no phase, no second clock):
        print(gowinpll('-i 27 -o 108 --device GW1N-9C'))
        -- With CLKOUTP at 90 degrees:
        print(gowinpll('-i 27 -o 108 --device GW1N-9C -o1 108 -p1 90'))

    Flags:
        -i <MHz>          Input clock frequency in MHz              (required)
        -o <MHz>          Output clock frequency in MHz             (required)
        -p <deg>          Phase for CLKOUT in degrees (must be 0)   (default: 0)
        --o1 <MHz>        Frequency for CLKOUTP output in MHz
                          (must equal -o; CLKOUTP is a phase-shifted copy of
                          CLKOUT, so a different frequency is not possible)
        --p1 <deg>        Phase offset of CLKOUTP relative to CLKOUT in degrees.
                          Must be an exact multiple of (360 / ODIV_SEL).
                          Requires --o1 to also be specified.
        --device <dev>    Target Gowin device string                (required)
        -n <name>         Verilog module name          (default: "pll")
        -c <name>         Clock input port name        (default: "clock_in")
        -g <name>         Clock output port name       (default: "clock_out")
        --clkoutd <name>  Also expose CLKOUTD with this port name and
                          the given integer divisor via --sdiv
        --sdiv <n>        CLKOUTD secondary divisor (2..128, default: 2)
        -h / --help       Print this help (returned as the error string)

    Returns (like all pll generators in this suite):
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

-- ---- rPLL frequency constraints (Apicula/nextpnr compiler-enforced) ----------
-- Source: LiteX gowin_gw1n.py, UG286 section 5.1, Apicula gowin_pack.py

local PFD_MIN    =   3.0   -- MHz
local PFD_MAX    = 400.0   -- MHz
local VCO_MIN    = 600.0   -- MHz  (datasheet says 400 but compiler enforces 600)
local VCO_MAX    = 1200.0  -- MHz
local CLKOUT_MIN =   4.6875 -- MHz  (600/128)
local CLKOUT_MAX = 600.0   -- MHz

-- Allowed ODIV_SEL values (from UG286 Table 5-3 and Apicula source)
local ODIV_VALS = {2, 4, 8, 16, 32, 48, 64, 80, 96, 112, 128}

-- PSDA_SEL is a 4-bit field: 0..15
local PSDA_MAX = 15

-- Phase tolerance for floating-point comparisons (degrees)
local PHASE_TOL = 1e-6

-- ---- Helper: compute achievable CLKOUTP phases for a given ODIV_SEL ---------
-- Returns a table of {psda, phase_deg} pairs (psda 0..15).
local function clkoutp_phases(odiv)
    local step = 360.0 / odiv
    local t = {}
    for psda = 0, PSDA_MAX do
        t[#t+1] = {psda = psda, phase = psda * step}
    end
    return t
end

-- ---- Helper: format a list of achievable phases as a human-readable string --
local function fmt_phase_list(odiv)
    local step = 360.0 / odiv
    local parts = {}
    for psda = 0, PSDA_MAX do
        parts[#parts+1] = fmt("%.4g", psda * step)
    end
    return table.concat(parts, ", ")
end

-- ---- Solver ------------------------------------------------------------------

-- Find the best IDIV_SEL, FBDIV_SEL, ODIV_SEL triple that minimises the
-- absolute error |fCLKOUT_achieved - fCLKOUT_requested|.
-- Ties are broken by preferring VCO frequency closer to the centre of the
-- allowed range (900 MHz), which generally gives better jitter performance.
--
-- When want_clkoutp is true, the solver additionally requires that the
-- requested phase p1_deg is achievable (i.e. is an exact multiple of
-- 360/ODIV_SEL within PHASE_TOL), AND that PSDA_SEL is in 0..15.
-- If no configuration satisfies the phase constraint, the solver returns
-- nil along with a diagnostic table listing, for each candidate ODIV_SEL
-- that would otherwise have been valid, the achievable phases.
--
-- Returns on success:
--   best_fout, idiv_sel, fbdiv_sel, odiv_sel, psda_sel   (psda_sel may be nil)
-- Returns on failure:
--   nil, diagnostics_table  (only when want_clkoutp is true and phase fails)
-- Returns nil (no args) when no frequency solution exists at all.
local function solve(f_in, f_out, want_clkoutp, p1_deg)
    local best_fout, best_idiv, best_fbdiv, best_odiv, best_psda
    local best_err = math.huge
    -- Collect phase-failure candidates for diagnostics (keyed by odiv).
    local phase_fail_odivs = {}  -- only populated when want_clkoutp is true

    for idiv_sel = 0, 63 do
        local idiv  = idiv_sel + 1
        local f_pfd = f_in / idiv
        if f_pfd >= PFD_MIN and f_pfd <= PFD_MAX then
            for fbdiv_sel = 0, 63 do
                local fbdiv    = fbdiv_sel + 1
                local f_clkout = f_in * fbdiv / idiv
                if f_clkout >= CLKOUT_MIN and f_clkout <= CLKOUT_MAX then
                    local err = math.abs(f_clkout - f_out)
                    for _, odiv in ipairs(ODIV_VALS) do
                        local f_vco = f_clkout * odiv
                        if f_vco >= VCO_MIN and f_vco <= VCO_MAX then
                            -- This idiv/fbdiv/odiv combination is frequency-valid.
                            -- Check phase constraint when CLKOUTP is requested.
                            local psda = nil
                            local phase_ok = true
                            if want_clkoutp then
                                local step = 360.0 / odiv
                                -- Normalise requested phase to [0, 360)
                                local p = p1_deg % 360.0
                                local psda_f = p / step
                                local psda_i = math.floor(psda_f + 0.5)  -- round
                                if psda_i > PSDA_MAX then
                                    phase_ok = false
                                elseif math.abs(psda_i * step - p) > PHASE_TOL then
                                    phase_ok = false
                                else
                                    psda = psda_i
                                end
                                if not phase_ok then
                                    -- Record this odiv as a candidate that failed
                                    -- phase (avoid duplicates).
                                    phase_fail_odivs[odiv] = true
                                end
                            end

                            if phase_ok then
                                -- Valid configuration; keep if better.
                                local is_better = err < best_err
                                if not is_better and err == best_err and best_fout then
                                    -- Tie-break: prefer VCO closer to 900 MHz.
                                    local cur_vco  = f_vco
                                    local prev_vco = best_fout * best_odiv
                                    is_better = math.abs(cur_vco - 900) <
                                                math.abs(prev_vco - 900)
                                end
                                if is_better then
                                    best_err   = err
                                    best_fout  = f_clkout
                                    best_idiv  = idiv_sel
                                    best_fbdiv = fbdiv_sel
                                    best_odiv  = odiv
                                    best_psda  = psda
                                end
                            end
                            break  -- only need first valid odiv for this idiv/fbdiv
                        end
                    end
                end
            end
        end
    end

    if not best_fout then
        if want_clkoutp and next(phase_fail_odivs) then
            -- There were frequency-valid solutions but all failed the phase
            -- constraint.  Return a diagnostics table.
            return nil, phase_fail_odivs
        end
        return nil
    end
    return best_fout, best_idiv, best_fbdiv, best_odiv, best_psda
end

-- ---- Public function ---------------------------------------------------------

function gowinpll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_in         = nil
    local f_out        = nil
    local p_deg        = 0        -- -p  : CLKOUT phase (must be 0)
    local f_out1       = nil      -- --o1 : CLKOUTP frequency (must equal f_out)
    local p1_deg       = nil      -- --p1 : CLKOUTP phase (degrees)
    local device       = nil
    local mod_name     = "pll"
    local clk_in       = "clock_in"
    local clk_out      = "clock_out"
    local clkoutp_name = nil      -- nil = CLKOUTP not exposed
    local clkoutd_name = nil      -- nil = CLKOUTD not exposed
    local sdiv         = 2        -- DYN_SDIV_SEL for CLKOUTD

    local i = 1
    while i <= #args do
        local a = args[i]

        if a == "-i" then
            i = i + 1
            f_in = tonumber(args[i])
            if not f_in then return nil, "gowinpll: invalid value for -i" end

        elseif a == "-o" then
            i = i + 1
            f_out = tonumber(args[i])
            if not f_out then return nil, "gowinpll: invalid value for -o" end

        elseif a == "-p" then
            i = i + 1
            p_deg = tonumber(args[i])
            if p_deg == nil then return nil, "gowinpll: invalid value for -p" end

        elseif a == "--o1" then
            i = i + 1
            f_out1 = tonumber(args[i])
            if not f_out1 then return nil, "gowinpll: invalid value for --o1" end

        elseif a == "--p1" then
            i = i + 1
            p1_deg = tonumber(args[i])
            if p1_deg == nil then return nil, "gowinpll: invalid value for --p1" end

        elseif a == "--device" then
            i = i + 1
            device = args[i]
            if not device or device == "" then
                return nil, "gowinpll: --device requires a device name (e.g. GW1N-9C)"
            end

        elseif a == "-n" then
            i = i + 1; mod_name = args[i] or mod_name

        elseif a == "-c" then
            i = i + 1; clk_in = args[i] or clk_in

        elseif a == "-g" then
            i = i + 1; clk_out = args[i] or clk_out

        elseif a == "--clkoutp" then
            i = i + 1; clkoutp_name = args[i] or "clock1_out"

        elseif a == "--clkoutd" then
            i = i + 1; clkoutd_name = args[i] or "clock2_out"

        elseif a == "--sdiv" then
            i = i + 1
            sdiv = tonumber(args[i])
            if not sdiv or sdiv < 2 or sdiv > 128 or math.floor(sdiv) ~= sdiv then
                return nil, "gowinpll: --sdiv must be an integer in 2..128"
            end

        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "gowinpll - Gowin rPLL Verilog generator (Apicula/nextpnr)",
                "  -i <MHz>          Input clock frequency in MHz (required)",
                "  -o <MHz>          Output clock frequency in MHz (required)",
                "  -p <deg>          Phase for CLKOUT in degrees (must be 0; CLKOUT",
                "                   is always the PLL phase reference)",
                "  -o1 <MHz>         Frequency for CLKOUTP (must equal -o).",
                "                   CLKOUTP is a phase-shifted copy of CLKOUT;",
                "                   a different frequency is not possible.",
                "  -p1 <deg>         Phase offset of CLKOUTP relative to CLKOUT.",
                "                   Must be a multiple of (360 / ODIV_SEL).",
                "                   Requires -o1.",
                "  --device <dev>    Target device string, e.g. GW1N-9C (required)",
                "  -n <name>         Module name (default: pll)",
                "  -c <name>         Input clock port name (default: clock_in)",
                "  -g <name>         Output clock port name (default: clock_out)",
                "  --clkoutp <name>  Expose CLKOUTP with given port name",
                "                   (automatically set when -o1 / -p1 are used)",
                "  --clkoutd <name>  Expose CLKOUTD output with given port name",
                "  --sdiv <n>        CLKOUTD divisor 2..128 (default: 2)",
            }, "\n")

        else
            return nil, "gowinpll: unknown option: " .. a
        end
        i = i + 1
    end

    -- ---- Validate required arguments -----------------------------------------

    if not f_in   then return nil, "gowinpll: input frequency (-i) is required"   end
    if not f_out  then return nil, "gowinpll: output frequency (-o) is required"  end
    if not device then return nil, "gowinpll: target device (--device) is required" end

    -- ---- Validate -p (CLKOUT phase) ------------------------------------------
    -- CLKOUT is the PLL phase reference; its phase is fixed at 0.
    -- The hardware provides no mechanism to shift it.
    local p_norm = p_deg % 360.0
    if math.abs(p_norm) > PHASE_TOL and math.abs(p_norm - 360.0) > PHASE_TOL then
        return nil, fmt(
            "gowinpll: -p %.4g is not supported.\n" ..
            "  CLKOUT is the rPLL phase reference and is always at 0 degrees.\n" ..
            "  Only -p 0 (or omitting -p) is valid.\n" ..
            "  To get a phase-shifted output, use -o1 / -p1 (CLKOUTP).",
            p_deg)
    end

    -- ---- Validate -o1 / -p1 (CLKOUTP) ---------------------------------------
    -- Determine whether CLKOUTP is wanted and which port name to use.
    local want_clkoutp = (f_out1 ~= nil) or (p1_deg ~= nil) or (clkoutp_name ~= nil)

    if want_clkoutp then
        -- -o1 and -p1 must both be supplied when either is present (unless the
        -- caller only supplied --clkoutp, in which case we default p1 to 0).
        if f_out1 == nil and p1_deg ~= nil then
            return nil, "gowinpll: -p1 requires -o1 to also be specified"
        end
        if f_out1 ~= nil and p1_deg == nil then
            -- Default phase to 0 when only frequency is given.
            p1_deg = 0.0
        end
        if p1_deg == nil then p1_deg = 0.0 end

        -- CLKOUTP shares CLKOUT's frequency; reject a different value.
        if f_out1 ~= nil and math.abs(f_out1 - f_out) > 1e-6 then
            return nil, fmt(
                "gowinpll: -o1 %.3f MHz differs from -o %.3f MHz.\n" ..
                "  CLKOUTP is a phase-shifted copy of CLKOUT on the rPLL primitive;\n" ..
                "  it always runs at the same frequency as CLKOUT.\n" ..
                "  To obtain a second frequency, use --clkoutd (CLKOUTD = CLKOUT / N).",
                f_out1, f_out)
        end

        -- Auto-assign a port name if none was given via --clkoutp.
        if not clkoutp_name then
            clkoutp_name = "clock1_out"
        end
    end

    -- ---- Frequency range checks ----------------------------------------------

    if f_in < PFD_MIN or f_in > PFD_MAX then
        return nil, fmt("gowinpll: input %.3f MHz is outside allowed range %.0f-%.0f MHz",
                        f_in, PFD_MIN, PFD_MAX)
    end
    if f_out < CLKOUT_MIN or f_out > CLKOUT_MAX then
        return nil, fmt("gowinpll: output %.3f MHz is outside allowed range %.4f-%.0f MHz",
                        f_out, CLKOUT_MIN, CLKOUT_MAX)
    end

    -- Validate CLKOUTD divisor
    if clkoutd_name and (sdiv < 2 or sdiv > 128) then
        return nil, fmt("gowinpll: --sdiv %d is outside valid range 2..128", sdiv)
    end

    -- ---- Solve ---------------------------------------------------------------

    local best_fout, idiv_sel, fbdiv_sel, odiv_sel, psda_sel
    local solve_result, solve_extra = solve(f_in, f_out, want_clkoutp, p1_deg)

    if solve_result == nil then
        if solve_extra then
            -- Phase failure: frequency solutions existed but none satisfied -p1.
            -- Build a diagnostic listing the achievable phases for each
            -- ODIV_SEL that was a frequency candidate.
            local lines = {
                fmt("gowinpll: no valid rPLL configuration found for %.3f -> %.3f MHz",
                    f_in, f_out),
                fmt("  with CLKOUTP phase %.4g degrees.", p1_deg),
                "  The rPLL phase step is (360 / ODIV_SEL) degrees, so only phases",
                "  that are exact multiples of that step are achievable.",
                "  For the ODIV_SEL values that satisfied the frequency constraints,",
                "  the achievable CLKOUTP phases (degrees) are:",
            }
            -- Sort odiv values for a predictable listing.
            local cands = {}
            for odiv, _ in pairs(solve_extra) do cands[#cands+1] = odiv end
            table.sort(cands)
            for _, odiv in ipairs(cands) do
                lines[#lines+1] = fmt("    ODIV_SEL=%3d  step=%-8.4g  phases: %s",
                    odiv, 360.0/odiv, fmt_phase_list(odiv))
            end
            return nil, table.concat(lines, "\n")
        else
            -- No frequency solution at all.
            return nil, fmt(
                "gowinpll: no valid rPLL configuration found for %.3f -> %.3f MHz",
                f_in, f_out)
        end
    end

    best_fout = solve_result
    idiv_sel  = solve_extra  -- NOTE: solve() returns multiple values; re-capture below.

    -- Re-call to properly capture all return values (Lua only allows this via
    -- a direct assignment from the function call).
    best_fout, idiv_sel, fbdiv_sel, odiv_sel, psda_sel =
        solve(f_in, f_out, want_clkoutp, p1_deg)

    local f_vco     = best_fout * odiv_sel
    local f_clkoutd = clkoutd_name and (best_fout / sdiv) or nil

    -- Compute achieved CLKOUTP phase (degrees) for the comment header.
    local achieved_p1 = nil
    if want_clkoutp then
        local step = 360.0 / odiv_sel
        achieved_p1 = (psda_sel or 0) * step
    end

    -- ---- Verilog generation --------------------------------------------------

    local L = {}
    local function e(s) L[#L+1] = s end

    e("/**")
    e(" * PLL configuration")
    e(" *")
    e(" * This Verilog module was generated automatically")
    e(" * using the gowinpll generator for Gowin FPGAs (Apicula/nextpnr).")
    e(" *")
    e(fmt(" * Target device:              %s", device))
    e(fmt(" * Given input frequency:      %8.3f MHz", f_in))
    e(fmt(" * Requested output frequency: %8.3f MHz", f_out))
    e(fmt(" * Achieved output frequency:  %8.3f MHz", best_fout))
    if want_clkoutp then
        e(fmt(" * Requested CLKOUTP phase:    %8.4g deg (relative to CLKOUT)", p1_deg))
        e(fmt(" * Achieved  CLKOUTP phase:    %8.4g deg  (PSDA_SEL=%d, step=%.4g deg)",
              achieved_p1, psda_sel or 0, 360.0/odiv_sel))
    end
    e(fmt(" * PFD frequency:              %8.3f MHz", f_in / (idiv_sel + 1)))
    e(fmt(" * VCO frequency:              %8.3f MHz", f_vco))
    if f_clkoutd then
        e(fmt(" * CLKOUTD frequency:          %8.3f MHz  (CLKOUT / %d)", f_clkoutd, sdiv))
    end
    e(" */")
    e("")

    -- Module ports
    e(fmt("module %s (", mod_name))
    e(fmt("    input  %s,  // %.3f MHz", clk_in, f_in))
    e(fmt("    output %s,  // %.3f MHz", clk_out, best_fout))
    if want_clkoutp then
        e(fmt("    output %s,  // %.3f MHz, %.4g deg phase",
              clkoutp_name, best_fout, achieved_p1))
    end
    if f_clkoutd then
        e(fmt("    output %s,  // %.3f MHz  (CLKOUT / %d)", clkoutd_name, f_clkoutd, sdiv))
    end
    e("    output locked,")
    e("    output reset")
    e("    );")
    e("")
    e("assign reset = ~locked;")
    e("")

    -- rPLL instantiation
    e("rPLL #(")
    e(fmt("    .FCLKIN(\"%g\"),        // input  clock in MHz", f_in))
    e(fmt("    .IDIV_SEL(%d),        // IDIV = %d  ->  PFD = %.3f MHz",
          idiv_sel, idiv_sel+1, f_in/(idiv_sel+1)))
    e(fmt("    .FBDIV_SEL(%d),       // FBDIV = %d  ->  CLKOUT = %.3f MHz",
          fbdiv_sel, fbdiv_sel+1, best_fout))
    e(fmt("    .ODIV_SEL(%d),        // VCO = %.3f MHz",
          odiv_sel, f_vco))
    if want_clkoutp then
        e(fmt("    .PSDA_SEL(\"%d\"),      // CLKOUTP phase = PSDA_SEL * (360/ODIV) = %.4g deg",
              psda_sel or 0, achieved_p1))
    end
    if f_clkoutd then
        e(fmt("    .DYN_SDIV_SEL(%d),    // CLKOUTD = CLKOUT / %d = %.3f MHz",
              sdiv, sdiv, f_clkoutd))
    end
    e(fmt("    .DYN_IDIV_SEL(\"false\"),"))
    e(fmt("    .DYN_FBDIV_SEL(\"false\"),"))
    e(fmt("    .DYN_ODIV_SEL(\"false\"),"))
    e(    "    .CLKFB_SEL(\"internal\"),")
    e(    "    .CLKOUT_BYPASS(\"false\"),")
    e(    "    .CLKOUTP_BYPASS(\"false\"),")
    if f_clkoutd then
        e("    .CLKOUTD_BYPASS(\"false\"),")
        e("    .CLKOUTD_SRC(\"CLKOUT\"),")
    end
    e(fmt("    .DEVICE(\"%s\")", device))
    e(") rpll_inst (")
    e(fmt("    .CLKIN(%s),", clk_in))
    e(    "    .CLKFB(1'b0),")
    e(    "    .FBDSEL(6'b0),")
    e(    "    .IDSEL(6'b0),")
    e(    "    .ODSEL(6'b0),")
    e(    "    .PSDA(4'b0),")
    e(    "    .DUTYDA(4'b0),")
    e(    "    .FDLY(4'b0),")
    e("    .RESET(1'b0),")
    e(    "    .RESET_P(1'b0),")
    e(fmt("    .CLKOUT(%s),", clk_out))
    if want_clkoutp then
        e(fmt("    .CLKOUTP(%s),", clkoutp_name))
    else
        e(    "    .CLKOUTP(),")
    end
    if f_clkoutd then
        e(fmt("    .CLKOUTD(%s),", clkoutd_name))
    else
        e(    "    .CLKOUTD(),")
    end
    e(    "    .CLKOUTD3(),")
    e(    "    .LOCK(locked)")
    e(");"    )
    e("")
    e("endmodule")

    return table.concat(L, "\n")
end
