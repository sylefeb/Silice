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
#pragma once
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "siliceLexer.h"
#include "siliceParser.h"

#include "Algorithm.h"

// -------------------------------------------------

namespace Silice
{
  class LuaPreProcessor;

  // -------------------------------------------------

  /// \brief expression linter
  class ExpressionLinter
  {
  private:

    /// \brief Host algorithm
    const Algorithm *m_Host;

    /// \brief Instantiation context for parameterized VIOs
    const Blueprint::t_instantiation_context& m_Ictx;

    /// \brief Does the Linter warn about width mismatches in assignments? (there are very frequent)
    bool m_WarnAssignWidth = false;

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

    /// \brief gathers all vars involved in an expression and whether
    ///        they are cast to track D (_vars is not cleared)
    void allVars(
      antlr4::tree::ParseTree                        *expr,
      const Algorithm::t_combinational_block_context *bctx,
      std::vector<std::pair<bool,std::string> >&     _vars,
      bool                                            comb_cast=false) const;

  public:

    ExpressionLinter(const Algorithm *host, const Blueprint::t_instantiation_context& ictx) : m_Host(host), m_Ictx(ictx) { }

    /// \brief Lint an expression
    void lint(
      siliceParser::Expression_0Context              *expr, 
      const Algorithm::t_combinational_block_context *bctx) const;

    /// \brief Lint an assignment
    void lintAssignment(
      siliceParser::AccessContext                    *access,
      antlr4::tree::TerminalNode                     *identifier,
      siliceParser::Expression_0Context              *expr,
      const Algorithm::t_combinational_block_context *bctx,
      bool                                            wire_definition = false) const;

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
      const Utils::t_source_loc&                      srcloc,
      const t_type_nfo                               &left,
      const t_type_nfo                               &right
      ) const;

  };

  // -------------------------------------------------

};

// -------------------------------------------------
