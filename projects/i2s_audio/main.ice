// check sound freqeuncy with https://www.szynalski.com/tone-generator/

$$  base_freq_mhz      = 12
$$  audio_freq_khz     = 44.1
$$  base_cycle_period  = 1000/base_freq_mhz
$$  target_audio_cycle_period = 1000000/audio_freq_khz
$$  bit_hperiod_count  = math.floor(0.5 + (target_audio_cycle_period / base_cycle_period) / 64 / 2)
$$  true_audio_cycle_period = bit_hperiod_count * 64 * 2 * base_cycle_period
$$  print('main clock cycle period    : ' .. base_cycle_period .. ' nsec')
$$  print('audio cycle period         : ' .. true_audio_cycle_period .. ' nsec')
$$  print('audio effective freq       : ' .. 1000000 / true_audio_cycle_period .. ' kHz')
$$  num_samples = 128
$$  print('wave frequency             : ' .. 1000000000 / true_audio_cycle_period / num_samples .. ' Hz')

// icestick only
$$  if not ICESTICK then
$$    error('this demo is setup for the icestick, changes needed for other boards (clock)')
$$  end

algorithm main(
  output uint5 leds,
  inout  uint8 pmod,
) {

  uint1  i2s_sck(0); // kept low (uses PCM51 internal PLL)
  uint1  i2s_bck(1); // 64x lck
  uint1  i2s_lck(1); // 44.1 MHz
  uint1  i2s_din(0);

  uint16 data(0);
	uint32 mod32(1);
	
	uint3  count(0); // adjust width on higher base frequencies

  brom int16 wave[] = {
$$for i=1,num_samples do
    $math.floor(1024.0 * math.cos(2*math.pi*i/num_samples))$,
$$end
  };

  // setup pmod as all outputs
  pmod.oenable := 8b11111111;
	// output i2s signals
	pmod.o       := {i2s_lck,i2s_din,i2s_bck,i2s_sck,1b0,1b0,1b0,1b0};

  always {
	
    // on posedge or negedge of bit clock?
	  uint1 negedge <:: (count == 0);
	  uint1 posedge <:: (count == $bit_hperiod_count$);
	
	  // shift data out
		if (negedge) {
			if (mod32[0,1]) {
				// next data (called for left and right)
				data        = wave.rdata;
				wave.addr   = ~i2s_lck ? (wave.addr + 1) : wave.addr;
			} else {
				// next bit
				data = data << 1;
			}
  	}
    
    // data out
    i2s_din = data[15,1];		
	  // update I2S clocks
	  i2s_bck = (negedge | posedge)    ? ~i2s_bck : i2s_bck;
	  i2s_lck = (negedge & mod32[0,1]) ? ~i2s_lck : i2s_lck;
    
    // update counters
		count   = (count == $bit_hperiod_count*2-1$) ? 0 : count + 1;
	  mod32   = negedge ? {mod32[0,1],mod32[1,31]} : mod32;
		
	}

}
