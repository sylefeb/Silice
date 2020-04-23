// SL 2020-04-22
// Flying over 3D planes

$include('vga_demo_main.ice')

$$div_width    = 16
$$div_unsigned = 1
$$div_shrink   = 3
$include('../../common/divint_any.ice')

// -------------------------

algorithm frame_display(
  input   uint10 pix_x,
  input   uint10 pix_y,
  input   uint1  pix_active,
  input   uint1  pix_vblank,
  output! uint$color_depth$ pix_r,
  output! uint$color_depth$ pix_g,
  output! uint$color_depth$ pix_b
) <autorun> {

  uint$div_width$ inv_y     = 0;  
  uint$div_width$ cur_inv_y = 0;  

  uint9 offs_y = 0;
  uint8 u      = 0;
  uint8 v      = 0;
  uint15 maxv  = 22000;
  
  uint16 pos_u  = 0;
  uint16 pos_v  = 0;

  uint7 lum    = 0;
  uint1 floor  = 0;

  div$div_width$ div(
    ret :> inv_y
  );

  pix_r  := 0; pix_g := 0; pix_b := 0;
  
  // ---------- show time!
  while (1) {

	  // display frame
	  while (pix_vblank == 0) {

      if (pix_active) {
      
        if (pix_y < 240) {
          offs_y = $240 + 32$ - pix_y;
          floor  = 0;
        } else {
          offs_y = pix_y - $240 - 32$;
          floor  = 1;
        }
        
        if (offs_y >= $32 + 3$ && offs_y < 200) {
        
          if (pix_x == 0) {
            // read result from previous
            cur_inv_y = inv_y;
            if (cur_inv_y[3,7] <= 70) {
              lum = 70 - cur_inv_y[3,7];
              if (lum > 63) {
                lum = 63;
              }
            } else {
              lum = 0;
            }
            // divide for next line
            div <- (maxv,offs_y);
          }

          u = pos_u + ((pix_x - 320) * cur_inv_y) >> 8;
          v = pos_v + cur_inv_y[0,6];
          
          if (u[5,1] ^ v[5,1]) {
            if (u[4,1] ^ v[4,1]) {
              pix_r = lum;
              pix_g = lum;
              pix_b = lum;
            } else {
              pix_r = lum[1,6];
              pix_g = lum[1,6];
              pix_b = lum[1,6];
            }
          } else {
            if (u[4,1] ^ v[4,1]) {
              if (floor) {
                pix_g = lum;
              } else {
                pix_b = lum;
              }
            } else {
              if (floor) {
                pix_g = lum[1,6];
              } else {
                pix_b = lum[1,6];
              }
            }
          }          
        }
      
      }
        
    }
    // prepare next    
    pos_u = pos_u + 1024;
    pos_v = pos_v + 3; 
    
    // wait for sync
    while (pix_vblank == 1) {} 
  }

}

// -------------------------
