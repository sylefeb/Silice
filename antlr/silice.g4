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

DISPLAY             : '$display' | '__display' ;

DISPLWRITE          : '__write' ;

TOSIGNED            : '__signed' ;

TOUNSIGNED          : '__unsigned' ;

DONE                : 'isdone' ;

ALWAYS              : 'always' | 'always_before' ;
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
AUTO                : '<:auto:>' ;

ALWSASSIGNDBL       : '::=' ;
ALWSASSIGN          : ':=' ;

OUTASSIGN           : '^=' ;

HASH                : '#';

IDENTIFIER          : LETTER+ (DIGIT|LETTERU)* ;

CONSTANT            : '-'? DIGIT+ ('b'|'h'|'d') (DIGIT|[a-fA-Fxz])+ ;

REPEATID            : '__id' ;

WHITESPACE          : (' ' | '\t') -> skip;

NEWLINE             : ('\r'? '\n' | '\r')+ -> skip ;

COMMENTBLOCK        : '/*' .*? '*/' -> skip ;

COMMENT             : '//' ~[\r\n]* NEWLINE -> skip ;

NEXT                : '++:' ;

ATTRIBS             : '(*' ~[\r\n]* '*)' ;

STRING              : '"' ~[\r\n"]* '"' ; // '; // antlr-mode is broken and does not handle literal `"` in selectors

ERROR_CHAR          : . ; // catch-all to move lexer errors to parser

/* ======== Parser ======== */

/* -- Declarations, init and bindings -- */

constValue          : minus='-'? NUMBER | CONSTANT | WIDTHOF '(' IDENTIFIER ')';

value               : constValue | initBitfield ;

sclock              :  '@' IDENTIFIER ;
sreset              :  '!' IDENTIFIER ;
sautorun            :  AUTORUN ;
sonehot             :  ONEHOT ;
sstacksz            :  'stack:' NUMBER ; // deprecated
sformdepth          :  '#depth' '=' NUMBER ;
sformtimeout        :  '#timeout' '=' NUMBER ;
sformmode           :  '#mode' '=' IDENTIFIER ('&' IDENTIFIER)* ;

bpModifier          : sclock | sreset | sautorun | sonehot | sstacksz | sformdepth | sformtimeout | sformmode ;
bpModifiers         : '<' bpModifier (',' bpModifier)* '>' ;

pad                 : PAD '(' (value | UNINITIALIZED) ')' ;
file                : FILE '(' STRING ')' ;
initList            : '{' value (',' value)* (',' pad)? ','? '}' | '{' (file ',')? pad '}'  | '{' '}' ;

memNoInputLatch     : 'input' '!' ;
memDelayed          : 'delayed' ;
memClocks           : (clk0=sclock ',' clk1=sclock) ;
memModifier         : memClocks | memNoInputLatch | memDelayed | STRING;
memModifiers        : '<' memModifier (',' memModifier)* ','? '>' ;

type                   : TYPE | (SAMEAS '(' base=IDENTIFIER ('.' member=IDENTIFIER)? ')') ;
declarationWire        : type alwaysAssigned;
declarationVarInitSet  : '=' (value | UNINITIALIZED) ;
declarationVarInitCstr : '(' (value | UNINITIALIZED) ')';
declarationVar         : type IDENTIFIER ( declarationVarInitSet | declarationVarInitCstr )? ATTRIBS? ;
declarationTable       : type IDENTIFIER '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))? ;
declarationMemory      : (BRAM | BROM | DUALBRAM | SIMPLEDUALBRAM) TYPE name=IDENTIFIER memModifiers? '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))? ;
declarationInstance    : blueprint=IDENTIFIER name=IDENTIFIER bpModifiers? ( '(' bpBindingList ')' ) ? ;
declaration            : declarationVar | declarationInstance | declarationTable | declarationMemory | declarationWire;

bpBinding              : left=IDENTIFIER (LDEFINE | LDEFINEDBL | RDEFINE | BDEFINE | BDEFINEDBL) right=idOrIoAccess | AUTO;
bpBindingList          : bpBinding ',' bpBindingList | bpBinding | ;

/* -- io lists -- */

io                  : ( (is_input='input' nolatch='!'? ) | (is_output='output' combinational='!'?) | is_inout='inout' ) IDENTIFIER ;

ioList              : io (',' io)* ','? | ;

/* -- vars -- */

var                 : declarationVar ;
varList             : var (',' var)* ','? | ;

/* -- groups -- */

group               : GROUP IDENTIFIER '{' varList '}' ;

/* -- interfaces -- */

intrface            : INTERFACE IDENTIFIER '{' ioList '}' ;

/* -- io definition (from group or interface) -- */

ioDef               : (INPUT | (OUTPUT combinational='!'?))? defid=IDENTIFIER groupname=IDENTIFIER ('{' ioList '}')? ;

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
                    '-' | '!' | '~&' | '~|' | '&' | '|' | '^~'| '~^' | '~'
					) atom | atom ;

concatenation       : '{' (NUMBER concatenation | expression_0 (',' expression_0)*) '}';

atom                : CONSTANT 
                    | NUMBER 
                    | IDENTIFIER 
                    | REPEATID
                    | access
                    | '(' expression_0 ')'
                    | TOSIGNED '(' expression_0 ')'
                    | TOUNSIGNED '(' expression_0 ')'
                    | WIDTHOF '(' base=IDENTIFIER ('.' member=IDENTIFIER)? ')'
                    | DONE '(' algo=IDENTIFIER ')'
                    | concatenation ;

/* -- Accesses to VIO -- */

bitfieldAccess      : field=IDENTIFIER '(' (idOrIoAccess | tableAccess) ')' '.' member=IDENTIFIER ;
ioAccess            : base=IDENTIFIER ('.' IDENTIFIER)+ ;
bitAccess           : (ioAccess | tableAccess | IDENTIFIER) '[' first=expression_0 ',' num=constValue ']' ;
tableAccess         : (ioAccess | IDENTIFIER) '[' expression_0 ']' ;
access              : (ioAccess | tableAccess | bitAccess | bitfieldAccess) ; 

idOrIoAccess        : (ioAccess | IDENTIFIER) ;

/* -- Assignments -- */
                    
assignment          : IDENTIFIER  ('=' | OUTASSIGN) expression_0
                    | access      ('=' | OUTASSIGN) expression_0 ;

alwaysAssigned      : IDENTIFIER   (ALWSASSIGN    | LDEFINE   ) expression_0
                    | access        ALWSASSIGN                  expression_0
                    | IDENTIFIER   (ALWSASSIGNDBL | LDEFINEDBL) expression_0
                    | access        ALWSASSIGNDBL               expression_0
                    ;

alwaysAssignedList  : alwaysAssigned ';' alwaysAssignedList | ;

/* -- Algorithm calls -- */

callParamList       : expression_0 (',' expression_0)* ','? | ;

asyncExec           : IDENTIFIER LARROW '(' callParamList ')' ;
joinExec            : '(' callParamList ')' LARROW IDENTIFIER ;
syncExec            : joinExec LARROW '(' callParamList ')' ;

/* -- Circuitry instanciation -- */

// TODO: allow passing ioAccess as well ( idOrIoAccess )
identifierList      : IDENTIFIER ',' identifierList 
                    | IDENTIFIER 
                    | ;

circuitryInst       : '(' outs=identifierList ')' '=' IDENTIFIER '(' ins=identifierList ')';

/* -- Control flow -- */

state               : state_name=IDENTIFIER ':' | NEXT ;
jump                : GOTO IDENTIFIER ;
returnFrom          : RETURN ;
breakLoop           : BREAK ;
assert_             : ASSERT '(' expression_0 ')';
// NOTE: keep the `_` here else it clashes with various keywords etc
assume              : ASSUME '(' expression_0 ')';
restrict            : RESTRICT '(' expression_0 ')';
was_at              : WASAT '(' IDENTIFIER (',' NUMBER)? ')';
assertstable        : ASSERTSTABLE '(' expression_0 ')';
assumestable        : ASSUMESTABLE '(' expression_0 ')';
stableinput         : STABLEINPUT '(' idOrIoAccess ')';
cover               : COVER '(' expression_0 ')';

block               : '{' declarationList instructionList '}';
ifThen              : 'if' '(' expression_0 ')' if_block=block ;
ifThenElse          : 'if' '(' expression_0 ')' if_block=block 'else' else_block=block ;
switchCase          : (SWITCH | ONEHOT) '(' expression_0 ')' '{' caseBlock * '}' ;
caseBlock           : ('case' case_value=value ':' | DEFAULT ) case_block=block;
whileLoop           : 'while' '(' expression_0 ')' while_block=block ;

display             : (DISPLAY | DISPLWRITE) '(' STRING ( ',' callParamList )? ')';

instruction         : assignment 
                    | syncExec
                    | asyncExec
                    | joinExec
                    | jump
                    | circuitryInst
                    | returnFrom
                    | breakLoop
                    | display
                    | assert_
                    | assume
                    | restrict
                    | was_at
                    | assumestable
                    | assertstable
                    | cover
                    ;

alwaysBlock         : ALWAYS       block;
alwaysAfterBlock    : ALWAYS_AFTER block;

repeatBlock         : REPEATCNT '{' instructionList '}' ;

pipeline            : block ('->' block) +;

/* -- Inputs/outputs -- */

inout               : 'inout' TYPE IDENTIFIER 
                    | 'inout' TYPE IDENTIFIER '[' NUMBER ']';
input               : 'input' nolatch='!'? type IDENTIFIER
                    | 'input' nolatch='!'? type IDENTIFIER '[' NUMBER ']';
output              : 'output' combinational='!'? declarationVar
                    | 'output' combinational='!'? declarationTable ; 
outputs             : 'input' OUTPUTS '(' alg=IDENTIFIER ')' grp=IDENTIFIER ;
inOrOut             :  input | output | inout | ioDef | outputs ;
inOutList           :  inOrOut (',' inOrOut)* ','? | ;

/* -- Declarations, subroutines, instruction lists -- */

declarationList     : declaration ';' declarationList | ;

instructionList     : 
                      (
                        (instruction ';') + 
                      | block
                      | repeatBlock
                      | state
                      | ifThenElse
                      | ifThen
                      | whileLoop
                      | switchCase
                      | pipeline
                      ) instructionList 
                      | ;

subroutineParam     : ( READ | WRITE | READWRITE | CALLS ) IDENTIFIER
					  | input | output ;
                    
subroutineParamList : subroutineParam (',' subroutineParam)* ','? | ;
subroutine          : SUB IDENTIFIER '(' subroutineParamList ')' '{' declList = declarationList  instructionList (RETURN ';')? '}' ;
                    
declAndInstrList    : (declaration ';' | subroutine | stableinput ';' ) *
                      alwaysPre = alwaysAssignedList 
                      alwaysBlock?
                      alwaysAfterBlock?
                      instructionList
					  ;

/* -- Import -- */

importv             : 'import' '(' FILENAME ')' ;

appendv             : 'append' '(' FILENAME ')' ;

/* -- Circuitry -- */

circuitry           : 'circuitry' IDENTIFIER '(' ioList ')' block ;

/* -- Algorithm -- */

algorithm           : 'algorithm' HASH? IDENTIFIER '(' inOutList ')' bpModifiers? '{' declAndInstrList '}' ;

/* -- RISC-V -- */

cblock_chunks       : ( ~( '{' | '}' )) + ;
cblock_items        : cblock | cblock_chunks;
cblock              : '{' cblock_items * '}' ;

riscvInstructions   : initList
                    | COMPILE '(' cblock ')' ;

rmemsz              : 'mem=' NUMBER ; // NOTE: no space is allowed before '=' to avoid issues with identifiers
rstacksz            : 'stack=' NUMBER ;
rcore               : 'core=' STRING ;

riscvModifier       : rmemsz | rstacksz | rcore;
riscvModifiers      : '<' riscvModifier (',' riscvModifier)* '>' ;

riscv               : RISCV IDENTIFIER '(' inOutList ')' riscvModifiers? '=' riscvInstructions ;

/* -- Overall structure -- */

topList       :  (algorithm | riscv | importv | appendv | subroutine | circuitry | group | bitfield | intrface) topList | ;

root                : topList EOF ;
 