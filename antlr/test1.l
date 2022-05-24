algorithm doomchip(
  column_io colio {
    input   draw_col,
    output  y,
    output  palidx,
    output  write,
    output  done,
  },
  input uint1   vsync,
$$if ULX3S or DE10NANO then
  input  uint7  btns,
$$end
  output uint8  leds,
) <autorun> {

}