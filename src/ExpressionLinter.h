/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007

With the additional clause that the copyright notice
above, identitfying the author and original copyright
holder must remain included in all distributions.

(header_1_0)
*/
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "siliceLexer.h"
#include "siliceParser.h"

#include "Algorithm.h"

// -------------------------------------------------

class LuaPreProcessor;

// -------------------------------------------------

namespace Silice
{

  // -------------------------------------------------

  /// \brief expression linter
  class ExpressionLinter
  {
  private:

    /// \brief Host algorithm
    const Algorithm *m_Host;

    /// \brief Instantiation context for parameterized VIOs
    const Algorithm::t_instantiation_context& m_Ictx;

    /// \brief Does the Linter warn about width mismatches in assignments? (there are very frequent)
    bool m_WarnAssignWidth = false;

    /// \brief types of warnings
    enum e_WarningType { Standard, Deprecation };

    /// \brief issues a warning
    void warn(e_WarningType type, antlr4::misc::Interval interval, int line, const char *msg, ...) const;

    /// \brief check concatenation consistency
    void checkConcatenation(
      antlr4::tree::ParseTree *expr,
      const std::vector<t_type_nfo>& tns) const;

    /// \brief check operator consistency and return expected type
    void checkAndApplyOperator(
      antlr4::tree::ParseTree *expr,
      std::string op,
      const t_type_nfo& nfo_a,
      const t_type_nfo& nfo_b,
      t_type_nfo& _nfo
    ) const;

    /// \brief check unary operator consistency and return expected type
    void checkAndApplyUnaryOperator(
      antlr4::tree::ParseTree *expr,
      std::string op,
      const t_type_nfo& nfo_u,
      t_type_nfo& _nfo
    ) const;
    
    /// \brief check both sides of a ternary select are the same
    void checkTernary(
      antlr4::tree::ParseTree *expr,
      const t_type_nfo& nfo_a,
      const t_type_nfo& nfo_b
    ) const;

    /// \brief returns type nfo of expression
    void typeNfo(
      antlr4::tree::ParseTree                        *expr,
      const Algorithm::t_combinational_block_context *bctx, 
      t_type_nfo& _nfo) const;

    /// \brief returns type nfo of an identifier
    void typeNfo(
      std::string                                     idnt,
      const Algorithm::t_combinational_block_context *bctx,
      t_type_nfo& _nfo) const;

    /// \brief resolves a parameterized VIO knowing the instantiation context
    void resolveParameterized(std::string idnt, const Algorithm::t_combinational_block_context *bctx, t_type_nfo &_nfo) const;

    /// \brief Token stream for warning reporting, optionally set
    static antlr4::TokenStream *s_TokenStream;
    /// \brief Pre-processor, optionally set
    static LuaPreProcessor     *s_LuaPreProcessor;

  public:

    ExpressionLinter(const Algorithm *host, const Algorithm::t_instantiation_context& ictx) : m_Host(host), m_Ictx(ictx) { }

    /// \brief Lint an expression
    void lint(
      siliceParser::Expression_0Context              *expr, 
      const Algorithm::t_combinational_block_context *bctx) const;

    /// \brief Lint an assignment
    void lintAssignment(
      siliceParser::AccessContext                    *access,
      antlr4::tree::TerminalNode                     *identifier,
      siliceParser::Expression_0Context              *expr,
      const Algorithm::t_combinational_block_context *bctx) const;

    /// \brief Lint a wire assignment
    void lintWireAssignment(
      const Algorithm::t_instr_nfo& wire_assign) const;

    /// \brief Lint an input parameter
    void lintInputParameter(
      std::string                                     name,
      const t_type_nfo                               &param,
      const Algorithm::t_call_param                  &inp,
      const Algorithm::t_combinational_block_context *bctx) const;

    /// \brief Lint an readback assignment
    void lintReadback(
      std::string                                     name,
      const Algorithm::t_call_param                  &outp,
      const t_type_nfo                               &rvalue_nfo,
      const Algorithm::t_combinational_block_context *bctx) const;

    /// \brief Lint a binding
    void lintBinding(
      std::string                                     msg,
      Algorithm::e_BindingDir                         dir,
      int                                             line,
      const t_type_nfo                               &left,
      const t_type_nfo                               &right
      ) const;

    /// \brief set the token stream
    static void setTokenStream(antlr4::TokenStream *tks)
    {
      s_TokenStream = tks;
    }

    /// \brief set the pre-processor
    static void setLuaPreProcessor(LuaPreProcessor *lpp)
    {
      s_LuaPreProcessor = lpp;
    }

    /// \brief get a token from a source interval (helper)
    antlr4::Token              *getToken(antlr4::misc::Interval interval,bool last_else_first = false);
    /// \brief returns the source file and line for the given token (helper)
    std::pair<std::string, int> getTokenSourceFileAndLine(antlr4::Token *tk);

  };

  // -------------------------------------------------

};

// -------------------------------------------------
