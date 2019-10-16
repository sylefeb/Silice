/*!
@file
@brief Contains the declaration of the parser driver class.
*/

#ifndef VCD_PARSER_DRIVER_HPP
#define VCD_PARSER_DRIVER_HPP

#include <string>
#include <map>
#include <set>
#include <stack>

#include "VCDParser.hpp"
#include "VCDTypes.hpp"
#include "VCDFile.hpp"

#define YY_DECL \
    VCDParser::parser::symbol_type yylex (VCDFileParser & driver)

YY_DECL;


/*!
@brief Class for parsing files containing CSP notation.
*/
class VCDFileParser {

    public:
        
        //! Create a new parser/
        VCDFileParser();
        virtual ~VCDFileParser();
        
        /*!
        @brief Parse the suppled file.
        @returns A handle to the parsed VCDFile object or nullptr if parsing
        fails.
        */
        VCDFile * parse_file(const std::string & filepath);
        
        //! The current file being parsed.
        std::string filepath;
        
        //! Should we debug tokenising?
        bool trace_scanning;

        //! Should we debug parsing of tokens?
        bool trace_parsing;

        //! Reports errors to stderr.
        void error(const VCDParser::location & l, const std::string & m);

        //! Reports errors to stderr.
        void error(const std::string & m);
    
        //! Current file being parsed and constructed.
        VCDFile * fh;
        
        //! Current stack of scopes being parsed.
        std::stack<VCDScope*> scopes;
        
    protected:

        //! Utility function for starting parsing.
        void scan_begin ();
        
        //! Utility function for stopping parsing.
        void scan_end   ();
};

#endif

