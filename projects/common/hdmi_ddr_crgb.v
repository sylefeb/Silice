module hdmi_ddr_crgb(
        input         clock,
        input         clock_n,
        input   [7:0] crgb_twice,
        output  [3:0] out_pin
    );

  ddr rp(
    .clock(clock),
    .clock_n(clock_n),
    .twice(crgb_twice[0+:2]),
    .out_pin(out_pin[2+:1])
  );

  ddr gp(
    .clock(clock),
    .clock_n(clock_n),
    .twice(crgb_twice[2+:2]),
    .out_pin(out_pin[1+:1])
  );

  ddr bp(
    .clock(clock),
    .clock_n(clock_n),
    .twice(crgb_twice[4+:2]),
    .out_pin(out_pin[0+:1])
  );

  ddr cp(
    .clock(clock),
    .clock_n(clock_n),
    .twice(crgb_twice[6+:2]),
    .out_pin(out_pin[3+:1])
  );

endmodule
