
# Verilog VCD Parser

[![Documentation](https://codedocs.xyz/ben-marshall/verilog-vcd-parser.svg)](https://codedocs.xyz/ben-marshall/verilog-vcd-parser/)

This project implements a no-frills *Value Change Dump* (VCD) file parser, as
described in the IEEE System Verilog 1800-2012 standard. It can be used to
write custom tools which need to read signal traces dumped out by Verilog (or
VHDL) simulators.

---

## Getting Started

After cloning the repository to your local machine, run the following in a
shell:

```sh
$> cd ./verilog-vcd-parser
$> make all
```

This will build both the demonstration executable in `build/vcd-parser` and
the API documentation in `build/docs`.

## Code Example

This code will load up a VCD file and print the hierarchy of the scopes
and signals declared in it.

```cpp
VCDFileParser parser;

VCDFile * trace = parser.parse_file("path-to-my-file.vcd");

if(trace == nullptr) {
    // Something went wrong.
} else {

    for(VCDScope * scope : *trace -> get_scopes()) {

        std::cout << "Scope: "  << scope ->  name  << std::endl;

        for(VCDSignal * signal : scope -> signals) {

            std::cout << "\t" << signal -> hash << "\t" 
                      << signal -> reference;

            if(signal -> size > 1) {
                std::cout << " [" << signal -> size << ":0]";
            }
            
            std::cout << std::endl;

        }
    }

}
```

We can also query the value of a signal at a particular time. Because a VCD
file can have multiple signals in multiple scopes which represent the same
physical signal, we use the signal hash to access it's value at a particular
time:

```cpp
// Get the first signal we fancy.
VCDSignal * mysignal = trace -> get_scope("$root") -> signals[0];

// Print the value of this signal at every time step.

for (VCDTime time : *trace -> get_timestamps()) {

    VCDValue * val = trace -> get_signal_value_at( mysignal -> hash, time);

    std::cout << "t = " << time
              << ", "   << mysignal -> reference
              << " = ";
    
    // Assumes val is not nullptr!
    switch(val -> get_type()) {
        case (VCD_SCALAR):
            std::cout << VCDValue::VCDBit2Char(val -> get_value_bit());
            break;
        case (VCD_VECTOR):
            VCDBitVector * vecval = val -> get_value_vector()
            for(auto it = vecval -> begin();
                     it != vecval -> end();
                     ++it) {
                std::cout << VCDValue::VCDBit2Char(*it);
            }
            break;
        case (VCD_REAL):
            std::cout << val -> get_value_real();
        default:
            break;
    }

    std::cout << endl;

}

```

The example above is deliberately verbose to show how common variables and
signal attributes can be accessed.


## Integration

It is assumed that given a set of source files, it will be easy for people to
integrate this as a submodule of their own projects. However, Flex and Bison
*must* be run before all compilable source files are present. If integrating
this into a larger project, you will want to ensure the following commands are
run before compiling any of the VCD parser sources.

```sh
$> make parser-srcs
```

This will run flex and bison on the `.ypp` and `.l` files in `src/` and put
the generated parser and lexer code in `build/`. The complete file list for
inclusion in a larger project is:

```
src/VCDFile.cpp
src/VCDFileParser.cpp
src/VCDValue.cpp
build/VCDParser.cpp
build/VCDScanner.cpp
```

With header files located in both `src/` and `build/`.

## Integration using static link library

`build/libverilog-vcd-parser.a` and the required .hpp files are copied into `build/`.

To use these from another application add -I and the .a file to your gcc command line:

```sh
$ gcc -Ibuild/ build/libverilog-vcd-parser.a myapp.cpp
```


## Tools

- The parser and lexical analyser are written using Bison and Flex
  respectively.
- The data structures and other functions are written using C++ 2011.
- The build system is GNU Make.
- The codebase is documented using Doxygen.
