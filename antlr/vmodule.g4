/*

    Silice FPGA language and compiler
    Copyright 2019, (C) Sylvain Lefebvre and contributors 

    List contributors with: git shortlog -n -s -- <filename>

    GPLv3 license, see LICENSE_GPLv3 in Silice repo root

This program is free software: you can redistribute it and/or modify it 
under the terms of the GNU General Public License as published by the 
Free Software Foundation, either version 3 of the License, or (at your option) 
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with 
this program.  If not, see <https://www.gnu.org/licenses/>.

(header_2_G)
*/

grammar vmodule;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

WRE                 : 'wire';

REG                 : 'reg';

INP                 : 'input';

OUTP                : 'output';

INOUTP              : 'inout';

PARAMETER           : 'parameter';

NUMBER              : DIGIT+ ;

IDENTIFIER          : LETTER+ (DIGIT|LETTER)* ;

ALPHANUM            : (LETTER|DIGIT|'\'')+ ;

WHITESPACE          : (' ' | '\t') -> skip ;

NEWLINE             : ('\r'? '\n' | '\r')+ -> skip ;

COMMENTBLOCK        : '/*' .*? '*/' -> skip ;

COMMENT             : '//' ~[\r\n]* NEWLINE -> skip ;

DIRECTIVE           : '`' ~[\r\n]* NEWLINE -> skip ;

ATTRIBUTES          : '(*' ~[*)]* '*)' -> skip ;

/* ======== Parser ======== */

regOrWire           : REG | WRE ;

mod                 : regOrWire? | regOrWire? '[' first=NUMBER ':' second=NUMBER ']' ;

input               : INP mod IDENTIFIER ;

output              : OUTP mod IDENTIFIER ;

inout               : INOUTP mod IDENTIFIER ;

inOrOut             : input | output | inout ;
                    
inOutList           : (inOrOut ',') * inOrOut | ;

paramDecl           : PARAMETER name=IDENTIFIER '=' value=(NUMBER|IDENTIFIER|ALPHANUM) | ;

paramList           : '#' '(' paramDecl ( ',' paramDecl )* ')' ;

vmodule             : 'module' IDENTIFIER paramList? '(' inOutList ')' ';' ;

root                : vmodule EOF ;
