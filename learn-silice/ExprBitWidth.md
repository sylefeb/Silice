**To be written**, but basically the rules are those of Verilog: in an expression, the width of the result is the max width of the operands.

A few tips:
- Beware of constants without a size specified, these are typically considered unsigned 32-bits. 
- Mixing unsigned and signed leads to trouble as unsigned prevails. Use `__signed(x)` and `__unsigned(x)` to 'cast' (not really a cast, rather tells Verilog how to interpret).

Links:
- [Verilog reference guide on expression widths](http://yangchangwoo.com/podongii_X2/html/technote/TOOL/MANUAL/21i_doc/data/fndtn/ver/ver4_4.htm).