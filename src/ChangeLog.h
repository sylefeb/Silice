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

#include <string>
#include <map>

#include "Utils.h"

namespace Silice
{

  /// \brief ChangeLog is a singleton class used to track code
  ///        potentially impacted by breaking changes in Silice.
  ///        It will report an error messages and a log of all
  ///        source lines potentially impacted.
  class ChangeLog
  {
  private:

    /// \brief The unique instance
    static ChangeLog *s_UniqueInstance;
    /// \brief Private constructor.
    ChangeLog() {  }
    /// \brief A point of interest found in the code.
    typedef struct {
      std::string case_ref;
      std::pair<std::string,int> source_file;
      std::string source_exerpt;
      int         source_exerpt_first_char;
      int         source_exerpt_last_char;
    } t_point_of_interest;
    /// \brief All points of interest found in the code, per case ref.
    std::map<std::string, std::vector<t_point_of_interest> > m_PointsOfInterest;

  public:

    static ChangeLog *getUniqueInstance();

    /// \brief adds a point of interest where a change may apply
    void addPointOfInterest(std::string caseRef, const Utils::t_source_loc& srcloc);
    /// \brief writes the report in the stream
    void printReport(std::ostream& out) const;
    
  };

};

// -------------------------------------------------

#define CHANGELOG (*ChangeLog::getUniqueInstance())

// -------------------------------------------------
