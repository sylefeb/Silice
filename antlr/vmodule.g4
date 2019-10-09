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

grammar vmodule;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

REG                 : 'reg';

INP                 : 'input';

OUTP                : 'output';

INOUTP              : 'inout';

NUMBER              : DIGIT+ ;

IDENTIFIER          : LETTER+ (DIGIT|LETTER)* ;

WHITESPACE          : (' ' | '\t') -> skip ;

NEWLINE             : ('\r'? '\n' | '\r')+ -> skip ;

COMMENTBLOCK        : '/*' .*? '*/' -> skip ;

COMMENT             : '//' ~[\r\n]* NEWLINE -> skip ;

DIRECTIVE           : '`' ~[\r\n]* NEWLINE -> skip ;

ATTRIBUTES          : '(*' ~[*)]* '*)' -> skip ;

/* ======== Parser ======== */

mod                 : REG? | REG? '[' first=NUMBER ':' second=NUMBER ']' ;

input               : INP mod IDENTIFIER ;

output              : OUTP mod IDENTIFIER ;

inout               : INOUTP mod IDENTIFIER ;

inOrOut             : input | output | inout ;
                    
inOutList           :  (inOrOut ',') * inOrOut | ;

vmodule             : 'module' IDENTIFIER '(' inOutList ')' ';' ;

root                : vmodule ;
