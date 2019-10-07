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
  output int8 led
  )
{
  int4  channel = 4hf;
  int8  tx_data = 0;
  int8  rx_data = 0;
  int1  new_tx_data = 0;
  int1  new_rx_data = 0;
  
  int24 count = 0;
  int1  blink = 0;
  
  // avr module
  avr_interface avr(
    //clk         <: clk,
    rst         <: reset,
    //cclk        <: cclk,
    //spi_ss      <: spi_ss,
    //spi_mosi    <: spi_mosi,
    //spi_sck     <: spi_sck,
    //channel     <: channel,
    rx          <: avr_tx,
    //new_tx_data <: new_tx_data,
    tx_block    <: avr_rx_busy,
    //tx_data     <: tx_data,
    //spi_miso    :> spi_miso,
    //spi_channel :> spi_channel,
    tx          :> avr_rx,
    rx_data     :> rx_data,
    //new_rx_data :> new_rx_data
    <:auto:>
  );

  // echo
  tx_data     := rx_data;
  new_tx_data := new_rx_data;

  led = 0;  
  
loop:

  count = count + 1;

  if (count == 0) {
    if (blink == 0) {
      blink = 1;
      led = 255;
    } else {
      blink = 0;
      led = rx_data;
    }
  }
  
  goto loop;    
  
}
