import('uart_rx.v')
import('uart_tx.v')
import('spi_slave.v')
import('cclk_detector.v')
import('avr_interface.v')

algorithm main(
  input  int1 cclk,
  input  int1 spi_ss,
  input  int1 spi_sck,
  input  int1 avr_tx,
  input  int1 avr_rx_busy,
  input  int1 spi_mosi,
  output int1 spi_miso,
  output int1 avr_rx,
  output int4 spi_channel,
  output int8 led,
  output int8 d1_c,
  output int8 d1_r,
  output int8 d1_g,
  output int8 d1_b,
  output int8 d2_c,
  output int8 d2_r,
  output int8 d2_g,
  output int8 d2_b
  )
{
  // LEDs
  int8  col   = 0;
  int16 md_r  = 16hffff;
  int16 md_g  = 16hffff;
  int16 md_b  = 16hffff;
  int18 count = 0;
  
  // UART
  int4  channel = 4hf;
  int8  tx_data = 0;
  int8  rx_data = 0;
  int1  new_tx_data = 0;
  int1  new_rx_data = 0;
  
  // avr module
  avr_interface avr(
    rst         <: reset,
    rx          <: avr_tx,
    tx_block    <: avr_rx_busy,
    tx          :> avr_rx,
    <:auto:>
  );
  
  d1_c := ~col;
  d2_c := ~col;
  d1_r := md_r[0,8];
  d1_g := md_g[0,8];
  d1_b := md_b[0,8];
  d2_r := md_r[8,8];
  d2_g := md_g[8,8];
  d2_b := md_b[8,8];

  // echo
  tx_data     := rx_data;
  new_tx_data := new_rx_data;

  led   = 0;
  col   = 0;
  
scanline:
  
  count = count + 1;
  col   = (1 << count[10,3]);
  
  if (new_rx_data) {
    if (rx_data == 49) {
      md_r = 0;
      md_g = 16hffff;
      md_b = 16hffff;
    }
    if (rx_data == 50) {
      md_r = 16hffff;
      md_g = 0;
      md_b = 16hffff;
    }
    if (rx_data == 51) {
      md_r = 16hffff;
      md_g = 16hffff;
      md_b = 0;
    }    
  }
  
  goto scanline;
}
