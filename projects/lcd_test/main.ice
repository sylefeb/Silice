// MIT license, see LICENSE_MIT in Silice repo root

$$LCD_4BITS=1
$$LCD_2LINES=1
$$LCD_MODE=0

$include('../common/lcd.ice')

algorithm main(
  output uint$NUM_LEDS$ leds = 1,
  output uint8          pmod,
) {
  uint8 data = 0;
  uint1 dummy_rw = uninitialized;

  uint1 pmod1  = uninitialized;
  uint1 pmod2  = uninitialized;
  uint1 pmod3  = uninitialized;
  uint1 pmod4  = uninitialized;
  uint1 pmod7  = uninitialized;
  uint1 pmod8  = uninitialized;
  uint1 pmod9  = uninitialized;
  uint1 pmod10 = uninitialized;

$$if SIMULATION then
  uint8 pmod   = uninitialized;
$$end

  // Instanciate our LCD 1602 controller and bind its parameters to the correct pins
  // (see schematic at the top)
  lcdio io;
  lcd_4_2_5X8 controller(
    lcd_rs        :> pmod7,
    lcd_rw        :> dummy_rw,  // The RW pin is grounded
    lcd_e         :> pmod8,
    lcd_d         :> data,
    io           <:> io,
  );

  uint8 msg1[6] = "Hello";
  uint8 msg2[8] = "Silice!";
  uint4 i = 0;

  // Always set all modes to 0, pulse 1 when needed
  $setup_lcdio('io')$

  // only use the D4-D7 pins, ignore D0-D3 (set to 0)
  pmod4 := data[7, 1]; // D7
  pmod3 := data[6, 1]; // D6
  pmod2 := data[5, 1]; // D5
  pmod1 := data[4, 1]; // D4

  pmod  := {pmod10,pmod9,pmod8,pmod7,pmod4,pmod3,pmod2,pmod1};

  // Wait for the LCD screen to be fully initialized
  while (!io.ready) {}

  // Move the cursor to the 6th column of the 1st line
  io.data = {4d0, 4d5};
  io.set_cursor = 1;
  while (!io.ready) {}

  // Print the first message: Hello
  i = 0;
  while (i < 5) {
    io.data = msg1[i];
    io.print = 1;
    while (!io.ready) {}

    i = i + 1;
  }

  // Move the cursor to the 6th column of the 2nd line
  io.data = {4d1, 4d5};
  io.set_cursor = 1;
  while (!io.ready) {}

  // Print the second message: Silice!
  i = 0;
  while (i < 7) {
    io.data = msg2[i];
    io.print = 1;
    while (!io.ready) {}

    i = i + 1;
  }

  leds = 1;
}
