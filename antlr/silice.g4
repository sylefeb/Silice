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

READ                : 'reads' ;
WRITE               : 'writes' ;
READWRITE           : 'readwrites' ;
CALLS               : 'calls' ;

FILENAME            : '\'' (DIGIT|LETTERU|'.'|'/')* '\'' ;

REPEATCNT           : NUMBER 'x' ;

SUB                 : 'subroutine' ;

RETURN              : 'return' ;

CALL                : 'call' ;

BREAK               : 'break' ;

DISPLAY             : '$display' | '__display' ;

TOSIGNED            : '__signed' ;

TOUNSIGNED          : '__unsigned' ;

ALWAYS              : 'always' ;

BRAM                : 'bram' ;

DUALBRAM            : 'dualport_bram';

BROM                : 'brom' ;

GROUP               : 'group' ;

BITFIELD            : 'bitfield' ;

UNINITIALIZED       : 'uninitialized' ;

DEFAULT             : 'default' (' ' | '\t')* ':';

LARROW              : '<-' ;
RARROW              : '->' ;

LDEFINE             : '<:' ;
RDEFINE             : ':>' ;
BDEFINE             : '<:>';
LDEFINEDBL          : '<::' ;
AUTO                : '<:auto:>' ;

ALWSASSIGNDBL       : '::=' ;
ALWSASSIGN          : ':=' ;

IDENTIFIER          : LETTER+ (DIGIT|LETTERU)* ;

CONSTANT            : '-'? DIGIT+ ('b'|'h'|'d') (DIGIT|[a-fA-Fxz])+ ;

REPEATID            : '__id' ;

WHITESPACE          : (' ' | '\t') -> skip;

NEWLINE             : ('\r'? '\n' | '\r')+ -> skip ;

COMMENTBLOCK        : '/*' .*? '*/' -> skip ;

COMMENT             : '//' ~[\r\n]* NEWLINE -> skip ;

NEXT                : '++:' ;

ATTRIBS             : '(*' ~[\r\n]* '*)' ;

STRING              : '"' ~[\r\n"]* '"' ;

ERROR_CHAR          : . ; // catch-all to move lexer errors to parser

/* ======== Parser ======== */

/* -- Declarations, init and bindings -- */

constValue          : minus='-'? NUMBER | CONSTANT ;

value               : constValue | initBitfield ;

sclock              :  '@' IDENTIFIER ;
sreset              :  '!' IDENTIFIER ;
sautorun            :  AUTORUN ;
sstacksz            :  'stack:' NUMBER ;

algModifier         : sclock | sreset | sautorun | sstacksz ;
algModifiers        : '<' algModifier (',' algModifier)* '>' ;

initList            : '{' value (',' value)* ','? '}' | '{' '}' ;

memNoInputLatch     : 'input' '!' ;
memClocks           : (clk0=sclock ',' clk1=sclock) ;
memModifier         : memClocks | memNoInputLatch ;
memModifiers        : '<' memModifier (',' memModifier)* ','? '>' ;

declarationWire      : TYPE alwaysAssigned;
declarationVar       : TYPE IDENTIFIER ('=' (value | UNINITIALIZED))? ATTRIBS?;
declarationTable     : TYPE IDENTIFIER '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))?;
declarationMemory    : (BRAM | BROM | DUALBRAM) TYPE name=IDENTIFIER memModifiers? '[' NUMBER? ']' ('=' (initList | STRING | UNINITIALIZED))?;
declarationGrpModAlg : modalg=IDENTIFIER name=IDENTIFIER algModifiers? ( '(' modalgBindingList ')' ) ?;
declaration          : declarationVar | declarationGrpModAlg | declarationTable | declarationMemory | declarationWire; 

modalgBinding        : left=IDENTIFIER (LDEFINE | LDEFINEDBL | RDEFINE | BDEFINE) right=idOrIoAccess | AUTO;
modalgBindingList    : modalgBinding ',' modalgBindingList | modalgBinding | ;

/* -- io lists -- */

io                  : ( (is_input='input' nolatch='!'? ) | (is_output='output' combinational='!'?) | is_inout='inout' ) IDENTIFIER ;

ioList              : io (',' io)* ','? | ;

/* -- groups -- */

var                 : declarationVar ;
varList             : var (',' var)* ','? | ;

group               : GROUP IDENTIFIER '{' varList '}' ;

ioGroup             : groupid=IDENTIFIER groupname=IDENTIFIER '{' ioList '}' ;

/* -- bitfields -- */

bitfield            : BITFIELD IDENTIFIER '{' varList '}' ;
namedValue          : name=IDENTIFIER '=' constValue ;
initBitfield        : field=IDENTIFIER '(' namedValue (',' + namedValue)* ','? ')' ;

/* -- Expressions -- */
/* 
Precedences are not properly enforced, but this has no consequence as Silice
outputs expressions as-is to Verilog, which then applies operator precedences.
*/

expression_0        : expression_1 (
                      '+' | '-' | '||' | '|' | '===' | '==' | '!==' | '!='  | '<<<' | '>>>' | '<<' | '>>' | '<' | '>' | '<=' | '>='
                      ) expression_1 
                    | expression_0 (
                      '+' | '-' | '||' | '|' | '===' | '==' | '!==' | '!='  | '<<<' | '>>>' | '<<' | '>>' | '<' | '>' | '<=' | '>='
                      ) expression_1 
                    | expression_0 '?' expression_0 ':' expression_0
                    | expression_1;

expression_1        : unaryExpression (
                    '*' | '&&' | '&' | '^~'| '~^' | '~' | '^'
                    ) unaryExpression 
                    | expression_1 (
                    '*' | '&&' | '&' | '^~'| '~^' | '~' | '^'
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
                    | concatenation ;

/* -- Accesses to VIO -- */

bitfieldAccess      : field=IDENTIFIER '(' idOrIoAccess ')' '.' member=IDENTIFIER ;
ioAccess            : base=IDENTIFIER ('.' IDENTIFIER)+ ;
bitAccess           : (ioAccess | tableAccess | IDENTIFIER) '[' first=expression_0 ',' num=NUMBER ']' ;
tableAccess         : (ioAccess | IDENTIFIER) '[' expression_0 ']' ;
access              : (ioAccess | tableAccess | bitAccess | bitfieldAccess) ; 

idOrIoAccess        : (ioAccess | IDENTIFIER) ;

/* -- Assignments -- */
                    
assignment          : IDENTIFIER  '=' expression_0
                    | access      '=' expression_0 ;

alwaysAssigned      : IDENTIFIER   ALWSASSIGN    expression_0
                    | access       ALWSASSIGN    expression_0
                    | IDENTIFIER   ALWSASSIGNDBL expression_0
                    | access       ALWSASSIGNDBL expression_0
                    ;

alwaysAssignedList  : alwaysAssigned ';' alwaysAssignedList | ;

/* -- Algorithm calls -- */

paramList           : expression_0 ',' paramList 
                    | expression_0 
                    | ;

assign              : IDENTIFIER | access ;
assignList          : assign (',' assign)* ','? | ;

asyncExec           : IDENTIFIER LARROW '(' paramList ')' ;
joinExec            : '(' assignList ')' LARROW IDENTIFIER ;
syncExec            : joinExec LARROW '(' paramList ')' ;

/* -- Circuitry instanciation -- */

// TODO: allow passing ioAccess as well ( idOrIoAccess )
identifierList      : IDENTIFIER ',' identifierList 
                    | IDENTIFIER 
                    | ;

circuitryInst       : '(' outs=identifierList ')' '=' IDENTIFIER '(' ins=identifierList ')';

/* -- Control flow -- */

state               : state_name=IDENTIFIER ':' | NEXT ;
jump                : GOTO IDENTIFIER ;
call                : CALL IDENTIFIER ;
returnFrom          : RETURN ;
breakLoop           : BREAK ;

block               : '{' declarationList instructionList '}';
ifThen              : 'if' '(' expression_0 ')' if_block=block ;
ifThenElse          : 'if' '(' expression_0 ')' if_block=block 'else' else_block=block ;
switchCase          : 'switch' '(' expression_0 ')' '{' caseBlock * '}' ;
caseBlock           : ('case' case_value=value ':' | DEFAULT ) case_block=block;
whileLoop           : 'while' '(' expression_0 ')' while_block=block ;

displayParams       : IDENTIFIER (',' IDENTIFIER)* ;
display             : DISPLAY '(' STRING ( ',' displayParams )? ')';

instruction         : assignment 
                    | syncExec
                    | asyncExec
                    | joinExec
                    | jump
                    | call
                    | circuitryInst
                    | returnFrom
                    | breakLoop
                    | display
                    ;

alwaysBlock         : ALWAYS '{' instructionList '}';
repeatBlock         : REPEATCNT '{' instructionList '}' ;

pipeline            : block ('->' block) +;

/* -- Inputs/outputs -- */

inout               : 'inout' TYPE IDENTIFIER 
                    | 'inout' TYPE IDENTIFIER '[' NUMBER ']';
input               : 'input' nolatch='!'? TYPE IDENTIFIER
                    | 'input' nolatch='!'? TYPE IDENTIFIER '[' NUMBER ']';
output              : 'output' combinational='!'? TYPE IDENTIFIER
                    | 'output' combinational='!'? TYPE IDENTIFIER '[' NUMBER ']';
inOrOut             :  input | output | inout | ioGroup;
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
                      instructionList
					  ;

/* -- Import -- */

importv             : 'import' '(' FILENAME ')' ;

appendv             : 'append' '(' FILENAME ')' ;

/* -- Circuitry -- */

circuitry           : 'circuitry' IDENTIFIER '(' ioList ')' '{' instructionList '}' ;

/* -- Algorithm -- */

algorithm           : 'algorithm' IDENTIFIER '(' inOutList ')' algModifiers? '{' declAndInstrList '}' ;

/* -- Overall structure -- */

topList       :  (algorithm | importv | appendv | subroutine | circuitry | group | bitfield) topList | ;

root                : topList EOF ;
