// MIT license, see LICENSE_MIT in Silice repo root

algorithm main(
  output uint$NUM_LEDS$ leds(0),
  inout  uint8          pmod)
{

  uint20 cnt(0);
  uint20 select(1);

  always {

    onehot (select) {
      case   0:  { pmod.oenable = 8b001000010; pmod.o = 8bxx0xxxx1x; }
      case   1:  { pmod.oenable = 8b001000010; pmod.o = 8bxx1xxxx0x; }
      case   2:  { pmod.oenable = 8b001100000; pmod.o = 8bxx10xxxxx; }
      case   3:  { pmod.oenable = 8b001000001; pmod.o = 8bxx1xxxxx0; }
      case   4:  { pmod.oenable = 8b001010000; pmod.o = 8bxx1x0xxxx; }
      case   5:  { pmod.oenable = 8b001100000; pmod.o = 8bxx01xxxxx; }
      case   6:  { pmod.oenable = 8b000100010; pmod.o = 8bxxx1xxx0x; }
      case   7:  { pmod.oenable = 8b000100010; pmod.o = 8bxxx0xxx1x; }
      case   8:  { pmod.oenable = 8b000000011; pmod.o = 8bxxxxxxx10; }
      case   9:  { pmod.oenable = 8b000010010; pmod.o = 8bxxxx0xx1x; }
      case  10:  { pmod.oenable = 8b001000001; pmod.o = 8bxx0xxxxx1; }
      case  11:  { pmod.oenable = 8b000000011; pmod.o = 8bxxxxxxx01; }
      case  12:  { pmod.oenable = 8b000100001; pmod.o = 8bxxx0xxxx1; }
      case  13:  { pmod.oenable = 8b000100001; pmod.o = 8bxxx1xxxx0; }
      case  14:  { pmod.oenable = 8b000110000; pmod.o = 8bxxx10xxxx; }
      case  15:  { pmod.oenable = 8b001010000; pmod.o = 8bxx0x1xxxx; }
      case  16:  { pmod.oenable = 8b000010010; pmod.o = 8bxxxx1xx0x; }
      case  17:  { pmod.oenable = 8b000110000; pmod.o = 8bxxx01xxxx; }
      case  18:  { pmod.oenable = 8b000010001; pmod.o = 8bxxxx1xxx0; }
      case  19:  { pmod.oenable = 8b000010001; pmod.o = 8bxxxx0xxx1; }
      default:   { pmod.oenable = 8b000000000; }
    }

    select = cnt == 0 ? {select[0,19],select[19,1]} : select;
    cnt    = cnt + 1;
  }

}
