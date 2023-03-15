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
// -------------------------------------------------
//                                ... hardcoding ...
// -------------------------------------------------

#include "ChangeLog.h"
#include "ParsingContext.h"

#include "ChangeLog_descriptions.inc"

#include <LibSL.h>

using namespace Silice;

ChangeLog *ChangeLog::s_UniqueInstance = nullptr;

ChangeLog *ChangeLog::getUniqueInstance()
{
  if (s_UniqueInstance == nullptr) {
    s_UniqueInstance = new ChangeLog();
  }
  return s_UniqueInstance;
}

// -------------------------------------------------

void ChangeLog::addPointOfInterest(std::string caseRef, const Utils::t_source_loc& srcloc)
{
  sl_assert(c_ChangleLogCases.count(caseRef) != 0);
  t_point_of_interest poi;
  poi.case_ref = caseRef;
  // get parsing context
  ParsingContext *pctx = nullptr;
  if (srcloc.root) {
    pctx = ParsingContext::rootContext(srcloc.root);
  } else {
    pctx = ParsingContext::activeContext();
  }
  int line = Utils::lineFromInterval(pctx->parser->getTokenStream(), srcloc.interval) - 1;
  poi.source_file = pctx->lpp->lineAfterToFileAndLineBefore(pctx, (int)line);
  // get source info    
  std::string _;
  Utils::getSourceInfo(pctx->parser->getTokenStream(), nullptr, srcloc.interval,
    _/*out*/,poi.source_exerpt/*out*/,
    poi.source_exerpt_first_char/*out*/, poi.source_exerpt_last_char/*out*/);
  // add
  m_PointsOfInterest[caseRef].push_back(poi);
}

// -------------------------------------------------

void ChangeLog::printReport(std::ostream& out) const
{
  const char nxl = '\n'; // end of line

  if (m_PointsOfInterest.empty()) {
    // nothnig to report, good!
    return;
  }
  out << Console::bold << Console::white 
    << nxl << nxl
    << "----------<<<<< change log report >>>>>----------" 
    << nxl << nxl;
  out << "Your code may be impacted by recent changes that modified\n";
  out << "the behavior of language constructs.\n";
  out << nxl;
  out << "Please review these carefully:\n";
  out << nxl;
  out << Console::normal << Console::gray;
  for (const auto& all_for_case : m_PointsOfInterest) {
    // print a case header
    out << Console::bold << Console::yellow << "[" << all_for_case.first << "] ";
    out << Console::normal << Console::gray;
    out << " -------------- ";
    out << c_ChangleLogCases.at(all_for_case.first).title;
    out << nxl << nxl;
    out << c_ChangleLogCases.at(all_for_case.first).description;
    out << nxl;
    // give all source info
    out << "  Source code potentially impacted:" << nxl;
    for (const auto& poi : all_for_case.second) {
      out << Console::bold << Console::white;
      std::cerr
        << "  - file: " << poi.source_file.first << nxl
        << "    line: " << poi.source_file.second + 1 << nxl;
      out << Console::normal << Console::gray;
    }
  }
  out << nxl << nxl;
}

// -------------------------------------------------
