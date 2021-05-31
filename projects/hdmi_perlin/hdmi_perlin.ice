// -------------------------

// HDMI driver
$include('../common/hdmi.ice')

// ----------------------------------------------------

$$if not ULX3S then
$$ -- error('this project has been only tested for the ULX3S, other boards will require some changes')
$$end

// ULX3S clock
import('../common/ulx3s_clk_100_25.v')

algorithm main(
  // led
  output uint8  leds(0),
  // video
  output uint4  gpdi_dp,
) <@clock_100mhz> {

  uint1 clock_25mhz(0);
  uint1 clock_100mhz(0);
  ulx3s_clk_100_25 pll(
    clkin   <: clock,
    clkout0 :> clock_100mhz, // we run the procedural texture clock at 100MHz
    clkout1 :> clock_25mhz   // video signal runs at 25MHz (640x480)
  );
 
  hdmi video<@clock_25mhz>(
    gpdi_dp :> gpdi_dp,
  );

  uint4 mod4(4b0001); // indicates which sub-cycle of video signal we are in

$$N_UVECS = 16
  uint8 unitVec_x[] = {
$$for n=0,N_UVECS do
    $math.floor(math.min(255.0,math.max(0.0,128.0 + 128.0*math.cos(math.pi*2.0*n/N_UVECS))))$,
$$end
  };
  uint8 unitVec_y[] = {
$$for n=0,N_UVECS do
    $math.floor(math.min(255.0,math.max(0.0,128.0 + 128.0*math.sin(math.pi*2.0*n/N_UVECS))))$,
$$end
  };

// from https://gist.github.com/nowl/828013 (value noise impl.)
$$permut = '208,34,231,213,32,248,233,56,161,78,24,140,71,48,140,254,245,255,247,247,40,185,248,251,245,28,124,204,204,76,36,1,107,28,234,163,202,224,245,128,167,204,9,92,217,54,239,174,173,102,193,189,190,121,100,108,167,44,43,77,180,204,8,81,70,223,11,38,24,254,210,210,177,32,81,195,243,125,8,169,112,32,97,53,195,13,203,9,47,104,125,117,114,124,165,203,181,235,193,206,70,180,174,0,167,181,41,164,30,116,127,198,245,146,87,224,149,206,57,4,192,210,65,210,129,240,178,105,228,108,245,148,140,40,35,195,38,58,65,207,215,253,65,85,208,76,62,3,237,55,89,232,50,217,64,244,157,199,121,252,90,17,212,203,149,152,140,187,234,177,73,174,193,100,192,143,97,53,145,135,19,103,13,90,135,151,199,91,239,247,33,39,145,101,120,99,3,186,86,99,41,237,203,111,79,220,135,158,42,30,154,120,67,87,167,135,176,183,191,253,115,184,21,233,58,129,233,142,39,128,211,118,137,139,255,114,20,218,113,154,27,127,246,250,1,8,198,250,209,92,222,173,21,88,102,219'

  brom uint9 permut00[] = { $permut$ };
  brom uint9 permut01[] = { $permut$ };
  brom uint9 permut11[] = { $permut$ };
  brom uint9 permut10[] = { $permut$ };

  //uint12 vx00(0);
  //uint12 vx10(0);
  //uint12 vx_0(0);

  //uint12 vx01(0);
  //uint12 vx11(0);
  //uint12 vx_1(0);

  uint12 v(0);

  always { 
    
    uint7 ci <:: video.x >> 4;
    uint7 cj <:: video.y >> 4;
    uint4 li <:: video.x & 15;
    uint4 lj <:: video.y & 15;

    uint12 vx00 <:: unitVec_x[permut00.rdata[0,4]];
    uint12 vx10 <:: unitVec_x[permut10.rdata[0,4]];
    uint12 vx_0 <:: vx00 + (((vx10 - vx00) * li) >> 4);

    uint12 vx01 <:: unitVec_x[permut01.rdata[0,4]];
    uint12 vx11 <:: unitVec_x[permut11.rdata[0,4]];
    uint12 vx_1 <:: vx01 + (((vx11 - vx01) * li) >> 4);

    uint12 v    <:: vx_0 + (((vx_1 - vx_0) * lj) >> 4);

    permut00.addr = (mod4[3,1]) ?  ci    : (cj ^ permut00.rdata[0,8]);
    permut10.addr = (mod4[3,1]) ? (ci+1) : (cj ^ permut10.rdata[0,8]);

    permut01.addr = (mod4[3,1]) ?  ci    : ((cj+1) ^ permut01.rdata[0,8]);
    permut11.addr = (mod4[3,1]) ? (ci+1) : ((cj+1) ^ permut11.rdata[0,8]);

    if (video.active) {

      video.red   = v;
      video.green = v;
      video.blue  = v;

    } else {

      video.red   = 0;
      video.green = 0;
      video.blue  = 0;

    }

    mod4 = {mod4[0,3],mod4[3,1]};
    
  }
  
}

// ----------------------------------------------------
