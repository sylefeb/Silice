// @sylefeb, 2020-10-08, simple UART in Silice
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

// UART config

$$if not uart_bauds then
$$uart_bauds             = 115200
$$end

$$if not uart_in_clock_freq_mhz then
$$  if DE10NANO then
$$    uart_in_clock_freq_mhz = 50
$$  elseif ULX3S then
$$    uart_in_clock_freq_mhz = 25
$$  elseif ICEBREAKER then
$$    uart_in_clock_freq_mhz = 12
$$  elseif ICESTICK then
$$    uart_in_clock_freq_mhz = 12
$$  else
$$    error("[uart] clock frequency 'uart_in_clock_freq_mhz' not specified")
$$  end
$$end

// sender

// -> interface

group uart_out
{
  uint8 data_in = 0,
  uint1 data_in_ready = 0,
  uint1 busy = 0,
}

interface io_uart_out
{
  input  data_in,
  input  data_in_ready,
  output busy,
}

// -> algorithm

algorithm uart_sender(
  io_uart_out  io,
  output uint1 uart_tx = 0
) <autorun> {
  
  uint10 interval      = $math.floor(0.5 + uart_in_clock_freq_mhz * 1000000 / uart_bauds)$;
  uint10 counter       = 0;
  uint11 transmit      = 0;

  always {
    if (transmit[1,10] != 0) {
      // keep transmitting
      if (counter == 0) {
        // keep going
        uart_tx  = transmit[0,1];
        transmit = {1b0,transmit[1,10]}; // goes to zero when done
      }
      counter = (counter == interval) ? 0 : (counter + 1);
    } else {
      // done
      uart_tx = 1;
      io.busy = 0;
      if (io.data_in_ready) {
        // start transmitting
        io.busy  = 1;
        transmit = {1b1,1b0,io.data_in,1b0};
      }
    }
  }

}

// receiver

// -> interface

group uart_in
{
  uint8 data_out = 0,
  uint1 data_out_ready = 0,
}

interface io_uart_in
{
  output data_out,
  output data_out_ready,
}

// -> algorithm

algorithm uart_receiver(
  io_uart_in  io,
  input uint1 uart_rx
) <autorun> {
  
  uint10 interval      = $math.floor(0.5 + uart_in_clock_freq_mhz * 1000000 / uart_bauds)$;
  uint10 half_interval = $math.floor(0.5 + uart_in_clock_freq_mhz * 1000000 / uart_bauds / 2)$;
  uint10 counter       = 0;

  uint10 receiving     = 0;
  uint10 received      = 0;

  uint1  latched_rx    = 0;

  always {     

    io.data_out_ready = 0; // maintain low

    if (receiving[0,1] == 0) {
      if (latched_rx == 0) {
        // start receiving
        receiving = 10b1111111111; // expecting 10 bits: start - data x8 - stop
        received  =  0;
        counter   = half_interval; // wait half-period
      }
    } else {
      if (counter == 0) { // right in the middle
        received  = {latched_rx,received[1,9]}; // read uart rx
        receiving = receiving >> 1;
        counter   = interval;
        if (receiving[0,1] == 0) {
          // done
          io.data_out       = received[1,8];
          io.data_out_ready = 1;
        }
      } else {
        counter   = counter - 1;
      }
    }

    latched_rx = uart_rx;

  }

}
