// A Bison parser, made by GNU Bison 3.0.4.

// Skeleton implementation for Bison LALR(1) parsers in C++

// Copyright (C) 2002-2015 Free Software Foundation, Inc.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

// As a special exception, you may create a larger work that contains
// part or all of the Bison parser skeleton and distribute that work
// under terms of your choice, so long as that work isn't itself a
// parser generator using the skeleton or a modified version thereof
// as a parser skeleton.  Alternatively, if you modify or redistribute
// the parser skeleton itself, you may (at your option) remove this
// special exception, which will cause the skeleton and the resulting
// Bison output files to be licensed under the GNU General Public
// License without this special exception.

// This special exception was added by the Free Software Foundation in
// version 2.2 of Bison.

// Take the name prefix into account.
#define yylex   VCDParserlex

// First part of user declarations.

#line 39 "./src/VCDParser.cpp" // lalr1.cc:404

# ifndef YY_NULLPTR
#  if defined __cplusplus && 201103L <= __cplusplus
#   define YY_NULLPTR nullptr
#  else
#   define YY_NULLPTR 0
#  endif
# endif

#include "VCDParser.hpp"

// User implementation prologue.

#line 53 "./src/VCDParser.cpp" // lalr1.cc:412
// Unqualified %code blocks.
#line 36 "./src/VCDParser.ypp" // lalr1.cc:413


#include "VCDFileParser.hpp"

//! Current time while parsing the VCD file.
VCDTime current_time = 0;


#line 64 "./src/VCDParser.cpp" // lalr1.cc:413


#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> // FIXME: INFRINGES ON USER NAME SPACE.
#   define YY_(msgid) dgettext ("bison-runtime", msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(msgid) msgid
# endif
#endif

#define YYRHSLOC(Rhs, K) ((Rhs)[K].location)
/* YYLLOC_DEFAULT -- Set CURRENT to span from RHS[1] to RHS[N].
   If N is 0, then set CURRENT to the empty location which ends
   the previous symbol: RHS[0] (always defined).  */

# ifndef YYLLOC_DEFAULT
#  define YYLLOC_DEFAULT(Current, Rhs, N)                               \
    do                                                                  \
      if (N)                                                            \
        {                                                               \
          (Current).begin  = YYRHSLOC (Rhs, 1).begin;                   \
          (Current).end    = YYRHSLOC (Rhs, N).end;                     \
        }                                                               \
      else                                                              \
        {                                                               \
          (Current).begin = (Current).end = YYRHSLOC (Rhs, 0).end;      \
        }                                                               \
    while (/*CONSTCOND*/ false)
# endif


// Suppress unused-variable warnings by "using" E.
#define YYUSE(E) ((void) (E))

// Enable debugging if requested.
#if YYDEBUG

// A pseudo ostream that takes yydebug_ into account.
# define YYCDEBUG if (yydebug_) (*yycdebug_)

# define YY_SYMBOL_PRINT(Title, Symbol)         \
  do {                                          \
    if (yydebug_)                               \
    {                                           \
      *yycdebug_ << Title << ' ';               \
      yy_print_ (*yycdebug_, Symbol);           \
      *yycdebug_ << std::endl;                  \
    }                                           \
  } while (false)

# define YY_REDUCE_PRINT(Rule)          \
  do {                                  \
    if (yydebug_)                       \
      yy_reduce_print_ (Rule);          \
  } while (false)

# define YY_STACK_PRINT()               \
  do {                                  \
    if (yydebug_)                       \
      yystack_print_ ();                \
  } while (false)

#else // !YYDEBUG

# define YYCDEBUG if (false) std::cerr
# define YY_SYMBOL_PRINT(Title, Symbol)  YYUSE(Symbol)
# define YY_REDUCE_PRINT(Rule)           static_cast<void>(0)
# define YY_STACK_PRINT()                static_cast<void>(0)

#endif // !YYDEBUG

#define yyerrok         (yyerrstatus_ = 0)
#define yyclearin       (yyla.clear ())

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab
#define YYRECOVERING()  (!!yyerrstatus_)


namespace VCDParser {
#line 150 "./src/VCDParser.cpp" // lalr1.cc:479

  /* Return YYSTR after stripping away unnecessary quotes and
     backslashes, so that it's suitable for yyerror.  The heuristic is
     that double-quoting is unnecessary unless the string contains an
     apostrophe, a comma, or backslash (other than backslash-backslash).
     YYSTR is taken from yytname.  */
  std::string
  parser::yytnamerr_ (const char *yystr)
  {
    if (*yystr == '"')
      {
        std::string yyr = "";
        char const *yyp = yystr;

        for (;;)
          switch (*++yyp)
            {
            case '\'':
            case ',':
              goto do_not_strip_quotes;

            case '\\':
              if (*++yyp != '\\')
                goto do_not_strip_quotes;
              // Fall through.
            default:
              yyr += *yyp;
              break;

            case '"':
              return yyr;
            }
      do_not_strip_quotes: ;
      }

    return yystr;
  }


  /// Build a parser object.
  parser::parser (VCDFileParser & driver_yyarg)
    :
#if YYDEBUG
      yydebug_ (false),
      yycdebug_ (&std::cerr),
#endif
      driver (driver_yyarg)
  {}

  parser::~parser ()
  {}


  /*---------------.
  | Symbol types.  |
  `---------------*/



  // by_state.
  inline
  parser::by_state::by_state ()
    : state (empty_state)
  {}

  inline
  parser::by_state::by_state (const by_state& other)
    : state (other.state)
  {}

  inline
  void
  parser::by_state::clear ()
  {
    state = empty_state;
  }

  inline
  void
  parser::by_state::move (by_state& that)
  {
    state = that.state;
    that.clear ();
  }

  inline
  parser::by_state::by_state (state_type s)
    : state (s)
  {}

  inline
  parser::symbol_number_type
  parser::by_state::type_get () const
  {
    if (state == empty_state)
      return empty_symbol;
    else
      return yystos_[state];
  }

  inline
  parser::stack_symbol_type::stack_symbol_type ()
  {}


  inline
  parser::stack_symbol_type::stack_symbol_type (state_type s, symbol_type& that)
    : super_type (s, that.location)
  {
      switch (that.type_get ())
    {
      case 32: // TOK_VALUE
        value.move< VCDBit > (that.value);
        break;

      case 23: // TOK_KW_BEGIN
      case 24: // TOK_KW_FORK
      case 25: // TOK_KW_FUNCTION
      case 26: // TOK_KW_MODULE
      case 27: // TOK_KW_TASK
      case 45: // scope_type
        value.move< VCDScopeType > (that.value);
        break;

      case 28: // TOK_TIME_NUMBER
        value.move< VCDTimeRes > (that.value);
        break;

      case 29: // TOK_TIME_UNIT
        value.move< VCDTimeUnit > (that.value);
        break;

      case 30: // TOK_VAR_TYPE
        value.move< VCDVarType > (that.value);
        break;

      case 38: // TOK_DECIMAL_NUM
        value.move< int > (that.value);
        break;

      case 9: // TOK_COMMENT_TEXT
      case 11: // TOK_DATE_TEXT
      case 18: // TOK_VERSION_TEXT
      case 33: // TOK_BIN_NUM
      case 35: // TOK_REAL_NUM
      case 37: // TOK_IDENTIFIER
      case 51: // reference
      case 52: // comment_text
      case 53: // version_text
      case 54: // date_text
        value.move< std::string > (that.value);
        break;

      default:
        break;
    }

    // that is emptied.
    that.type = empty_symbol;
  }

  inline
  parser::stack_symbol_type&
  parser::stack_symbol_type::operator= (const stack_symbol_type& that)
  {
    state = that.state;
      switch (that.type_get ())
    {
      case 32: // TOK_VALUE
        value.copy< VCDBit > (that.value);
        break;

      case 23: // TOK_KW_BEGIN
      case 24: // TOK_KW_FORK
      case 25: // TOK_KW_FUNCTION
      case 26: // TOK_KW_MODULE
      case 27: // TOK_KW_TASK
      case 45: // scope_type
        value.copy< VCDScopeType > (that.value);
        break;

      case 28: // TOK_TIME_NUMBER
        value.copy< VCDTimeRes > (that.value);
        break;

      case 29: // TOK_TIME_UNIT
        value.copy< VCDTimeUnit > (that.value);
        break;

      case 30: // TOK_VAR_TYPE
        value.copy< VCDVarType > (that.value);
        break;

      case 38: // TOK_DECIMAL_NUM
        value.copy< int > (that.value);
        break;

      case 9: // TOK_COMMENT_TEXT
      case 11: // TOK_DATE_TEXT
      case 18: // TOK_VERSION_TEXT
      case 33: // TOK_BIN_NUM
      case 35: // TOK_REAL_NUM
      case 37: // TOK_IDENTIFIER
      case 51: // reference
      case 52: // comment_text
      case 53: // version_text
      case 54: // date_text
        value.copy< std::string > (that.value);
        break;

      default:
        break;
    }

    location = that.location;
    return *this;
  }


  template <typename Base>
  inline
  void
  parser::yy_destroy_ (const char* yymsg, basic_symbol<Base>& yysym) const
  {
    if (yymsg)
      YY_SYMBOL_PRINT (yymsg, yysym);
  }

#if YYDEBUG
  template <typename Base>
  void
  parser::yy_print_ (std::ostream& yyo,
                                     const basic_symbol<Base>& yysym) const
  {
    std::ostream& yyoutput = yyo;
    YYUSE (yyoutput);
    symbol_number_type yytype = yysym.type_get ();
    // Avoid a (spurious) G++ 4.8 warning about "array subscript is
    // below array bounds".
    if (yysym.empty ())
      std::abort ();
    yyo << (yytype < yyntokens_ ? "token" : "nterm")
        << ' ' << yytname_[yytype] << " ("
        << yysym.location << ": ";
    YYUSE (yytype);
    yyo << ')';
  }
#endif

  inline
  void
  parser::yypush_ (const char* m, state_type s, symbol_type& sym)
  {
    stack_symbol_type t (s, sym);
    yypush_ (m, t);
  }

  inline
  void
  parser::yypush_ (const char* m, stack_symbol_type& s)
  {
    if (m)
      YY_SYMBOL_PRINT (m, s);
    yystack_.push (s);
  }

  inline
  void
  parser::yypop_ (unsigned int n)
  {
    yystack_.pop (n);
  }

#if YYDEBUG
  std::ostream&
  parser::debug_stream () const
  {
    return *yycdebug_;
  }

  void
  parser::set_debug_stream (std::ostream& o)
  {
    yycdebug_ = &o;
  }


  parser::debug_level_type
  parser::debug_level () const
  {
    return yydebug_;
  }

  void
  parser::set_debug_level (debug_level_type l)
  {
    yydebug_ = l;
  }
#endif // YYDEBUG

  inline parser::state_type
  parser::yy_lr_goto_state_ (state_type yystate, int yysym)
  {
    int yyr = yypgoto_[yysym - yyntokens_] + yystate;
    if (0 <= yyr && yyr <= yylast_ && yycheck_[yyr] == yystate)
      return yytable_[yyr];
    else
      return yydefgoto_[yysym - yyntokens_];
  }

  inline bool
  parser::yy_pact_value_is_default_ (int yyvalue)
  {
    return yyvalue == yypact_ninf_;
  }

  inline bool
  parser::yy_table_value_is_error_ (int yyvalue)
  {
    return yyvalue == yytable_ninf_;
  }

  int
  parser::parse ()
  {
    // State.
    int yyn;
    /// Length of the RHS of the rule being reduced.
    int yylen = 0;

    // Error handling.
    int yynerrs_ = 0;
    int yyerrstatus_ = 0;

    /// The lookahead symbol.
    symbol_type yyla;

    /// The locations where the error started and ended.
    stack_symbol_type yyerror_range[3];

    /// The return value of parse ().
    int yyresult;

    // FIXME: This shoud be completely indented.  It is not yet to
    // avoid gratuitous conflicts when merging into the master branch.
    try
      {
    YYCDEBUG << "Starting parse" << std::endl;


    // User initialization code.
    #line 29 "./src/VCDParser.ypp" // lalr1.cc:741
{
    yyla.location.begin.filename = yyla.location.end.filename = &driver.filepath;
}

#line 507 "./src/VCDParser.cpp" // lalr1.cc:741

    /* Initialize the stack.  The initial state will be set in
       yynewstate, since the latter expects the semantical and the
       location values to have been already stored, initialize these
       stacks with a primary value.  */
    yystack_.clear ();
    yypush_ (YY_NULLPTR, 0, yyla);

    // A new symbol was pushed on the stack.
  yynewstate:
    YYCDEBUG << "Entering state " << yystack_[0].state << std::endl;

    // Accept?
    if (yystack_[0].state == yyfinal_)
      goto yyacceptlab;

    goto yybackup;

    // Backup.
  yybackup:

    // Try to take a decision without lookahead.
    yyn = yypact_[yystack_[0].state];
    if (yy_pact_value_is_default_ (yyn))
      goto yydefault;

    // Read a lookahead token.
    if (yyla.empty ())
      {
        YYCDEBUG << "Reading a token: ";
        try
          {
            symbol_type yylookahead (yylex (driver));
            yyla.move (yylookahead);
          }
        catch (const syntax_error& yyexc)
          {
            error (yyexc);
            goto yyerrlab1;
          }
      }
    YY_SYMBOL_PRINT ("Next token is", yyla);

    /* If the proper action on seeing token YYLA.TYPE is to reduce or
       to detect an error, take that action.  */
    yyn += yyla.type_get ();
    if (yyn < 0 || yylast_ < yyn || yycheck_[yyn] != yyla.type_get ())
      goto yydefault;

    // Reduce or error.
    yyn = yytable_[yyn];
    if (yyn <= 0)
      {
        if (yy_table_value_is_error_ (yyn))
          goto yyerrlab;
        yyn = -yyn;
        goto yyreduce;
      }

    // Count tokens shifted since error; after three, turn off error status.
    if (yyerrstatus_)
      --yyerrstatus_;

    // Shift the lookahead token.
    yypush_ ("Shifting", yyn, yyla);
    goto yynewstate;

  /*-----------------------------------------------------------.
  | yydefault -- do the default action for the current state.  |
  `-----------------------------------------------------------*/
  yydefault:
    yyn = yydefact_[yystack_[0].state];
    if (yyn == 0)
      goto yyerrlab;
    goto yyreduce;

  /*-----------------------------.
  | yyreduce -- Do a reduction.  |
  `-----------------------------*/
  yyreduce:
    yylen = yyr2_[yyn];
    {
      stack_symbol_type yylhs;
      yylhs.state = yy_lr_goto_state_(yystack_[yylen].state, yyr1_[yyn]);
      /* Variants are always initialized to an empty instance of the
         correct type. The default '$$ = $1' action is NOT applied
         when using variants.  */
        switch (yyr1_[yyn])
    {
      case 32: // TOK_VALUE
        yylhs.value.build< VCDBit > ();
        break;

      case 23: // TOK_KW_BEGIN
      case 24: // TOK_KW_FORK
      case 25: // TOK_KW_FUNCTION
      case 26: // TOK_KW_MODULE
      case 27: // TOK_KW_TASK
      case 45: // scope_type
        yylhs.value.build< VCDScopeType > ();
        break;

      case 28: // TOK_TIME_NUMBER
        yylhs.value.build< VCDTimeRes > ();
        break;

      case 29: // TOK_TIME_UNIT
        yylhs.value.build< VCDTimeUnit > ();
        break;

      case 30: // TOK_VAR_TYPE
        yylhs.value.build< VCDVarType > ();
        break;

      case 38: // TOK_DECIMAL_NUM
        yylhs.value.build< int > ();
        break;

      case 9: // TOK_COMMENT_TEXT
      case 11: // TOK_DATE_TEXT
      case 18: // TOK_VERSION_TEXT
      case 33: // TOK_BIN_NUM
      case 35: // TOK_REAL_NUM
      case 37: // TOK_IDENTIFIER
      case 51: // reference
      case 52: // comment_text
      case 53: // version_text
      case 54: // date_text
        yylhs.value.build< std::string > ();
        break;

      default:
        break;
    }


      // Compute the default @$.
      {
        slice<stack_symbol_type, stack_type> slice (yystack_, yylen);
        YYLLOC_DEFAULT (yylhs.location, slice, yylen);
      }

      // Perform the reduction.
      YY_REDUCE_PRINT (yyn);
      try
        {
          switch (yyn)
            {
  case 11:
#line 112 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    driver.fh -> date = yystack_[1].value.as< std::string > ();
}
#line 661 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 13:
#line 116 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    // PUSH the current scope stack.
    
    VCDScope * new_scope = new VCDScope();
    new_scope -> name = yystack_[1].value.as< std::string > ();
    new_scope -> type = yystack_[2].value.as< VCDScopeType > ();
    new_scope -> parent = driver.scopes.top();
    
    driver.fh -> add_scope(
        new_scope
    );
    
    driver.scopes.top() -> children.push_back(new_scope);
    driver.scopes.push(new_scope);

}
#line 682 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 14:
#line 132 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    driver.fh -> time_resolution = yystack_[2].value.as< VCDTimeRes > ();
    driver.fh -> time_units      = yystack_[1].value.as< VCDTimeUnit > ();
}
#line 691 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 15:
#line 136 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    // POP the current scope stack.

    driver.scopes.pop();

}
#line 702 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 16:
#line 143 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    // Add this variable to the current scope.

    VCDSignal * new_signal  = new VCDSignal();
    new_signal -> type      = yystack_[4].value.as< VCDVarType > ();
    new_signal -> size      = yystack_[3].value.as< int > ();
    new_signal -> hash      = yystack_[2].value.as< std::string > ();
    new_signal -> reference = yystack_[1].value.as< std::string > ();

    VCDScope * scope = driver.scopes.top();
    scope -> signals.push_back(new_signal);

    driver.fh -> add_signal(new_signal);

}
#line 722 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 17:
#line 158 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    driver.fh -> version = yystack_[1].value.as< std::string > ();
}
#line 730 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 30:
#line 181 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    current_time =  yystack_[0].value.as< int > ();
    driver.fh    -> add_timestamp(yystack_[0].value.as< int > ());
}
#line 739 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 35:
#line 194 "./src/VCDParser.ypp" // lalr1.cc:859
    {

    VCDSignalHash   hash  = yystack_[0].value.as< std::string > ();
    VCDTimedValue * toadd = new VCDTimedValue();
    
    toadd -> time   = current_time;
    toadd -> value  = new VCDValue(yystack_[1].value.as< VCDBit > ());

    driver.fh -> add_signal_value(toadd, hash);

}
#line 755 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 36:
#line 208 "./src/VCDParser.ypp" // lalr1.cc:859
    {

    VCDSignalHash   hash  = yystack_[0].value.as< std::string > ();
    VCDTimedValue * toadd = new VCDTimedValue();
    
    toadd -> time   = current_time;

    VCDBitVector * vec = new VCDBitVector();
    VCDValue * val = new VCDValue(vec);

    for(int i =1; i < yystack_[1].value.as< std::string > ().size(); i ++) {
        switch(yystack_[1].value.as< std::string > ()[i]) {
            case '0':
                vec -> push_back(VCD_0);
                break;
            case '1':
                vec -> push_back(VCD_1);
                break;
            case 'x':
            case 'X':
                vec -> push_back(VCD_X);
                break;
            case 'z':
            case 'Z':
                vec -> push_back(VCD_Z);
                break;
            default:
                vec -> push_back(VCD_X);
                break;
        }
    }

    toadd -> value = val;

    driver.fh -> add_signal_value(toadd, hash);

}
#line 797 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 37:
#line 245 "./src/VCDParser.ypp" // lalr1.cc:859
    {

    VCDSignalHash   hash  = yystack_[0].value.as< std::string > ();
    VCDTimedValue * toadd = new VCDTimedValue();
    
    toadd -> time   = current_time;
    toadd -> value  = 0;

    VCDValue * val;
    VCDReal real_value;
    
    // Legal way of parsing dumped floats according to the spec.
    // Sec 21.7.2.1, paragraph 4.
    const char * buffer = yystack_[1].value.as< std::string > ().c_str() + 1;
    std::scanf(buffer, "%g", &real_value);
    
    toadd -> value = new VCDValue(real_value);
    driver.fh -> add_signal_value(toadd, hash);
}
#line 821 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 38:
#line 266 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[0].value.as< std::string > ();
}
#line 829 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 39:
#line 269 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[3].value.as< std::string > ();
    yylhs.value.as< std::string > ().append("[");
    yylhs.value.as< std::string > ().append("]");
}
#line 839 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 40:
#line 275 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[5].value.as< std::string > ();
    yylhs.value.as< std::string > ().append("[");
    yylhs.value.as< std::string > ().append(":");
    yylhs.value.as< std::string > ().append("]");
}
#line 850 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 41:
#line 283 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string("");
}
#line 858 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 42:
#line 286 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string(yystack_[0].value.as< std::string > ());
}
#line 866 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 43:
#line 289 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[1].value.as< std::string > ();
    yylhs.value.as< std::string > ().append(yystack_[0].value.as< std::string > ());
}
#line 875 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 44:
#line 295 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string("");
}
#line 883 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 45:
#line 298 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string(yystack_[0].value.as< std::string > ());
}
#line 891 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 46:
#line 301 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[1].value.as< std::string > ();
    yylhs.value.as< std::string > ().append(yystack_[0].value.as< std::string > ());
}
#line 900 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 47:
#line 308 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string("");
}
#line 908 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 48:
#line 311 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = std::string(yystack_[0].value.as< std::string > ());
}
#line 916 "./src/VCDParser.cpp" // lalr1.cc:859
    break;

  case 49:
#line 314 "./src/VCDParser.ypp" // lalr1.cc:859
    {
    yylhs.value.as< std::string > () = yystack_[1].value.as< std::string > ();
    yylhs.value.as< std::string > ().append(yystack_[0].value.as< std::string > ());
}
#line 925 "./src/VCDParser.cpp" // lalr1.cc:859
    break;


#line 929 "./src/VCDParser.cpp" // lalr1.cc:859
            default:
              break;
            }
        }
      catch (const syntax_error& yyexc)
        {
          error (yyexc);
          YYERROR;
        }
      YY_SYMBOL_PRINT ("-> $$ =", yylhs);
      yypop_ (yylen);
      yylen = 0;
      YY_STACK_PRINT ();

      // Shift the result of the reduction.
      yypush_ (YY_NULLPTR, yylhs);
    }
    goto yynewstate;

  /*--------------------------------------.
  | yyerrlab -- here on detecting error.  |
  `--------------------------------------*/
  yyerrlab:
    // If not already recovering from an error, report this error.
    if (!yyerrstatus_)
      {
        ++yynerrs_;
        error (yyla.location, yysyntax_error_ (yystack_[0].state, yyla));
      }


    yyerror_range[1].location = yyla.location;
    if (yyerrstatus_ == 3)
      {
        /* If just tried and failed to reuse lookahead token after an
           error, discard it.  */

        // Return failure if at end of input.
        if (yyla.type_get () == yyeof_)
          YYABORT;
        else if (!yyla.empty ())
          {
            yy_destroy_ ("Error: discarding", yyla);
            yyla.clear ();
          }
      }

    // Else will try to reuse lookahead token after shifting the error token.
    goto yyerrlab1;


  /*---------------------------------------------------.
  | yyerrorlab -- error raised explicitly by YYERROR.  |
  `---------------------------------------------------*/
  yyerrorlab:

    /* Pacify compilers like GCC when the user code never invokes
       YYERROR and the label yyerrorlab therefore never appears in user
       code.  */
    if (false)
      goto yyerrorlab;
    yyerror_range[1].location = yystack_[yylen - 1].location;
    /* Do not reclaim the symbols of the rule whose action triggered
       this YYERROR.  */
    yypop_ (yylen);
    yylen = 0;
    goto yyerrlab1;

  /*-------------------------------------------------------------.
  | yyerrlab1 -- common code for both syntax error and YYERROR.  |
  `-------------------------------------------------------------*/
  yyerrlab1:
    yyerrstatus_ = 3;   // Each real token shifted decrements this.
    {
      stack_symbol_type error_token;
      for (;;)
        {
          yyn = yypact_[yystack_[0].state];
          if (!yy_pact_value_is_default_ (yyn))
            {
              yyn += yyterror_;
              if (0 <= yyn && yyn <= yylast_ && yycheck_[yyn] == yyterror_)
                {
                  yyn = yytable_[yyn];
                  if (0 < yyn)
                    break;
                }
            }

          // Pop the current state because it cannot handle the error token.
          if (yystack_.size () == 1)
            YYABORT;

          yyerror_range[1].location = yystack_[0].location;
          yy_destroy_ ("Error: popping", yystack_[0]);
          yypop_ ();
          YY_STACK_PRINT ();
        }

      yyerror_range[2].location = yyla.location;
      YYLLOC_DEFAULT (error_token.location, yyerror_range, 2);

      // Shift the error token.
      error_token.state = yyn;
      yypush_ ("Shifting", error_token);
    }
    goto yynewstate;

    // Accept.
  yyacceptlab:
    yyresult = 0;
    goto yyreturn;

    // Abort.
  yyabortlab:
    yyresult = 1;
    goto yyreturn;

  yyreturn:
    if (!yyla.empty ())
      yy_destroy_ ("Cleanup: discarding lookahead", yyla);

    /* Do not reclaim the symbols of the rule whose action triggered
       this YYABORT or YYACCEPT.  */
    yypop_ (yylen);
    while (1 < yystack_.size ())
      {
        yy_destroy_ ("Cleanup: popping", yystack_[0]);
        yypop_ ();
      }

    return yyresult;
  }
    catch (...)
      {
        YYCDEBUG << "Exception caught: cleaning lookahead and stack"
                 << std::endl;
        // Do not try to display the values of the reclaimed symbols,
        // as their printer might throw an exception.
        if (!yyla.empty ())
          yy_destroy_ (YY_NULLPTR, yyla);

        while (1 < yystack_.size ())
          {
            yy_destroy_ (YY_NULLPTR, yystack_[0]);
            yypop_ ();
          }
        throw;
      }
  }

  void
  parser::error (const syntax_error& yyexc)
  {
    error (yyexc.location, yyexc.what());
  }

  // Generate an error message.
  std::string
  parser::yysyntax_error_ (state_type yystate, const symbol_type& yyla) const
  {
    // Number of reported tokens (one for the "unexpected", one per
    // "expected").
    size_t yycount = 0;
    // Its maximum.
    enum { YYERROR_VERBOSE_ARGS_MAXIMUM = 5 };
    // Arguments of yyformat.
    char const *yyarg[YYERROR_VERBOSE_ARGS_MAXIMUM];

    /* There are many possibilities here to consider:
       - If this state is a consistent state with a default action, then
         the only way this function was invoked is if the default action
         is an error action.  In that case, don't check for expected
         tokens because there are none.
       - The only way there can be no lookahead present (in yyla) is
         if this state is a consistent state with a default action.
         Thus, detecting the absence of a lookahead is sufficient to
         determine that there is no unexpected or expected token to
         report.  In that case, just report a simple "syntax error".
       - Don't assume there isn't a lookahead just because this state is
         a consistent state with a default action.  There might have
         been a previous inconsistent state, consistent state with a
         non-default action, or user semantic action that manipulated
         yyla.  (However, yyla is currently not documented for users.)
       - Of course, the expected token list depends on states to have
         correct lookahead information, and it depends on the parser not
         to perform extra reductions after fetching a lookahead from the
         scanner and before detecting a syntax error.  Thus, state
         merging (from LALR or IELR) and default reductions corrupt the
         expected token list.  However, the list is correct for
         canonical LR with one exception: it will still contain any
         token that will not be accepted due to an error action in a
         later state.
    */
    if (!yyla.empty ())
      {
        int yytoken = yyla.type_get ();
        yyarg[yycount++] = yytname_[yytoken];
        int yyn = yypact_[yystate];
        if (!yy_pact_value_is_default_ (yyn))
          {
            /* Start YYX at -YYN if negative to avoid negative indexes in
               YYCHECK.  In other words, skip the first -YYN actions for
               this state because they are default actions.  */
            int yyxbegin = yyn < 0 ? -yyn : 0;
            // Stay within bounds of both yycheck and yytname.
            int yychecklim = yylast_ - yyn + 1;
            int yyxend = yychecklim < yyntokens_ ? yychecklim : yyntokens_;
            for (int yyx = yyxbegin; yyx < yyxend; ++yyx)
              if (yycheck_[yyx + yyn] == yyx && yyx != yyterror_
                  && !yy_table_value_is_error_ (yytable_[yyx + yyn]))
                {
                  if (yycount == YYERROR_VERBOSE_ARGS_MAXIMUM)
                    {
                      yycount = 1;
                      break;
                    }
                  else
                    yyarg[yycount++] = yytname_[yyx];
                }
          }
      }

    char const* yyformat = YY_NULLPTR;
    switch (yycount)
      {
#define YYCASE_(N, S)                         \
        case N:                               \
          yyformat = S;                       \
        break
        YYCASE_(0, YY_("syntax error"));
        YYCASE_(1, YY_("syntax error, unexpected %s"));
        YYCASE_(2, YY_("syntax error, unexpected %s, expecting %s"));
        YYCASE_(3, YY_("syntax error, unexpected %s, expecting %s or %s"));
        YYCASE_(4, YY_("syntax error, unexpected %s, expecting %s or %s or %s"));
        YYCASE_(5, YY_("syntax error, unexpected %s, expecting %s or %s or %s or %s"));
#undef YYCASE_
      }

    std::string yyres;
    // Argument number.
    size_t yyi = 0;
    for (char const* yyp = yyformat; *yyp; ++yyp)
      if (yyp[0] == '%' && yyp[1] == 's' && yyi < yycount)
        {
          yyres += yytnamerr_ (yyarg[yyi++]);
          ++yyp;
        }
      else
        yyres += *yyp;
    return yyres;
  }


  const signed char parser::yypact_ninf_ = -22;

  const signed char parser::yytable_ninf_ = -1;

  const signed char
  parser::yypact_[] =
  {
      49,    43,     3,     8,    67,   -21,     9,   -13,     2,   -11,
     -11,   -11,   -11,   -12,     4,    13,    17,    25,    49,    66,
     -22,   -22,   -22,   -22,   -22,   -22,   -22,    -4,   -22,    -3,
     -22,    -2,   -22,   -22,   -22,   -22,   -22,   -22,    30,    10,
     -22,    -6,   -22,    -5,     1,     5,    16,    23,   -22,   -22,
     -22,   -22,   -22,    66,   -22,   -11,   -22,   -22,   -22,   -22,
     -22,   -22,   -22,    35,    36,    40,   -22,   -22,   -22,   -22,
     -22,   -22,   -22,   -22,    42,    57,    65,    45,   -22,     6,
     -22,    51,    69,   -22
  };

  const unsigned char
  parser::yydefact_[] =
  {
       2,    41,    47,     0,     0,     0,     0,     0,    44,     0,
       0,     0,     0,     0,     0,     0,     0,     0,     5,     4,
       6,     8,    23,    24,    33,    34,    42,     0,    31,     0,
      48,     0,    12,    25,    26,    27,    28,    29,     0,     0,
      15,     0,    45,     0,     0,     0,     0,     0,    30,    35,
      36,    37,     1,     3,     7,     0,     9,    22,    32,    10,
      43,    11,    49,     0,     0,     0,    17,    46,    18,    19,
      20,    21,    13,    14,     0,    38,     0,     0,    16,     0,
      39,     0,     0,    40
  };

  const signed char
  parser::yypgoto_[] =
  {
     -22,   -22,   -22,    77,    78,   -18,   -22,   -22,    93,     0,
     -22,   -22,   -22,   -22,   -22,   -22
  };

  const signed char
  parser::yydefgoto_[] =
  {
      -1,    17,    18,    19,    20,    21,    38,    22,    27,    28,
      24,    25,    76,    29,    43,    31
  };

  const unsigned char
  parser::yytable_[] =
  {
      23,    56,    66,    57,    59,    61,    60,    39,    68,    62,
      80,    81,    69,    67,    30,    32,    40,    41,    23,    23,
      42,    14,    15,    70,    16,    52,    48,    58,    14,    15,
      71,    16,    65,    14,    15,    56,    16,    14,    15,    64,
      16,    49,    72,    73,    58,    58,    58,    58,    14,    15,
      50,    16,    26,    23,    51,    14,    15,     1,    16,     2,
      77,     3,     4,     5,     6,     7,     8,    63,     9,    10,
      11,    12,    78,    83,    55,    14,    15,    74,    16,    75,
      13,    14,    15,    79,    16,     9,    10,    11,    12,    82,
      33,    34,    35,    36,    37,    53,    54,    13,    14,    15,
       0,    16,    44,    45,    46,    47
  };

  const signed char
  parser::yycheck_[] =
  {
       0,    19,     7,     7,     7,     7,     9,    28,     7,    11,
       4,     5,     7,    18,    11,     7,     7,    30,    18,    19,
      18,    32,    33,     7,    35,     0,    38,    27,    32,    33,
       7,    35,    38,    32,    33,    53,    35,    32,    33,    29,
      35,    37,     7,     7,    44,    45,    46,    47,    32,    33,
      37,    35,     9,    53,    37,    32,    33,     8,    35,    10,
       3,    12,    13,    14,    15,    16,    17,    37,    19,    20,
      21,    22,     7,     4,     8,    32,    33,    37,    35,    37,
      31,    32,    33,    38,    35,    19,    20,    21,    22,    38,
      23,    24,    25,    26,    27,    18,    18,    31,    32,    33,
      -1,    35,     9,    10,    11,    12
  };

  const unsigned char
  parser::yystos_[] =
  {
       0,     8,    10,    12,    13,    14,    15,    16,    17,    19,
      20,    21,    22,    31,    32,    33,    35,    40,    41,    42,
      43,    44,    46,    48,    49,    50,     9,    47,    48,    52,
      11,    54,     7,    23,    24,    25,    26,    27,    45,    28,
       7,    30,    18,    53,    47,    47,    47,    47,    38,    37,
      37,    37,     0,    42,    43,     8,    44,     7,    48,     7,
       9,     7,    11,    37,    29,    38,     7,    18,     7,     7,
       7,     7,     7,     7,    37,    37,    51,     3,     7,    38,
       4,     5,    38,     4
  };

  const unsigned char
  parser::yyr1_[] =
  {
       0,    39,    40,    40,    40,    40,    41,    41,    42,    42,
      43,    43,    43,    43,    43,    43,    43,    43,    44,    44,
      44,    44,    44,    44,    44,    45,    45,    45,    45,    45,
      46,    47,    47,    48,    48,    49,    50,    50,    51,    51,
      51,    52,    52,    52,    53,    53,    53,    54,    54,    54
  };

  const unsigned char
  parser::yyr2_[] =
  {
       0,     2,     0,     2,     1,     1,     1,     2,     1,     2,
       3,     3,     2,     4,     4,     2,     6,     3,     3,     3,
       3,     3,     3,     1,     1,     1,     1,     1,     1,     1,
       2,     1,     2,     1,     1,     2,     2,     2,     1,     4,
       6,     0,     1,     2,     0,     1,     2,     0,     1,     2
  };



  // YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
  // First, the terminals, then, starting at \a yyntokens_, nonterminals.
  const char*
  const parser::yytname_[] =
  {
  "\"end of file\"", "error", "$undefined", "TOK_BRACKET_O",
  "TOK_BRACKET_C", "TOK_COLON", "TOK_DOLLAR", "TOK_KW_END",
  "TOK_KW_COMMENT", "TOK_COMMENT_TEXT", "TOK_KW_DATE", "TOK_DATE_TEXT",
  "TOK_KW_ENDDEFINITIONS", "TOK_KW_SCOPE", "TOK_KW_TIMESCALE",
  "TOK_KW_UPSCOPE", "TOK_KW_VAR", "TOK_KW_VERSION", "TOK_VERSION_TEXT",
  "TOK_KW_DUMPALL", "TOK_KW_DUMPOFF", "TOK_KW_DUMPON", "TOK_KW_DUMPVARS",
  "TOK_KW_BEGIN", "TOK_KW_FORK", "TOK_KW_FUNCTION", "TOK_KW_MODULE",
  "TOK_KW_TASK", "TOK_TIME_NUMBER", "TOK_TIME_UNIT", "TOK_VAR_TYPE",
  "TOK_HASH", "TOK_VALUE", "TOK_BIN_NUM", "TOK_BINARY_NUMBER",
  "TOK_REAL_NUM", "TOK_REAL_NUMBER", "TOK_IDENTIFIER", "TOK_DECIMAL_NUM",
  "$accept", "input", "declaration_commands", "simulation_commands",
  "declaration_command", "simulation_command", "scope_type",
  "simulation_time", "value_changes", "value_change",
  "scalar_value_change", "vector_value_change", "reference",
  "comment_text", "version_text", "date_text", YY_NULLPTR
  };

#if YYDEBUG
  const unsigned short int
  parser::yyrline_[] =
  {
       0,    94,    94,    95,    96,    97,   101,   102,   106,   107,
     111,   112,   115,   116,   132,   136,   142,   158,   164,   165,
     166,   167,   168,   169,   170,   174,   175,   176,   177,   178,
     181,   187,   188,   191,   192,   194,   208,   245,   266,   269,
     274,   283,   286,   289,   295,   298,   301,   308,   311,   314
  };

  // Print the state stack on the debug stream.
  void
  parser::yystack_print_ ()
  {
    *yycdebug_ << "Stack now";
    for (stack_type::const_iterator
           i = yystack_.begin (),
           i_end = yystack_.end ();
         i != i_end; ++i)
      *yycdebug_ << ' ' << i->state;
    *yycdebug_ << std::endl;
  }

  // Report on the debug stream that the rule \a yyrule is going to be reduced.
  void
  parser::yy_reduce_print_ (int yyrule)
  {
    unsigned int yylno = yyrline_[yyrule];
    int yynrhs = yyr2_[yyrule];
    // Print the symbols being reduced, and their result.
    *yycdebug_ << "Reducing stack by rule " << yyrule - 1
               << " (line " << yylno << "):" << std::endl;
    // The symbols being reduced.
    for (int yyi = 0; yyi < yynrhs; yyi++)
      YY_SYMBOL_PRINT ("   $" << yyi + 1 << " =",
                       yystack_[(yynrhs) - (yyi + 1)]);
  }
#endif // YYDEBUG



} // VCDParser
#line 1363 "./src/VCDParser.cpp" // lalr1.cc:1167
#line 319 "./src/VCDParser.ypp" // lalr1.cc:1168



void VCDParser::parser::error (
    const location_type& l,
    const std::string& m) {
    driver.error(l,m);
}
