/*!
@file
@brief Contains the lexical definition for the parser.
*/

%{
    
#include <cerrno>
#include <climits>
#include <cstdlib>
#include <string>
#include <cstring>
#include <cstdio>

#include "VCDFileParser.hpp"
#include "VCDParser.hpp"

#undef yywrap
#define yywrap() 1

#define yyterminate() return VCDParser::parser::make_END(loc)

static VCDParser::location loc;
    
%}

%option noyywrap nounput batch debug noinput

BRACKET_O           \[
BRACKET_C           \]
COLON               :
DOLLAR              \$
KW_END              \$end 
KW_COMMENT          \$comment
KW_DATE             \$date
KW_ENDDEFINITIONS   \$enddefinitions
KW_SCOPE            \$scope
KW_TIMESCALE        \$timescale
KW_UPSCOPE          \$upscope
KW_VAR              \$var
KW_VERSION          \$version
KW_DUMPALL          \$dumpall
KW_DUMPOFF          \$dumpoff
KW_DUMPON           \$dumpon
KW_DUMPVARS         \$dumpvars
KW_BEGIN            begin
KW_FORK             fork
KW_FUNCTION         function
KW_MODULE           module
KW_TASK             task
TIME_NUMBER         1|10|100
TIME_UNIT           s|ms|us|ns|ps|fs
VAR_TYPE_EVENT      event
VAR_TYPE_INTEGER    integer
VAR_TYPE_PARAMETER  parameter
VAR_TYPE_REAL       real
VAR_TYPE_REALTIME   realtime
VAR_TYPE_REG        reg
VAR_TYPE_SUPPLY0    supply0
VAR_TYPE_SUPPLY1    supply1
VAR_TYPE_TIME       time
VAR_TYPE_TRI        tri
VAR_TYPE_TRIAND     triand
VAR_TYPE_TRIOR      trior
VAR_TYPE_TRIREG     trireg
VAR_TYPE_TRI0       tri0
VAR_TYPE_TRI1       tri1
VAR_TYPE_WAND       wand
VAR_TYPE_WIRE       wire
VAR_TYPE_WOR        wor
HASH                #
SCALAR_NUM          0|1|x|X|z|Z       
BIN_NUM             (b|B)(0|1|x|X|z|Z)+
REAL_NUM            (r|r)(0-9)+[\.(0.9)+]
IDENTIFIER_CODE     [a-zA-Z_0-9!/\,\.@':~#\*\(\)\+\{\}\$\%\[\]`\"&;<>=\?\-\^\(\)\|\\]+
SCOPE_IDENTIFIER    [a-zA-Z_][a-zA-Z_0-9\(\)]+
DECIMAL_NUM         [0-9]+

COMMENT_TEXT        [^("$")]*
DATE_TEXT           [^("$")]*
VERSION_TEXT        [^("$")]*

%x IN_COMMENT
%x IN_DATE
%x IN_VERSION
%x IN_TIMESCALE
%x IN_SCOPE
%x IN_VAR
%x IN_VAR_PID
%x IN_VAR_PSIZE
%x IN_VAR_RNG
%x IN_SIMTIME
%x IN_VAL_CHANGES
%x IN_VAL_IDCODE

%{
#define YY_USER_ACTION loc.columns(yyleng);
%}

%%

%{
    loc.step();
%}


{KW_END} {
    return VCDParser::parser::make_TOK_KW_END(loc);
}

<IN_VAL_IDCODE,IN_VAR,IN_VAR_PID,IN_VAR_RNG,IN_VERSION,IN_DATE,IN_COMMENT,IN_TIMESCALE,IN_SCOPE>{KW_END} {
    BEGIN(INITIAL);
    return VCDParser::parser::make_TOK_KW_END(loc);
}

{KW_COMMENT} {
    BEGIN(IN_COMMENT);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_COMMENT(loc);
}

<IN_COMMENT>{COMMENT_TEXT} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_COMMENT_TEXT(std::string(yytext),loc);
}

{KW_DATE} {
    BEGIN(IN_DATE);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_DATE(loc);
}

<IN_DATE>{DATE_TEXT} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_DATE_TEXT(std::string(yytext),loc);
}

{KW_VERSION} {
    BEGIN(IN_VERSION);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_VERSION(loc);
}

<IN_VERSION>{VERSION_TEXT} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_VERSION_TEXT(std::string(yytext),loc);
}

{KW_TIMESCALE} {
    BEGIN(IN_TIMESCALE);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_TIMESCALE(loc);
}

<IN_TIMESCALE>{TIME_NUMBER} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_TIME_NUMBER(std::atoi(yytext),loc);
}

<IN_TIMESCALE>{TIME_UNIT} {
    //std::cout << yytext << ", ";
    VCDTimeUnit tr = TIME_S;

    if(std::strcmp(yytext, "s")) {
        tr = TIME_S;
    } else if(std::strcmp(yytext, "ms")) {
        tr = TIME_MS;
    } else if(std::strcmp(yytext, "us")) {
        tr = TIME_US;
    } else if(std::strcmp(yytext, "ns")) {
        tr = TIME_NS;
    } else if(std::strcmp(yytext, "ps")) {
        tr = TIME_PS;
    }

    return VCDParser::parser::make_TOK_TIME_UNIT(tr,loc);
}


{KW_SCOPE} {
    BEGIN(IN_SCOPE);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_SCOPE(loc);
}

<IN_SCOPE>{KW_BEGIN} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_BEGIN(VCD_SCOPE_BEGIN,loc);
}

<IN_SCOPE>{KW_FORK} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_FORK(VCD_SCOPE_FORK,loc);
}

<IN_SCOPE>{KW_FUNCTION} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_FUNCTION(VCD_SCOPE_FUNCTION, loc);
}

<IN_SCOPE>{KW_MODULE} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_MODULE(VCD_SCOPE_MODULE, loc);
}

<IN_SCOPE>{KW_TASK} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_TASK(VCD_SCOPE_TASK, loc);
}

<IN_SCOPE>{SCOPE_IDENTIFIER} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_IDENTIFIER(std::string(yytext),loc);
}

{KW_UPSCOPE} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_UPSCOPE(loc);
}

{KW_ENDDEFINITIONS} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_ENDDEFINITIONS(loc);
}

{KW_VAR} {
    BEGIN(IN_VAR);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_VAR(loc);
}

<IN_VAR>{VAR_TYPE_EVENT} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_EVENT    ,loc);}
<IN_VAR>{VAR_TYPE_INTEGER} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_INTEGER  ,loc);}
<IN_VAR>{VAR_TYPE_PARAMETER} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_PARAMETER,loc);}
<IN_VAR>{VAR_TYPE_REAL} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_REAL     ,loc);}
<IN_VAR>{VAR_TYPE_REALTIME} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_REALTIME ,loc);}
<IN_VAR>{VAR_TYPE_REG} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_REG      ,loc);}
<IN_VAR>{VAR_TYPE_SUPPLY0} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_SUPPLY0  ,loc);}
<IN_VAR>{VAR_TYPE_SUPPLY1} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_SUPPLY1  ,loc);}
<IN_VAR>{VAR_TYPE_TIME} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TIME     ,loc);}
<IN_VAR>{VAR_TYPE_TRI} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRI      ,loc);}
<IN_VAR>{VAR_TYPE_TRIAND} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRIAND   ,loc);}
<IN_VAR>{VAR_TYPE_TRIOR} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRIOR    ,loc);}
<IN_VAR>{VAR_TYPE_TRIREG} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRIREG   ,loc);}
<IN_VAR>{VAR_TYPE_TRI0} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRI0     ,loc);}
<IN_VAR>{VAR_TYPE_TRI1} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_TRI1     ,loc);}
<IN_VAR>{VAR_TYPE_WAND} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_WAND     ,loc);}
<IN_VAR>{VAR_TYPE_WIRE} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_WIRE     ,loc);}
<IN_VAR>{VAR_TYPE_WOR} {return VCDParser::parser::make_TOK_VAR_TYPE(VCD_VAR_WOR      ,loc);}

<IN_VAR>{DECIMAL_NUM} {
    BEGIN(IN_VAR_PSIZE);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_DECIMAL_NUM(std::atoi(yytext),loc);
}

<IN_VAR_PSIZE>{IDENTIFIER_CODE} {
    BEGIN(IN_VAR_PID);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_IDENTIFIER(std::string(yytext),loc);
}

<IN_VAR_PID>{SCOPE_IDENTIFIER} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_IDENTIFIER(std::string(yytext),loc);
}

<IN_VAR_PID>{BRACKET_O} {
    BEGIN(IN_VAR_RNG);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_BRACKET_O(loc);
}

<IN_VAR_RNG>{DECIMAL_NUM} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_DECIMAL_NUM(std::atoi(yytext),loc);
}

<IN_VAR_RNG>{COLON} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_COLON(loc);
}

<IN_VAR_RNG>{BRACKET_C} {
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_BRACKET_C(loc);
}

{HASH} {
    BEGIN(IN_SIMTIME);
    //std::cout << "simtime: " << yytext << ", ";
    return VCDParser::parser::make_TOK_HASH(loc);
}

<IN_SIMTIME>{DECIMAL_NUM} {
    BEGIN(INITIAL);
    //std::cout << yytext << std::endl;
    return VCDParser::parser::make_TOK_DECIMAL_NUM(std::atoi(yytext),loc);
}

{KW_DUMPALL} {
    BEGIN(IN_VAL_CHANGES);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_DUMPALL(loc);
}

{KW_DUMPOFF} {
    BEGIN(IN_VAL_CHANGES);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_DUMPOFF(loc);
}

{KW_DUMPON} {
    BEGIN(IN_VAL_CHANGES);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_DUMPON(loc);
}

{KW_DUMPVARS} {
    BEGIN(IN_VAL_CHANGES);
    //std::cout << yytext << ", ";
    return VCDParser::parser::make_TOK_KW_DUMPVARS(loc);
}

<IN_VAL_CHANGES,INITIAL>{SCALAR_NUM} {
    //std::cout << yytext << ", ";
    BEGIN(IN_VAL_IDCODE);

    VCDBit val;

    switch(yytext[0]) {
        case '0':
            val = VCD_0;
            break;
        case '1':
            val = VCD_1;
            break;
        case 'x':
        case 'X':
            val = VCD_X;
            break;
        case 'z':
        case 'Z':
            val = VCD_Z;
            break;
        default:
            val = VCD_X;
            break;
    }

    return VCDParser::parser::make_TOK_VALUE(val, loc);
}

<IN_VAL_CHANGES,INITIAL>{BIN_NUM} {
    //std::cout << yytext << ", ";
    BEGIN(IN_VAL_IDCODE);
    return VCDParser::parser::make_TOK_BIN_NUM(std::string(yytext), loc);
}

<IN_VAL_CHANGES,INITIAL>{REAL_NUM} {
    //std::cout << yytext << ", ";
    BEGIN(IN_VAL_IDCODE);
    return VCDParser::parser::make_TOK_REAL_NUM(std::string(yytext), loc);
}

<IN_VAL_IDCODE>{IDENTIFIER_CODE} {
    //std::cout << yytext << std::endl;
    BEGIN(INITIAL);
    return VCDParser::parser::make_TOK_IDENTIFIER(std::string(yytext),loc);
}

\t {loc.columns();}
\n {loc.lines();}
\r {loc.lines();}


<<EOF>> {
    return VCDParser::parser::make_END(loc);
}

<*>.|\n {
    // DO nothing!
}

%%

void VCDFileParser::scan_begin() {
    yy_flex_debug = trace_scanning;
    if(filepath.empty() || filepath == "-") {
        yyin = stdin;
    }
    else if(!(yyin = fopen(filepath.c_str(), "r"))) {
        error("Cannot open "+filepath+": "+strerror(errno));
        exit(EXIT_FAILURE);
    }
}

void VCDFileParser::scan_end() {
    fclose(yyin);
    yypop_buffer_state();
}
