-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    altpll.lua
    ----------
    Generates a Verilog wrapper module instantiating the Altera/Intel ALTPLL
    megafunction, suitable for Quartus II / Quartus Prime synthesis.

    Depends on: allpll.lua  (must be on the Lua path or in the same directory)

    The ALTPLL megafunction is Quartus-only -- it is not supported by
    open-source toolchains (Yosys/nextpnr).  Quartus resolves the
    multiply/divide ratios into actual M/N/C VCO counter values at
    compile time and validates them against hardware constraints.

    Frequency formula:
        fOUT = fIN * multiply_by / divide_by

    The solver finds the smallest integer pair (multiply_by, divide_by)
    that exactly represents the ratio fOUT/fIN, then checks that:
        - Both counters are within the device family counter range
        - VCO = fIN * multiply_by is within the family VCO range
    If the exact ratio does not fit, the solver searches for the best
    approximation within the counter limits.

    PLL frequency limits used (conservative values across speed grades):
        Family              Counter max   VCO min    VCO max   fIN max
        Cyclone             32            300 MHz    800 MHz   200 MHz
        Cyclone II          32            300 MHz    800 MHz   200 MHz
        Cyclone III         512           600 MHz   1300 MHz   400 MHz
        Cyclone IV E        512           600 MHz   1300 MHz   400 MHz
        Cyclone IV GX       512           600 MHz   1300 MHz   400 MHz
        Cyclone V           512           600 MHz   1600 MHz   700 MHz
        MAX 10              512           600 MHz   1300 MHz   400 MHz

    Usage:
        dofile('allpll.lua')
        dofile('altpll.lua')

        -- Fully explicit:
        print(altpll('-i 50 -o 100 --family "Cyclone IV E"'))

    Flags:
        -i <MHz>               Input clock frequency in MHz
        -o <MHz>               Output clock frequency in MHz     (required)
        -p <deg>               Phase shift for first output clock in degrees  (default: 0)
        --o1 <MHz>             Second output clock frequency in MHz  (optional)
        --p1 <deg>             Phase shift for second output clock in degrees (default: 0)
        --o2 <MHz>             Third output clock frequency in MHz   (optional)
        --p2 <deg>             Phase shift for third output clock in degrees  (default: 0)
        --o3 <MHz>             Fourth output clock frequency in MHz  (optional)
        --p3 <deg>             Phase shift for fourth output clock in degrees (default: 0)
        --family <name>        Quartus device family string
                               (default: "Cyclone II")
        -n <n>              Verilog module name (default: "pll")
        -c <n>              Input clock port name (default: "clock_in")
        -g <n>              Output clock port name (default: "clock_out")
        reset input is always present (active-high async reset)
        -h / --help            Print this help (returned as error string)

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

-- ---- Board presets -----------------------------------------------------------
-- Each entry: { f_in (MHz), family string }

local BOARDS = {
    de2      = { f_in = 50.0, family = "Cyclone II" },
    de10nano = { f_in = 50.0, family = "Cyclone V"  },
}

-- ---- Device family PLL constraints ------------------------------------------
-- Conservative values sourced from Altera/Intel device datasheets.
-- counter_max: maximum value for M and C (post-scale) counters.
-- vco_min/max: VCO operating range in MHz.
-- fin_max:     maximum input clock frequency to the PLL in MHz.

local FAMILIES = {
    -- Key is the lowercase, whitespace-stripped version of the family string.
    ["cyclone"]      = { counter_max = 32,  vco_min = 300, vco_max =  800, fin_max = 200 },
    ["cycloneii"]    = { counter_max = 32,  vco_min = 300, vco_max =  800, fin_max = 200 },
    ["cycloneiii"]   = { counter_max = 512, vco_min = 600, vco_max = 1300, fin_max = 400 },
    ["cycloneive"]   = { counter_max = 512, vco_min = 600, vco_max = 1300, fin_max = 400 },
    ["cycloneivgx"]  = { counter_max = 512, vco_min = 600, vco_max = 1300, fin_max = 400 },
    ["cyclonev"]     = { counter_max = 512, vco_min = 600, vco_max = 1600, fin_max = 700 },
    ["max10"]        = { counter_max = 512, vco_min = 600, vco_max = 1300, fin_max = 400 },
}

-- Normalise a family string to the lookup key
local function family_key(s)
    return s:lower():gsub("%s+", ""):gsub("[^%a%d]", "")
end

-- Look up family constraints; returns a table or nil.
local function family_limits(family_str)
    return FAMILIES[family_key(family_str)]
end

-- ---- GCD / fraction reduction -----------------------------------------------

local function gcd(a, b)
    while b ~= 0 do a, b = b, a % b end
    return a
end

-- ---- Solver -----------------------------------------------------------------
--
-- Strategy: express fOUT/fIN as a reduced fraction M/N.
-- If M and N both fit within counter_max, the VCO (fIN * M) is in range,
-- and fOUT is a valid output frequency, we accept it.
--
-- If the exact ratio overflows the counter limits we search for the
-- best rational approximation using the Stern-Brocot / mediant approach,
-- keeping both numerator and denominator within counter_max.
--
-- Returns: fout_achieved, multiply_by, divide_by   or   nil on failure.

local function solve(f_in, f_out, limits)
    local cmax = limits.counter_max

    -- Try exact rational representation first.
    -- Represent f_out/f_in as p/q in lowest terms.
    -- Use integer arithmetic scaled by 1000 to avoid float precision issues
    -- with common frequencies (e.g. 50->100 => 2/1, 50->33.333... won't be exact).
    local scale = 1000
    local p = round(f_out * scale)
    local q = round(f_in  * scale)
    local g = gcd(p, q)
    p = p / g
    q = q / g

    -- Check if the reduced fraction fits
    if p <= cmax and q <= cmax then
        local f_vco = f_in * p
        if f_vco >= limits.vco_min and f_vco <= limits.vco_max then
            return f_in * p / q, p, q
        end
        -- VCO out of range with exact M/N; try scaling up (multiply both by k)
        -- so VCO = fIN * (p*k) lands in [vco_min, vco_max].
        local k_min = math.ceil(limits.vco_min / (f_in * p))
        local k_max = math.floor(limits.vco_max / (f_in * p))
        for k = k_min, k_max do
            local m = p * k
            local n = q * k
            if m <= cmax and n <= cmax then
                return f_in * m / n, m, n
            end
        end
    end

    -- Fall back: best rational approximation via Stern-Brocot tree search.
    -- Find m/n with 1 <= m,n <= cmax minimising |fIN*m/n - fOUT|,
    -- subject to VCO = fIN*m being in [vco_min, vco_max].
    local best_fout, best_m, best_n
    local best_err = math.huge

    -- Constrain M to keep VCO in range: m in [vco_min/fIN, vco_max/fIN]
    local m_lo = math.ceil(limits.vco_min / f_in)
    local m_hi = math.floor(limits.vco_max / f_in)
    m_lo = math.max(1, m_lo)
    m_hi = math.min(cmax, m_hi)

    for m = m_lo, m_hi do
        -- For this m, best n = round(fIN*m / fOUT)
        local n_ideal = f_in * m / f_out
        for n = math.max(1, math.floor(n_ideal)), math.min(cmax, math.ceil(n_ideal)) do
            local fout = f_in * m / n
            local err  = math.abs(fout - f_out)
            if err < best_err then
                best_err  = err
                best_fout = fout
                best_m    = m
                best_n    = n
            end
        end
    end

    if not best_fout then return nil end
    return best_fout, best_m, best_n
end

-- ---- Public function --------------------------------------------------------

function altpll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_in      = nil
    local f_out     = nil
    local phase_deg = 0       -- phase shift for clk0 (first output) in degrees
    local family    = "Cyclone II"
    local mod_name  = "pll"
    local clk_in    = "clock_in"
    local clk_out   = "clock_out"

    -- Extra output clocks: up to 3 entries indexed 1-3
    -- Each entry: { f_out=MHz, phase_deg=degrees }
    local extra_clocks = {}

    -- Parse arguments
    local i = 1
    while i <= #args do
        local a = args[i]

        if a == "-i" then
            i = i + 1
            f_in = tonumber(args[i])
            if not f_in then return nil, "altpll: invalid value for -i" end

        elseif a == "-o" then
            i = i + 1
            f_out = tonumber(args[i])
            if not f_out then return nil, "altpll: invalid value for -o" end

        elseif a == "-p" then
            i = i + 1
            local pv = tonumber(args[i])
            if not pv then return nil, "altpll: invalid value for -p" end
            phase_deg = pv

        elseif a == "--o1" or a == "--o2" or a == "--o3" then
            local idx = tonumber(a:sub(4))
            i = i + 1
            local fv = tonumber(args[i])
            if not fv then return nil, "altpll: invalid value for " .. a end
            extra_clocks[idx] = extra_clocks[idx] or { f_out = nil, phase_deg = 0 }
            extra_clocks[idx].f_out = fv

        elseif a == "--p1" or a == "--p2" or a == "--p3" then
            local idx = tonumber(a:sub(4))
            i = i + 1
            local pv = tonumber(args[i])
            if not pv then return nil, "altpll: invalid value for " .. a end
            extra_clocks[idx] = extra_clocks[idx] or { f_out = nil, phase_deg = 0 }
            extra_clocks[idx].phase_deg = pv

        elseif a == "--family" then
            i = i + 1
            family = args[i] or family

        elseif a == "-n" then
            i = i + 1; mod_name = args[i] or mod_name
        elseif a == "-c" then
            i = i + 1; clk_in  = args[i] or clk_in
        elseif a == "-g" then
            i = i + 1; clk_out = args[i] or clk_out


        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "altpll - Altera/Intel ALTPLL megafunction Verilog wrapper generator",
                "  -i <MHz>          Input clock frequency in MHz",
                "  -o <MHz>          Output clock frequency in MHz (required)",
                "  -p <deg>          Phase shift for first output clock in degrees (default: 0)",
                "  --o1 <MHz>        Second output clock frequency in MHz (optional)",
                "  --p1 <deg>        Phase shift for second output clock in degrees (default: 0)",
                "  --o2 <MHz>        Third output clock frequency in MHz (optional)",
                "  --p2 <deg>        Phase shift for third output clock in degrees (default: 0)",
                "  --o3 <MHz>        Fourth output clock frequency in MHz (optional)",
                "  --p3 <deg>        Phase shift for fourth output clock in degrees (default: 0)",
                "  --family <name>   Quartus device family string (default: Cyclone II)",
                "  -n <n>         Module name (default: pll)",
                "  -c <n>         Input clock port name (default: clock_in)",
                "  -g <n>         Output clock port name (default: clock_out)",
            }, "\n")

        else
            return nil, "altpll: unknown option: " .. a
        end
        i = i + 1
    end

    -- Validate required arguments
    if not f_in  then return nil, "altpll: input frequency (-i) is required"  end
    if not f_out then return nil, "altpll: output frequency (-o) is required" end

    -- Look up family limits
    local limits = family_limits(family)
    if not limits then
        -- Unknown family: warn and use Cyclone II limits as a conservative fallback
        print(fmt("altpll warning: unknown family '%s', using Cyclone II limits as fallback", family))
        limits = FAMILIES["cycloneii"]
    end

    -- Frequency range checks
    if f_in < 1.0 or f_in > limits.fin_max then
        return nil, fmt("altpll: input %.3f MHz is outside allowed range 1-%.0f MHz for %s",
                        f_in, limits.fin_max, family)
    end
    -- ALTPLL can synthesise any output the VCO range allows; reject obviously
    -- unreachable targets (below minimum VCO / maximum counter, or above max VCO).
    local f_out_min = limits.vco_min / limits.counter_max
    local f_out_max = limits.vco_max
    if f_out < f_out_min or f_out > f_out_max then
        return nil, fmt("altpll: output %.3f MHz is outside achievable range %.3f-%.0f MHz for %s",
                        f_out, f_out_min, f_out_max, family)
    end

    -- Solve
    local fout_achieved, multiply_by, divide_by = solve(f_in, f_out, limits)
    if not fout_achieved then
        return nil, fmt("altpll: cannot find valid M/N counters for %.3f -> %.3f MHz (%s)",
                        f_in, f_out, family)
    end

    local f_vco = f_in * multiply_by
    local err   = math.abs(fout_achieved - f_out)
    if err > 0.001 then
        print(fmt("altpll: note: exact frequency not achievable; closest is %.6f MHz (error %.6f MHz)",
                  fout_achieved, err))
    end

    -- Phase shift for clk0: convert degrees to picoseconds of clk0's period
    local clk0_period_ps = round(1.0e6 / fout_achieved)
    local clk0_phase_ps  = round((phase_deg / 360.0) * clk0_period_ps)

    -- Validate extra output clocks.  All share the same VCO (f_vco = fIN * multiply_by).
    -- Each extra clock uses its own C-counter: fOUTn = f_vco / Cn.
    -- Phase is converted from degrees to picoseconds for the defparam.
    local extra_solved = {}   -- [1..3] = { divide_by, phase_ps, fout }
    for idx = 1, 3 do
        local ec = extra_clocks[idx]
        if ec then
            if not ec.f_out then
                return nil, fmt("altpll: --o%d frequency is required when --p%d is given", idx, idx)
            end
            if ec.f_out < f_out_min or ec.f_out > f_out_max then
                return nil, fmt("altpll: --o%d %.3f MHz is outside achievable range %.3f-%.0f MHz for %s",
                                idx, ec.f_out, f_out_min, f_out_max, family)
            end
            -- Best C-counter for this output
            local c_ideal = f_vco / ec.f_out
            local c_div   = math.max(1, math.min(limits.counter_max, round(c_ideal)))
            local fout_ec = f_vco / c_div
            local err_ec  = math.abs(fout_ec - ec.f_out)
            if err_ec > 0.001 then
                print(fmt("altpll: note: --o%d exact frequency not achievable; closest is %.6f MHz (error %.6f MHz)",
                          idx, fout_ec, err_ec))
            end
            -- Phase degrees -> picoseconds of this output clock's period
            local period_ps = round(1.0e6 / fout_ec)
            local phase_ps  = round((ec.phase_deg / 360.0) * period_ps)
            extra_solved[idx] = { divide_by = c_div, phase_ps = phase_ps, fout = fout_ec }
        end
    end

    -- inclk0_input_frequency is the input period in picoseconds (integer)
    local inclk0_ps = round(1.0e6 / f_in)   -- 1e6 ps / MHz = period in ps

    -- ---- Verilog generation -------------------------------------------------

    local L = {}
    local function e(s) L[#L+1] = s end

    e("/**")
    e(" * PLL configuration")
    e(" *")
    e(" * This Verilog module was generated automatically")
    e(" * using the altpll generator for Altera/Intel FPGAs (Quartus).")
    e(" *")
    e(fmt(" * Device family:               %s", family))
    e(fmt(" * Given input frequency:      %8.3f MHz", f_in))
    e(fmt(" * Requested output frequency: %8.3f MHz", f_out))
    e(fmt(" * Achieved output frequency:  %8.3f MHz", fout_achieved))
    e(fmt(" * Phase shift (clk0):        %8d ps  (%g deg)",
          clk0_phase_ps, phase_deg))
    e(fmt(" * VCO frequency:              %8.3f MHz  (multiply_by=%d, divide_by=%d)",
          f_vco, multiply_by, divide_by))
    for idx = 1, 3 do
        local es = extra_solved[idx]
        if es then
            e(fmt(" * Extra clock %d (clk%d):        %8.3f MHz  (divide_by=%d, phase=%d ps)",
                  idx, idx, es.fout, es.divide_by, es.phase_ps))
        end
    end
    e(" *")
    e(" * NOTE: This module is for Quartus synthesis only. The ALTPLL")
    e(" * megafunction is not supported by open-source toolchains.")
    e(" */")
    e("")

    -- Module declaration
    e(fmt("module %s (", mod_name))
    e(fmt("    input  %s,", clk_in))
    e(fmt("    output %s,", clk_out))
    for idx = 1, 3 do
        if extra_solved[idx] then
            e(fmt("    output clock_out%d,", idx))
        end
    end
    e("    output locked,")
    e("    output reset")
    e("    );")
    e("")
    e("assign reset = ~locked;")
    e("")

    -- Internal wires (altpll clock bus and unused signals)
    e("wire [4:0] sub_wire0;")
    e(fmt("wire sub_wire1 = sub_wire0[0];"))
    e(fmt("assign %s = sub_wire1;", clk_out))
    for idx = 1, 3 do
        if extra_solved[idx] then
            e(fmt("wire sub_wire%d = sub_wire0[%d];", idx + 1, idx))
            e(fmt("assign clock_out%d = sub_wire%d;", idx, idx + 1))
        end
    end
    e("")

    -- ALTPLL instantiation
    e("altpll altpll_component (")
    e(fmt("    .inclk  ({1'b0, %s}),", clk_in))
    e("    .areset (1'b0),")
    e("    .clk    (sub_wire0),")
    e("    .locked (locked),")
    -- Tie off all unused optional ports
    e("    .activeclock (),")
    e("    .clkbad (),")
    e("    .clkena ({6{1'b1}}),")
    e("    .clkloss (),")
    e("    .clkswitch (1'b0),")
    e("    .configupdate (1'b0),")
    e("    .enable0 (),")
    e("    .enable1 (),")
    e("    .extclk (),")
    e("    .extclkena ({4{1'b1}}),")
    e("    .fbin (1'b1),")
    e("    .fbmimicbidir (),")
    e("    .fbout (),")
    e("    .fref (),")
    e("    .icdrclk (),")
    e("    .pfdena (1'b1),")
    e("    .phasecounterselect ({4{1'b1}}),")
    e("    .phasedone (),")
    e("    .phasestep (1'b1),")
    e("    .phaseupdown (1'b1),")
    e("    .pllena (1'b1),")
    e("    .scanaclr (1'b0),")
    e("    .scanclk (1'b0),")
    e("    .scanclkena (1'b1),")
    e("    .scandata (1'b0),")
    e("    .scandataout (),")
    e("    .scandone (),")
    e("    .scanread (1'b0),")
    e("    .scanwrite (1'b0),")
    e("    .sclkout0 (),")
    e("    .sclkout1 (),")
    e("    .vcooverrange (),")
    e("    .vcounderrange ()")
    e("    );")

    -- defparam block (Quartus megafunction configuration)
    e("defparam")
    e("    altpll_component.bandwidth_type          = \"AUTO\",")
    e(fmt("    altpll_component.clk0_divide_by          = %d,", divide_by))
    e("    altpll_component.clk0_duty_cycle         = 50,")
    e(fmt("    altpll_component.clk0_multiply_by        = %d,", multiply_by))
    e(fmt("    altpll_component.clk0_phase_shift        = \"%d\",", clk0_phase_ps))
    for idx = 1, 3 do
        local es = extra_solved[idx]
        if es then
            -- clkN uses the shared VCO multiply_by; its own divide_by = C-counter
            e(fmt("    altpll_component.clk%d_divide_by          = %d,", idx, es.divide_by))
            e(fmt("    altpll_component.clk%d_duty_cycle         = 50,", idx))
            e(fmt("    altpll_component.clk%d_multiply_by        = %d,", idx, multiply_by))
            e(fmt("    altpll_component.clk%d_phase_shift        = \"%d\",", idx, es.phase_ps))
        end
    end
    e("    altpll_component.compensate_clock        = \"CLK0\",")
    e(fmt("    altpll_component.inclk0_input_frequency  = %d,", inclk0_ps))
    e(fmt("    altpll_component.intended_device_family  = \"%s\",", family))
    e(fmt("    altpll_component.lpm_hint                = \"CBX_MODULE_PREFIX=%s\",", mod_name))
    e("    altpll_component.lpm_type                = \"altpll\",")
    e("    altpll_component.operation_mode          = \"NORMAL\",")
    e("    altpll_component.pll_type                = \"AUTO\",")
    e("    altpll_component.port_activeclock        = \"PORT_UNUSED\",")
    e("    altpll_component.port_areset             = \"PORT_USED\",")
    e("    altpll_component.port_clkbad0            = \"PORT_UNUSED\",")
    e("    altpll_component.port_clkbad1            = \"PORT_UNUSED\",")
    e("    altpll_component.port_clkloss            = \"PORT_UNUSED\",")
    e("    altpll_component.port_clkswitch          = \"PORT_UNUSED\",")
    e("    altpll_component.port_configupdate       = \"PORT_UNUSED\",")
    e("    altpll_component.port_fbin               = \"PORT_UNUSED\",")
    e("    altpll_component.port_inclk0             = \"PORT_USED\",")
    e("    altpll_component.port_inclk1             = \"PORT_UNUSED\",")
    e("    altpll_component.port_locked             = \"PORT_USED\",")
    e("    altpll_component.port_pfdena             = \"PORT_UNUSED\",")
    e("    altpll_component.port_pllena             = \"PORT_UNUSED\",")
    -- Quartus requires port_clkN for all 5 indices (0-4); width_clock must
    -- always be 5 for synthesis to succeed regardless of how many are active.
    for idx = 0, 4 do
        local used = (idx == 0) or (extra_solved[idx] ~= nil)
        e(fmt("    altpll_component.port_clk%d               = \"%s\",",
              idx, used and "PORT_USED" or "PORT_UNUSED"))
    end
    e("    altpll_component.self_reset_on_loss_lock = \"OFF\",")
    e("    altpll_component.width_clock             = 5;")
    e("")
    e("endmodule")

    return table.concat(L, "\n")
end
