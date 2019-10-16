/*!
@file
@brief Definition of the VCDFileParser class
*/

#include "VCDFileParser.hpp"

/*!
@brief Standalone test function to allow testing of the VCD file parser.
*/
int main(int argc, char **argv)
{

    std::string infile(argv[1]);

    std::cout << "Parsing " << infile << std::endl;

    VCDFileParser parser;

    VCDFile *trace = parser.parse_file(infile);

    if (trace)
    {
        std::cout << "Parse successful." << std::endl;
        std::cout << "Version:       " << trace->version << std::endl;
        std::cout << "Date:          " << trace->date << std::endl;
        std::cout << "Signal count:  " << trace->get_signals()->size() << std::endl;
        std::cout << "Times Recorded:" << trace->get_timestamps()->size() << std::endl;

        // Print out every signal in every scope.
        for (VCDScope *scope : *trace->get_scopes())
        {

            std::cout << "Scope: " << scope->name << std::endl;

            for (VCDSignal *signal : scope->signals)
            {

                std::cout << "\t" << signal->hash << "\t"
                          << signal->reference;

                if (signal->size > 1)
                {
                    std::cout << " [" << signal->size << ":0]";
                }

                std::cout << std::endl;
            }
        }

        delete trace;

        return 0;
    }
    else
    {
        std::cout << "Parse Failed." << std::endl;
        return 1;
    }
}
