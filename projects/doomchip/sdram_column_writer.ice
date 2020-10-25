// SL 2020-04-28
// -------------------------

algorithm sdram_column_writer(
  column_io colio {
    output  draw_col,
    input   y,
    input   palidx,
    input   write,
    input   done,
  },
  sdram_user   sd,  
  output uint1 fbuffer,
) <autorun> {
  
  dualport_bram uint8 col_buffer[$doomchip_height*2$] = uninitialized;
  uint10 drawer_offset = 0; // offset of column being drawn
  uint10 xfer_offset   = $doomchip_height$; // offset of column being transfered
  uint10 xfer_count    = $doomchip_height$; // transfer count
  uint10 xfer_col      = $doomchip_width-1$; // column being transfered
  uint10 last_drawn    = -1;
  uint10 draw_col      = 0;  
  uint1  done          = 0;
  
  sd.rw               := 1; // write to SDRAM
  sd.in_valid         := 0; // maintain low, pulses high
  col_buffer.wenable0 := 1; // write on port0
  col_buffer.wenable1 := 0; // read  on port1
  // column that can be drawn
  colio.draw_col      := draw_col;
  
  always {
    if (colio.write) {
      // write in bram
      col_buffer.addr0  = drawer_offset + colio.y;
      col_buffer.wdata0 = colio.palidx;
    }
    if (colio.done && (last_drawn != draw_col)) {
      last_drawn = draw_col;
      // __display("done received (draw_col: %d)",draw_col);
      done = 1;
    }   
  }
  
  fbuffer = 0;
  while (1) {
    // continue with transfer if not done
    if (xfer_count < $doomchip_height$) {
      // wait for sdram to be available
      while (sd.busy == 1) { }
      // write
      sd.data_in      = col_buffer.rdata1;
      sd.addr         = {~fbuffer,24b0} | (xfer_col) | (xfer_count << 9);
      sd.in_valid     = 1; // go ahead!
      // next      
      xfer_count      = xfer_count + 1;
      if (xfer_count < $doomchip_height$) {
        col_buffer.addr1 = xfer_offset + xfer_count;
      } else {
        // done
        // __display("xfer %d done (count %d)",xfer_col,xfer_count);
        xfer_col         = (draw_col == 0) ? 0 : xfer_col+1;
        draw_col         = (draw_col == $doomchip_width$) ? 0 : draw_col+1; 
        xfer_offset      = (xfer_offset   == 0) ? $doomchip_height$ : 0;
        drawer_offset    = (drawer_offset == 0) ? $doomchip_height$ : 0;
        col_buffer.addr1 = xfer_offset; // position for restart        
        if (draw_col == $doomchip_width$) {
          // frame done
          draw_col = 0;
          // swap buffers on last
          fbuffer  = ~fbuffer;
          // NOTE: risk of tearing if we do not wait vsync
        }
        // __display(" -> next: xfer %d, draw %d",xfer_col,draw_col);
      }
    } else {    
      if (done) {
        done = 0;
        // __display("column %d drawn",draw_col);
        // __display(" -> starting xfer %d",xfer_col);
        // starts xfer
        xfer_count    = 0; 
      }    
    }
  }
  
}

// -------------------------
