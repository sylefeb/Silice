// @sylefeb, 2020-10-08, UART example

$include('../common/uart.ice')

// UART echo

algorithm main(
  output uint$NUM_LEDS$ leds,
  output uint1 uart_tx,
  input  uint1 uart_rx
) {

  uart_out uo;
  uart_sender usend(
    io      <:> uo,
    uart_tx :>  uart_tx
  );

  uart_in ui;
  uart_receiver urecv(
    io      <:> ui,
    uart_rx <:  uart_rx
  );

  uo.data_in_ready := 0; // maintain low

  leds = 0;

  while (1) {
    if (ui.data_out_ready) {
      uo.data_in       = ui.data_out;
      if (ui.data_out != 100) {
        leds           = leds + 1;
      }
      uo.data_in_ready = 1;
    }
  }

}
