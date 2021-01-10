module hdmi_differential_pairs(
        input   clock,
        input   [7:0] pos,
        input   [7:0] neg,
        output  [3:0] out_pos,
        output  [3:0] out_neg
    );

  differential_pair rp(
    .clock(clock),
    .pos(pos[0+:2]),
    .neg(neg[0+:2]),
    .out_pin_pos(out_pos[2+:1]),
    .out_pin_neg(out_neg[2+:1])
  );

  differential_pair gp(
    .clock(clock),
    .pos(pos[2+:2]),
    .neg(neg[2+:2]),
    .out_pin_pos(out_pos[1+:1]),
    .out_pin_neg(out_neg[1+:1])
  );

  differential_pair bp(
    .clock(clock),
    .pos(pos[4+:2]),
    .neg(neg[4+:2]),
    .out_pin_pos(out_pos[0+:1]),
    .out_pin_neg(out_neg[0+:1])
  );

  differential_pair cp(
    .clock(clock),
    .pos(pos[6+:2]),
    .neg(neg[6+:2]),
    .out_pin_pos(out_pos[3+:1]),
    .out_pin_neg(out_neg[3+:1])
  );

endmodule
