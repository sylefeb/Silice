import('hdmi_clock.v')

// ----------------------------------------------------

// see also
// - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=36569119
// - https://www.fpga4fun.com/HDMI.html
// - https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/tmds_encoder.v
algorithm tmds_encoder(
  input   uint8  data,
  input   uint2  ctrl,
  input   uint1  data_or_ctrl,
  output  uint10 tmds
) <autorun> {

  uint9 q_m             = 0;
  int6  dc_bias         = 0;
  
  uint4 num_ones        := data[0,1] + data[1,1] + data[2,1] + data[3,1]
                         + data[4,1] + data[5,1] + data[6,1] + data[7,1];

  int6  diff_ones_zeros := q_m[0,1] + q_m[1,1] + q_m[2,1] + q_m[3,1] 
                         + q_m[4,1] + q_m[5,1] + q_m[6,1] + q_m[7,1] - 6d4;

  int1  xored1          := data[1,1] ^ data[0,1];
  int1  xored2          := data[2,1] ^ xored1;
  int1  xored3          := data[3,1] ^ xored2;
  int1  xored4          := data[4,1] ^ xored3;
  int1  xored5          := data[5,1] ^ xored4;
  int1  xored6          := data[6,1] ^ xored5;
  int1  xored7          := data[7,1] ^ xored6;

  int1  xnored1         := ~(data[1,1] ^ data[0,1]);
  int1  xnored2         := ~(data[2,1] ^ xnored1);
  int1  xnored3         := ~(data[3,1] ^ xnored2);
  int1  xnored4         := ~(data[4,1] ^ xnored3);
  int1  xnored5         := ~(data[5,1] ^ xnored4);
  int1  xnored6         := ~(data[6,1] ^ xnored5);
  int1  xnored7         := ~(data[7,1] ^ xnored6);
  
  always {
    // choice of encoding scheme (xor / xnor)
    if ((num_ones > 4) || (num_ones == 4 && data[0,1] == 0)) {
      q_m = { 1b0 , {xnored7,xnored6,xnored5,xnored4,xnored3,xnored2,xnored1} , data[0,1] };  
    } else {
      q_m = { 1b1 , {xored7,xored6,xored5,xored4,xored3,xored2,xored1} , data[0,1] };    
    }
    if (data_or_ctrl) {
      // output data
      if (dc_bias == 0 || diff_ones_zeros == 0) {
        tmds      = {~q_m[8,1] , q_m[8,1], (q_m[8,1] ? q_m[0,8] : ~q_m[0,8])};
        if (q_m[8,1] == 0) {
          dc_bias = dc_bias - diff_ones_zeros;
        } else {
          dc_bias = dc_bias + diff_ones_zeros;
        }
      } else {
        if (  (dc_bias > 0 && diff_ones_zeros > 0)
           || (dc_bias < 0 && diff_ones_zeros < 0) ) {
          tmds    = {1b1, q_m[8,1], ~q_m[0,8] };
          dc_bias = dc_bias + q_m[8,1] - diff_ones_zeros;
        } else {
          tmds    = {1b0,q_m};
          dc_bias = dc_bias - (~q_m[8,1]) + diff_ones_zeros;
        }
      }
    } else {
      // output control
      switch (ctrl) {
        case 2b00: { tmds = 10b1101010100; }
        case 2b01: { tmds = 10b0010101011; }
        case 2b10: { tmds = 10b0101010100; }
        case 2b11: { tmds = 10b1010101011; }
      }
      dc_bias = 0;
    }
  }

}

// ----------------------------------------------------

algorithm tmds_shifter(
  input   uint10 data,
  output! uint1  outbit_p,
  output! uint1  outbit_n,
) <autorun> {
  uint4  mod10 = 0;
  uint10 shift = 0;
  always {
    shift    = (mod10 == 9) ? data : shift[1,9];
    outbit_p =   shift[0,1];
    outbit_n = ~ shift[0,1];
    mod10    = (mod10 == 9) ? 0 : mod10 + 1;
  }
}

// ----------------------------------------------------

algorithm hdmi(
  output  uint10 x,
  output  uint10 y,
  output  uint1  active,
  output  uint1  vblank,
  output! uint3  gpdi_dp,
  output! uint3  gpdi_dn,
  input   uint8  red,
  input   uint8  green,
  input   uint8  blue,
) <autorun> {
    
  uint10 cntx  = 0;
  uint10 cnty  = 0;
  
  uint1  hsync = 0;
  uint1  vsync = 0;
  
  // pll for tmds
  uint1  clk_tmds = uninitialized;
  hdmi_clock pll(
    clk      <: clock,      //  25 MHz
    hdmi_clk :> clk_tmds,   // 250 MHz ... yeeehaw!
  );
  
  uint2  null_ctrl  = 0;
  uint2  sync_ctrl  = 0;
  uint10 tmds_red   = 0;
  uint10 tmds_green = 0;
  uint10 tmds_blue  = 0;
  // encoders
  tmds_encoder tmdsR(
    data         <: red,
    ctrl         <: null_ctrl,
    data_or_ctrl <: active,
    tmds         :> tmds_red
  );
  tmds_encoder tmdsG(
    data         <: green,
    ctrl         <: null_ctrl,
    data_or_ctrl <: active,
    tmds         :> tmds_green
  );
  tmds_encoder tmdsB(
    data         <: blue,
    ctrl         <: sync_ctrl,
    data_or_ctrl <: active,
    tmds         :> tmds_blue
  );
  // shifters
  uint1 r_p = 0;
  uint1 r_n = 0;
  tmds_shifter shiftR<@clk_tmds>(
    data     <: tmds_red,
    outbit_p :> r_p,
    outbit_n :> r_n,
  );
  uint1 g_p = 0;
  uint1 g_n = 0;
  tmds_shifter shiftG<@clk_tmds>(
    data     <: tmds_green,
    outbit_p :> g_p,
    outbit_n :> g_n,
  );
  uint1 b_p = 0;
  uint1 b_n = 0;
  
  tmds_shifter shiftB<@clk_tmds>(
    data     <: tmds_blue,
    outbit_p :> b_p,
    outbit_n :> b_n,
  );
  
  //uint8  red   = 0;
  //uint8  green = 0;
  //uint8  blue  = 0;
  
  gpdi_dp[2,1] := r_p;
  gpdi_dn[2,1] := r_n;
  gpdi_dp[1,1] := g_p;
  gpdi_dn[1,1] := g_n;
  gpdi_dp[0,1] := b_p;
  gpdi_dn[0,1] := b_n;
  
  //red   := cntx;
  //blue  := cnty;
  
  always {

    // synchronization bits
    hsync     = (cntx > 655) && (cntx < 752);
    vsync     = (cnty > 489) && (cnty < 492);
    sync_ctrl = {vsync,hsync};
    
    // active area
    active    = (cntx < 640) && (cnty < 480);    
    // vblank
    vblank    = (cnty >= 480);

    // update coordinates
    cnty      = (cntx == 799) ? (cnty == 524 ? 0 : (cnty + 1)) : cnty;
    cntx      = (cntx == 799) ? 0 : (cntx + 1);
    
    x         = cntx;
    y         = cnty;

  }
}

// ----------------------------------------------------
