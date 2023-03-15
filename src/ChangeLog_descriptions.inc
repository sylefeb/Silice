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

// This file contains descriptions of changes that
// might impact existing code. See ChangeLog.cpp

/// TODO: auto-generate from text file?

const std::string c_CL0001_desc = 
"  Preprocessor directives can no longer cross unit declaration boundaries.\n"
;

const std::string c_CL0002_desc = 
"  The syntax to define pipelines has changed. Before a pipeline had to\n"
"  use one block per stage, with arrows in between stages:\n"
"     { /*stage0*/ } -> { /*stage1*/ } -> { /*stage2*/ }\n"
"  Now the blocks are no longer necessary:\n"
"       /*stage0*/   ->   /*stage1*/   ->   /*stage2*/\n"
"  However, this impacts what is considered to be outside of the pipeline.\n"
"  In the following example:\n"
"       A { S0 } -> { S1 } -> { S2 } B \n"
"  A and B were before considered outside of the pipeline. They are now\n"
"  pulled respectively in S0 and S2.\n"
"  To recover the previous behavior, enclose the pipeline in a block:\n"
"       A { { S0 } -> { S1 } -> { S2 } } B \n"
;

const std::string c_CL0003_desc = 
"  TO BE WRITTEN"
;

/// \brief A change log case.
typedef struct {
    std::string from_version; // version from which this applies
    std::string title;        // title
    std::string description;  // description
} t_changelog_case;

/// \brief All cases in a map using case reference as key.
std::map<std::string,t_changelog_case> c_ChangleLogCases = {

    {"CL0001", {"0.1.1", "Preprocessor directives", c_CL0001_desc}},
    {"CL0002", {"0.1.1", "Pipeline syntax",         c_CL0002_desc}},
    {"CL0003", {"0.1.1", "While loops cycle rules", c_CL0003_desc}},

};

// -------------------------------------------------
