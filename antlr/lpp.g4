/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/

grammar lpp;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z_] ;
fragment LETTERU    : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

DISPLAY             : '$display' ~[\r\n]* ;

INCLUDE             : '$include' ;

DOLLAR              : '$';
DOUBLE_DOLLAR       : WHITESPACE* '$$';
//                    ^^^^^^^^^^^ why tho???

WHITESPACE          : (' ' | '\t') -> skip ;

NEWLINE             : ('\r'? '\n' | '\r') ;

ANY                 : ~[\r\n$]+ ;

FILENAME            : '\'' (DIGIT|LETTERU|'.'|'/')* '\'' ;

/* ======== Parser ======== */

lualine     : DOUBLE_DOLLAR code=ANY;

luacode     : DOLLAR code=ANY? DOLLAR | DOUBLE_DOLLAR ;

siliceincl  : INCLUDE filename=ANY; 

silicecode  : ANY | DISPLAY;

siliceline  : silicecode? (luacode silicecode?) * ;

line  : lualine | siliceline | siliceincl;

root  : (line NEWLINE) * line EOF ;
