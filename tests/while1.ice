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
  int20 a = 0;
  int8  myled = 0;
  
  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;
  led         := myled;

  myled = 0;
  
  while (1) {
    a = a + 1;
    if (a[19,1] != 0) {
      myled = 255;
    } else {
      myled = 0;
    }
  }
  
}
