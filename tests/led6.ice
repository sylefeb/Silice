algorithm blink(input int8 a,output int1 v)
{
  int32 w = 0;
loop:
  w = w + 1;
  v = ((w & (1 << a)) >> a);
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
  blink b5;
  blink b6;
  blink b7;
  blink b8;
  
  int20 a5 = 24;
  int20 a6 = 25;
  int20 a7 = 26;
  int20 a8 = 27;
  int8  myled = 0;
  
  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;
  led         := myled;

  b5 <- (a5);
  b6 <- (a6);
  b7 <- (a7);
  b8 <- (a8);
  
loop:
  
  myled = 0;
  
  myled = myled | (b5.v << 0);
  myled = myled | (b6.v << 1);
  myled = myled | (b7.v << 2);
  myled = myled | (b8.v << 3);
  myled = myled | (b8.v << 4);
  myled = myled | (b7.v << 5);
  myled = myled | (b6.v << 6);
  myled = myled | (b5.v << 7);
  
  goto loop;
}
