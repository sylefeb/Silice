// SL 2020-09-05
// Silice HDMI driver
//
// 640x480, 250MHz TMDS from 25MHz pixel clock
//
// Currently limited to the ULX3S, but should be relatively easy to port,
// pending pll and differential serial output primitives
//
// See also
// - https://www.digikey.com/eewiki/pages/viewpage.action?pageId=36569119
// - https://www.fpga4fun.com/HDMI.html
// - https://github.com/lawrie/ulx3s_examples/blob/master/hdmi/tmds_encoder.v

import('hdmi_clock.v')
import('differential_pair.v')

// ----------------------------------------------------

algorithm tmds_encoder(
  input   uint8  data,
  input   uint2  ctrl,
  input   uint1  data_or_ctrl,
  output  uint10 tmds
) <autorun> {

  uint9 q_m             = 0;
  int5  dc_bias         = 0;

  // tracks 'number on ones' in input
  uint4 num_ones        := data[0,1] + data[1,1] + data[2,1] + data[3,1]
                         + data[4,1] + data[5,1] + data[6,1] + data[7,1];
  // tracks 'numbers of ones minus number of zeros' in internal byte
  int5  diff_ones_zeros := q_m[0,1] + q_m[1,1] + q_m[2,1] + q_m[3,1] 
                         + q_m[4,1] + q_m[5,1] + q_m[6,1] + q_m[7,1] - 6d4;

  // XOR chain on input
  int1  xored1          := data[1,1] ^ data[0,1];
  int1  xored2          := data[2,1] ^ xored1;
  int1  xored3          := data[3,1] ^ xored2;
  int1  xored4          := data[4,1] ^ xored3;
  int1  xored5          := data[5,1] ^ xored4;
  int1  xored6          := data[6,1] ^ xored5;
  int1  xored7          := data[7,1] ^ xored6;

  // XNOR chain on input
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
  output! uint1  outbit,
) <autorun> {
  uint4  mod10 = 0;
  uint10 shift = 0;
  always {
    shift    = (mod10 == 9) ? data : shift[1,9];
    outbit   = shift[0,1];
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
  uint1 r_o = 0;
  tmds_shifter shiftR<@clk_tmds>(
    data   <: tmds_red,
    outbit :> r_o,
  );
  uint1 g_o = 0;
  tmds_shifter shiftG<@clk_tmds>(
    data    <: tmds_green,
    outbit :> g_o,
  );
  uint1 b_o = 0;  
  tmds_shifter shiftB<@clk_tmds>(
    data   <: tmds_blue,
    outbit :> b_o,
  );
    
  uint1 r_p = 0;
  uint1 r_n = 0;
  uint1 g_p = 0;
  uint1 g_n = 0;
  uint1 b_p = 0;
  uint1 b_n = 0;
  
  differential_pair outr( I <: r_o, OT :> r_p, OC :> r_n );
  differential_pair outg( I <: g_o, OT :> g_p, OC :> g_n );
  differential_pair outb( I <: b_o, OT :> b_p, OC :> b_n );
  
  // TODO: this is not elegant ; Silice will support direct binding of bit-vectors
  //       at some point, update code when possible and remove r_*,g_*,b_* vars
  gpdi_dp[2,1] := r_p;
  gpdi_dn[2,1] := r_n;
  gpdi_dp[1,1] := g_p;
  gpdi_dn[1,1] := g_n;
  gpdi_dp[0,1] := b_p;
  gpdi_dn[0,1] := b_n;

  always {

    // synchronization bits
    hsync     = (cntx > 655) && (cntx < 752);
    vsync     = (cnty > 489) && (cnty < 492);
    sync_ctrl = {vsync,hsync};
    
    // update coordinates
    cnty      = (cntx == 799) ? (cnty == 524 ? 0 : (cnty + 1)) : cnty;
    cntx      = (cntx == 799) ? 0 : (cntx + 1);
    
    x         = cntx;
    y         = cnty;
    
    // active area
    active    = (cntx < 640) && (cnty < 480);    
    // vblank
    vblank    = (cnty >= 480);

  }
}

// ----------------------------------------------------
