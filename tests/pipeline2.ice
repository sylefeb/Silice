
algorithm main(output uint8 leds)
{
  uint8  i = 0;
  uint8  a = 0;
  uint8  b = 0;
  uint8  v = 10;
  uint8  pipeline_ready = 0;
  uint8  pipeline_i = 0;
  uint64 o = 0;

  while (i < 8+2) {

    {
      pipeline_i = i;
      a          = i + 1;
      $display("-----");
      $display("[0] %d",pipeline_i);
    } -> {
      if (pipeline_ready >= 1) {
        b = a + 10;
        $display("[1] %d",pipeline_i);
      }
    } -> {
      if (pipeline_ready >= 2) {
        o[pipeline_i*8,8] = b;
        $display("[2] [%d] = %h",pipeline_i,b);
      }
    }

    i = i + 1;
    pipeline_ready = pipeline_ready + 1;

  }

  $display("%h",o);
}
