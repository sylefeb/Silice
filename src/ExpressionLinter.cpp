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

#include "ExpressionLinter.h"
#include "LuaPreProcessor.h"

// -------------------------------------------------

using namespace Silice;

// -------------------------------------------------

antlr4::TokenStream *ExpressionLinter::s_TokenStream     = nullptr;
LuaPreProcessor     *ExpressionLinter::s_LuaPreProcessor = nullptr;

// -------------------------------------------------

void ExpressionLinter::lint(
  siliceParser::Expression_0Context              *expr,
  const Algorithm::t_combinational_block_context *bctx) const
{
  t_type_nfo nfo;
  typeNfo(expr,bctx,nfo);
}

// -------------------------------------------------

void ExpressionLinter::lintAssignment(
  siliceParser::AccessContext                    *access,
  antlr4::tree::TerminalNode                     *identifier,
  siliceParser::Expression_0Context              *expr,
  const Algorithm::t_combinational_block_context *bctx) const
{
  t_type_nfo lvalue_nfo;
  if (access != nullptr) {
    typeNfo(access, bctx, lvalue_nfo);
  } else {
    sl_assert(identifier != nullptr);
    lvalue_nfo = m_Host->determineIdentifierTypeAndWidth(bctx, identifier, (int)identifier->getSymbol()->getLine());
  }
  t_type_nfo rvalue_nfo;
  typeNfo(expr, bctx, rvalue_nfo);
  // check
  if (lvalue_nfo.base_type != rvalue_nfo.base_type) {
    if (rvalue_nfo.base_type == Int) {
      warn(expr->getSourceInterval(), -1, "assigning signed expression to unsigned lvalue");
    }
  }
  if (lvalue_nfo.width < rvalue_nfo.width) {
    warn(expr->getSourceInterval(), -1, "assigning %d bits wide expression to %d bits wide lvalue", rvalue_nfo.width,lvalue_nfo.width);
  }
}

// -------------------------------------------------

void ExpressionLinter::lintInputParameter(
  std::string                                     name,
  const t_type_nfo                               &param,
  siliceParser::Expression_0Context              *expr,
  const Algorithm::t_combinational_block_context *bctx) const
{
  t_type_nfo rvalue_nfo;
  typeNfo(expr, bctx, rvalue_nfo);
  // check
  if (param.base_type != rvalue_nfo.base_type) {
    if (rvalue_nfo.base_type == Int) {
      warn(expr->getSourceInterval(), -1, "parameter '%s': assigning signed expression to unsigned lvalue",name.c_str());
    }
  }
  if (param.width < rvalue_nfo.width) {
    warn(expr->getSourceInterval(), -1, "parameter '%s': assigning %d bits wide expression to %d bits wide lvalue", name.c_str(), rvalue_nfo.width, param.width);
  }
}

// -------------------------------------------------

void ExpressionLinter::lintReadback(
  std::string                                     name,
  siliceParser::AccessContext                    *access,
  antlr4::tree::TerminalNode                     *identifier,
  const t_type_nfo                               &rvalue_nfo,
  const Algorithm::t_combinational_block_context *bctx) const
{
  t_type_nfo lvalue_nfo;
  if (access != nullptr) {
    typeNfo(access, bctx, lvalue_nfo);
  } else {
    sl_assert(identifier != nullptr);
    lvalue_nfo = m_Host->determineIdentifierTypeAndWidth(bctx, identifier, (int)identifier->getSymbol()->getLine());
  }
  // check
  if (lvalue_nfo.base_type != rvalue_nfo.base_type) {
    if (rvalue_nfo.base_type == Int) {
      warn(access ? access->getSourceInterval() : identifier->getSourceInterval(), -1, "output '%s': assigning signed expression to unsigned lvalue", name.c_str());
    }
  }
  if (lvalue_nfo.width < rvalue_nfo.width) {
    warn(access ? access->getSourceInterval() : identifier->getSourceInterval(), -1, "output '%s': assigning %d bits wide expression to %d bits wide lvalue", name.c_str(), rvalue_nfo.width, lvalue_nfo.width);
  }
}

// -------------------------------------------------

void ExpressionLinter::lintBinding(
  std::string                                     msg,
  Algorithm::e_BindingDir                         dir,
  int                                             line,
  const t_type_nfo                               &left,
  const t_type_nfo                               &right
) const
{
  // check
  if (left.base_type != right.base_type) {
    warn(antlr4::misc::Interval::INVALID, line, "%s, bindings have inconsistent signedness", msg.c_str());
  }
  if (left.width != right.width) {
    warn(antlr4::misc::Interval::INVALID, line, "%s, bindings have inconsistent bit-widths", msg.c_str());
  }
}

// -------------------------------------------------

template <int C>
antlr4::tree::ParseTree *child(antlr4::tree::ParseTree *expr)
{
  sl_assert(expr->children.size() > C);
  return expr->children[C];
}

// -------------------------------------------------

void ExpressionLinter::warn(antlr4::misc::Interval interval, int line, const char *msg, ...) const
{
  const int messageBufferSize = 4096;
  char message[messageBufferSize];

  va_list args;
  va_start(args, msg);
  vsprintf_s(message, messageBufferSize, msg, args);
  va_end(args);

  std::cerr << Console::yellow << "[warning] " << Console::gray;
  if (line > -1) {
  } else if (s_TokenStream != nullptr && !(interval == antlr4::misc::Interval::INVALID)) {
    antlr4::Token *tk = s_TokenStream->get(interval.a);
    line = (int)tk->getLine();
  }

  if (s_LuaPreProcessor != nullptr) {
    auto fl = s_LuaPreProcessor->lineAfterToFileAndLineBefore(line);
    std::cerr << "(" << Console::white << fl.first << Console::gray << ", line " << sprint("%4d",fl.second) << ") ";
  } else {
    std::cerr << "(" << line << ") ";
  }
  std::cerr << message;
  std::cerr << std::endl;
}

// -------------------------------------------------

void ExpressionLinter::checkConcatenation(
  antlr4::tree::ParseTree       *expr,
  const std::vector<t_type_nfo>& tns) const
{
  t_type_nfo t0 = tns.front();
  ForIndex(t, tns.size()) {
    if (tns[t].base_type != t0.base_type) {
warn(expr->getSourceInterval(), -1, "signedness of expressions differs in concatenation");
    }
    if (tns[t].width == -1) {
      m_Host->reportError(expr->getSourceInterval(), -1, "concatenation contains expression of unkown bit-width");
    }
  }
}

// -------------------------------------------------

void ExpressionLinter::checkTernary(
  antlr4::tree::ParseTree *expr,
  const t_type_nfo& nfo_a,
  const t_type_nfo& nfo_b
) const {
  if (nfo_a.width != nfo_b.width) {
    warn(expr->getSourceInterval(), -1, "width of expressions differ in ternary return values");
  }
  if (nfo_a.base_type != nfo_b.base_type) {
    warn(expr->getSourceInterval(), -1, "signedness of expressions differ in ternary return values");
  }
}

// -------------------------------------------------

static e_Type base_type_of(const t_type_nfo& nfo_a, const t_type_nfo& nfo_b)
{
  if (nfo_a.base_type == UInt || nfo_b.base_type == UInt) {
    return UInt;
  } else {
    return Int;
  }
}

// -------------------------------------------------

void ExpressionLinter::checkAndApplyOperator(
  antlr4::tree::ParseTree *expr,
  std::string       op,
  const t_type_nfo& nfo_a,
  const t_type_nfo& nfo_b,
  t_type_nfo&      _nfo
) const {
  if (op == "+") {
    _nfo.base_type = base_type_of(nfo_a, nfo_b);
    _nfo.width     = max(nfo_a.width, nfo_b.width) + 1;
  } else if (op == "-") {
    _nfo.base_type = base_type_of(nfo_a, nfo_b);
    _nfo.width     = max(nfo_a.width, nfo_b.width) + 1;
  } else if (op == "*") {
    _nfo.base_type = base_type_of(nfo_a, nfo_b);
    _nfo.width     = nfo_a.width + nfo_b.width;
  } else if (op == ">>") {
    if (nfo_a.base_type == Int) {
      warn(expr->getSourceInterval(), -1, "unsigned shift used on signed value");
    }
    _nfo.base_type = UInt; // force unsigned
    _nfo.width     = nfo_a.width;
  } else if (op == "<<") {
    if (nfo_a.base_type == Int) {
      warn(expr->getSourceInterval(), -1, "unsigned shift used on signed value");
    }
    _nfo.base_type = UInt; // force unsigned
    _nfo.width     = nfo_a.width;
  } else if (
       op == "==" || op == "===" || op == "!=" || op == "!=="
    || op == "<"  || op == ">"   || op == "<=" || op == ">=") {
    if (nfo_a.base_type != nfo_b.base_type) {
      warn(expr->getSourceInterval(), -1, "mixed signedness in comparison");
    }
    _nfo.base_type = UInt;
    _nfo.width     = 1;
  } else {
    _nfo.base_type = base_type_of(nfo_a, nfo_b);
    _nfo.width = max(nfo_a.width, nfo_b.width);
  }
}

// -------------------------------------------------

void ExpressionLinter::checkAndApplyUnaryOperator(
  antlr4::tree::ParseTree *expr,
  std::string op,
  const t_type_nfo& nfo_u,
  t_type_nfo& _nfo
) const {
  if (op == "-") {
    _nfo.base_type = nfo_u.base_type;
    _nfo.width     = nfo_u.width;
  } else if (op == "~") {
    _nfo.base_type = nfo_u.base_type;
    _nfo.width     = nfo_u.width;
  } else {
    // all other result in a single bit
    _nfo.base_type = UInt;
    _nfo.width = 1;
  }
}

// -------------------------------------------------

void ExpressionLinter::typeNfo(
  antlr4::tree::ParseTree                        *expr,
  const Algorithm::t_combinational_block_context *bctx,
  t_type_nfo& _nfo) const
{
  // NOTE TODO: const collapsing, so we could use const values in width and operators prediction
  auto atom   = dynamic_cast<siliceParser::AtomContext*>(expr);
  auto term   = dynamic_cast<antlr4::tree::TerminalNode*>(expr);
  auto unary  = dynamic_cast<siliceParser::UnaryExpressionContext*>(expr);
  auto cexpr  = dynamic_cast<siliceParser::ConcatexprContext*>(expr);
  auto concat = dynamic_cast<siliceParser::ConcatenationContext*>(expr);
  auto access = dynamic_cast<siliceParser::AccessContext*>(expr);
  auto expr0 = dynamic_cast<siliceParser::Expression_0Context*>(expr);
  auto expr1 = dynamic_cast<siliceParser::Expression_1Context*>(expr);
  auto expr2 = dynamic_cast<siliceParser::Expression_2Context*>(expr);
  auto expr3 = dynamic_cast<siliceParser::Expression_3Context*>(expr);
  auto expr4 = dynamic_cast<siliceParser::Expression_4Context*>(expr);
  auto expr5 = dynamic_cast<siliceParser::Expression_5Context*>(expr);
  auto expr6 = dynamic_cast<siliceParser::Expression_6Context*>(expr);
  auto expr7 = dynamic_cast<siliceParser::Expression_7Context*>(expr);
  auto expr8 = dynamic_cast<siliceParser::Expression_8Context*>(expr);
  auto expr9 = dynamic_cast<siliceParser::Expression_9Context*>(expr);
  auto expr10 = dynamic_cast<siliceParser::Expression_10Context*>(expr);
  if (term) {
    if (term->getSymbol()->getType() == siliceParser::CONSTANT) {
      constantTypeInfo(term->getText(), _nfo);
    } else if (term->getSymbol()->getType() == siliceParser::NUMBER) {
      _nfo.base_type = UInt;
      _nfo.width     = -1; // undetermined (NOTE: verilog default to 32 bits ...)
    } else if (term->getSymbol()->getType() == siliceParser::IDENTIFIER) {
      _nfo = m_Host->determineIdentifierTypeAndWidth(bctx, term, (int)term->getSymbol()->getLine());
    } else if (term->getSymbol()->getType() == siliceParser::REPEATID) {
      _nfo.base_type = UInt;
      _nfo.width = -1; // unspecified
    } else {
      throw Fatal("internal error [%s, %d]; unrecognized symbol '%s'", __FILE__, __LINE__,term->getText().c_str());
    }
  } else if (access) {
    // ask host to determine access type
    _nfo = m_Host->determineAccessTypeAndWidth(bctx, access, nullptr);
  } else if (atom) {
    auto concat_ = dynamic_cast<siliceParser::ConcatenationContext*>(atom->concatenation());
    auto access_ = dynamic_cast<siliceParser::AccessContext*>(atom->access());
    if (atom->TOUNSIGNED() != nullptr) {
      // recurse and force uint
      typeNfo(atom->expression_0(), bctx, _nfo);
      _nfo.base_type = UInt;
    } else if (atom->TOSIGNED() != nullptr) {
      // recurse and force int
      typeNfo(atom->expression_0(), bctx, _nfo);
      _nfo.base_type = Int;
    } else if (access_) {
      // recurse
      typeNfo(access_, bctx, _nfo);
    } else if (concat_) {
      // recurse
      typeNfo(concat_, bctx, _nfo);
    } else if (atom->expression_0()) {
      // recurse on parenthesis
      typeNfo(atom->expression_0(), bctx, _nfo);
    } else {
      // recurse on terminal symbol
      typeNfo(child<0>(expr), bctx, _nfo);
    }
  } else if (unary) {
    if (unary->children.size() == 2) {
      // recurse and check
      t_type_nfo nfo_u;
      typeNfo(unary->atom(), bctx, nfo_u);
      checkAndApplyUnaryOperator(expr, child<0>(expr)->getText(), nfo_u, _nfo);
    } else {
      // recurse
      typeNfo(unary->atom(), bctx, _nfo);
    }
  } else if (concat) {
    // recurse and check signedness consitency
    sl_assert(!expr->children.empty());
    std::vector<t_type_nfo> tns;
    for (auto c : concat->concatexpr()) {
      tns.push_back(t_type_nfo());
      typeNfo(c, bctx, tns.back());
    }
    checkConcatenation(expr, tns);
    _nfo.base_type = tns.front().base_type;
    _nfo.width = 0;
    for (auto tn : tns) {
      _nfo.width += tn.width;
    }
  } else if (cexpr) {
    if (cexpr->expression_0()) {
      // recurse
      typeNfo(cexpr->expression_0(), bctx, _nfo);
    } else {
      // recurse on concatenation
      typeNfo(cexpr->concatenation(), bctx, _nfo);
      // get number
      int num    = std::stoi(cexpr->NUMBER()->getText());
      _nfo.width = _nfo.width * num;
    }
  } else if (expr0 || expr1 || expr2 || expr3 || expr4 || expr5 
          || expr6 || expr7 || expr8 || expr9 || expr10) {
    if (expr->children.size() == 1) {
      // recurse
      typeNfo(child<0>(expr), bctx, _nfo);
    } else if (expr->children.size() == 3) {
      // recurse both sides and check
      t_type_nfo nfo_a, nfo_b;
      typeNfo(child<0>(expr), bctx, nfo_a);
      typeNfo(child<2>(expr), bctx, nfo_b);
      checkAndApplyOperator(expr, child<1>(expr)->getText(), nfo_a, nfo_b, _nfo);
    } else {
      sl_assert(expr->children.size() == 5);
      // recurse both sides and check
      t_type_nfo nfo_a, nfo_b, nfo_if;
      typeNfo(child<0>(expr), bctx, nfo_if);
      typeNfo(child<2>(expr), bctx, nfo_a);
      typeNfo(child<4>(expr), bctx, nfo_b);
      checkTernary(expr, nfo_a, nfo_b);
      _nfo.base_type = base_type_of(nfo_a, nfo_b);
      _nfo.width     = max(nfo_a.width, nfo_b.width);
    }
  } else {
    throw Fatal("internal error [%s, %d] '%s'", __FILE__, __LINE__,expr->getText().c_str());
  }
}

// -------------------------------------------------
