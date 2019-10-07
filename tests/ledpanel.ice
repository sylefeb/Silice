algorithm main(
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
  int8  col  = 0;
  int16 md_r = 0;
  int16 md_g = 16hffff;
  int16 md_b = 16hffff;
  
  int18 count = 0;
  int16 level = 0;
  
  d1_c := ~col;
  d2_c := ~col;
  d1_r := md_r[0,8];
  d1_g := md_g[0,8];
  d1_b := md_b[0,8];
  d2_r := md_r[8,8];
  d2_g := md_g[8,8];
  d2_b := md_b[8,8];

  led   = 0;
  col   = 0;
  count = 0;
  
scanline:
  
  count = count + 1;
  col   = (1 << count[10,3]);
  
  level = count[0,7];
  
  md_r = 16hffff;
  md_g = 16hffff;
  
  16x {
    if (__id*4 > level) {
      md_r[__id,1] = 1b0;
    }
    if (col*2 > level) {
      md_g[__id,1] = 1b0;
    }
  }
  
  goto scanline;
}
