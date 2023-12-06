`ifndef ICE40_SB_GB
`define ICE40_SB_GB

module sb_gb(
  input        user,
  output       buffered
  );

  SB_GB sbgb (
      .USER_SIGNAL_TO_GLOBAL_BUFFER(user),
      .GLOBAL_BUFFER_OUTPUT(buffered)
  );

endmodule

`endif

// http://www.latticesemi.com/~/media/LatticeSemi/Documents/TechnicalBriefs/SBTICETechnologyLibrary201504.pdf
