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
/// NOTE: avoid using 'error' in the description to not break test script...

const std::string c_CL0001_desc =
"  The new instantiation-time preprocessor introduced a few constraints.\n"
"  A problem that can appear is receiving the following error:\n"
"\n"
"      'error: [parser] Pre-processor directives are unbalanced ...'\n"
"\n"
"  The new rule is that a preprocessor if-then-else can appear between\n"
"  the ( and ) of the algorithm or unit in/out declaration, and between\n"
"  the { and } of the algorithm block, but there should be no if-then-else\n"
"  enclosing or repeating these parentheses and braces.\n"
"  Preprocessor directives can no longer cross unit declaration boundaries.\n"
;

const std::string c_CL0002_desc =
"  Expression trackers are now restricted to where they are required to\n"
"  remove ambiguities:\n"
"   - unit bodies,\n"
"   - algorithm preambles,\n"
"   - subroutine preambles.\n"
"\n"
"  In all other places, use the newly introduced initializing expressions:\n"
"\n"
"     uint8 a = b + 5 - c;\n"
"\n"
"  This declares variable `a` and initializes it to the given expression.\n"
;

const std::string c_CL0003_desc =
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

const std::string c_CL0004_desc =
"  The state following a loop is now collapsed into the loop conditional whenever\n"
"  possible, avoiding an extra cycle. This results in a more efficient usage of\n"
"  cycles, and clarifies the while loop chaining rules. However, this can impact\n"
"  the logic of existing code in cases such as follows:\n"
"  \n"
"    while (C) {\n"
"      A\n"
"    }\n"
"    B\n"
"  \n"
"  Before, there would* always* be a cycle introduced upon exiting the loop, so\n"
"  `B` would be in a different cycle than `A`. This also meant that there\n"
"  would be an extra cycle between `C` becoming false, and `B` being reached.\n"
"  \n"
"  Silice now automatically deals with such loops as if they were written as :\n"
"  \n"
"    while (1) {\n"
"      if (C) {\n"
"        A\n"
"      } else {\n"
"        B\n"
"        break;\n"
"      }\n"
"    }\n"
"  \n"
"  This means there is no extra cycle between `C` becoming false and `B` being\n"
"  reached.\n"
"  \n"
"  While it is generally favorable, this change may break some existing code.\n"
"  To revert to the previous behavior, add a step operator as follows :\n"
"  \n"
"    while (C) {\n"
"      A\n"
"    }\n"
"    ++: // added\n"
"    B\n"
"\n"
;

const std::string c_CL0005_desc =
"  Some if/else constructs are such that when taking one branch\n"
"  what comes after the if/else is not reached.\n"
"  \n"
"  For instance in a loop body :\n"
"  \n"
"  if (C) {\n"
"    break;\n"
"  }\n"
"  N\n"
"  \n"
"  If `C` is true, `N` is never reached. Before this was introducing\n"
"  a cycle before `N`, which can actually be skipped by pulling `N`\n"
"  in the `else` part:\n"
"  \n"
"  if (C) {\n"
"    break;\n"
"  } else {\n"
"    N\n"
"  }\n"
"  \n"
"  This is now done automatically.\n"
"  These optimizations cascade to successive if-s, for instance:\n"
"  \n"
"  if (C1) { break; }\n"
"  if (C2) { break; }\n"
"  if (C3) { break; }\n"
"  N\n"
"  \n"
"  Takes now only one cycle as the if-s and `N` are automatically\n"
"  nested (versus 3 cycles before).\n"
;

const std::string c_CL0006_desc = 
"  The mechanism for declaring pins has been revised to be simpler\n"
"  and more powerful. You are getting this message because a pin in\n"
"  your design is not properly declared in the board framework.\n"
"  Please make sure this is not due to a typo which could result\n"
"  in incorrect code. Using frameworks provided with Silice should\n"
"  not produce this message (please open a github issue in this case).\n"
"  Add --no-pin-check on the command line to bypass this check.\n"
;

/// \brief A change log case.
typedef struct {
    std::string from_version; // version from which this applies
    std::string title;        // title
    std::string description;  // description
} t_changelog_case;

/// \brief All cases in a map using case reference as key.
std::map<std::string,t_changelog_case> c_ChangleLogCases = {

    {"CL0001", {"0.1.2", "Instantiation time pre-processor", c_CL0001_desc}},
    {"CL0002", {"0.1.2", "Tracker declarations",             c_CL0002_desc}},
    {"CL0003", {"0.1.2", "Pipeline syntax",                  c_CL0003_desc}},
    {"CL0004", {"0.1.2", "While loops cycle rules",          c_CL0004_desc}},
    {"CL0005", {"0.1.2", "If-else cycle rules",              c_CL0005_desc}},
    {"CL0006", {"1.0.0", "Pin declarations in frameworks",   c_CL0006_desc}},
};

// -------------------------------------------------
