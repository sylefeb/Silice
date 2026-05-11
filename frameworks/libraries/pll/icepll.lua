-- LLM assisted code
-- Reviewed / edited by @sylefeb
--[[
    icepll.lua
    ----------
    Lua reimplementation of the icepll tool from the IceStorm project.
    Generates a Verilog module instantiating an iCE40 SB_PLL40_CORE or
    SB_PLL40_PAD primitive, given an input and desired output frequency.

    Depends on: allpll.lua  (must be on the Lua path or in the same directory)

    Usage:
        local icepll = require("icepll")
        local verilog, err = icepll("-i 12 -o 48")
        if verilog then
            print(verilog)
        else
            io.stderr:write(err .. "\n")
        end

    Flags:
        -i <MHz>   Input clock frequency in MHz          (required)
        -o <MHz>   Desired output frequency in MHz       (required)
        -m         Module output mode - always on here, accepted and ignored
        -p         Use SB_PLL40_PAD instead of SB_PLL40_CORE
        -S         Use NON_SIMPLE feedback path (default: SIMPLE)
        -n <name>  Verilog module name                   (default: "pll")
        -c <name>  Clock input port name                 (default: "clock_in")
        -g <name>  Clock output port name                (default: "clock_out")
        -h/--help  Print this help text (returned as the error string)

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
local binstr     = allpll.binstr
local fmt        = allpll.fmt

-- -- iCE40 PLL frequency constraints ------------------------------------------

local ICE_PFD_MIN =  10.0   -- MHz  Phase-frequency detector input range
local ICE_PFD_MAX = 133.0
local ICE_VCO_MIN = 533.0   -- MHz  VCO operating range
local ICE_VCO_MAX = 1066.0
local ICE_OUT_MIN =  16.0   -- MHz  Output frequency range
local ICE_OUT_MAX = 275.0

-- -- Internal helpers ----------------------------------------------------------

--- Map PFD frequency to FILTER_RANGE parameter (iCE40 lookup table).
--- Source: Lattice iCE40 sysCLOCK PLL Design and Usage Guide.
---
--- @param  f_pfd  number  Phase-frequency detector input in MHz
--- @return         integer FILTER_RANGE value 1..6
local function filter_range(f_pfd)
    if     f_pfd < 17  then return 1
    elseif f_pfd < 26  then return 2
    elseif f_pfd < 44  then return 3
    elseif f_pfd < 66  then return 4
    elseif f_pfd < 101 then return 5
    else                    return 6
    end
end

--- Exhaustive solver: find the DIVR/DIVF/DIVQ triple that minimises the
--- absolute error |f_achieved - f_pllout|.
---
--- iCE40 PLL output frequency formula (SIMPLE feedback):
---   F_VCO  = F_PLLIN / (DIVR + 1) * (DIVF + 1)
---   F_OUT  = F_VCO / 2^DIVQ
---
--- Divider ranges (from the iCE40 Technology Library):
---   DIVR : 0..15   (4-bit)
---   DIVF : 0..127  (7-bit)
---   DIVQ : 1..6    (3-bit; DIVQ=0 is reserved)
---
--- @param  f_pllin   number  Input frequency in MHz
--- @param  f_pllout  number  Desired output frequency in MHz
--- @return  fout, divr, divf, divq, frange  on success
--- @return  nil                             on failure (no valid config)
local function analyze(f_pllin, f_pllout)
    local best_fout, best_divr, best_divf, best_divq, best_fr
    local best_err = math.huge

    for divr = 0, 15 do
        local f_pfd = f_pllin / (divr + 1)
        if f_pfd >= ICE_PFD_MIN and f_pfd <= ICE_PFD_MAX then
            for divf = 0, 127 do
                local f_vco = f_pfd * (divf + 1)
                if f_vco >= ICE_VCO_MIN and f_vco <= ICE_VCO_MAX then
                    for divq = 1, 6 do
                        local fout = f_vco / (1 << divq)
                        if fout >= ICE_OUT_MIN and fout <= ICE_OUT_MAX then
                            local err = math.abs(fout - f_pllout)
                            if err < best_err then
                                best_err  = err
                                best_fout = fout
                                best_divr = divr
                                best_divf = divf
                                best_divq = divq
                                best_fr   = filter_range(f_pfd)
                            end
                        end
                    end
                end
            end
        end
    end

    if not best_fout then return nil end
    return best_fout, best_divr, best_divf, best_divq, best_fr
end

-- -- Public function -----------------------------------------------------------

--- Generate an iCE40 PLL Verilog module from a CLI argument string.
---
--- @param  args_string  string  CLI-style arguments (see module header)
--- @return               string  Verilog source on success
--- @return               nil, string  on failure
function icepll(args_string)
    local args = parse_args(args_string or "")

    -- Defaults
    local f_pllin   = nil
    local f_pllout  = nil
    local use_pad   = false
    local simple_fb = true
    local mod_name  = "pll"
    local clk_in    = "clock_in"
    local clk_out   = "clock_out"

    -- Argument parsing
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-i" then
            i = i + 1
            f_pllin = tonumber(args[i])
            if not f_pllin then return nil, "icepll: invalid value for -i" end
        elseif a == "-o" then
            i = i + 1
            f_pllout = tonumber(args[i])
            if not f_pllout then return nil, "icepll: invalid value for -o" end
        elseif a == "-p" then
            use_pad = true
        elseif a == "-S" then
            simple_fb = false
        elseif a == "-m" then
            -- module output mode is always on in this implementation; ignore
        elseif a == "-n" then
            i = i + 1; mod_name = args[i] or mod_name
        elseif a == "-c" then
            i = i + 1; clk_in = args[i] or clk_in
        elseif a == "-g" then
            i = i + 1; clk_out = args[i] or clk_out
        elseif a == "-h" or a == "--help" then
            return nil, table.concat({
                "icepll - iCE40 PLL Verilog generator",
                "  -i <MHz>   Input frequency in MHz (required)",
                "  -o <MHz>   Output frequency in MHz (required)",
                "  -m         Module mode (always on here, ignored)",
                "  -p         Use SB_PLL40_PAD (default: SB_PLL40_CORE)",
                "  -S         Use NON_SIMPLE feedback path",
                "  -n <name>  Module name (default: pll)",
                "  -c <name>  Clock input port name (default: clock_in)",
                "  -g <name>  Clock output port name (default: clock_out)",
            }, "\n")
        else
            return nil, "icepll: unknown option: " .. a
        end
        i = i + 1
    end

    -- Validate required arguments
    if not f_pllin  then return nil, "icepll: input frequency (-i) is required"  end
    if not f_pllout then return nil, "icepll: output frequency (-o) is required" end

    -- Frequency range checks
    if f_pllin < 10 or f_pllin > 133 then
        return nil, fmt("icepll: input %.3f MHz is outside allowed range 10-133 MHz", f_pllin)
    end
    if f_pllout < ICE_OUT_MIN or f_pllout > ICE_OUT_MAX then
        return nil, fmt("icepll: output %.3f MHz is outside allowed range 16-275 MHz", f_pllout)
    end

    -- Solve
    local best_fout, divr, divf, divq, frange = analyze(f_pllin, f_pllout)
    if not best_fout then
        return nil, fmt("icepll: no valid PLL configuration found for %.3f -> %.3f MHz",
                        f_pllin, f_pllout)
    end

    -- Primitive and port names depend on PAD vs CORE
    local primitive = use_pad and "SB_PLL40_PAD"  or "SB_PLL40_CORE"
    local ref_port  = use_pad and "PACKAGEPIN"     or "REFERENCECLK"
    local out_port  = use_pad and "PLLOUTGLOBAL"   or "PLLOUTCORE"
    local feedback  = simple_fb and "SIMPLE" or "NON_SIMPLE"

    -- Build output line-by-line
    local L = {}
    local function e(s) L[#L + 1] = s end

    e("/**")
    e(" * PLL configuration")
    e(" *")
    e(" * This Verilog module was generated automatically")
    e(" * using the icepll tool from the IceStorm project.")

    e(" *")
    e(fmt(" * Given input frequency:      %8.3f MHz", f_pllin))
    e(fmt(" * Requested output frequency: %8.3f MHz", f_pllout))
    e(fmt(" * Achieved output frequency:  %8.3f MHz", best_fout))
    e(" */")
    e("")
    e(fmt("module %s (", mod_name))
    e(fmt("\tinput  %s,", clk_in))
        e(fmt("\toutput %s,", clk_out))
    e("\toutput locked,")
    e("\toutput reset")
    e("\t);")
    e("")
    e("assign reset = ~locked;")
    e("")
    e(fmt("%s #(", primitive))
    e(fmt("\t\t.FEEDBACK_PATH(\"%s\"),",         feedback))
    e(fmt("\t\t.DIVR(4'b%s),\t\t// DIVR = %2d", binstr(divr, 4), divr))
    e(fmt("\t\t.DIVF(7'b%s),\t// DIVF = %2d",   binstr(divf, 7), divf))
    e(fmt("\t\t.DIVQ(3'b%s),\t\t// DIVQ = %2d", binstr(divq, 3), divq))
    e(fmt("\t\t.FILTER_RANGE(3'b%s)\t// FILTER_RANGE = %d", binstr(frange, 3), frange))
    e("\t) uut (")
    e("\t\t.LOCK(locked),")
    e("\t\t.RESETB(1'b1),")
    e("\t\t.BYPASS(1'b0),")
    e(fmt("\t\t.%s(%s),", ref_port, clk_in))
    e(fmt("\t\t.%s(%s)",  out_port, clk_out))
    e("\t);")
    e("endmodule")

    return table.concat(L, "\n")
end

return icepll