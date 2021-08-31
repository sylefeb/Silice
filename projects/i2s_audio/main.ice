// SL 2021-07-20
// MIT license, see LICENSE_MIT in Silice repo root

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
$$  print('half period counter        : ' .. bit_hperiod_count)
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

  // the sound wave period is stored in a BROM  
  brom int16 wave[] = {
$$for i=1,num_samples do
    $math.floor(1024.0 * math.cos(2*math.pi*i/num_samples))$,
$$end
  };

  uint1  i2s_bck(1); // serial clock (32 periods per audio half period)
  uint1  i2s_lck(1); // audio clock (low: right, high: left)
  
  uint16 data(0);    // data being sent, shifted through i2s_din
  uint4  count(0);   // counter for generating the serial bit clock
                     // NOTE: width may require adjustment on other base freqs.
  uint5  mod32(1);   // modulo 32, for audio clock
  
  always {
    
    // track expressions for posedge and negedge of serial bit clock
    uint1 edge      <:: (count == $bit_hperiod_count-1$);
    uint1 negedge   <:: edge &  i2s_bck;
    uint1 posedge   <:: edge & ~i2s_bck;
    uint1 allsent   <:: mod32 == 0;
   
    // setup pmod as all outputs
    pmod.oenable = 8b11111111;
    // output i2s signals
    pmod.o       = {i2s_lck,data[15,1] /*serial bit*/,i2s_bck,1b0,4b0000};

    // shift data out on negative edge
    if (negedge) {
      if (allsent) {
        // next data (twice per audio period, right then left)
        data        = wave.rdata;
        wave.addr   = ~i2s_lck ? (wave.addr + 1) : wave.addr;
      } else {
        // shift next bit (MSB first)
        // NOTE: as we send 16 bits only, the remaining 16 bits are zeros
        data = data << 1;
      }
    }
    
    // update I2S clocks
    i2s_bck = edge                ? ~i2s_bck : i2s_bck;
    i2s_lck = (negedge & allsent) ? ~i2s_lck : i2s_lck;
    
    // update counter and modulo
    count   = edge    ? 0 : count + 1;
    mod32   = negedge ? mod32 + 1 : mod32;
    
  }
}
