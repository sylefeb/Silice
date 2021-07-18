// Rob Shelton ( @robng15 Twitter, @rob-ng15 GitHub )
// Simple 32bit FPU calculation/conversion routines
// Designed for as small as FPGA usage as possible,
// not for speed.
//
// Donated to Silice by @sylefeb
//
// Parameters for calculations: ( 32 bit float { sign, exponent, mantissa } format )
// addsub, multiply and divide a and b ( as floating point numbers ), addsub flag == 0 for add, == 1 for sub
//
// Parameters for conversion:
// intotofloat a as 32 bit integer, dounsigned == 1 dounsigned, == 0 signed conversion
// floattouint and floattoint a as 32 bit float
//
// Control:
// start == 1 to start operation
// busy gives status, == 0 not running or complete, == 1 running
//
// Output:
// result gives result of conversion or calculation
//
// NB: Error states are those required by Risc-V floating point

// BITFIELD FOR FLOATING POINT NUMBER - IEEE-754 32 bit format
bitfield floatingpointnumber{
    uint1   sign,
    uint8   exponent,
    uint23  fraction
}

// COMBINE COMPONENTS INTO FLOATING POINT NUMBER
// NOTE exp from addsub multiply divide is 16 bit biased ( ie, exp + 127 )
// small numbers return 0, bit numbers return max
circuitry combinecomponents( input sign, input exp, input fraction, output f32 ) {
    switch( ( exp > 254 ) | ( exp < 0 ) ) {
        case 1: { f32 = ( exp < 0 ) ? 0 : { sign, 8b01111111, 23h7fffff }; }
        case 0: { f32 = { sign, exp[0,8], fraction[0,23] }; }
    }
}

// CLASSIFY EXPONENT AND FRACTION or EXPONENT
circuitry classEF( output E, output F, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 8hff, ( floatingpointnumber(N).exponent ) == 8h00 };
    F = ( floatingpointnumber(N).fraction ) == 0;
}
circuitry classE( output E, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 8hff, ( floatingpointnumber(N).exponent ) == 8h00 };
}

// CIRCUITS TO DEAL WITH 48 BIT FRACTIONS TO 23 BIT FRACTIONS
// REALIGN A 48BIT NUMBER SO MSB IS 1
circuitry normalise48( inout bitstream ) {
    while( ~bitstream[47,1] ) {
        bitstream = bitstream << 1;
    }
}
// EXTRACT 23 BIT FRACTION FROM LEFT ALIGNED 48 BIT FRACTION WITH ROUNDING
circuitry round48( input bitstream, output roundfraction ) {
    roundfraction = bitstream[24,23] + bitstream[23,1];
}

// ADJUST EXPONENT IF ROUNDING FORCES, using newfraction and truncated bit from oldfraction
circuitry adjustexp48( inout exponent, input nf, input of ) {
    exponent = 127 + exponent + ( ( nf == 0 ) & of[23,1] );
}

// CONVERT SIGNED/UNSIGNED INTEGERS TO FLOAT
// dounsigned == 1 for signed conversion (31 bit plus sign), == 0 for dounsigned conversion (32 bit)
algorithm inttofloat(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint1   dounsigned,

    output  uint32  result
) <autorun> {
    uint2   FSM = uninitialised;
    uint2   FSM2 = uninitialised;
    uint1   sign = uninitialised;
    int16   exp = uninitialised;
    uint8   zeros = uninitialised;
    uint32  number = uninitialised;

    busy = 0;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                FSM = 1;
                while( FSM != 0 ) {
                    onehot( FSM ) {
                        case 0: {
                            // SIGNED / UNSIGNED
                            sign = dounsigned ? 0 : a[31,1];
                            number = dounsigned ? a : ( a[31,1] ? -a : a );
                        }
                        case 1: {
                            switch( number == 0 ) {
                                case 1: { result = 0; }
                                case 0: {
                                    FSM2 = 1;
                                    while( FSM2 !=0 ) {
                                        onehot( FSM2 ) {
                                            case 0: { zeros = 0; while( ~number[31-zeros,1] ) { zeros = zeros + 1; } }
                                            case 1: {
                                                number = ( zeros < 8 ) ? number >> ( 8 - zeros ) : ( zeros > 8 ) ? number << ( zeros - 8 ) : number;
                                                exp = 158 - zeros;
                                                ( result ) = combinecomponents( sign, exp, number );
                                            }
                                        }
                                        FSM2 = FSM2 << 1;
                                    }
                                }
                            }
                        }
                    }
                    FSM = FSM << 1;
                }
                busy = 0;
            }
        }
    }
}

// CONVERT FLOAT TO UNSIGNED/SIGNED INTEGERS
algorithm floattouint(
    input   uint32  a,
    output  uint32  result,
    output  uint1   busy,
    input   uint1   start
) <autorun> {
    uint2   classEa = uninitialised;
    int16    exp = uninitialised;
    uint33  sig = uninitialised;

    busy = 0;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                ( classEa ) = classE( a );
                switch( classEa ) {
                    case 2b00: {
                        switch( a[31,1] ) {
                            case 1: { result = 0; }
                            default: {
                                exp = floatingpointnumber( a ).exponent - 127;
                                sig = ( exp < 24 ) ? { 9b1, a[0,23], 1b0 } >> ( 23 - exp ) : { 9b1, a[0,23], 1b0 } << ( exp - 24);
                                result = ( exp > 31 ) ? 32hffffffff : ( sig[1,32] + sig[0,1] );
                            }
                        }
                    }
                    case 2b01: { result = 0; }
                    default: { result = a[31,1] ? 0 : 32hffffffff;  }
                }
                busy = 0;
            }
        }
    }
}
algorithm floattoint(
    input   uint32  a,
    output  uint32  result,
    output  uint1   busy,
    input   uint1   start
) <autorun> {
    uint2   classEa = uninitialised;
    int16   exp = uninitialised;
    uint33  sig = uninitialised;

    busy = 0;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                ( classEa ) = classE( a );
                switch( classEa ) {
                    case 2b00: {
                        exp = floatingpointnumber( a ).exponent - 127;
                        sig = ( exp < 24 ) ? { 9b1, a[0,23], 1b0 } >> ( 23 - exp ) : { 9b1, a[0,23], 1b0 } << ( exp - 24);
                        result = ( exp > 30 ) ? ( a[31,1] ? 32hffffffff : 32h7fffffff ) : a[31,1] ? -( sig[1,32] + sig[0,1] ) : ( sig[1,32] + sig[0,1] );
                    }
                    case 2b01: { result = 0; }
                    default: { result = a[31,1] ? 32hffffffff : 32h7fffffff; }
                }
                busy = 0;
            }
        }
    }
}

// ADDSUB
// ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm floataddsub(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint32  b,
    input   uint1   addsub,

    output  uint32  result
) <autorun> {
    uint5   FSM = uninitialised;
    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   sign = uninitialised;
    uint1   signA = uninitialised;
    uint1   signB = uninitialised;
    int16   expA = uninitialised;
    int16   expB = uninitialised;
    uint48  sigA = uninitialised;
    uint48  sigB = uninitialised;
    uint23  newfraction = uninitialised;

    busy = 0;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                FSM = 1;
                while( FSM != 0 ) {
                    onehot( FSM ) {
                        case 0: {
                            // FOR SUBTRACTION CHANGE SIGN OF SECOND VALUE
                            signA = a[31,1]; signB = addsub ? ~b[31,1] : b[31,1];
                            ( classEa ) = classE( a );
                            ( classEb ) = classE( b );
                        }
                        case 1: {
                            // EXTRACT COMPONENTS - HOLD TO LEFT TO IMPROVE FRACTIONAL ACCURACY
                            expA = floatingpointnumber( a ).exponent - 127;
                            expB = floatingpointnumber( b ).exponent - 127;
                            sigA = { 2b01, floatingpointnumber(a).fraction, 23b0 };
                            sigB = { 2b01, floatingpointnumber(b).fraction, 23b0 };
                        }
                        case 2: {
                            // ADJUST TO EQUAL EXPONENTS
                            switch( { expA < expB, expB < expA } ) {
                                case 2b10: { sigA = sigA >> ( expB - expA ); expA = expB; }
                                case 2b01: { sigB = sigB >> ( expA - expB ); expB = expA; }
                                default: {}
                            }
                        }
                        case 3: {
                            switch( classEa | classEb ) {
                                case 2b00: {
                                    switch( { signA, signB } ) {
                                        // PERFORM + HANDLING SIGNS
                                        case 2b01: {
                                            switch( sigB > sigA ) {
                                                case 1: { sign = 1; sigA = sigB - sigA; }
                                                case 0: { sign = 0; sigA = sigA - sigB; }
                                            }
                                        }
                                        case 2b10: {
                                            switch(  sigA > sigB ) {
                                                case 1: { sign = 1; sigA = sigA - sigB; }
                                                case 0: { sign = 0; sigA = sigB - sigA; }
                                            }
                                        }
                                        default: { sign = signA; sigA = sigA + sigB; }
                                    }
                                }
                                case 2b01: { result = ( classEb == 2b01 ) ? a : addsub ? { ~b[31,1], b[0,31] } : b; }
                                default: { result = { 1b0, 8b11111111, 23b0 }; }
                            }
                        }
                        case 4: {
                            switch( classEa | classEb ) {
                                case 0: {
                                    switch( sigA ) {
                                        case 0: { result = 0; }
                                        default: {
                                            // NORMALISE AND ROUND
                                            switch( sigA[47,1] ) {
                                                case 1: { expA = expA + 1; }
                                                default: {
                                                    while( ~sigA[46,1] ) { sigA = sigA << 1; expA = expA - 1; }
                                                    sigA = sigA << 1;
                                                }
                                            }
                                            ( newfraction ) = round48( sigA );
                                            ( expA ) = adjustexp48( exp, newfraction, sigA );
                                            ( result ) = combinecomponents( sign, expA, newfraction );
                                        }
                                    }
                                }
                                default: {}
                            }
                        }
                    }
                    FSM = FSM << 1;
                }
                busy = 0;
            }
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
$$if not uintmul_algo then
$$uintmul_algo = 1
algorithm douintmul(
    input   uint32  factor_1,
    input   uint32  factor_2,
    output  uint64  product
) <autorun> {
    uint18    A <: { 2b0, factor_1[16,16] };
    uint18    B <: { 2b0, factor_1[0,16] };
    uint18    C <: { 2b0, factor_2[16,16] };
    uint18    D <: { 2b0, factor_2[0,16] };
    product := ( D*B + { D*A, 16b0 } + { C*B, 16b0 } + { C*A, 32b0 } );
}
$$end

algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint32  b,

    output  uint32  result
) <autorun> {
    uint2   FSM = uninitialised;

    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   productsign <: a[31,1] ^ b[31,1];
    uint48  product = uninitialised;
    int16   productexp  = uninitialised;
    uint23  newfraction = uninitialised;

    douintmul UINTMUL();
    UINTMUL.factor_1 := { 9b1, a[0,23] };
    UINTMUL.factor_2 := { 9b1, b[0,23] };

    busy = 0;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                FSM = 1;
                while( FSM != 0 ) {
                    onehot( FSM ) {
                        case 0: {
                            ( classEa ) = classE( a );
                            ( classEb ) = classE( b );
                            product = UINTMUL.product[0,48];
                            productexp = (floatingpointnumber( a ).exponent - 127) + (floatingpointnumber( b ).exponent - 127) + product[47,1];
                        }
                        case 1: {
                            switch( classEa | classEb ) {
                                case 2b00: {
                                    ( product ) = normalise48( product );
                                    ( newfraction ) = round48( product );
                                    ( productexp ) = adjustexp48( productexp, newfraction, product );
                                    ( result ) = combinecomponents( productsign, productexp, newfraction );
                                }
                                case 2b01: { result = { productsign, 31b0 }; }
                                default: { result = { productsign, 8b11111111, 23b0 }; }
                            }
                        }
                    }
                    FSM = FSM << 1;
                }
                busy = 0;
            }
        }
    }
}

// DIVIDE TWO FLOATING POINT NUMBERS
algorithm divbit48(
    input   uint48  quo,
    input   uint48  rem,
    input   uint48  top,
    input   uint48  bottom,
    input   uint6   x,
    output  uint48  newquotient,
    output  uint48  newremainder
) <autorun> {
    uint48  temp = uninitialised;
    uint1   quobit = uninitialised;
    while(1) {
        temp = ( rem << 1 ) | top[x,1];
        quobit = __unsigned(temp) >= __unsigned(bottom);
        newremainder = __unsigned(temp) - ( quobit ? __unsigned(bottom) : 0 );
        newquotient = quo | ( quobit << x );
    }
}

algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint32  b,

    output  uint32  result
) <autorun> {
    uint4   FSM = uninitialised;
    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   quotientsign <: a[31,1] ^ b[31,1];
    int16   quotientexp = uninitialised;
    uint48  quotient = uninitialised;
    uint48  remainder = uninitialised;
    uint6   bit = uninitialised;
    uint48  sigA = uninitialised;
    uint48  sigB = uninitialised;
    uint23  newfraction = uninitialised;

    divbit48 DIVBIT48( quo <: quotient, rem <: remainder, top <: sigA, bottom <: sigB, x <: bit );

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                FSM = 1;
                while( FSM != 0 ) {
                    onehot( FSM ) {
                        case 0: {
                            ( classEa ) = classE( a );
                            ( classEb ) = classE( b );
                            sigA = { 1b1, floatingpointnumber(a).fraction, 24b0 };
                            sigB = { 25b1, floatingpointnumber(b).fraction };
                            quotientexp = (floatingpointnumber( a ).exponent - 127) - (floatingpointnumber( b ).exponent - 127);
                            quotient = 0;
                            remainder = 0;
                            bit = 47;
                        }
                        case 1: { while( ~sigB[0,1] ) { sigB = { 1b0, sigB[1,31] }; } }
                        case 2: {
                            switch( classEa | classEb ) {
                                case 2b00: {
                                    while( bit != 63 ) {
                                        quotient = DIVBIT48.newquotient; remainder = DIVBIT48.newremainder;
                                        bit = bit - 1;
                                    }
                                }
                                case 2b01: { result = ( classEb == 2b01 ) ? { quotientsign, 8b11111111, 23b0 } : { quotientsign, 31b0 }; }
                                default: { result = { quotientsign, 8b11111111, 23b0 }; }
                            }
                        }
                        case 3: {
                            switch( classEa | classEb ) {
                                case 0: {
                                    switch( quotient ) {
                                        case 0: { result = { quotientsign, 31b0 }; }
                                        default: {
                                            ( quotient ) = normalise48( quotient );
                                            ( newfraction ) = round48( quotient );
                                            quotientexp = 127 + quotientexp - ( floatingpointnumber(b).fraction > floatingpointnumber(a).fraction ) + ( ( newfraction == 0 ) & quotient[23,1] );
                                            ( result ) = combinecomponents( quotientsign, quotientexp, newfraction );
                                        }
                                    }
                                }
                                default: {}
                            }
                        }
                    }
                    FSM = FSM << 1;
                }
                busy = 0;
            }
        }
    }
}

// ADAPTED FROM https://projectf.io/posts/square-root-in-verilog/
algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    output  uint32  result
) <autorun> {
    uint4   FSM = uninitialised;

    uint48  x = uninitialised;
    uint48  q = uninitialised;
    uint50  ac = uninitialised;
    uint50  test_res = uninitialised;
    uint6   i = uninitialised;

    uint2   classEa = uninitialised;
    uint1   sign <: floatingpointnumber( a ).sign;
    int16   exp  = uninitialised;
    uint23  newfraction = uninitialised;

    while(1) {
        switch( start ) {
            case 0: {}
            case 1: {
                busy = 1;
                FSM = 1;
                ( classEa ) = classE( a );
                switch( a[31,1] ) {
                    case 1: { result = { a[31,1], 8b11111111, 23h7fffff }; }
                    default: {
                        switch( classEa ) {
                            case 2b00: {
                                while( FSM != 0 ) {
                                    onehot( FSM ) {
                                        case 0: {
                                            i = 0;
                                            q = 0;
                                            exp = floatingpointnumber( a ).exponent - 127;
                                            ac = ~exp[0,1] ? 1 : { 48b0, 1b1, a[22,1] };
                                            x = ~exp[0,1] ? { a[0,23], 25b0 } : { a[0,22], 26b0 };
                                        }
                                        case 1: {
                                            while( i != 47 ) {
                                                test_res = ac - { q, 2b01 };
                                                ac = { test_res[49,1] ? ac[0,47] : test_res[0,47], x[46,2] };
                                                q = { q[0,47], ~test_res[49,1] };
                                                x = { x[0,46], 2b00 };
                                                i = i + 1;
                                            }
                                        }
                                        case 2: {
                                            ( q ) = normalise48( q );
                                        }
                                        case 3: {
                                            exp = ( exp >>> 1 ) + 127;
                                            ( newfraction ) = round48( q );
                                            ( result ) = combinecomponents( sign, exp, newfraction );
                                        }
                                    }
                                    FSM = FSM << 1;
                                }                    }
                            case 2b01: { result = 0; }
                            default: { result = a; }
                        }
                    }
                }
                busy = 0;
            }
        }
    }
}

// FLOATING POINT COMPARISONS - ADAPTED FROM SOFT-FLOAT

/*============================================================================

This C source file is part of the SoftFloat IEEE Floating-Point Arithmetic
Package, Release 3e, by John R. Hauser.

Copyright 2011, 2012, 2013, 2014 The Regents of the University of California.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions, and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors may
    be used to endorse or promote products derived from this software without
    specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

circuitry floatless( input a, input b, output lessthan ) {
    lessthan = ( a[31,1] != b[31,1] ) ? a[31,1] & ((( a | b ) << 1) != 0 ) : ( a != b ) & ( a[31,1] ^ ( a < b));
}
circuitry floatequal( input a, input b, output equalto ) {
    equalto = ( a == b ) | ((( a | b ) << 1) == 0 );
}
circuitry floatlessequal( input a, input b, output lessequalto, ) {
    lessequalto = ( a[31,1] != b[31,1] ) ? a[31,1] | ((( a | b ) << 1) == 0 ) : ( a == b ) | ( a[31,1] ^ ( a < b ));
}

algorithm floatcompare(
    input   uint32  a,
    input   uint32  b,
    output  uint1   less,
    output  uint1   equal
) <autorun> {
    while(1) {
        ( less ) = floatless( a, b );
        ( equal ) = floatequal( a, b );
    }
}
