/******************************************************************************

   The MIT License (MIT)

   Copyright (c) 2015 Embedded Micro

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
   THE SOFTWARE.

   *****************************************************************************

   This module is a simple dual port RAM. This RAM is implemented in such a
   way that Xilinx's tools will recognize it as a RAM and implement large
   instances in block RAM instead of flip-flops.
   
   The parameter SIZE is used to specify the word size. That is the size of 
   each entry in the RAM.
   
   The parameter DEPTH is used to specify how many entries are in the RAM.
   
   read_data outputs the value of the entry pointed to by raddr in the previous
   clock cycle. That means to read address 10, you would set address to be 10
   and wait one cycle for its value to show up. The RAM is always reading whatever
   address is. If you don't need to read, just ignore this value.
   
   To write, set write_en to 1, write_data to the value to write, and waddr to 
   the address you want to write.
   
   You should avoid reading and writing to the same address simultaneously.
*/

module simple_dual_ram #(
    parameter SIZE = 8,                // size of each entry
    parameter DEPTH = 8                // number of entries
  )(
    // write interface
    input wclk,                        // write clock
    input [$clog2(DEPTH)-1:0] waddr,   // write address
    input [SIZE-1:0] write_data,       // write data
    input write_en,                    // write enable (1 = write)
    
    // read interface
    input rclk,                        // read clock
    input [$clog2(DEPTH)-1:0] raddr,   // read address
    output reg [SIZE-1:0] read_data    // read data
  );
  
  reg [SIZE-1:0] mem [DEPTH-1:0];      // memory array
  
  // write clock domain
  always @(posedge wclk) begin
    if (write_en)                      // if write enable
      mem[waddr] <= write_data;        // write memory
  end
  
  // read clock domain
  always @(posedge rclk) begin
    read_data <= mem[raddr];           // read memory
  end
  
endmodule