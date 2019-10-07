grammar lpp;

/* ======== Lexer ======== */

fragment LETTER     : [a-zA-Z_] ;
fragment DIGIT      : [0-9] ;

WHITESPACE          : (' ' | '\t') -> skip ;

NEWLINE             : ('\r'? '\n' | '\r') ;

ANY                 : ~[\r\n$]+ ;

/* ======== Parser ======== */

lualine     : '$$' code=ANY ;

luacode     : '$' code=ANY '$' ;

silicecode  : ANY ;

siliceline  : silicecode? (luacode silicecode?) * ;

line  : lualine | siliceline;

root  : (line NEWLINE) * line ;
