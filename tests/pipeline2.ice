
algorithm main()
{
  uint8  i = 0;
  uint8  a = 0;
  uint8  b = 0;
  uint8  v = 10;
  uint8  pipeline_ready = 0;
  uint8  pipeline_i_0 = 0;
  uint8  pipeline_i_1 = 0;
  uint8  pipeline_i_2 = 0;
  uint64 o = 0;

  while (pipeline_i_2 < 8) {
  
    {
      pipeline_i_0 = i;
      a = pipeline_i_0 + 1;
      $display("-----");
      $display("[0] %d",pipeline_i_0);
    } -> {
      pipeline_i_1 = pipeline_i_0;
      if (pipeline_ready >= 1) {
        b = a + 10;
        $display("[1] %d",pipeline_i_1);
      }
    } -> {    
      pipeline_i_2 = pipeline_i_1;
      if (pipeline_ready >= 2) {
        o[pipeline_i_2*8,8] = b;
        $display("[2] [%d] = %d",pipeline_i_2,b);
      }
    }

    i = i + 1;   
    pipeline_ready = pipeline_ready + 1;
    
  }
  i = pipeline_i_2;
  
  $display("%d",o);
}