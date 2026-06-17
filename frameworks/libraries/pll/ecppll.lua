-- LLM assisted code
-- Faithful Lua translation of ecppll.cpp (Project Trellis / ECP5 PLL tool)
-- Exposes a single function:
--   pllstr, err = ecppll(cmdline_string)
-- where cmdline_string is the command-line of the original tool (without argv[0]).
-- Returns the Verilog module as a string (or nil on error) and an error string
-- (or nil on success).
--
-- Intended to be loaded with dofile().  Uses allpll.lua (sibling file) for
-- shared helpers (parse_args, round, fmt).

-- ---------------------------------------------------------------------------
-- Bootstrap: load allpll from the same directory as this file.
-- Works whether this file was loaded via require() or dofile().
-- ---------------------------------------------------------------------------
local _allpll
do
  local src = debug.getinfo(1, "S").source
  if src:sub(1,1) == "@" then src = src:sub(2) end
  local dir = src:match("^(.*[/\\])") or "./"
  _allpll = dofile(dir .. "allpll.lua")
end
local parse_args = _allpll.parse_args
local fmt        = _allpll.fmt

-- ---------------------------------------------------------------------------
-- Constants (from ecppll.cpp #defines)
-- ---------------------------------------------------------------------------
local INPUT_MIN  =   8.0
local INPUT_MAX  = 400.0
local OUTPUT_MIN =  10.0
local OUTPUT_MAX = 400.0
local PFD_MIN    =   3.125
local PFD_MAX    = 400.0
local VCO_MIN    = 400.0
local VCO_MAX    = 800.0

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- C fabsf equivalent
local function fabsf(x) return math.abs(x) end

-- C (int) cast: truncate toward zero (same as C cast for positive floats)
local function toint(x)
  if x >= 0 then return math.floor(x) else return math.ceil(x) end
end

-- Replicate C float32 arithmetic.
-- Lua uses double (float64) by default, but the original C code uses float
-- (float32) throughout.  Reproducing the exact same rounding requires us to
-- round intermediate results to the nearest float32 value.
-- We do this with a tiny helper that converts a double to the nearest
-- IEEE-754 single-precision value and back.
local function f32(x)
  -- Pack as 4-byte float, unpack back to double.
  return string.unpack("f", string.pack("f", x))
end

-- ---------------------------------------------------------------------------
-- PLL parameter structures (Lua tables mirror the C structs)
-- ---------------------------------------------------------------------------

local function new_secondary()
  return {
    enabled = false,
    div     = 0,
    cphase  = 0,
    fphase  = 0,
    name    = "",
    freq    = 0.0,
    phase   = 0.0,
  }
end

local function new_pll_params()
  local p = {
    mode           = "SIMPLE",   -- "SIMPLE" or "HIGHRES"
    refclk_div     = 0,
    feedback_div   = 0,
    output_div     = 0,
    primary_cphase = 9,          -- constructor initialises to 9
    clkin_name     = "clock_in",
    clkout0_name   = "clock_out",
    dynamic        = 0,
    reset          = 0,
    standby        = 0,
    feedback_clkout         = 0,
    internal_feedback       = 0,
    internal_feedback_wake  = 0,
    feedback_name  = {"OP", "OS", "OS2", "OS3"},  -- [1]-indexed in Lua
    feedback_wname = {"", "", "", ""},             -- filled later
    clkin_frequency = 0.0,
    secondary      = { new_secondary(), new_secondary(), new_secondary() },
    fout  = 0.0,
    fvco  = 0.0,
    xo2   = false,
  }
  -- constructor sets primary_cphase inside the loop, same value every iter
  for i = 1, 3 do
    p.secondary[i].enabled = false
    p.primary_cphase = 9
  end
  return p
end

-- ---------------------------------------------------------------------------
-- calc_pll_params  (mirrors void calc_pll_params in ecppll.cpp)
-- ---------------------------------------------------------------------------
local function calc_pll_params(params, input, output)
  local error_val = math.huge   -- std::numeric_limits<float>::max()
  for input_div = 1, 128 do
    local fpfd = f32(f32(input) / f32(input_div))
    if fpfd >= PFD_MIN and fpfd <= PFD_MAX then
      for feedback_div = 1, 80 do
        for output_div = 1, 128 do
          local fvco = f32(f32(fpfd) * f32(feedback_div) * f32(output_div))
          if fvco >= VCO_MIN and fvco <= VCO_MAX then
            local fout = f32(f32(fvco) / f32(output_div))
            local diff = fabsf(f32(fout - output))
            local prev_diff = fabsf(f32(params.fout - output))  -- always recompute from stored fout
            -- Mirror exact C condition:
            -- if(fabsf(fout-output) < error || (== error && closer to 600))
            if diff < error_val or
               (diff == error_val and fabsf(f32(fvco - 600)) < fabsf(f32(params.fvco - 600))) then
              error_val          = diff
              params.refclk_div  = input_div
              params.feedback_div = feedback_div
              params.output_div  = output_div
              params.fout        = fout
              params.fvco        = fvco
              -- shift primary by 180 degrees (Lattice convention)
              -- In C: fout/fvco are float but *1e6 promotes to double; ns_phase stored as float
              local ns_phase = f32(1.0 / (fout * 1e6) * 0.5)   -- double arith -> stored to f32
              params.primary_cphase = toint(ns_phase * (fvco * 1e6))  -- f32 * double -> double -> int
            end
          end
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- calc_pll_params_highres  (mirrors void calc_pll_params_highres)
-- ---------------------------------------------------------------------------
local function calc_pll_params_highres(params, input, output)
  local error_val = math.huge
  for input_div = 1, 128 do
    local fpfd = f32(f32(input) / f32(input_div))
    if fpfd >= PFD_MIN and fpfd <= PFD_MAX then
      for feedback_div = 1, 80 do
        for output_div = 1, 128 do
          local fvco = f32(f32(fpfd) * f32(feedback_div) * f32(output_div))
          if fvco >= VCO_MIN and fvco <= VCO_MAX then
            local ffeedback = f32(f32(fvco) / f32(output_div))
            if ffeedback >= OUTPUT_MIN and ffeedback <= OUTPUT_MAX then
              for secondary_div = 1, 128 do
                local fout = f32(f32(fvco) / f32(secondary_div))
                local diff = fabsf(f32(fout - output))
                if diff < error_val or
                   (diff == error_val and fabsf(f32(fvco - 600)) < fabsf(f32(params.fvco - 600))) then
                  error_val          = diff
                  params.mode        = "HIGHRES"
                  params.refclk_div  = input_div
                  params.feedback_div = feedback_div
                  params.output_div  = output_div
                  params.secondary[1].div     = secondary_div
                  params.secondary[1].enabled = true
                  params.secondary[1].freq    = fout
                  params.fout = fout
                  params.fvco = fvco
                end
              end
            end
          end
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- generate_secondary_output  (mirrors void generate_secondary_output)
-- channel is 1-based (Lua), maps to secondary[1..3]
-- ---------------------------------------------------------------------------
local function generate_secondary_output(params, channel, name, frequency, phase)
  local div  = toint(f32(params.fvco) / f32(frequency))
  local freq = f32(f32(params.fvco) / f32(div))
  -- (original prints "sdiv <div>" to stdout; we omit that)

  -- In C all *1e6, /360.0, /8.0 are double literals so float operands promote to double;
  -- each assignment to a C float variable rounds the result back to f32.
  local ns_shift    = f32( 1.0 / (freq * 1e6) * phase / 360.0 )
  local phase_count = f32( ns_shift * (params.fvco * 1e6) )
  local cphase      = toint(phase_count)
  local fphase      = toint( (phase_count - cphase) * 8.0 )

  local ns_actual   = f32( 1.0 / (params.fvco * 1e6) * (cphase + fphase / 8.0) )
  local phase_shift = f32( 360 * ns_actual / (1.0 / (freq * 1e6)) )

  params.secondary[channel].enabled = true
  params.secondary[channel].div     = div
  params.secondary[channel].freq    = freq
  params.secondary[channel].phase   = phase_shift
  params.secondary[channel].cphase  = cphase + params.primary_cphase
  params.secondary[channel].fphase  = fphase
  params.secondary[channel].name    = name
end

-- ---------------------------------------------------------------------------
-- write_pll_config  (mirrors void write_pll_config)
-- Returns the Verilog text as a string instead of writing to a file.
-- ---------------------------------------------------------------------------
local function write_pll_config(params, name)
  local out = {}
  local function w(s) out[#out+1] = s end

  w("// diamond 3.7 accepts this PLL\n")
  w("// diamond 3.8-3.9 is untested\n")
  w("// diamond 3.10 or higher is likely to abort with error about unable to use feedback signal\n")
  w("// cause of this could be from wrong CPHASE/FPHASE parameters\n")
  w(fmt("module %s\n(\n", name))

  if params.reset ~= 0 then
    w("    input reset, // 0:inactive, 1:reset\n")
  end
  if params.standby ~= 0 then
    w("    input standby, // 0:inactive, 1:standby\n")
  end
  if params.dynamic ~= 0 then
    w("    input [1:0] phasesel, // clkout[] index affected by dynamic phase shift (except clkfb), 5 ns min before apply\n")
    w("    input phasedir, // 0:delayed (lagging), 1:advence (leading), 5 ns min before apply\n")
    w("    input phasestep, // 45 deg step, high for 5 ns min, falling edge = apply\n")
    w("    input phaseloadreg, // high for 10 ns min, falling edge = apply\n")
  end
  w(fmt("    input %s, // %g MHz, 0 deg\n", params.clkin_name, params.clkin_frequency))
  w(fmt("    output %s, // %g MHz, 0 deg\n", params.clkout0_name, params.fout))

  for i = 1, 3 do
    -- condition: !(i==0 && HIGHRES)  — in C i is 0-based; here i is 1-based, so i==1
    if not (i == 1 and params.mode == "HIGHRES") and params.secondary[i].enabled then
      w(fmt("    output %s, // %g MHz, %g deg\n",
            params.secondary[i].name,
            params.secondary[i].freq,
            params.secondary[i].phase))
    end
  end

  w("    output locked\n")
  w(");\n")

  if params.internal_feedback ~= 0 or params.mode == "HIGHRES" then
    w("wire clkfb;\n")
  end
  if params.dynamic ~= 0 then
    w("wire [1:0] phasesel_hw;\n")
    w("assign phasesel_hw = phasesel - 1;\n")
  end

  w(fmt("(* FREQUENCY_PIN_CLKI=\"%g\" *)\n", params.clkin_frequency))

  if params.mode ~= "HIGHRES" then
    w(fmt("(* FREQUENCY_PIN_CLKOP=\"%g\" *)\n", params.fout))
  end

  if params.secondary[1].enabled then
    w(fmt("(* FREQUENCY_PIN_CLKOS=\"%g\" *)\n", params.secondary[1].freq))
  end
  if params.secondary[2].enabled then
    w(fmt("(* FREQUENCY_PIN_CLKOS2=\"%g\" *)\n", params.secondary[2].freq))
  end
  if params.secondary[3] and params.secondary[3].enabled then
    w(fmt("(* FREQUENCY_PIN_CLKOS3=\"%g\" *)\n", params.secondary[3].freq))
  end

  w("(* ICP_CURRENT=\"12\" *) (* LPF_RESISTOR=\"8\" *) (* MFG_ENABLE_FILTEROPAMP=\"1\" *) (* MFG_GMCREF_SEL=\"2\" *)\n")
  w(fmt("%s #(\n", params.xo2 and "EHXPLLJ" or "EHXPLLL"))

  w(fmt("        .PLLRST_ENA(\"%s\"),\n",        params.reset ~= 0               and "ENABLED" or "DISABLED"))
  w(fmt("        .INTFB_WAKE(\"%s\"),\n",         params.internal_feedback_wake ~= 0 and "ENABLED" or "DISABLED"))
  w(fmt("        .STDBY_ENABLE(\"%s\"),\n",       params.standby ~= 0            and "ENABLED" or "DISABLED"))
  w(fmt("        .DPHASE_SOURCE(\"%s\"),\n",      params.dynamic ~= 0            and "ENABLED" or "DISABLED"))

  if params.xo2 then
    w("        .OUTDIVIDER_MUXA2(\"DIVA\"),\n")
    w("        .OUTDIVIDER_MUXB2(\"DIVB\"),\n")
    w("        .OUTDIVIDER_MUXC2(\"DIVC\"),\n")
    w("        .OUTDIVIDER_MUXD2(\"DIVD\"),\n")
  else
    w("        .OUTDIVIDER_MUXA(\"DIVA\"),\n")
    w("        .OUTDIVIDER_MUXB(\"DIVB\"),\n")
    w("        .OUTDIVIDER_MUXC(\"DIVC\"),\n")
    w("        .OUTDIVIDER_MUXD(\"DIVD\"),\n")
  end

  w(fmt("        .CLKI_DIV(%d),\n",       params.refclk_div))
  w(        "        .CLKOP_ENABLE(\"ENABLED\"),\n")
  w(fmt("        .CLKOP_DIV(%d),\n",      params.output_div))
  w(fmt("        .CLKOP_CPHASE(%d),\n",   params.primary_cphase))
  w(        "        .CLKOP_FPHASE(0),\n")

  if params.secondary[1].enabled then
    w(        "        .CLKOS_ENABLE(\"ENABLED\"),\n")
    w(fmt("        .CLKOS_DIV(%d),\n",     params.secondary[1].div))
    w(fmt("        .CLKOS_CPHASE(%d),\n",  params.secondary[1].cphase))
    w(fmt("        .CLKOS_FPHASE(%d),\n",  params.secondary[1].fphase))
  end
  if params.secondary[2].enabled then
    w(        "        .CLKOS2_ENABLE(\"ENABLED\"),\n")
    w(fmt("        .CLKOS2_DIV(%d),\n",    params.secondary[2].div))
    w(fmt("        .CLKOS2_CPHASE(%d),\n", params.secondary[2].cphase))
    w(fmt("        .CLKOS2_FPHASE(%d),\n", params.secondary[2].fphase))
  end
  if params.secondary[3] and params.secondary[3].enabled then
    w(        "        .CLKOS3_ENABLE(\"ENABLED\"),\n")
    w(fmt("        .CLKOS3_DIV(%d),\n",    params.secondary[3].div))
    w(fmt("        .CLKOS3_CPHASE(%d),\n", params.secondary[3].cphase))
    w(fmt("        .CLKOS3_FPHASE(%d),\n", params.secondary[3].fphase))
  end

  -- FEEDBK_PATH: feedback_name is 1-based in Lua (index = feedback_clkout+1)
  local fbidx = params.feedback_clkout + 1
  if params.internal_feedback ~= 0 then
    w(fmt("        .FEEDBK_PATH(\"INT_%s\"),\n", params.feedback_name[fbidx]))
  else
    w(fmt("        .FEEDBK_PATH(\"CLK%s\"),\n",  params.feedback_name[fbidx]))
  end
  w(fmt("        .CLKFB_DIV(%d)\n", params.feedback_div))
  w("    ) pll_i (\n")

  if params.reset ~= 0 then
    w("        .RST(reset),\n")
  else
    w("        .RST(1'b0),\n")
  end
  if params.standby ~= 0 then
    w("        .STDBY(standby),\n")
  else
    w("        .STDBY(1'b0),\n")
  end
  w(fmt("        .CLKI(%s),\n", params.clkin_name))

  if params.mode == "HIGHRES" then
    w("        .CLKOP(clkfb),\n")
  else
    w(fmt("        .CLKOP(%s),\n", params.clkout0_name))
  end

  if params.secondary[1].enabled then
    if params.mode == "HIGHRES" then
      w(fmt("        .CLKOS(%s),\n", params.clkout0_name))
    else
      w(fmt("        .CLKOS(%s),\n", params.secondary[1].name))
    end
  end
  if params.secondary[2].enabled then
    w(fmt("        .CLKOS2(%s),\n", params.secondary[2].name))
  end
  if params.secondary[3] and params.secondary[3].enabled then
    w(fmt("        .CLKOS3(%s),\n", params.secondary[3].name))
  end

  if params.internal_feedback ~= 0 or params.mode == "HIGHRES" then
    w("        .CLKFB(clkfb),\n")
  else
    w(fmt("        .CLKFB(%s),\n", params.feedback_wname[fbidx]))
  end

  if params.internal_feedback ~= 0 then
    w("        .CLKINTFB(clkfb),\n")
  else
    w("        .CLKINTFB(),\n")
  end

  if params.dynamic ~= 0 then
    w("        .PHASESEL0(phasesel_hw[0]),\n")
    w("        .PHASESEL1(phasesel_hw[1]),\n")
    w("        .PHASEDIR(phasedir),\n")
    w("        .PHASESTEP(phasestep),\n")
    if params.xo2 then
      w("        .LOADREG(phaseloadreg),\n")
    else
      w("        .PHASELOADREG(phaseloadreg),\n")
    end
  else
    w("        .PHASESEL0(1'b0),\n")
    w("        .PHASESEL1(1'b0),\n")
    w("        .PHASEDIR(1'b1),\n")
    w("        .PHASESTEP(1'b1),\n")
    if params.xo2 then
      w("        .LOADREG(1'b1),\n")
    else
      w("        .PHASELOADREG(1'b1),\n")
    end
  end

  w("        .PLLWAKESYNC(1'b0),\n")
  w("        .ENCLKOP(1'b0),\n")
  w("        .LOCK(locked)\n")
  w("	);\n")
  w("endmodule\n")

  return table.concat(out)
end

-- ---------------------------------------------------------------------------
-- ecppll(cmdline)  — public entry point
-- ---------------------------------------------------------------------------
-- Parse a CLI string (as the original tool would receive it) and return
-- (verilog_string, nil) on success or (nil, error_string) on failure.
-- Warnings (out-of-range frequencies) are silently accumulated and returned
-- as the second value only when they are fatal; non-fatal warnings are
-- ignored (matching the C tool's behaviour of printing to stderr and
-- continuing).
-- ---------------------------------------------------------------------------
function ecppll(cmdline)
  -- -------------------------------------------------------------------------
  -- 1. Parse arguments
  -- -------------------------------------------------------------------------
  local tokens = parse_args(cmdline)

  -- Build a map of option -> value (boolean flags just set to true)
  local vm    = {}   -- vm[key] = value or true
  local warns = {}

  local function get_float(key, tbl, idx)
    local v = tonumber(tbl[idx])
    if not v then
      return nil, fmt("option '--%s' requires a numeric argument", key)
    end
    return v
  end

  local i = 1
  while i <= #tokens do
    local t = tokens[i]
    -- strip leading dashes: --foo or -f
    local key = t:match("^%-%-(.+)") or t:match("^%-(.+)")
    if not key then
      return nil, fmt("unexpected token: %s", t)
    end

    -- Boolean flags
    if key == "help" or key == "h" then
      return nil, "help requested"
    elseif key == "highres" or key == "dynamic" or key == "reset"
        or key == "standby" or key == "internal_feedback"
        or key == "internal_feedback_wake" or key == "xo2" then
      vm[key] = true
      i = i + 1

    -- Options requiring a value
    elseif key == "module"      or key == "n"
        or key == "clkin_name"  or key == "clkout0_name"
        or key == "clkout1_name"or key == "clkout2_name"
        or key == "clkout3_name"
        or key == "file"        or key == "f"
        or key == "feedback_clkout" then
      i = i + 1
      if i > #tokens then
        return nil, fmt("option '--%s' requires an argument", key)
      end
      vm[key] = tokens[i]
      i = i + 1

    elseif key == "clkin" or key == "i"
        or key == "clkout0" or key == "o"
        or key == "o1" or key == "o2" or key == "o3"
        or key == "clkout1" or key == "clkout2" or key == "clkout3"
        or key == "phase1"  or key == "phase2"  or key == "phase3"
        or key == "p"  or key == "p1" or key == "p2" or key == "p3" then
      i = i + 1
      if i > #tokens then
        return nil, fmt("option '--%s' requires a numeric argument", key)
      end
      local v = tonumber(tokens[i])
      if not v then
        return nil, fmt("option '--%s' requires a numeric argument", key)
      end
      vm[key] = v
      i = i + 1
    else
      return nil, fmt("unknown option: --%s", key)
    end
  end

  -- Normalise short aliases
  if vm["i"]  and not vm["clkin"]   then vm["clkin"]   = vm["i"]   end
  if vm["o"]  and not vm["clkout0"] then vm["clkout0"] = vm["o"]   end
  if vm["o1"] and not vm["clkout1"] then vm["clkout1"] = vm["o1"]  end
  if vm["o2"] and not vm["clkout2"] then vm["clkout2"] = vm["o2"]  end
  if vm["o3"] and not vm["clkout3"] then vm["clkout3"] = vm["o3"]  end
  if vm["p"]  and not vm["phase1"]  then vm["phase1"]  = vm["p"]   end  -- -p is primary phase alias
  if vm["p1"] and not vm["phase1"]  then vm["phase1"]  = vm["p1"]  end
  if vm["p2"] and not vm["phase2"]  then vm["phase2"]  = vm["p2"]  end
  if vm["p3"] and not vm["phase3"]  then vm["phase3"]  = vm["p3"]  end
  if vm["n"]  and not vm["module"]  then vm["module"]  = vm["n"]   end
  if vm["f"]  and not vm["file"]    then vm["file"]    = vm["f"]   end

  -- Set defaults for phases (boost default_value(0))
  if not vm["phase1"] then vm["phase1"] = 0.0 end
  if not vm["phase2"] then vm["phase2"] = 0.0 end
  if not vm["phase3"] then vm["phase3"] = 0.0 end

  -- -------------------------------------------------------------------------
  -- 2. Validate required options
  -- -------------------------------------------------------------------------
  if not vm["clkin"] or not vm["clkout0"] then
    return nil, "Error: missing input or output frequency!"
  end

  local inputf  = vm["clkin"]
  local outputf = vm["clkout0"]

  -- Warnings (C code prints to stderr but continues)
  if inputf < INPUT_MIN or inputf > INPUT_MAX then
    warns[#warns+1] = fmt("Warning: Input frequency %gMHz not in range (%gMHz, %gMHz)",
                          inputf, INPUT_MIN, INPUT_MAX)
  end
  if outputf < OUTPUT_MIN or outputf > OUTPUT_MAX then
    warns[#warns+1] = fmt("Warning: Output frequency %gMHz not in range (%gMHz, %gMHz)",
                          outputf, OUTPUT_MIN, OUTPUT_MAX)
  end

  -- -------------------------------------------------------------------------
  -- 3. Build params struct
  -- -------------------------------------------------------------------------
  local params = new_pll_params()
  params.clkin_frequency = inputf

  local module_name = vm["module"] or "pll"

  params.clkin_name   = vm["clkin_name"]   or "clock_in"
  params.clkout0_name = vm["clkout0_name"] or "clock_out"

  -- Default secondary names
  params.secondary[1].name = "clock1_out"
  params.secondary[2].name = "clock2_out"
  params.secondary[3].name = "clock3_out"

  -- -------------------------------------------------------------------------
  -- 4. Compute PLL parameters
  -- -------------------------------------------------------------------------
  if vm["highres"] then
    if vm["clkout1"] then
      warns[#warns+1] = "Cannot specify secondary frequency in highres mode"
    end
    params.secondary[1].name = vm["clkout1_name"] or "clock1_out"
    calc_pll_params_highres(params, inputf, outputf)
  else
    calc_pll_params(params, inputf, outputf)

    if vm["clkout1"] then
      local n = vm["clkout1_name"] or "clock1_out"
      generate_secondary_output(params, 1, n, vm["clkout1"], vm["phase1"])
    end
    if vm["clkout2"] then
      local n = vm["clkout2_name"] or "clock2_out"
      generate_secondary_output(params, 2, n, vm["clkout2"], vm["phase2"])
    end
    if vm["clkout3"] then
      local n = vm["clkout3_name"] or "clock3_out"
      generate_secondary_output(params, 3, n, vm["clkout3"], vm["phase3"])
    end
  end

  -- -------------------------------------------------------------------------
  -- Check requested vs achieved frequencies (for all requested clocks)
  -- -------------------------------------------------------------------------
  local function check_freq(requested, actual, name)
    if requested == nil or actual == nil then return end  -- skip if not set/achieved
    local allowed_diff = 1 -- 1MHz tolerance
    local actual_diff = math.abs(actual - requested)
    if actual_diff > allowed_diff then
      return fmt("PLL cannot generate %s: requested %g MHz, achieved %g MHz",
                 name, requested, actual, actual_diff, allowed_diff)
    end
  end
  -- Check primary output
  local err_str = check_freq(vm["clkout0"], params.fout, "output 0")
  if err_str then
    return nil, err_str
  end
  -- Check secondary outputs only if user requested them
  for i = 1, 3 do
    local req_key = i == 1 and "clkout1" or i == 2 and "clkout2" or "clkout3"
    local sec = params.secondary[i]
    if vm[req_key] ~= nil and sec.enabled then
      err_str = check_freq(vm[req_key], sec.freq, "output " .. i)
      if err_str then
        return nil, err_str
      end
    end
  end

  -- -------------------------------------------------------------------------
  -- 5. Fill remaining params fields
  -- -------------------------------------------------------------------------
  params.xo2     = vm["xo2"]                    and true or false
  params.dynamic = vm["dynamic"]                and 1    or 0
  params.reset   = vm["reset"]                  and 1    or 0
  params.standby = vm["standby"]                and 1    or 0
  params.internal_feedback      = vm["internal_feedback"]      and 1 or 0
  params.internal_feedback_wake = vm["internal_feedback_wake"] and 1 or 0

  -- feedback_name already set in new_pll_params (1-indexed)
  -- feedback_wname: index 1=clkout0, 2=secondary[1], 3=secondary[2], 4=secondary[3]
  params.feedback_wname[1] = params.clkout0_name
  params.feedback_wname[2] = params.secondary[1].name
  params.feedback_wname[3] = params.secondary[2].name
  params.feedback_wname[4] = params.secondary[3].name

  params.feedback_clkout = 0
  if vm["feedback_clkout"] then
    local fc = vm["feedback_clkout"]
    if     fc == "0" then params.feedback_clkout = 0
    elseif fc == "1" then params.feedback_clkout = 1
    elseif fc == "2" then params.feedback_clkout = 2
    elseif fc == "3" then params.feedback_clkout = 3
    end
  end

  -- -------------------------------------------------------------------------
  -- 6. Generate Verilog
  -- -------------------------------------------------------------------------
  local verilog = write_pll_config(params, module_name)

  -- Return warnings as a combined message if any (non-fatal), otherwise nil
  local warn_str = #warns > 0 and table.concat(warns, "\n") or nil
  return verilog, warn_str
end

-- Make usable both as a dofile() target and as a require() module.
-- When loaded with dofile() the return value is the ecppll function itself,
-- so callers can write:
--   local ecppll = dofile("path/to/ecppll.lua")
-- or, after dofile, use the global 'ecppll' directly:
--   dofile("path/to/ecppll.lua")   -- sets nothing globally
-- We expose as a module table so both patterns work:
--   local M = dofile("ecppll.lua"); M.ecppll(...)
-- The simplest contract stated in the task is:
--   pllstr,err = ecppll('...')
-- so we return the function directly (matches "exposed as ecppll").
return ecppll
