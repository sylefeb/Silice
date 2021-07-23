// SL 2021-07-20

// First we use the pre-processor to compute counters
// based on the FPGA frequency and target audio frequency.
// The audio frequency is likely to not be perfectly matched.
$$  base_freq_mhz      = 12   -- FPGA frequency
$$  audio_freq_khz     = 44.1 -- Audio frequency (target)
$$  base_cycle_period  = 1000/base_freq_mhz
$$  target_audio_cycle_period = 1000000/audio_freq_khz
$$  bit_hperiod_count  = math.floor(0.5 + (target_audio_cycle_period / base_cycle_period) / 64 / 2)
$$  true_audio_cycle_period = bit_hperiod_count * 64 * 2 * base_cycle_period
// Print out the periods and the effective audio frequency
$$  print('main clock cycle period    : ' .. base_cycle_period .. ' nsec')
$$  print('audio cycle period         : ' .. true_audio_cycle_period .. ' nsec')
$$  print('audio effective freq       : ' .. 1000000 / true_audio_cycle_period .. ' kHz')
// Print out the sound frequency that will be heard
// This depends on the number of samples along the wave and the audio frequency:
$$  num_samples = 128   -- number of wave samples
$$  print('wave frequency             : ' .. 1000000000 / true_audio_cycle_period / num_samples .. ' Hz')
// IceStick only: issue an error for other boards
$$  if not ICESTICK then
$$    error('this demo is setup for the icestick, changes needed for other boards (clock)')
$$  end

algorithm main(
  output uint5 leds,
  inout  uint8 pmod, // we use a PMOD with inout pins
) {

  uint1  i2s_sck(0); // kept low (uses PCM51 internal PLL)
  uint1  i2s_bck(1); // serial clock (32 periods per audio half period)
  uint1  i2s_lck(1); // audio clock (low: right, high: left)
  uint1  i2s_din(0); // bit being sent

  uint16 data(0);    // data being sent, shifted through i2s_din
  uint3  count(0);   // counter for generating the serial bit clock
                     // NOTE: width may require adjustment on other base freqs.
  uint32 mod32(1);   // modulo 32, for audio clock

  // the sound wave period is stored in a BROM  
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
  
    // track expressions for posedge and negedge of serial bit clock
    uint1 negedge <:: (count == 0);
    uint1 posedge <:: (count == $bit_hperiod_count$);
  
    // shift data out on negative edge
    if (negedge) {
      if (mod32[0,1]) {
        // next data (twice per audio period, right then left)
        data        = wave.rdata;
        wave.addr   = ~i2s_lck ? (wave.addr + 1) : wave.addr;
      } else {
        // shift next bit (MSB first)
        // NOTE: as we send 16 bits only, the remaining 16 bits are zeros
        data = data << 1;
      }
    }
    
    // data out (MSB first)
    i2s_din = data[15,1];   

    // update I2S clocks
    i2s_bck = (negedge | posedge)    ? ~i2s_bck : i2s_bck;
    i2s_lck = (negedge & mod32[0,1]) ? ~i2s_lck : i2s_lck;
    
    // update counter and modulo
    count   = (count == $bit_hperiod_count*2-1$) ? 0 : count + 1;
    mod32   = negedge ? {mod32[0,1],mod32[1,31]} : mod32;
    
  }

}
