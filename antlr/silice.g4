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

UNINITIALIZED       : 'uninitialized' | 'uninitialised' ;

PAD                 : 'pad' ;

FILE                : 'file' ;

ASSERT              : 'assert' ;

ASSUME              : 'assume' ;

RESTRICT            : 'restrict';

WASAT               : 'wasat';

STABLE              : 'stable';

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
sstacksz            :  'stack:' NUMBER ;

algModifier         : sclock | sreset | sautorun | sonehot | sstacksz ;
algModifiers        : '<' algModifier (',' algModifier)* '>' ;

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
declarationGrpModAlg   : modalg=IDENTIFIER name=IDENTIFIER algModifiers? ( '(' modalgBindingList ')' ) ? ;
declaration            : declarationVar | declarationGrpModAlg | declarationTable | declarationMemory | declarationWire;

modalgBinding        : left=IDENTIFIER (LDEFINE | LDEFINEDBL | RDEFINE | BDEFINE | BDEFINEDBL) right=idOrIoAccess | AUTO;
modalgBindingList    : modalgBinding ',' modalgBindingList | modalgBinding | ;

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

concatexpr          : expression_0 | NUMBER concatenation ;

concatenation       : '{' concatexpr (',' concatexpr)* '}' ;

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
assert_             : HASH ASSERT '(' expression_0 ')';
// NOTE: keep the `_` here else it clashes with various keywords etc
assume              : HASH ASSUME '(' expression_0 ')';
restrict            : HASH RESTRICT '(' expression_0 ')';
was_at              : HASH WASAT '(' IDENTIFIER (',' NUMBER)? ')';
stable              : HASH STABLE '(' expression_0 ')';

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
                    | stable
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
inOrOut             :  input | output | inout | ioDef;
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
                    
declAndInstrList    : (declaration ';' | subroutine ) *
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

algorithm           : 'algorithm' IDENTIFIER '(' inOutList ')' algModifiers? '{' declAndInstrList '}' ;

/* -- Overall structure -- */

topList       :  (algorithm | importv | appendv | subroutine | circuitry | group | bitfield | intrface) topList | ;

root                : topList EOF ;
