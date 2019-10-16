/*!
@file
@brief Definition of the VCDFileParser class
*/

#include "VCDFileParser.hpp"

VCDFileParser::VCDFileParser()
{

    this->trace_scanning = false;
    this->trace_parsing = false;
}

VCDFileParser::~VCDFileParser()
{
}

VCDFile *VCDFileParser::parse_file(const std::string &filepath)
{

    this->filepath = filepath;

    scan_begin();

    this->fh = new VCDFile();
    VCDFile *tr = this->fh;

    this->fh->root_scope = new VCDScope;
    this->fh->root_scope->name = std::string("$root");
    this->fh->root_scope->type = VCD_SCOPE_ROOT;

    this->scopes.push(this->fh->root_scope);

    tr->add_scope(scopes.top());

    VCDParser::parser parser(*this);

    parser.set_debug_level(trace_parsing);

    int result = parser.parse();

    scopes.pop();

    scan_end();

    if (result == 0)
    {
        this->fh = nullptr;
        return tr;
    }
    else
    {
        tr = nullptr;
        delete this->fh;
        return nullptr;
    }
}

void VCDFileParser::error(const VCDParser::location &l, const std::string &m)
{
    std::cerr << "line " << l.begin.line
              << std::endl;
    std::cerr << " : " << m << std::endl;
}

void VCDFileParser::error(const std::string &m)
{
    std::cerr << " : " << m << std::endl;
}
