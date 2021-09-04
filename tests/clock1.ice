algorithm test(output int8 l)
{
  int8 ll = 0;
  l := ll;
loop:
  ll = ~ll;
  goto loop;
}

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
  int1  custom_clock = 0;
  int22 count = 0;
  
  test t0<@custom_clock>;

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;
  
  led         := t0.l;

  t0 <- ();
    
loop:
  count = count + 1;
  if (count == 0) {
    custom_clock = ~custom_clock;
  }
  goto loop;  
}
