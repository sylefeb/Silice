module display_value(
    input [7:0]     value
  );
  
  always @* begin
    $display("value = %d",value);
  end
  
endmodule

