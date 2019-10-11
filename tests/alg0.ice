
algorithm alg(input uint8 num,output uint8 ret)
{
  ret = num;
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

  uint8 num = 231;
  uint8 res = 0;

  alg alg0;

  spi_miso    := 1bz;
  avr_rx      := 1bz;
  spi_channel := 4bzzzz;

  led := res;
  res := 0;

  (res) <- alg0 <- (num);

  
}


