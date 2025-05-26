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

grammar silice;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z] ;
fragment LETTERU    : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

BASETYPE            : 'int' | 'uint' ;

NUMBER              : DIGIT+ ;

TYPE                : BASETYPE DIGIT+;

GOTO                : 'goto' ;

AUTORUN             : 'autorun' ;

ONEHOT              : 'onehot' ;
SWITCH              : 'switch' ;

READ                : 'reads' ;
WRITE               : 'writes' ;
READWRITE           : 'readwrites' ;
CALLS               : 'calls' ;

FILENAME            : '\'' (DIGIT|LETTERU|'.'|'/'|'-')* '\'' ;

REPEATCNT           : NUMBER 'x' ;

SUB                 : 'subroutine' ;

RETURN              : 'return' ;

BREAK               : 'break' ;

STALL               : 'stall' ;

DISPLAY             : '$display' | '__display' ;

DISPLWRITE          : '__write' ;

FINISH              : '__finish' ;

TOSIGNED            : '__signed' ;

TOUNSIGNED          : '__unsigned' ;

INLINE_V            : '__verilog' ;

DONE                : 'isdone' ;

ALWAYS              : 'always';
ALWAYS_BEFORE       : 'always_before';
ALWAYS_AFTER        : 'always_after' ;

BRAM                : 'bram' ;

DUALBRAM            : 'dualport_bram';

SIMPLEDUALBRAM      : 'simple_dualport_bram';

BROM                : 'brom' ;

GROUP               : 'group' ;

INTERFACE           : 'interface' ;

BITFIELD            : 'bitfield' ;

SAMEAS              : 'sameas' ;

WIDTHOF             : 'widthof' ;

INPUT               : 'input' ;

OUTPUT              : 'output' ;

OUTPUTS             : 'outputs' ;

UNINITIALIZED       : 'uninitialized' | 'uninitialised' ;

PAD                 : 'pad' ;

FILE                : 'file' ;

COMPILE             : 'compile' ;

RISCV               : 'riscv' ;

ASSERT              : '#assert' ;

ASSUME              : '#assume' ;

RESTRICT            : '#restrict';

WASAT               : '#wasin';

ASSERTSTABLE        : '#assertstable';

ASSUMESTABLE        : '#assumestable';

STABLEINPUT         : '#stableinput';

COVER               : '#cover';

DEFAULT             : 'default' (' ' | '\t')* ':';

LARROW              : '<-' ;
RARROW              : '->' ;

LDEFINE             : '<:' ;
RDEFINE             : ':>' ;
BDEFINE             : '<:>';
LDEFINEDBL          : '<::' ;
BDEFINEDBL          : '<::>';
AUTOBIND            : '<:auto:>' ;
AUTO                : 'auto' ;

ALWSASSIGNDBL       : '::=' ;
ALWSASSIGN          : ':=' ;

ASSIGN_BACKWARD     : '^=' ;
ASSIGN_FORWARD      : 'v=' ;
ASSIGN_AFTER        : 'vv=' ;

HASH                : '#';

IDENTIFIER          : LETTER+ (DIGIT|LETTERU)* ;

NONAME              : '_';

SIZED_NUMBER        : '-'? DIGIT+ ('b'|'h'|'d') (DIGIT|[a-fA-Fxz])+ ;

REPEATID            : '__id' ;

WHITESPACE          : (' ' | '\t') -> skip;

NEWLINE             : ('\r'? '\n' | '\r')+ -> skip ;

COMMENTBLOCK        : '/*' .*? '*/' -> skip ;

COMMENT             : '//' ~[\r\n]* NEWLINE -> skip ;

NEXT                : '++:' ;

ATTRIBS             : '(*' ~[\r\n]* '*)' ;

STRING              : '"' (~[\r\n"] | '\\"')* '"' ; // '; // antlr-mode is broken and does not handle literal `"` in selectors

ERROR_CHAR          : . ; // catch-all to move lexer errors to parser

/* ======== Parser ======== */

/* -- Declarations, init and bindings -- */

constValue          : minus='-'? NUMBER | SIZED_NUMBER | (WIDTHOF '(' base=IDENTIFIER ('.' member=IDENTIFIER)? ')');

value               : constValue | initBitfield ;

sclock              :  '@' IDENTIFIER ;
sreset              :  '!' IDENTIFIER ;
sautorun            :  AUTORUN ;
sonehot             :  ONEHOT ;
sreginput           :  'reginputs' ;
sstacksz            :  'stack:' NUMBER ; // deprecated
sformdepth          :  '#depth' '=' NUMBER ;
sformtimeout        :  '#timeout' '=' NUMBER ;
sformmode           :  '#mode' '=' IDENTIFIER ('&' IDENTIFIER)* ;
sspecialize         :  IDENTIFIER ':' TYPE ;
sparam              :  IDENTIFIER '=' (NUMBER|SIZED_NUMBER|STRING) ;

bpModifier          : sclock | sreset | sautorun | sonehot | sstacksz | sformdepth | sformtimeout | sformmode | sreginput | sspecialize | sparam;
bpModifiers         : '<' bpModifier (',' bpModifier)* '>' ;

pad                 : PAD '(' (value | UNINITIALIZED) ')' ;
file                : FILE '(' STRING ')' ;
initList            : '{' value (',' value)* (',' pad)? ','? '}' | '{' (file ',')? pad '}'  | '{' '}' ;

memDelayed          : 'delayed' ;
memClocks           : (clk0=sclock ',' clk1=sclock) ;
memModifier         : memClocks | memDelayed | STRING;
memModifiers        : '<' memModifier (',' memModifier)* ','? '>' ;

type                   : TYPE | (SAMEAS '(' base=IDENTIFIER ('.' member=IDENTIFIER)? ')') | AUTO;
declarationWire        : type alwaysAssigned;
declarationVarInitSet  : '=' (value | UNINITIALIZED) ;
declarationVarInitCstr : '(' (value | UNINITIALIZED) ')';
declarationVarInitExpr : '=' expression_0 ;
declarationVar         : type IDENTIFIER ( declarationVarInitSet | declarationVarInitCstr | declarationVarInitExpr )? ATTRIBS? ;
declarationTable       : type IDENTIFIER '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))? ;
declarationMemory      : (BRAM | BROM | DUALBRAM | SIMPLEDUALBRAM) TYPE name=IDENTIFIER memModifiers? '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))? ;
declarationInstance    : blueprint=IDENTIFIER (name=IDENTIFIER | NONAME) bpModifiers? ( '(' bpBindingList ')' ) ? ;
declaration            : subroutine
                       | declarationVar ';'
                       | declarationInstance ';'
                       | declarationTable ';'
                       | declarationMemory ';'
                       | declarationWire ';'
                       | stableinput ';'
                       ;

bpBinding              : left=IDENTIFIER (LDEFINE | LDEFINEDBL | RDEFINE | BDEFINE | BDEFINEDBL) right=idOrAccess | AUTOBIND;
bpBindingList          : bpBinding ',' bpBindingList | bpBinding | ;

/* -- io lists -- */

io                  : ( (is_input='input') | ((is_output='output' | is_inout='inout') combinational='!'? combinational_nocheck='(!)'?)) IDENTIFIER declarationVarInitCstr? ;

ioList              : io (',' io)* ','? | ;

/* -- vars -- */

var                 : declarationVar ;
varList             : var (',' var)* ','? | ;

/* -- groups -- */

group               : GROUP IDENTIFIER '{' varList '}' ;

/* -- interfaces -- */

intrface            : INTERFACE IDENTIFIER '{' ioList '}' ;

/* -- io definition (from group or interface) -- */

ioDef               : (INPUT | (OUTPUT combinational='!'? combinational_nocheck='(!)'?))? defid=IDENTIFIER groupname=IDENTIFIER ('{' ioList '}')? ;

/* -- bitfields -- */

bitfield            : BITFIELD IDENTIFIER '{' varList '}' ;
namedValue          : name=IDENTIFIER '=' constValue ;
initBitfield        : field=IDENTIFIER '(' namedValue (',' + namedValue)* ','? ')' ;

/* -- Expressions -- */

expression_0        : expression_0 '?' expression_0 ':' expression_0
                    | expression_1;

expression_1        : expression_1 (
                    '||'
                    ) expression_2
                    | expression_2 ;

expression_2        : expression_2 (
                    '&&'
                    ) expression_3
                    | expression_3 ;

expression_3        : expression_3 (
                    '|'
                    ) expression_4
                    | expression_4 ;

expression_4        : expression_4 (
                    '^' | '^~'| '~^'
                    ) expression_5
                    | expression_5 ;

expression_5        : expression_5 (
                    '&'
                    ) expression_6
                    | expression_6 ;

expression_6        : expression_6 (
                    '===' | '==' | '!==' | '!='
                    ) expression_7
                    | expression_7 ;

expression_7        : expression_7 (
                    '<' | '>' | '<=' | '>='
                    ) expression_8
                    | expression_8 ;

expression_8        : expression_8 (
                    '<<' | '<<<' | '>>' | '>>>'
                    ) expression_9
                    | expression_9 ;

expression_9        : expression_9 (
                    '+' | '-'
                    ) expression_10
                    | expression_10 ;

expression_10        : expression_10 (
                    '*'
                    ) unaryExpression
                    | unaryExpression ;

unaryExpression     : (
                    '-' | '!' | '~&' | '~|' | '&' | '|' | '^' | '^~'| '~^' | '~'
					) atom | atom ;

concatenation       : '{' (NUMBER concatenation | expression_0 (',' expression_0)*) '}';

combcast            : ':' (access | IDENTIFIER);

atom                : SIZED_NUMBER
                    | NUMBER
                    | IDENTIFIER
                    | REPEATID
                    | access
                    | combcast
                    | '(' expression_0 ')'
                    | TOSIGNED '(' expression_0 ')'
                    | TOUNSIGNED '(' expression_0 ')'
                    | WIDTHOF '(' base=IDENTIFIER ('.' member=IDENTIFIER)? ')'
                    | DONE '(' algo=IDENTIFIER ')'
                    | concatenation ;

/* -- Accesses to VIO -- */

bitfieldAccess      : field=IDENTIFIER '(' (idOrIoAccess | tableAccess) ')' '.' member=IDENTIFIER ;
ioAccess            : base=IDENTIFIER ('.' IDENTIFIER)+ ;
partSelect          : (ioAccess | tableAccess | bitfieldAccess | IDENTIFIER) '[' first=expression_0 ',' num=constValue ']' ;
tableAccess         : (ioAccess | IDENTIFIER) '[' expression_0 ']' ;
access              : (ioAccess | tableAccess | partSelect | bitfieldAccess) ;

idOrIoAccess        : (ioAccess | IDENTIFIER) ;
idOrAccess          : (  access | IDENTIFIER) ;

/* -- Assignments -- */

assignment          : IDENTIFIER  ('=' | ASSIGN_BACKWARD | ASSIGN_FORWARD | ASSIGN_AFTER) expression_0
                    | access      ('=' | ASSIGN_BACKWARD | ASSIGN_FORWARD | ASSIGN_AFTER) expression_0 ;

alwaysAssigned      : IDENTIFIER   (ALWSASSIGN    | LDEFINE   ) expression_0
                    | access        ALWSASSIGN                  expression_0
                    | IDENTIFIER   (ALWSASSIGNDBL | LDEFINEDBL) expression_0
                    | access        ALWSASSIGNDBL               expression_0
                    ;

/* -- Algorithm calls -- */

callParamList       : expression_0 (',' expression_0)* ','? | ;

asyncExec           : IDENTIFIER LARROW '(' callParamList ')' ;
joinExec            : '(' callParamList ')' LARROW IDENTIFIER ;
syncExec            : joinExec LARROW '(' callParamList ')' ;

/* -- Circuitry instantiation -- */

circuitryInst       : '(' outs=callParamList ')' '='  IDENTIFIER ('<' sparam (',' sparam)* '>')? '(' ins=callParamList ')';

/* -- Control flow -- */

state               : state_name=IDENTIFIER ':' | NEXT ;
jump                : GOTO IDENTIFIER ;
returnFrom          : RETURN ;
breakLoop           : BREAK ;
stall               : STALL ;
assert_             : ASSERT '(' expression_0 ')';
// NOTE: keep the `_` here else it clashes with various keywords etc
assume              : ASSUME '(' expression_0 ')';
restrict            : RESTRICT '(' expression_0 ')';
was_at              : WASAT '(' IDENTIFIER (',' NUMBER)? ')';
assertstable        : ASSERTSTABLE '(' expression_0 ')';
assumestable        : ASSUMESTABLE '(' expression_0 ')';
stableinput         : STABLEINPUT '(' idOrIoAccess ')';
cover               : COVER '(' expression_0 ')';

block               : '{' instructionSequence '}';
ifThen              : 'if' '(' expression_0 ')' if_block=block ;
ifThenElse          : 'if' '(' expression_0 ')' if_block=block else_keyword='else' else_block=block ;
switchCase          : (SWITCH | ONEHOT) '(' expression_0 ')' '{' caseBlock * '}' ;
caseBlock           : ('case' case_value=value ':' | DEFAULT ) case_block=block;
whileLoop           : 'while' '(' expression_0 ')' while_block=block ;

display             : (DISPLAY | DISPLWRITE) '(' STRING ( ',' callParamList )? ')';

inline_v            : INLINE_V '(' STRING ( ',' callParamList )? ')';

finish              : FINISH '(' ')';

instruction         : assignment
                    | syncExec
                    | asyncExec
                    | joinExec
                    | jump
                    | circuitryInst
                    | returnFrom
                    | breakLoop
                    | stall
                    | display
                    | finish
                    | assert_
                    | assume
                    | restrict
                    | was_at
                    | assumestable
                    | assertstable
                    | cover
                    | inline_v
                    | alwaysAssigned
                    ;

alwaysBlock         : ALWAYS        block;
alwaysBeforeBlock   : ALWAYS_BEFORE block;
alwaysAfterBlock    : ALWAYS_AFTER  block;

repeatBlock         : REPEATCNT '{' instructionSequence '}' ;

/* -- Inputs/outputs -- */

inout               : 'inout' combinational='!'? combinational_nocheck='(!)'? declarationVar
                    | 'inout' combinational='!'? combinational_nocheck='(!)'? declarationTable ;
input               : 'input' declarationVar
                    | 'input' declarationTable;
output              : 'output' combinational='!'? combinational_nocheck='(!)'? declarationVar
                    | 'output' combinational='!'? combinational_nocheck='(!)'? declarationTable ;
outputs             : 'input' OUTPUTS '(' alg=IDENTIFIER ')' grp=IDENTIFIER ;
inOrOut             :  input | output | inout | ioDef | outputs ;
inOutList           :  inOrOut (',' inOrOut)* ','? | ;

/* -- Declarations, subroutines, instruction lists -- */

instructionListItem :
                      (
                        (instruction ';')
                      | declaration
                      | block
                      | alwaysBlock
                      | alwaysBeforeBlock
                      | alwaysAfterBlock
                      | repeatBlock
                      | state
                      | ifThenElse
                      | ifThen
                      | whileLoop
                      | switchCase
                      );
instructionList     : instructionListItem *;

pipeline             : instructionList ('->' instructionList) * ;

instructionSequence  : pipeline | ;

subroutineParam     : ( READ | WRITE | READWRITE | CALLS ) IDENTIFIER
					  | input | output ;

subroutineParamList : subroutineParam (',' subroutineParam)* ','? | ;
subroutine          : SUB IDENTIFIER '(' subroutineParamList ')' '{' instructionSequence (RETURN ';')? '}'
                    | SUB IDENTIFIER ';' ;

declAndInstrSeq     : instructionSequence ;

/* -- Import -- */

importv             : 'import' '(' FILENAME ')' ;

appendv             : 'append' '(' FILENAME ')' ;

/* -- Circuitry -- */

circuitry           : 'circuitry' IDENTIFIER '(' ioList ')' block ;

/* -- Algorithm -- */

algorithm           : 'algorithm' HASH? IDENTIFIER '(' inOutList ')' bpModifiers? '{' declAndInstrSeq '}' ;

algorithmBlockContent : instructionSequence ;

algorithmBlock      : 'algorithm' bpModifiers? '{' algorithmBlockContent '}' ;

/* -- Unit -- */

unitBlocks          :   (declaration) *
                        (alwaysAssigned ';') *
                        alwaysBlock?
                        alwaysBeforeBlock? algorithmBlock? alwaysAfterBlock?
                        ;


unit                : 'unit' HASH? IDENTIFIER '(' inOutList ')' bpModifiers? '{' unitBlocks '}' ;

/* -- RISC-V -- */

cblock_chunks       : ( ~( '{' | '}' )) + ;
cblock_items        : cblock | cblock_chunks;
cblock              : '{' cblock_items * '}' ;

riscvModifier       : IDENTIFIER '=' (STRING | NUMBER);
riscvModifiers      : '<' riscvModifier (',' riscvModifier)* '>' ;

riscv               : RISCV IDENTIFIER '(' inOutList ')' riscvModifiers? ('=' initList | cblock) ;

/* -- Overall structure -- */

topList             :  (unit | algorithm  | riscv     | importv | appendv
                             | subroutine | circuitry | group   | bitfield
                             | intrface
                       ) *
                    ;

root                : topList EOF ;

rootInOutList       : inOutList EOF ;

rootUnit            : (unit | algorithm) EOF ;

rootIoList          : ioList EOF ;

rootCircuitry       : circuitry EOF ;
