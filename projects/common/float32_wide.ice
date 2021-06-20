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
// intotofloat a as 32 bit integer, signedunsigned == 0 unsigned, ==  signed conversion
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
    if( ( exp > 254 ) || ( exp < 0 ) ) {
        f32 = ( exp < 0 ) ? 0 : { sign, 8b01111111, 23h7fffff };
    } else {
        f32 = { sign, exp[0,8], fraction[0,23] };
    }
}

// CLASSIFY EXPONENT AND FRACTION or EXPONENT
circuitry classEF( output E, output F, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 8hff, ( floatingpointnumber(N).exponent ) == 8h00 };
    F = ( floatingpointnumber(N).fraction ) == 23h0000;
}
circuitry classE( output E, input N ) {
    E = { ( floatingpointnumber(N).exponent ) == 8hff, ( floatingpointnumber(N).exponent ) == 8h00 };
}

// CIRCUITS TO DEAL WITH 48 BIT FRACTIONS TO 23 BIT FRACTIONS
// REALIGN A 48BIT NUMBER SO MSB IS 1
circuitry normalise48( inout bitstream ) {
    while( ~bitstream[47,1] && ( bitstream != 0 ) ) {
        bitstream = { bitstream[0,47], 1b0 };
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
// signedunsigned == 1 for signed conversion (31 bit plus sign), == 0 for unsigned conversion (32 bit)

circuitry countleadingzeros( input bitstream, output count ) {
    uint2   CYCLE = uninitialised;

    CYCLE = 1;
    while( CYCLE != 0 ) {
        onehot( CYCLE ) {
            case 0: {
                count = 0;
            }
            case 1: {
                switch( bitstream ) {
                    case 0: { count = 32; }
                    default: {
                        while( ~bitstream[31-count,1] ) {
                            count = count + 1;
                        }
                    }
                }
            }
        }
        CYCLE = { CYCLE[0,1], 1b0 };
    }
}
algorithm inttofloat(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint1   signedunsigned,

    output  uint32  result
) <autorun> {
    uint2   FSM = uninitialised;
    uint1   sign = uninitialised;
    uint8   exp = uninitialised;
    uint8   zeros = uninitialised;
    uint32  number = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        // SIGNED / UNSIGNED
                        sign = signedunsigned ? 0 : a[31,1];
                        number = signedunsigned ? a : ( a[31,1] ? -a : a );
                    }
                    case 1: {
                        switch( number ) {
                            case 0: { result = 0; }
                            default: {
                                ( zeros ) = countleadingzeros( number );
                                number = ( zeros < 8 ) ? number >> ( 8 - zeros ) : ( zeros > 8 ) ? number << ( zeros - 8 ) : number;
                                exp = 158 - zeros;
                                ( result ) = combinecomponents( sign, exp, number );
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

// CONVERT FLOAT TO SIGNED/UNSIGNED INTEGERS
algorithm floattouint(
    input   uint32  a,
    output  uint32  result,
    output  uint1   busy,
    input   uint1   start
) <autorun> {
    uint2   classEa = uninitialised;
    int8    exp = uninitialised;
    uint33  sig = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            ( classEa ) = classE( a );
            switch( classEa ) {
                case 2b00: {
                    switch( a[31,1] ) {
                        case 1: { result = 0; }
                        default: {
                            exp = floatingpointnumber( a ).exponent - 127;
                            if( exp < 24 ) {
                                sig = { 9b1, a[0,23], 1b0 } >> ( 23 - exp );
                            } else {
                                sig = { 9b1, a[0,23], 1b0 } << ( exp - 24);
                            }
                            result = ( exp > 31 ) ? 32hffffffff : ( sig[1,32] + sig[0,1] );
                        }
                    }
                }
                case 2b01: { result = 0; }
                case 2b10: { result = a[31,1] ? 0 : 32hffffffff;  }
            }
            busy = 0;
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
    int8    exp = uninitialised;
    uint33  sig = uninitialised;

    busy = 0;

    while(1) {
        if( start ) {
            busy = 1;
            ( classEa ) = classE( a );
            switch( classEa ) {
                case 2b00: {
                    exp = floatingpointnumber( a ).exponent - 127;
                    if( exp < 24 ) {
                        sig = { 9b1, a[0,23], 1b0 } >> ( 23 - exp );
                    } else {
                        sig = { 9b1, a[0,23], 1b0 } << ( exp - 24);
                    }
                    result = ( exp > 30 ) ? ( a[31,1] ? 32hffffffff : 32h7fffffff ) : a[31,1] ? -( sig[1,32] + sig[0,1] ) : ( sig[1,32] + sig[0,1] );
                 }
                case 2b01: { result = 0; }
                case 2b10: { result = a[31,1] ? 32hffffffff : 32h7fffffff; }
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

    input   uint32  a,
    input   uint32  b,
    input   uint1   addsub,

    output  uint32  result
) <autorun> {
    uint4   FSM = uninitialised;
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
                        signA = a[31,1]; signB = addsub ? ~b[31,1] : b[31,1];
                    }
                    case 1: {
                        // EXTRACT COMPONENTS - HOLD TO LEFT TO IMPROVE FRACTIONAL ACCURACY
                        expA = floatingpointnumber( a ).exponent - 127;
                        expB = floatingpointnumber( b ).exponent - 127;
                        sigA = { 2b01, floatingpointnumber(a).fraction, 23b0 };
                        sigB = { 2b01, floatingpointnumber(b).fraction, 23b0 };
                        sign = floatingpointnumber(a).sign;
                        ( classEa ) = classE( a );
                        ( classEb ) = classE( b );
                    }
                    case 2: {
                        // ADJUST TO EQUAL EXPONENTS
                        if( ( classEa | classEb ) == 2b00 ) {
                            if( expA < expB ) {
                                sigA = sigA >> ( expB - expA );
                                expA = expB;
                            } else {
                                if( expB < expA ) {
                                    sigB = sigB >> ( expA - expB );
                                    expB = expA;
                                }
                            }
                        }
                    }
                    case 3: {
                        switch( classEa | classEb ) {
                            case 2b00: {
                                switch( { signA, signB } ) {
                                    // PERFORM + HANDLING SIGNS
                                    case 2b01: {
                                        if( sigB > sigA ) {
                                            sign = 1;
                                            round = ( sigA != 0 );
                                            sigA = sigB - ( ~round ? 1 : sigA );
                                        } else {
                                            sign = 0;
                                            round = ( sigB != 0 );
                                            sigA = sigA - ( ~round ? 1 : sigB );
                                        }
                                    }
                                    case 2b10: {
                                        if(  sigA > sigB ) {
                                            sign = 1;
                                            round = ( sigB != 0 );
                                            sigA = sigA - ( ~round ? 1 : sigB );
                                        } else {
                                            sign = 0;
                                            round = ( sigA != 0 );
                                            sigA = sigB - ( ~round ? 1 : sigA );
                                        }
                                    }
                                    default: { sign = signA; sigA = sigA + sigB; }
                                }
                                if( sigA == 0 ) {
                                    result = 0;
                                } else {
                                    // NORMALISE AND ROUND
                                    if( sigA[47,1] ) {
                                        expA = expA + 1;
                                    } else {
                                        while( ~sigA[46,1] ) {
                                            sigA = { sigA[0,47], 1b0 };
                                            expA = expA - 1;
                                        }
                                        sigA = { sigA[0,47], 1b0 };
                                    }
                                    sigA[23,1] = sigA[23,1] & round;
                                    ( newfraction ) = round48( sigA );
                                    ( expA ) = adjustexp48( exp, newfraction, sigA );
                                    ( result ) = combinecomponents( sign, expA, newfraction );
                                }
                            }
                            case 2b01: { result = ( classEb == 2b01 ) ? a : addsub ? { ~b[31,1], b[0,31] } : b; }
                            default: { result = { 1b0, 8b11111111, 23b0 }; }
                        }
                    }
                }
                FSM = { FSM[0,3], 1b0 };
            }
            busy = 0;
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint32  b,

    output  uint32  result
) <autorun> {
    uint3   FSM = uninitialised;

    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint1   productsign = uninitialised;
    uint48  product = uninitialised;
    int16   productexp  = uninitialised;
    uint23  newfraction = uninitialised;

    // Calculation is split into 4 18 x 18 multiplications for DSP
    uint18  A = uninitialised;
    uint18  B = uninitialised;
    uint18  C = uninitialised;
    uint18  D = uninitialised;
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
                        A = { 11b1, a[16,7] };
                        B = { 2b0, a[0,16] };
                        C = { 11b1, b[16,7] };
                        D = { 2b0, b[0,16] };
                    }
                    case 1: {
                        product = ( D*B + { D*A, 16b0 } + { C*B, 16b0 } + { C*A, 32b0 } );
                        productexp = (floatingpointnumber( a ).exponent - 127) + (floatingpointnumber( b ).exponent - 127) + product[47,1];
                        productsign = a[31,1] ^ b[31,1];
                    }
                    case 2: {
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
                FSM = { FSM[0,2], 1b0 };
            }
            busy = 0;
        }
    }
}

// DIVIDE TWO FLOATING POINT NUMBERS
algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy,

    input   uint32  a,
    input   uint32  b,

    output  uint32  result
) <autorun> {
    uint4   FSM = uninitialised;
    uint1   DIVBIT = uninitialised;
    uint2   classEa = uninitialised;
    uint2   classEb = uninitialised;
    uint48  temporary = uninitialised;
    uint1   quotientsign = uninitialised;
    int16   quotientexp = uninitialised;
    uint48  quotient = uninitialised;
    uint48  remainder = uninitialised;
    uint6   bit = uninitialised;
    uint48  sigA = uninitialised;
    uint48  sigB = uninitialised;
    uint23  newfraction = uninitialised;

    while(1) {
        if( start ) {
            //busy = 1;
            FSM = 1;
            while( FSM != 0 ) {
                onehot( FSM ) {
                    case 0: {
                        ( classEa ) = classE( a );
                        ( classEb ) = classE( b );
                        sigA = { 1b1, floatingpointnumber(a).fraction, 24b0 };
                        sigB = { 25b1, floatingpointnumber(b).fraction };
                        quotientsign = a[31,1] ^ b[31,1];
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
                                    temporary = { remainder[0,47], sigA[bit,1] };
                                    DIVBIT = __unsigned(temporary) >= __unsigned(sigB);
                                    switch( DIVBIT ) {
                                        case 1: { remainder = __unsigned(temporary) - __unsigned(sigB); quotient[bit,1] = 1; }
                                        case 0: { remainder = temporary; }
                                    }
                                    bit = bit - 1;
                                }
                            }
                            case 2b01: { result = ( classEb == 2b01 ) ? { quotientsign, 8b11111111, 23b0 } : { quotientsign, 31b0 }; }
                            default: { result = { quotientsign, 8b11111111, 23b0 }; }
                        }
                    }
                    case 3: {
                        switch( classEa | classEb ) {
                            case 2b00: {
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
    uint1   sign = uninitialised;
    uint8   exp  = uninitialised;
    uint23  fraction = uninitialised;

    while(1) {
        if( start ) {
            busy = 1;
            FSM = 1;
            if( ( a == 0 ) || ( a[31,1] ) ) {
                result = ( a == 0 ) ? 0 : { a[31,1], 8b11111111, 23b0 };
            } else {
                while( FSM != 0 ) {
                    onehot( FSM ) {
                        case 0: {
                            i = 0;
                            q = 0;
                            sign = floatingpointnumber( a ).sign;
                            exp = floatingpointnumber( a ).exponent;
                            fraction = floatingpointnumber( a ).fraction;

                            if( exp[0,1] ) {
                                ac = 1;
                                x = { floatingpointnumber( a ).fraction, 25b0 };
                            } else {
                                ac = { 48b0, 1b1, fraction[22,1] };
                                x = { fraction[0,22], 26b0 };
                            }
                        }
                        case 1: {
                            while( i != 47 ) {
                                test_res = ac - { q, 2b01 };
                                if( ~test_res[49,1] ) {
                                    ac = { test_res[0,47], x[46,2] };
                                    x = { x[0,46], 2b00 };
                                    q = { q[0,46], 1b1 };
                                } else {
                                    ac = { ac[0,47], x[0,2] };
                                    x = { x[0,46], 2b00 };
                                    q = { q[0,47], 1b0 };
                                }
                                i = i + 1;
                            }
                        }
                        case 2: {
                            exp = exp - 127;
                            ( q ) = normalise48( q );
                        }
                        case 3: {
                            exp = ( exp >>> 1 ) + 127;
                            ( fraction ) = round48( q );
                            ( result ) = combinecomponents( sign, exp, fraction );
                        }
                    }
                    FSM = { FSM[0,3], 1b0 };
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
    lessthan = ( a[31,1] != b[31,1] ) ? a[31,1] & ((( a | b ) << 1) != 0 ) : ( a != b ) & ( a[31,1] ^ ( a < b));
}
circuitry floatequal( input a, input b, output equalto ) {
    equalto = ( a == b ) | ((( a | b ) << 1) == 0 );
}
circuitry floatlessequal( input a, input b, output lessequal, ) {
    lessequal = ( a[31,1] != b[31,1] ) ? a[31,1] | ((( a | b ) << 1) == 0 ) : ( a == b ) | ( a[31,1] ^ ( a < b ));
}
