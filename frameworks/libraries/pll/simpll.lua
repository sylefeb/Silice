-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    simpll.lua
    ----------
    Generates a Verilog module that simulates a PLL for use with Verilator or
    Icarus Verilog under Silice's SIMULATION define.

    IMPORTANT CONSTRAINTS
    =====================
    Verilator does not support #delay statements, so the simulated clocks must
    be driven externally (the testbench drives clock_in at some frequency).
    All output clocks are derived from clock_in using posedge-only counter
    logic (no negedge, no #delay).

    Because of this:
      * Every output frequency must be <= freq_in / 2  (you need at least two
        clock_in cycles to produce one output cycle with posedge-only logic).
      * Every output frequency must divide freq_in evenly; any rounding error
        is treated as a fatal error when freq_in is user-specified.

    PHASE SHIFTS
    ============
    Phase shifts are implemented by initialising each output counter and clock
    register at a non-zero value.  The phase of each clock is expressed as a
    fraction of that clock's own period (not clock_in's period).

    The full output cycle of a clock with half-period divisor D spans 2*D
    input ticks (D ticks low, D ticks high at 0 deg).  A phase of ph degrees
    shifts the output by k = round(ph / 360 * 2 * D) ticks into that cycle:
      cnt_init = k % D
      clk_init = 1 if k >= D, else 0
    So ph=180 exactly inverts the clock (clk_init=1, cnt_init=0), and
    ph=90 starts the clock halfway through its low half.

    This is exact only when ph/360 * 2*D is an integer, i.e. D must be a
    multiple of 720/gcd(720, ph).

    When freq_in is user-specified:
      The achieved phase must be within 1 degree of the requested phase,
      otherwise an error is raised.

    When freq_in is auto-selected:
      The generator folds the phase constraint into the LCM search: for each
      output with a non-zero integer phase ph (degrees), the divisor D must
      satisfy D % (720 / gcd(720, ph)) == 0.  This is ensured by requiring
      freq_in to be a multiple of f * (720 / gcd(720, ph)).
      Phases must be integer degrees in auto mode.

    Usage (mirrors the other pll generators):
        local simpll = require("simpll")
        local verilog, err = simpll("-i 100 -o 25 --o1 50 --p1 90 -n mypll")
        if verilog then print(verilog) else io.stderr:write(err.."\n") end

    Flags:
        -i / --clkin_freq <MHz>      Input clock frequency in MHz (optional)
        -o / --clkout0_freq <MHz>    Primary output frequency     (required)
        -p / --phase0 <deg>          Phase for primary output     (default: 0)
        --o1 / --clkout1_freq <MHz>  Secondary output 1 frequency
        --o2 / --clkout2_freq <MHz>  Secondary output 2 frequency
        --o3 / --clkout3_freq <MHz>  Secondary output 3 frequency
        --p1 / --phase1 <deg>        Phase for output 1           (default: 0)
        --p2 / --phase2 <deg>        Phase for output 2           (default: 0)
        --p3 / --phase3 <deg>        Phase for output 3           (default: 0)
        -n / --module_name <name>    Verilog module name          (default: "pll")
        -f <file>                    Accepted and ignored
        -h / --help                  Print this help text

    Returns:
        On success: verilog_string, nil
        On failure: nil, error_string
--]]

-- Load allpll from the same directory as this file, regardless of whether
-- this file was loaded via require() or via dofile().
local allpll = (function()
    if package.loaded["allpll"] then return package.loaded["allpll"] end
    local src = debug.getinfo(1, "S").source
    local dir = (src:sub(1,1) == "@" and src:sub(2) or src):match("^(.*[/\\])") or "./"
    local m   = dofile(dir .. "allpll.lua")
    package.loaded["allpll"] = m
    return m
end)()

local parse_args = allpll.parse_args
local round      = allpll.round
local fmt        = allpll.fmt

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

--- Greatest common divisor (integers only, Euclidean).
local function gcd(a, b)
    a, b = math.abs(a), math.abs(b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

--- Least common multiple of two positive integers.
local function lcm(a, b)
    return (a // gcd(a, b)) * b
end

--- Return true when x is (very nearly) an integer.
local function is_integer(x)
    return math.abs(x - round(x)) < 1e-9
end

--- For a phase of ph degrees (integer) the divisor D must be a multiple of
--- 720/gcd(720,ph) so that round(ph/360*2*D) reproduces ph exactly.
--- (Factor of 2 because the full output cycle spans 2*D input ticks.)
--- Returns that required divisor factor (1 when ph==0).
local function phase_divisor_factor(ph)
    if ph == 0 then return 1 end
    return 720 // gcd(720, ph)
end

--- Find the smallest integer freq_in (in MHz) such that:
---   - freq_in >= 2 * max(freqs)                  (posedge-only constraint)
---   - freq_in / f  is an integer for every output f
---   - (freq_in / f) is a multiple of phase_divisor_factor(ph)
---     for every output (f, ph) pair with ph ~= 0
---
--- Strategy: build a per-output "unit" u[i] = f[i] * phase_divisor_factor(ph[i]).
--- freq_in must be a multiple of every u[i] (which guarantees both that
--- freq_in/f[i] is an integer AND that it is a multiple of the phase factor).
--- Then take the smallest multiple of lcm(all u[i]) that is >= 2*max(freqs).
--- phase_divisor_factor uses 720 (not 360) because the full output cycle
--- spans 2*D input ticks, giving step size 360/(2*D) degrees.
---
--- All frequencies and phases must be integer values in auto mode.
---
--- @param  outputs  table  list of { f=MHz, ph=degrees } records
--- @return           number  freq_in on success
--- @return           nil, string  on failure
local function find_freq_in(outputs)
    for _, o in ipairs(outputs) do
        if not is_integer(o.f) then
            return nil, fmt(
                "simpll: auto freq_in requires all output frequencies to be "..
                "integer MHz values, but %.6f MHz is not", o.f)
        end
        if not is_integer(o.ph) then
            return nil, fmt(
                "simpll: auto freq_in requires all phase values to be "..
                "integer degrees, but %.6f deg is not", o.ph)
        end
    end

    -- Build LCM of all per-output units (f * phase_factor).
    local base  = 1
    local max_f = 0
    for _, o in ipairs(outputs) do
        local fi   = round(o.f)
        local pf   = phase_divisor_factor(round(o.ph))
        local unit = fi * pf
        base  = lcm(base, unit)
        if fi > max_f then max_f = fi end
    end

    -- Minimum freq_in imposed by the posedge-only (divisor >= 2) constraint.
    local min_freq_in = 2 * max_f
    local k = math.ceil(min_freq_in / base)
    if k < 1 then k = 1 end
    return k * base
end

--- Compute and validate the integer divisor and counter init value for every
--- active output, given a concrete freq_in.
---
--- For each output idx with frequency f and phase ph:
---   divisor   = freq_in / f             (must be integer and >= 2)
---   cnt_init  = round(ph / 360 * divisor)
---   achieved  = cnt_init / divisor * 360  (degrees)
---   error     = |achieved - ph|           (must be < 1 deg when freq_in given)
---
--- @param freq_in     number   Input frequency in MHz
--- @param out_freqs   table    [0..3] -> MHz (nil entries skipped)
--- @param out_phases  table    [0..3] -> degrees
--- @param user_given  boolean  true when freq_in came from the -i flag
--- @return             table   results[idx] = {div, cnt_init, ph_req, ph_got}
--- @return             nil, string  on failure
local function compute_outputs(freq_in, out_freqs, out_phases, user_given)
    local results = {}
    for idx = 0, 3 do
        local f  = out_freqs[idx]
        if f then
            local ph = out_phases[idx] or 0

            -- Divisor check
            local raw_div = freq_in / f
            if raw_div < 2 then
                return nil, fmt(
                    "simpll: output %d frequency %.3f MHz >= freq_in/2 (%.3f MHz).\n"..
                    "  Posedge-only simulation requires divisor >= 2.\n"..
                    "  freq_in must be at least %.3f MHz for this output.",
                    idx, f, freq_in / 2, f * 2)
            end
            if not is_integer(raw_div) then
                if user_given then
                    return nil, fmt(
                        "simpll: output %d frequency %.6f MHz does not divide "..
                        "freq_in %.6f MHz evenly (divisor = %.10f).\n"..
                        "  Choose a freq_in that is an exact integer multiple of "..
                        "all output frequencies.",
                        idx, f, freq_in, raw_div)
                else
                    return nil, fmt(
                        "simpll: internal error - non-integer divisor %.10f "..
                        "for output %d (%.6f MHz) with auto freq_in %.3f MHz",
                        raw_div, idx, f, freq_in)
                end
            end
            local div = round(raw_div)

            -- Phase: compute offset k into the full 2*D-tick output cycle.
            -- k = round(ph / 360 * 2 * D)
            -- cnt_init = k % D   (position within the current half-cycle)
            -- clk_init = 1 if k >= D (we start in the high half), else 0
            local k        = round(ph / 360.0 * 2 * div)
            local cnt_init = k % div
            local clk_init = (k >= div) and 1 or 0
            local ph_got   = (k / (2.0 * div)) * 360.0

            -- Error check: wrap-aware absolute difference.
            local ph_err = math.abs(ph_got - ph)
            if ph_err > 180 then ph_err = 360 - ph_err end
            if user_given and ph_err > 1.0 then
                return nil, fmt(
                    "simpll: output %d phase cannot be achieved within 1 degree.\n"..
                    "  Requested: %.3f deg, best achievable: %.3f deg "..
                    "(divisor %d, step size %.3f deg).\n"..
                    "  To get exact phase, use a freq_in divisible by %d*%d = %d MHz.",
                    idx, ph, ph_got, div, 360.0 / (2 * div),
                    round(f), phase_divisor_factor(round(ph)),
                    round(f) * phase_divisor_factor(round(ph)))
            end

            results[idx] = {
                div      = div,
                cnt_init = cnt_init,
                clk_init = clk_init,
                ph_req   = ph,
                ph_got   = ph_got,
            }
        end
    end
    return results
end

-- ---------------------------------------------------------------------------
-- Public function
-- ---------------------------------------------------------------------------

--- Generate a simulation PLL Verilog module from a CLI argument string.
---
--- @param  args_string  string  CLI-style arguments (see module header)
--- @return               string  Verilog source on success
--- @return               nil, string  on failure
function simpll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_in       = nil    -- nil means "auto-detect"
    local out_freqs  = {}     -- [0..3] -> MHz or nil
    local out_phases = {}     -- [0..3] -> degrees (default 0)
    local mod_name   = "pll"

    -- Argument parsing
    local i = 1
    while i <= #args do
        local a = args[i]

        if     a == "-i" or a == "--clkin_freq"   then
            i = i + 1
            f_in = tonumber(args[i])
            if not f_in then return nil, "simpll: invalid value for -i / --clkin_freq" end

        elseif a == "-o" or a == "--clkout0_freq" then
            i = i + 1
            out_freqs[0] = tonumber(args[i])
            if not out_freqs[0] then return nil, "simpll: invalid value for -o / --clkout0_freq" end

        elseif a == "-p" or a == "--phase0"       then
            i = i + 1; out_phases[0] = tonumber(args[i]) or 0

        elseif a == "--clkout1_freq" or a == "--o1" then
            i = i + 1
            out_freqs[1] = tonumber(args[i])
            if not out_freqs[1] then return nil, "simpll: invalid value for --o1 / --clkout1_freq" end
        elseif a == "--clkout2_freq" or a == "--o2" then
            i = i + 1
            out_freqs[2] = tonumber(args[i])
            if not out_freqs[2] then return nil, "simpll: invalid value for --o2 / --clkout2_freq" end
        elseif a == "--clkout3_freq" or a == "--o3" then
            i = i + 1
            out_freqs[3] = tonumber(args[i])
            if not out_freqs[3] then return nil, "simpll: invalid value for --o3 / --clkout3_freq" end

        elseif a == "--phase1" or a == "--p1"     then
            i = i + 1; out_phases[1] = tonumber(args[i]) or 0
        elseif a == "--phase2" or a == "--p2"     then
            i = i + 1; out_phases[2] = tonumber(args[i]) or 0
        elseif a == "--phase3" or a == "--p3"     then
            i = i + 1; out_phases[3] = tonumber(args[i]) or 0

        elseif a == "-n" or a == "--module_name"  then
            i = i + 1; mod_name = args[i] or mod_name

        elseif a == "-f" then
            i = i + 1  -- output file path; accepted and ignored

        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "simpll - Simulation PLL Verilog generator (Verilator / Icarus)",
                "",
                "  -i / --clkin_freq <MHz>      Input clock frequency in MHz (optional)",
                "                               If omitted, the smallest valid freq_in",
                "                               is chosen automatically and displayed.",
                "  -o / --clkout0_freq <MHz>    Primary output frequency     (required)",
                "  -p / --phase0 <deg>          Phase for primary output     (default: 0)",
                "  --o1 / --clkout1_freq <MHz>  Secondary output 1 frequency",
                "  --o2 / --clkout2_freq <MHz>  Secondary output 2 frequency",
                "  --o3 / --clkout3_freq <MHz>  Secondary output 3 frequency",
                "  --p1 / --phase1 <deg>        Phase for output 1           (default: 0)",
                "  --p2 / --phase2 <deg>        Phase for output 2           (default: 0)",
                "  --p3 / --phase3 <deg>        Phase for output 3           (default: 0)",
                "  -n / --module_name <name>    Verilog module name          (default: pll)",
                "  -f <file>                    Accepted and ignored",
                "",
                "CONSTRAINTS:",
                "  * Output frequency <= freq_in / 2  (posedge-only, no #delay).",
                "  * freq_in must divide evenly by every output frequency.",
                "  * When freq_in is given, each phase must be achievable within 1 degree.",
                "  * When freq_in is auto-selected, all frequencies and phases must be",
                "    integer values (MHz and degrees respectively).",
            }, "\n")

        else
            -- Silently ignore unknown flags (matches upstream pll generators).
        end
        i = i + 1
    end

    -- Primary output is required.
    if not out_freqs[0] then
        return nil, "simpll: output frequency (-o / --clkout0_freq) is required"
    end

    -- Sanity: no output frequency may be <= 0.
    for idx, f in pairs(out_freqs) do
        if f <= 0 then
            return nil, fmt("simpll: output %d frequency must be positive (got %.3f)", idx, f)
        end
    end

    -- Fill missing phases with 0.
    for idx = 0, 3 do
        if out_freqs[idx] and not out_phases[idx] then
            out_phases[idx] = 0
        end
    end

    -- Collect active outputs in index order (needed for find_freq_in).
    local active_outputs = {}
    for idx = 0, 3 do
        if out_freqs[idx] then
            active_outputs[#active_outputs + 1] = {
                idx = idx,
                f   = out_freqs[idx],
                ph  = out_phases[idx],
            }
        end
    end

    -- Resolve freq_in.
    local auto_freq_in = (f_in == nil)
    if auto_freq_in then
        local found, errmsg = find_freq_in(active_outputs)
        if not found then return nil, errmsg end
        f_in = found
        print(fmt("[simpll] auto-selected freq_in = %.0f MHz"..
                  "  (drive clock_in at this frequency in the testbench)", f_in))
    end

    -- Compute divisors, counter inits, and achieved phases.
    local outs, errmsg = compute_outputs(f_in, out_freqs, out_phases, not auto_freq_in)
    if not outs then return nil, errmsg end

    -- Secondary output port names (mirrors ecppll convention).
    local sec_name = { [1]="clock1_out", [2]="clock2_out", [3]="clock3_out" }

    -- -----------------------------------------------------------------------
    -- Verilog generation
    -- -----------------------------------------------------------------------
    local L = {}
    local function e(s) L[#L + 1] = s end

    -- Header comment
    e("/**")
    e(" * Simulation PLL")
    e(" *")
    e(" * Generated by simpll.lua for Verilator / Icarus Verilog.")
    e(" * Uses posedge-only counter logic; no #delay, no negedge.")
    e(" * Phase shifts are implemented via counter initialisation.")
    e(" *")
    e(fmt(" * Input  frequency : %.3f MHz%s",
          f_in, auto_freq_in and "  (auto-selected)" or ""))
    for _, o in ipairs(active_outputs) do
        local r = outs[o.idx]
        e(fmt(" * Output %d : %.3f MHz, phase req %.3f deg, achieved %.3f deg"..
              "  (divisor %d, cnt_init %d, clk_init %d)",
              o.idx, f_in / r.div, r.ph_req, r.ph_got, r.div, r.cnt_init, r.clk_init))
    end
    e(" */")
    e("")

    -- Module declaration
    e(fmt("module %s (", mod_name))
    e(fmt("    input  clock_in,   // %.3f MHz - drive from testbench", f_in))
    for k, o in ipairs(active_outputs) do
        local r       = outs[o.idx]
        local is_last = (k == #active_outputs)
        local comma   = is_last and "" or ","
        local oname   = (o.idx == 0) and "clock_out" or sec_name[o.idx]
        e(fmt("    output %s%s // %.3f MHz, phase %.3f deg  (/%d)",
              oname, comma, f_in / r.div, r.ph_got, r.div))
    end
    e("    );")
    e("")

    -- One counter per output.
    -- Counter width = number of bits needed to represent values 0..div-1.
    local function counter_width(div)
        local w = 1
        while (1 << w) < div do w = w + 1 end
        return w
    end

    for _, o in ipairs(active_outputs) do
        local r     = outs[o.idx]
        local div   = r.div
        local cw    = counter_width(div)
        local oname = (o.idx == 0) and "clock_out" or sec_name[o.idx]
        e(fmt("    // --- Output %d : %.3f MHz, phase %.3f deg"..
              "  (divisor %d, cnt_init %d, clk_init %d) ---",
              o.idx, f_in / div, r.ph_got, div, r.cnt_init, r.clk_init))
        e(fmt("    reg [%d:0] cnt%d = %d;", cw - 1, o.idx, r.cnt_init))
        e(fmt("    reg       clk%d = %d;",   o.idx, r.clk_init))
        e(fmt("    assign %s = clk%d;", oname, o.idx))
        e(fmt("    always @(posedge clock_in) begin"))
        e(fmt("        if (cnt%d == %d) begin", o.idx, div - 1))
        e(fmt("            cnt%d <= 0;", o.idx))
        e(fmt("            clk%d <= ~clk%d;", o.idx, o.idx))
        e(fmt("        end else begin"))
        e(fmt("            cnt%d <= cnt%d + 1;", o.idx, o.idx))
        e(fmt("        end"))
        e(fmt("    end"))
        e("")
    end

    e("endmodule")

    return table.concat(L, "\n")
end

return simpll
