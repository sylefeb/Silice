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

FILENAME            : '\'' (DIGIT|LETTERU|'.'|'/')* '\'' ;

REPEATCNT           : NUMBER 'x' ;

SUB                 : 'subroutine' ;

RETURN              : 'return' ;

CALL                : 'call' ;

BREAK               : 'break' ;

DISPLAY             : '$display' ;

DEFAULT             : 'default' (' ' | '\t')* ':';

LARROW              : '<-' ;
RARROW              : '->' ;

LDEFINE             : '<:' ;
RDEFINE             : ':>' ;
BDEFINE             : '<:>';
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

STRING              : '"' ~[\r\n"]* '"' ;

/* ======== Parser ======== */

/* -- Declarations, init and bindings -- */

value               : minus='-'? NUMBER | CONSTANT ;

sclock              :  '@' IDENTIFIER ;
sreset              :  '!' IDENTIFIER ;
sautorun            :  AUTORUN ;

algModifier         : sclock | sreset | sautorun ;

algModifiers        : '<' (algModifier ',') * algModifier '>' ;

initList            : '{' (value ',')* value? '}';

declarationVar      : TYPE IDENTIFIER '=' value ;
declarationTable    : TYPE IDENTIFIER '[' NUMBER? ']' '=' (initList | STRING);
declarationModAlg   : modalg=IDENTIFIER name=IDENTIFIER algModifiers? ( '(' modalgBindingList ')' ) ?;
declaration         : declarationVar | declarationModAlg | declarationTable ; 

modalgBinding       : left=IDENTIFIER (LDEFINE | RDEFINE | BDEFINE) right=IDENTIFIER | AUTO;
modalgBindingList   : modalgBinding ',' modalgBindingList | modalgBinding | ;

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

concatenation       : '{' (expression_0 ',')* expression_0 '}' ;

atom                : CONSTANT 
                    | NUMBER 
                    | IDENTIFIER 
                    | REPEATID
                    | access
                    | '(' expression_0 ')'
					| concatenation ;

/* -- Accesses to VIO -- */

ioAccess            : algo=IDENTIFIER '.' io=IDENTIFIER ;
bitAccess           : (ioAccess | tableAccess | IDENTIFIER) '[' first=expression_0 ',' num=NUMBER ']' ;
tableAccess         : (ioAccess | IDENTIFIER) '[' expression_0 ']' ;
access              : (ioAccess | tableAccess | bitAccess) ; 

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

paramList           : IDENTIFIER ',' paramList 
                    | IDENTIFIER 
                    | IDENTIFIER '[' NUMBER ']' ',' paramList 
                    | IDENTIFIER '[' NUMBER ']'
                    | ;

asyncExec           : IDENTIFIER LARROW '(' paramList ')' ;
joinExec            : '(' paramList ')' LARROW IDENTIFIER ;
syncExec            : joinExec LARROW '(' paramList ')' ;

/* -- Control flow -- */

state               : state_name=IDENTIFIER ':' | NEXT ;
jump                : GOTO IDENTIFIER ;
call                : CALL IDENTIFIER ;
returnFrom          : RETURN ;
breakLoop           : BREAK ;

block               : '{' instructionList '}';
ifThen              : 'if' '(' expression_0 ')' if_block=block ;
ifThenElse          : 'if' '(' expression_0 ')' if_block=block 'else' else_block=block ;
switchCase          : 'switch' '(' expression_0 ')' '{' caseBlock * '}' ;
caseBlock           : ('case' case_value=value ':' | DEFAULT ) case_block=block;
whileLoop           : 'while' '(' expression_0 ')' while_block=block ;

displayParams       : (IDENTIFIER ',') * IDENTIFIER ;
display             : DISPLAY '(' STRING ( ',' displayParams )? ')';

instruction         : assignment 
                    | syncExec
                    | asyncExec
                    | joinExec
                    | jump
                    | call
					| returnFrom
                    | breakLoop
					| display
                    ;

repeatBlock         : REPEATCNT '{' instructionList '}' ;

pipeline            : block ('->' block) +;

/* -- Inputs/outputs -- */

inout               : 'inout' TYPE IDENTIFIER 
                    | 'inout' TYPE IDENTIFIER '[' NUMBER ']';
input               : 'input' TYPE IDENTIFIER 
                    | 'input' TYPE IDENTIFIER '[' NUMBER ']';
output              : 'output' combinational='!'? TYPE IDENTIFIER
                    | 'output' combinational='!'? TYPE IDENTIFIER '[' NUMBER ']';
inOrOut             :  input | output | inout ;
inOutList           :  (inOrOut ',') * inOrOut | ;

/* -- Declarations, subroutines, instruction lists -- */

declarationList     : declaration ';' declarationList | ;

instructionList     : 
                      (instruction ';') + instructionList 
                    | repeatBlock instructionList
                    | state       instructionList
                    | ifThenElse  instructionList
                    | ifThen      instructionList
                    | whileLoop   instructionList
					| switchCase  instructionList
					| pipeline    instructionList
					| ;

subroutineParam     : ( READ | WRITE | READWRITE ) IDENTIFIER
					| input | output ;
subroutineParamList : (subroutineParam ',')* subroutineParam;
subroutine          : SUB IDENTIFIER '(' subroutineParamList ')' '{' declList = declarationList  instructionList RETURN ';' '}' ;
subroutineList      : subroutine * ;
                    
declAndInstrList    : declList = declarationList 
                      subroutineList 
                      alwaysPre  = alwaysAssignedList 
                      instructionList
					  ;

/* -- Import -- */

importv             : 'import' '(' FILENAME ')' ;

appendv             : 'append' '(' FILENAME ')' ;

/* -- Algorithm -- */

algorithm           : 'algorithm' IDENTIFIER '(' inOutList ')' algModifiers? '{' declAndInstrList '}' ;

/* -- Overall structure -- */

topList       :  (algorithm | importv | appendv | subroutine) topList | ;

root                : topList ;
