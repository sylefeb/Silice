// SL 2020-05, GB 2021-06
// -------------------------
// LCD1602 driver
// -------------------------
// Specification document: https://www.openhacks.com/uploadsproductos/eone-1602a1.pdf
// Initialization: http://web.alfredstate.edu/faculty/weimandn/lcd/lcd_initialization/lcd_initialization_index.html
// -------------------------
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice

$$if LCD_4BITS ~= 1 and LCD_4BITS ~= 0 then
$$error('Please define the LCD_4BITS variable to 1 if you need to control the LCD display on a 4 bits bus, otherwise 0 to control the LCD display on a 8 bits wide bus')
$$end
$$if LCD_2LINES ~= 1 and LCD_2LINES ~= 0 then
$$error('Please define the LCD_2LINES variable to 1 if your LCD display has 2 lines, else 0')
$$end
$$if LCD_MODE ~= 0 and LCD_MODE ~= 1 then
$$error('Please define the LCD_MODE variable to either 0 or 1 depending on the pixel size of the screen (respectively 5x8 or 5x11)')
$$end

group lcdio {
  //! Holds data to send to the LCD display
  uint8 data           = 0,
  uint1 ready          = 0,
  //! Clears the display and move the cursor to the home position (0, 0)
  uint1 clear_display  = 0,
  //! Moves the cursor to the home position (0, 0)
  uint1 return_home    = 0,
  //! Enable or disable display:
  //!   - if `data[0, 1] = 8b1` then enable
  //!   - if `data[0, 1] = 8b0` then disable
  uint1 display_onoff  = 0,
  //! Enable or disable showing the cursor:
  //!   - if `data[0, 1] = 8b1` then enable
  //!   - if `data[0, 1] = 8b0` then disable
  uint1 cursor_onoff   = 0,
  //! Enable or disable blinking the cursor:
  //!   - if `data[0, 1] = 8b1` then enable
  //!   - if `data[0, 1] = 8b0` then disable
  uint1 blink_onoff    = 0,
  //! Shifts the entire display left or right:
  //!   - if `data[0, 1] = 1b1` shift left
  //!   - if `data[0, 1] = 1b0` shift right
  uint1 shift_display  = 0,
  //! Writes 8-bit data to the RAM
  //!   - data is stored in `data`
  //!
  //! Note: if in 4-bit mode, only the first 4 bits (`data[0, 4]`)
  //!       are taken in account
  uint1 print          = 0,
  //! Sets the cursor to the coordinates given in `data`:
  //!   - Lower 4 bits indicate the column (in range [0, 15])
  //!   - Upper 4 bits indicate the row (in range [0, 1])
  //!
  //! Example: `data = 0b00010100` => (row: 1, column: 8)
  uint1 set_cursor   = 0
}

$$function setup_lcdio(group_name)
$$  return group_name .. ".clear_display := 0;\n" ..
$$         group_name .. ".return_home   := 0;\n" ..
$$         group_name .. ".display_onoff := 0;\n" ..
$$         group_name .. ".cursor_onoff  := 0;\n" ..
$$         group_name .. ".blink_onoff   := 0;\n" ..
$$         group_name .. ".shift_display := 0;\n" ..
$$         group_name .. ".print         := 0;\n" ..
$$         group_name .. ".set_cursor    := 0;\n"
$$end

$$__LCD_SIZE=''
$$if LCD_4BITS ~= nil and LCD_4BITS == 1 then
$$  __LCD_SIZE='4'
$$else
$$  __LCD_SIZE='8'
$$end
$$__LCD_PIXEL_RATIO=''
$$if LCD_MODE ~= nil and LCD_MODE == 1 then
$$  __LCD_PIXEL_RATIO='5X11'
$$else
$$  __LCD_PIXEL_RATIO='5X8'
$$end

//! To be defined:
//!   - LCD_MODE: indicates whether the pixel size of characters is 5x8 or 5x11
//!   - LCD_4BITS: do we control the LCD display on a 4 or 8 bits wide bus?
//!   - LCD_2LINES: is there two lines on the LCd display?
algorithm lcd_$__LCD_SIZE$_$LCD_2LINES+1$_$__LCD_PIXEL_RATIO$ (
  output uint1 lcd_rs,
  output uint1 lcd_rw,
  output uint1 lcd_e,
  output uint8 lcd_d,
  lcdio io {
    input  data,
    output ready,
    input  clear_display,
    input  return_home,
    input  display_onoff,
    input  cursor_onoff,
    input  blink_onoff,
    input  shift_display,
    input  print,
    input  set_cursor
  }
) <autorun> {
  subroutine wait(input uint27 delay) {
    uint27 count = 0;
    while (count != delay) {
      count = count + 1;
    }
  }

  subroutine pulse_enable(writes lcd_e, calls wait) {
    lcd_e = 0;
    () <- wait <- (100);  // 1us @100MHz
    lcd_e = 1;
    () <- wait <- (50);   // enable pulse must be >450ns
    lcd_e = 0;
    () <- wait <- (5000); // commands need >37us to settle
  }

  subroutine send_command(
    writes lcd_d,
    calls wait,
    calls pulse_enable,
    input uint8 cmd,
    input uint27 delay
  ) {
$$if LCD_4BITS then
    // If in 4-bits mode, send command in two steps:
    //   - first the 4 upper bits
    //   - second the 4 lower bits
    //
    // Note: No need to add delay between those
    lcd_d = cmd & 8b11110000;
    () <- pulse_enable <- ();
    lcd_d = {cmd & 4b1111, 4b0000};
    () <- pulse_enable <- ();
    () <- wait <- (delay);
$$else
    lcd_d = cmd;
    () <- pulse_enable <- ();
    () <- wait <- (delay);
$$end
  }

  subroutine display_on_off(
    readwrites current_display_state,
    writes lcd_rs,
    calls send_command,
    input uint1 display,
    input uint1 cursor,
    input uint1 blink,
    input uint1 data
  ) {
    // Display ON/OFF: RS, RW=0; D = 00001D__; delay 37us
    uint8 cmd = uninitialized;
    uint3 selector <: {display, cursor, blink};

    onehot (selector) {
      case 0: { cmd = {5b00001, current_display_state[1, 2], data}; }
      case 1: { cmd = {5b00001, current_display_state[2, 1], data, current_display_state[0, 1]}; }
      case 2: { cmd = {5b00001, data, current_display_state[0, 2]}; }
    }
    current_display_state = cmd[0, 3];

    lcd_rs = 0;
    () <- send_command <- (cmd, 3700);
  }

  uint3 current_display_state = 3b100;

  lcd_rw  := 0;

  io.ready = 0;
  lcd_rs   = 0;
  lcd_d    = 0;

  /// Step 1: power on, then delay >100ms
  () <- wait <- (10000000);

  /// Step 2: Instruction 00110000b, then delay >4.1ms
  lcd_d = 8b00110000;
  () <- pulse_enable <- ();
  () <- wait <- (450000);
  // Step 3: Instruction 00110000b, then delay >100us
  lcd_d = 8b00110000;
  () <- pulse_enable <- ();
  () <- wait <- (10000);
  // Step 4: Instruction 00110000b, then delay >100us
  lcd_d = 8b00110000;
  () <- pulse_enable <- ();
  () <- wait <- (10000);

$$if LCD_4BITS then
  // Step 5: Instruction 00100000b, then delay >100us
  lcd_d = 8b00100000;
  () <- pulse_enable <- ();
  () <- wait <- (10000);

  // NOTE: from now on we are in 4-bits mode, therefore we can use the subroutine 'send_command'
$$end

$$if LCD_4BITS then
  // Step 6: Instruction 0010b, then 1000b, then delay >53us or chech BF
$$else
  // Step 5: Instruction 00111000b, then delay >53us of check BF
$$end
  () <- send_command <- ({3b001, 1b$~LCD_4BITS & 1$, 1b$LCD_2LINES$, 1b$LCD_MODE$, 2b00}, 5500);

$$if LCD_4BITS then
  // Step 7: Instruction 0000b, then 1000b, then delay >53us or check BF
$$else
  // Step 6: Instruction 00001000b, then delay >53us or check BF
$$end
  () <- send_command <- (8b00001000, 5300);

$$if LCD_4BITS then
  // Step 8: Instruction 0000b, then 0001b, then delay >3ms or check BF
$$else
  // Step 7: Instruction 00000001b, then delay >3ms or check BF
$$end
  () <- send_command <- (8b00000001, 300000);

$$if LCD_4BITS then
  // Step 9: Instruction 0000b, then 0110b, then delay >53us or check BF
$$else
  // Step 8: Instruction 00000110b, then delay >53us or check BF
$$end
  () <- send_command <- (8b00000110, 5300);

$$if LCD_4BITS then
  // Step 10: Initialization ends
  // Step 11: Instruction 0000b, then 1100b, then delay >53us or check BF
$$else
  // Step 9: Initialization ends
  // Step 10: Instruction 00001100b, then delay >53us or check BF
$$end
  () <- send_command <- (8b00001100, 5300);

  io.ready = 1;

  while (1) {
    uint6 instruction <: {io.clear_display, io.return_home, io.display_onoff ^ io.cursor_onoff ^ io.blink_onoff,
                          io.shift_display, io.print, io.set_cursor};

    if (instruction != 0) {
      io.ready = 0;

      onehot (instruction) {
        case 5: {
          // Clear display: RS, RW=0; D = 00000001; delay 1.52ms
          lcd_rs = 0;
          () <- send_command <- (8b00000001, 15200);
        }
        case 4: {
          // Return Home: RS, RW=0; D = 0000001_; delay 1.52ms
          lcd_rs = 0;
          () <- send_command <- (8b00000010, 15200);
        }
        case 3: {
          // Display ON/OFF: RS, RW=0; D = 00001DCB; delay 37us
          () <- display_on_off <- (io.display_onoff, io.cursor_onoff, io.blink_onoff, io.data[0, 1]);
        }
        case 2: {
          // Cursor or Display Shift: RS, RW=0; D = 0001SR__; delay 37us
          lcd_rs = 0;
          () <- send_command <- ({5b00011, ~io.data[0, 1], 2b00}, 3700);
        }
        case 1: {
          // Write data to RAM: RS=1; RW=0; D = 'data'; delay 37us
          lcd_rs = 1;
          () <- send_command <- (io.data, 3700);
        }
        case 0: {
          // Set DDRAM Address: RS, RW=0; D = 1ADDRESS; delay 37us
          uint4 num_lines    <: 4d$LCD_2LINES+1$;
          uint4 row          <: io.data[4, 4] >= num_lines ? num_lines - 1 : io.data[4, 4];

          uint7 offset = uninitialized;

          lcd_rs = 0;

          switch (row) {
            case 0:  { offset = 7h00 + io.data[0, 4]; } // first line starts the same for both 1- and 2-line displays
            case 1:  { offset = 7h40 + io.data[0, 4]; } // 1-line display cannot go here
            default: { offset = 7h00 + io.data[0, 4]; } // defaults to first line
          }

          () <- send_command <- ({1b1, offset}, 3700);
        }
      }

      io.ready = 1;
    }
  }
}

$$__LCD_SIZE=nil
$$__LCD_PIXEL_RATIO=nil
