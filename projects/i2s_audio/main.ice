$$if not ICESTICK then
$$ -- error('this demo is setup for the icestick, changes needed for other boards (clock)')
$$end

$$if not SIMULATION then	
$$  base_freq_mhz  = 12
$$  audio_freq_khz = 16
$$else
$$  base_freq_mhz  = 64
$$  audio_freq_khz = 1000
$$end
$$bit_period_count = math.floor(0.5 + base_freq_mhz * 1000 / audio_freq_khz) // 16
$$print('I2S audio hakf period count: ' .. bit_period_count)

$$ -- error('')

algorithm main(
  output uint5 leds,
$$if not SIMULATION then	
  inout  uint8 pmod,
$$end	
) {

  uint1  i2s_sck(0); // kept low (uses PCM51 internal PLL)
  uint1  i2s_bck(1); // 64x lck
  uint1  i2s_lck(1); // 44.1 MHz
  uint1  i2s_din(0);

  uint16 data(0);
	uint16 mod16(1);
	
	uint8  count(0); // NOTE adjust width on higher base frequencies

  brom uint16 cosine[] = {
$$for i=0,1023 do
    $math.floor(32767.0 + 32767.0 * math.cos(2*math.pi*i/1024))$,
$$end
  };

$$if not SIMULATION then	
  // setup pmod as all outputs
  pmod.oenable := 8b11111111;
	// output i2s signals
	pmod.o       := {i2s_lck,i2s_din,i2s_bck,i2s_sck,1b0,1b0,1b0,1b0};
$$end

  always {
	
	  uint1 period      <:: (count == 0);
	  uint1 half_period <:: (count == $bit_period_count>>1$);
	
	  // shift data out
		if (period) {
			if (mod16[0,1]) {
				// next data
				__display("(count:%d) next data",count);
				data        = cosine.rdata;
				cosine.addr = cosine.addr + 1;
			} else {
				// next bit
				data = (data<<1);
			}
  	}
    i2s_din = data[15,1];		
		
	  // update I2S clocks
	  i2s_bck = (period | half_period) ? ~i2s_bck : i2s_bck;
	  i2s_lck = (period & mod16[0,1])  ? ~i2s_lck : i2s_lck;

		__display("(count:%d) %b %b  data:%b",count,i2s_bck,i2s_lck,data);

    // update counter
		count   = (count == $bit_period_count-1$) ? 0 : count + 1;
	  mod16   = period ? {mod16[0,1],mod16[1,15]} : mod16;
		
	}

}
