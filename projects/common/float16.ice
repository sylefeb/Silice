// Rob Shelton ( @robng15 Twitter, @rob-ng15 GitHub )
// Simple 32bit FPU calculation/conversion routines
// Designed for as small as FPGA usage as possible,
// not for speed.
//
// Donated to Silice by @sylefeb
//
// Parameters for calculations: ( 16 bit float { sign, exponent, mantissa } format )
// addsub, multiply and divide a and b ( as floating point numbers ), addsub flag == 0 for add, == 1 for sub
//
// Parameters for conversion (always signed):
// intotofloat a as 16 bit integer
// floattoint a as 16 bit float
//
// Control:
// start == 1 to start operation
// busy gives status, == 0 not running or complete, == 1 running
//
// Output:
// result gives result of conversion or calculation
//

// BITFIELD FOR FLOATING POINT NUMBER - IEEE-754 32 bit format
bitfield floatingpointnumber{
    uint1   sign,
    uint5   exponent,
    uint10  fraction
}

// COMBINE COMPONENTS INTO FLOATING POINT NUMBER
// NOTE exp from addsub multiply divide is 8 bit biased ( ie, exp + 15 )
// small numbers return 0, bit numbers return max
circuitry combinecomponents( input sign, input exp, input fraction, output f16 ) {
    switch( ( exp > 30 ) || ( exp < 0 ) ) {
        case 1: { f16 = ( exp < 0 ) ? 0 : { sign, 5b01111, 10h3ff }; }
        case 0: { f16 = { sign, exp[0,5], fraction[0,10] }; }
    }
}

// CLASSIFY EXPONENT AND FRACTION or EXPONENT
circuitry classEF( output E, output F, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 5h1f, ( floatingpointnumber(N).exponent ) == 5h0 };
    F = ( floatingpointnumber(N).fraction ) == 0;
}
circuitry classE( output E, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 5h1f, ( floatingpointnumber(N).exponent ) == 5h0 };
}

// REALIGN A 22BIT NUMBER SO MSB IS 1
circuitry normalise22( inout bitstream ) {
    while( ~bitstream[21,1] ) {
        bitstream = { bitstream[0,21], 1b0 };
    }
}
// EXTRACT 10 BIT FRACTION FROM LEFT ALIGNED 22 BIT FRACTION WITH ROUNDING
circuitry round22( input bitstream, output roundfraction ) {
    roundfraction = bitstream[11,10] + bitstream[10,1];
}

// ADJUST EXPONENT IF ROUNDING FORCES, using newfraction and truncated bit from oldfraction
circuitry adjustexp22( inout exponent, input nf, input of ) {
    exponent = 15 + exponent + ( ( nf == 0 ) & of[10,1] );
}

// ALIGN FRACTION TO THE RIGHT FOR DIVISION
circuitry alignright22( inout bitstream ) {
     while( ~bitstream[0,1] ) {
         bitstream = { 1b0, bitstream[1,21] };
    }
}

// CONVERT SIGNED INTEGERS TO FLOAT
algorithm inttofloat(
    input   uint1   start,
    output  uint1   busy,
    input   int16   a,
    input   uint1   dounsigned,
    output  uint16  result
) <autorun> {
    uint2   FSM = uninitialised;
    uint2   FSM2 = uninitialised;
    uint1   sign = uninitialised;
    int8    exp = uninitialised;
    uint8   zeros = uninitialised;
    uint16  number = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        // SIGNED / UNSIGNED
                        sign = dounsigned ? 0 : a[15,1];
                        number = dounsigned ? a : a[15,1] ? -a : a ;
                    }
                    case 1: {
                        switch( number == 0 ) {
                            case 1: { result = 0; }
                            case 0: {
                                FSM2 = 1;
                                while( FSM2 !=0 ) {
                                    onehot( FSM2 ) {
                                        case 0: { zeros = 0; while( ~number[ 15-zeros, 1 ] ) { zeros = zeros + 1; } }
                                        case 1: {
                                            number = ( zeros < 5 ) ? number >> ( 5 - zeros ) : ( zeros > 5 ) ? number << ( zeros - 5 ) : number;
                                            exp = 30 - zeros;
                                            ( result ) = combinecomponents( sign, exp, number );
                                        }
                                    }
                                    FSM2 = { FSM2[0,1], 1b0 };
                                }
                            }
                        }
                    }
                }
                FSM = { FSM[0,1], 1b0 };
            }
            busy = 0;
        }
    }
}

// CONVERT FLOAT TO SIGNED INTEGERS
algorithm floattoint(
    input   uint16  a,
    output  int16   result,
    output  uint1   busy,
    input   uint1   start
) <autorun> {
    uint2   classEa = uninitialised;
    int8    exp = uninitialised;
    int17   sig = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            ( classEa ) = classE( a );
            switch( classEa ) {
                case 2b00: {
                    exp = floatingpointnumber( a ).exponent - 15;
                    sig = ( exp < 11 ) ? { 5b1, a[0,10], 1b0 } >> ( 10 - exp ) : { 5b1, a[0,10], 1b0 } << ( exp - 11 );
                    result = ( exp > 14 ) ? ( a[15,1] ? 16hffff : 16h7fff ) : a[15,1] ? -( sig[1,16] + sig[0,1] ) : ( sig[1,16] + sig[0,1] );
                }
                case 2b01: { result = 0; }
                default: { result = a[15,1] ? 16hffff : 16h7fff; }
            }
            busy = 0;
        }
    }
}

// CONVERT FLOAT TO UNSIGNED INTEGERS
algorithm floattouint(
    input   uint16  a,
    output  int16   result,
    output  uint1   busy,
    input   uint1   start
) <autorun> {
    uint2   classEa = uninitialised;
    int8    exp = uninitialised;
    int17   sig = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            ( classEa ) = classE( a );
            switch( classEa ) {
                case 2b00: {
                    exp = floatingpointnumber( a ).exponent - 15;
                    sig = ( exp < 11 ) ? { 5b1, a[0,10], 1b0 } >> ( 10 - exp ) : { 5b1, a[0,10], 1b0 } << ( exp - 11 );
                    result = ( exp > 15 ) ? 16hffff : a[15,1] ? 0 : ( sig[1,16] + sig[0,1] );
                }
                case 2b01: { result = 0; }
                default: { result = 16hffff; }
            }
            busy = 0;
        }
    }
}

// ADDSUB
// ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm floataddsub(
    input   uint1   start,
    output  uint1   busy,

    input   uint16  a,
    input   uint16  b,
    input   uint1   addsub,

    output  uint16  result
) <autorun> {
    uint5   FSM = uninitialised;
    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   sign = uninitialised;
    uint1   signA = uninitialised;
    uint1   signB = uninitialised;
    int8    expA = uninitialised;
    int8    expB = uninitialised;
    uint22  sigA = uninitialised;
    uint22  sigB = uninitialised;
    uint22  newfraction = uninitialised;
    uint1   round = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            round = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        // FOR SUBTRACTION CHANGE SIGN OF SECOND VALUE
                        signA = a[15,1]; signB = addsub ? ~b[15,1] : b[15,1];
                        ( classEa ) = classE( a );
                        ( classEb ) = classE( b );
                    }
                    case 1: {
                        // EXTRACT COMPONENTS - HOLD TO LEFT TO IMPROVE FRACTIONAL ACCURACY
                        expA = floatingpointnumber( a ).exponent - 15;
                        expB = floatingpointnumber( b ).exponent - 15;
                        sigA = { 2b01, floatingpointnumber(a).fraction, 10b0 };
                        sigB = { 2b01, floatingpointnumber(b).fraction, 10b0 };
                        sign = floatingpointnumber(a).sign;
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
                                            case 1: { sign = 1; round = ( sigA != 0 ); sigA = sigB - ( ~round ? 1 : sigA ); }
                                            case 0: { sign = 0; round = ( sigB != 0 ); sigA = sigA - ( ~round ? 1 : sigB ); }
                                        }
                                    }
                                    case 2b10: {
                                        switch(  sigA > sigB ) {
                                            case 1: { sign = 1; round = ( sigB != 0 ); sigA = sigA - ( ~round ? 1 : sigB ); }
                                            case 0: { sign = 0; round = ( sigA != 0 ); sigA = sigB - ( ~round ? 1 : sigA ); }
                                        }
                                    }
                                    default: { sign = signA; sigA = sigA + sigB; }
                                }
                            }
                            case 2b01: { result = ( classEb == 2b01 ) ? a : addsub ? { ~b[15,1], b[0,15] } : b; }
                            default: { result = { 1b0, 5b11111, 10b0 }; }
                        }
                    }
                    case 4: {
                        switch( classEa | classEb ) {
                            case 0: {
                                switch( sigA ) {
                                    case 0: { result = 0; }
                                    default: {
                                        // NORMALISE AND ROUND
                                        switch( sigA[21,1] ) {
                                            case 1: { expA = expA + 1; }
                                            default: {
                                                while( ~sigA[20,1] ) { sigA = { sigA[0,21], 1b0 }; expA = expA - 1; }
                                                sigA = { sigA[0,21], 1b0 };
                                            }
                                        }
                                        sigA[10,1] = sigA[10,1] & round;
                                        ( newfraction ) = round22( sigA );
                                        ( expA ) = adjustexp22( exp, newfraction, sigA );
                                        ( result ) = combinecomponents( sign, expA, newfraction );
                                    }
                                }
                            }
                            default: {}
                        }
                    }
                }
                FSM = { FSM[0,5], 1b0 };
            }
            busy = 0;
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy,

    input   uint16  a,
    input   uint16  b,

    output  uint16  result
) <autorun> {
    uint2   FSM = uninitialised;

    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   productsign <: a[15,1] ^ b[15,1];
    uint32  product = uninitialised;
    int8    productexp  = uninitialised;
    uint10  newfraction = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        ( classEa ) = classE( a );
                        ( classEb ) = classE( b );
                        product = { 6b1, a[0,10] } * { 6b1, b[0,10] };
                        productexp = (floatingpointnumber( a ).exponent - 15) + (floatingpointnumber( b ).exponent - 15) + product[21,1];
                    }
                    case 1: {
                        switch( classEa | classEb ) {
                            case 2b00: {
                                ( product ) = normalise22( product );
                                ( newfraction ) = round22( product );
                                ( productexp ) = adjustexp22( productexp, newfraction, product );
                                ( result ) = combinecomponents( productsign, productexp, newfraction );
                            }
                            case 2b01: { result = { productsign, 15b0 }; }
                            default: { result = { productsign, 5b11111, 10b0 }; }
                        }
                    }
                }
                FSM = { FSM[0,1], 1b0 };
            }
            busy = 0;
        }
    }
}

// DIVIDE TWO FLOATING POINT NUMBERS
algorithm divbit22(
    input   uint22  quo,
    input   uint22  rem,
    input   uint22  top,
    input   uint22  bottom,
    input   uint5   x,
    output  uint22  newquotient,
    output  uint22  newremainder
) <autorun> {
    uint22  temp = uninitialised;
    uint1   quobit = uninitialised;
    while(1) {
        temp = ( rem << 1 ) + top[x,1];
        quobit = __unsigned(temp) >= __unsigned(bottom);
        newremainder = __unsigned(temp) - ( quobit ? __unsigned(bottom) : 0 );
        newquotient = quo | ( quobit << x );
    }
}
algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy,

    input   uint16  a,
    input   uint16  b,

    output  uint16  result
) <autorun> {
    uint4   FSM = uninitialised;
    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   quotientsign <: a[15,1] ^ b[15,1];
    int8    quotientexp = uninitialised;
    uint22  quotient = uninitialised;
    uint22  remainder = uninitialised;
    uint5   bit = uninitialised;
    uint22  sigA = uninitialised;
    uint22  sigB = uninitialised;
    uint10  newfraction = uninitialised;

    divbit22 DIVBIT22( quo <: quotient, rem <: remainder, top <: sigA, bottom <: sigB, x <: bit );

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        ( classEa ) = classE( a );
                        ( classEb ) = classE( b );
                        sigA = { 1b1, floatingpointnumber(a).fraction, 11b0 };
                        sigB = { 12b1, floatingpointnumber(b).fraction };
                        quotientexp = (floatingpointnumber( a ).exponent - 15) - (floatingpointnumber( b ).exponent - 15);
                        quotient = 0;
                        remainder = 0;
                        bit = 21;
                    }
                    case 1: { ( sigB ) = alignright22( sigB ); }
                    case 2: {
                        switch( classEa | classEb ) {
                            case 2b00: {
                                while( bit != 31 ) {
                                    quotient = DIVBIT22.newquotient; remainder = DIVBIT22.newremainder;
                                    bit = bit - 1;
                                }
                            }
                            case 2b01: { result = ( classEb == 2b01 ) ? { quotientsign, 5b11111, 10b0 } : { quotientsign, 15b0 }; }
                            default: { result = { quotientsign, 5b11111, 10b0 }; }
                        }
                    }
                    case 3: {
                        switch( classEa | classEb ) {
                            case 0: {
                                switch( quotient ) {
                                    case 0: { result = { quotientsign, 15b0 }; }
                                    default: {
                                        ( quotient ) = normalise22( quotient );
                                        ( newfraction ) = round22( quotient );
                                        quotientexp = 15 + quotientexp - ( floatingpointnumber(b).fraction > floatingpointnumber(a).fraction ) + ( ( newfraction == 0 ) & quotient[12,1] );
                                        ( result ) = combinecomponents( quotientsign, quotientexp, newfraction );
                                    }
                                }
                            }
                            default: {}
                        }
                    }
                }
                FSM = { FSM[0,3], 1b0 };
            }
            busy = 0;
        }
    }
}

// ADAPTED FROM https://projectf.io/posts/square-root-in-verilog/
algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy,

    input   uint16  a,
    output  uint16  result
) <autorun> {
    uint4   FSM = uninitialised;

    uint22  x = uninitialised;
    uint22  q = uninitialised;
    uint24  ac = uninitialised;
    uint24  test_res = uninitialised;
    uint6   i = uninitialised;

    uint2   classEa = uninitialised;
    uint1   sign <: floatingpointnumber( a ).sign;
    int16   exp  = uninitialised;
    uint23  newfraction = uninitialised;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            ( classEa ) = classE( a );
            switch( a[15,1] ) {
                case 1: { result = { a[15,1], 5b11111, 10h3ff }; }
                default: {
                    switch( classEa ) {
                        case 2b00: {
                            while( FSM != 0 ) {
                                onehot( FSM ) {
                                    case 0: {
                                        i = 0;
                                        q = 0;
                                        exp = floatingpointnumber( a ).exponent - 15;
                                        ac = ~exp[0,1] ? 1 : { 22b0, 1b1, a[9,1] };
                                        x = ~exp[0,1] ? { a[0,10], 12b0 } : { a[0,9], 13b0 };
                                    }
                                    case 1: {
                                        while( i != 21 ) {
                                            test_res = ac - { q, 2b01 };
                                            ac = { test_res[23,1] ? ac[0,21] : test_res[0,21], x[20,2] };
                                            q = { q[0,21], ~test_res[23,1] };
                                            x = { x[0,20], 2b00 };
                                            i = i + 1;
                                        }
                                    }
                                    case 2: {
                                        ( q ) = normalise22( q );
                                    }
                                    case 3: {
                                        exp = ( exp >>> 1 ) + 15;
                                        ( newfraction ) = round22( q );
                                        ( result ) = combinecomponents( sign, exp, newfraction );
                                    }
                                }
                                FSM = { FSM[0,3], 1b0 };
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
    lessthan = ( a[15,1] != b[15,1] ) ? a[15,1] & ((( a | b ) << 1) != 0 ) : ( a != b ) & ( a[15,1] ^ ( a < b));
}
circuitry floatequal( input a, input b, output equalto ) {
    equalto = ( a == b ) | ((( a | b ) << 1) == 0 );
}
circuitry floatlessequal( input a, input b, output lessequal, ) {
    lessequal = ( a[15,1] != b[15,1] ) ? a[15,1] | ((( a | b ) << 1) == 0 ) : ( a == b ) | ( a[15,1] ^ ( a < b ));
}

algorithm floatcompare(
    input   uint16  a,
    input   uint16  b,
    output  uint1   less,
    output  uint1   lessequal,
    output  uint1   equal
) <autorun> {
    while(1) {
        ( less ) = floatless( a, b );
        ( lessequal ) = floatlessequal( a, b );
        ( equal ) = floatequal( a, b );
    }
}
