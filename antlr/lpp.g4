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

grammar lpp;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z_] ;
fragment LETTERU    : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

DISPLAY             : WHITESPACE* '$display' ~[\r\n]* ;
//                    ^^^^^^^^^^^ why tho???

INCLUDE             : WHITESPACE* '$include' ;
//                    ^^^^^^^^^^^ why tho???

NO_DOLLAR           : '\\$';
BSLASH              : '\\';
DOLLAR              : '$';
DOUBLE_DOLLAR       : WHITESPACE* '$$';
//                    ^^^^^^^^^^^ why tho???

WHITESPACE          : (' ' | '\t') -> skip ;

NEWLINE             : ('\r'? '\n' | '\r') ;

ANY                 : ~[\r\n$\\]+ ;

FILENAME            : '\'' (DIGIT|LETTERU|'.'|'/')* '\'' ;

/* ======== Parser ======== */

lualine     : DOUBLE_DOLLAR code=ANY;

luacode     : DOLLAR code=ANY? DOLLAR | DOUBLE_DOLLAR ;

siliceincl  : INCLUDE filename=ANY; 

any         : (ANY | NO_DOLLAR | BSLASH)+;

silicecode  : any | DISPLAY;

siliceline  : silicecode? (luacode silicecode?) * ;

line  : lualine | siliceline | siliceincl;

root  : (line NEWLINE) * line EOF ;
