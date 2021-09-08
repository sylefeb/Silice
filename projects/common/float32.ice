// Rob Shelton ( @robng15 Twitter, @rob-ng15 GitHub )
// Simple 32bit FPU calculation/conversion routines
// Designed for as small as FPGA usage as possible,
// not for speed.
//
// Copyright (c) 2021 Rob Shelton
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// Donated to Silice by @sylefeb
// MIT license, see LICENSE_MIT in Silice repo root
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
bitfield fp32{
    uint1   sign,
    uint8   exponent,
    uint23  fraction
}

bitfield floatingpointflags{
    uint1   IF,     // infinity as an argument
    uint1   NN,     // NaN as an argument
    uint1   NV,     // Result is not valid,
    uint1   DZ,     // Divide by zero
    uint1   OF,     // Result overflowed
    uint1   UF,     // Result underflowed
    uint1   NX      // Not exact ( integer to float conversion caused bits to be dropped )
}

// IDENTIFY infinity, signalling NAN, quiet NAN, ZERO
algorithm classify(
    input   uint32  a,
    output  uint1   INF,
    output  uint1   sNAN,
    output  uint1   qNAN,
    output  uint1   ZERO
) <autorun> {
    uint1   expFF <:: ( fp32(a).exponent == 8hff );
    always {
        INF = expFF & ~a[22,1];
        sNAN = expFF & a[22,1] & a[21,1];
        qNAN = expFF & a[22,1] & ~a[21,1];
        ZERO = ( fp32(a).exponent == 0 );
    }
}

// ALGORITHMS TO DEAL WITH 48 BIT FRACTIONS TO 23 BIT FRACTIONS
// NORMALISE A 48 BIT MANTISSA SO THAT THE MSB IS ONE
// FOR ADDSUB ALSO DECREMENT THE EXPONENT FOR EACH SHIFT LEFT
algorithm donormalise48_adjustexp(
    input   uint1   start,
    output  uint1   busy(0),
    input   int10   exp,
    input   uint48  bitstream,
    output  int10   newexp,
    output  uint48  normalised
) <autorun> {
    uint4   shiftcount <:: { normalised[33,15] == 0, normalised[41,7] == 0, normalised[45,3] == 0, 1b1 };
    while(1) {
        if( start ) {
            busy = 1;
            normalised = bitstream; newexp = exp;
            while( ~normalised[47,1] ) {
                switch( shiftcount ) {
                    default: { normalised = { normalised[0,47], 1b0 }; }
                    case 3: { normalised = { normalised[0,45], 3b0 }; }
                    case 7: { normalised = { normalised[0,41], 7b0 }; }
                    case 15: { normalised = { normalised[0,33], 15b0 }; }
                }
                newexp = newexp - shiftcount;
            }
            busy = 0;
        }
    }
}
algorithm donormalise48(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint48  bitstream,
    output  uint48  normalised
) <autorun> {
    uint4   shiftcount <:: { normalised[33,15] == 0, normalised[41,7] == 0, normalised[45,3] == 0, 1b1 };
    while(1) {
        if( start ) {
            busy = 1;
            normalised = bitstream;
            while( ~normalised[47,1] ) {
                switch( shiftcount ) {
                    default: { normalised = { normalised[0,47], 1b0 }; }
                    case 3: { normalised = { normalised[0,45], 3b0 }; }
                    case 7: { normalised = { normalised[0,41], 7b0 }; }
                    case 15: { normalised = { normalised[0,33], 15b0 }; }
                }
            }
            busy = 0;
        }
    }
}

// EXTRACT 23 BIT FRACTION FROM LEFT ALIGNED 48 BIT FRACTION WITH ROUNDING
// ADD BIAS TO EXPONENT AND ADJUST EXPONENT IF ROUNDING FORCES
algorithm doround48(
    input   uint48  bitstream,
    input   int10   exponent,
    output  uint23  roundfraction,
    output  int10   newexponent
) <autorun> {
    always {
        roundfraction = bitstream[24,23] + bitstream[23,1];
        newexponent = 127 + exponent + ( ( roundfraction == 0 ) & bitstream[23,1] );
    }
}

// COMBINE COMPONENTS INTO FLOATING POINT NUMBER
// UNDERFLOW return 0, OVERFLOW return infinity
algorithm docombinecomponents32(
    input   uint1   sign,
    input   int10   exp,
    input   uint23  fraction,
    output  uint1   OF,
    output  uint1   UF,
    output  uint32  f32
) <autorun> {
    always {
        OF = ( exp > 254 ); UF = exp[9,1];
        f32 = UF ? 0 : OF ? { sign, 8b11111111, 23h0 } : { sign, exp[0,8], fraction[0,23] };
    }
}

// CONVERT SIGNED/UNSIGNED INTEGERS TO FLOAT
// dounsigned == 1 for signed conversion (31 bit plus sign), == 0 for dounsigned conversion (32 bit)
algorithm inttofloat(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint1   dounsigned,
    output  uint7   flags,
    output  uint32  result
) <autorun> {
    uint1   sign <:: dounsigned ? 0 : a[31,1];
    uint8   zeros = uninitialised;
    uint32  number <:: dounsigned ? a : ( a[31,1] ? -a : a );
    uint32  fraction <:: NX ? number >> ( 8 - zeros ) : ( zeros > 8 ) ? number << ( zeros - 8 ) : number;
    int10   exponent <:: 158 - zeros;
    uint1   OF = uninitialised; uint1 UF = uninitialised; uint1 NX = uninitialised;

    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint32  f32 = uninitialised;
    docombinecomponents32 COMBINE(
        sign <: sign,
        exp <: exponent,
        fraction <: fraction,
        OF :> cOF,
        UF :> cUF,
        f32 :> f32
    );
    flags := { 4b0, OF, UF, NX };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0; NX = 0;
            switch( number ) {
                case 0: { result = 0; }
                default: {
                    // CHECK FOR 24, 16 OR 8 LEADING ZEROS, CONTINUE COUNTING FROM THERE
                    zeros = number[8,24] == 0 ? 24 : number[16,16] == 0 ? 16 : number[24,8] == 0 ? 8 : 0; while( ~number[31-zeros,1] ) { zeros = zeros + 1; } NX = ( zeros < 8 );
                    ++:
                    OF = cOF; UF = cUF; result = f32;
                }
            }
            busy = 0;
        }
    }
}

// CONVERT FLOAT TO SIGNED INTEGERS
algorithm floattoint(
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun> {
    int10   exp <:: fp32( a ).exponent - 127;
    uint33  sig <:: ( exp < 24 ) ? { 9b1, fp32( a ).fraction, 1b0 } >> ( 23 - exp ) : { 9b1, fp32( a ).fraction, 1b0 } << ( exp - 24);
    uint1   IF <:: aINF;
    uint1   NN <:: asNAN | aqNAN;
    uint1   NV = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );

    flags := { IF, NN, NV, 4b0000 };
    always {
        switch( { IF | NN, aZERO } ) {
            case 2b00: { NV = ( exp > 30 ); result = NV ? { fp32( a ).sign, 31h7fffffff } : fp32( a ).sign ? -( sig[1,32] + sig[0,1] ) : ( sig[1,32] + sig[0,1] ); }
            case 2b01: { NV = 0; result = 0; }
            default: { NV = 1; result = NN ? 32h7fffffff : { fp32( a ).sign, 31h7fffffff }; }
        }
    }
}

// CONVERT FLOAT TO UNSIGNED INTEGERS
algorithm floattouint(
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun> {
    int10   exp <:: fp32( a ).exponent - 127;
    uint33  sig <:: ( exp < 24 ) ? { 9b1, fp32( a ).fraction, 1b0 } >> ( 23 - exp ) : { 9b1, fp32( a ).fraction, 1b0 } << ( exp - 24);
    uint1   IF <:: aINF;
    uint1   NN <:: asNAN | aqNAN;
    uint1   NV = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );

    flags := { IF, NN, NV, 4b0000 };
    always {
        switch( { IF | NN, aZERO } ) {
            case 2b00: {
                if( fp32( a ).sign ) {
                    NV = 1; result = 0;
                } else {
                    NV = ( exp > 31 ); result = NV ? 32hffffffff : ( sig[1,32] + sig[0,1] );
                }
            }
            case 2b01: { NV = 0; result = 0; }
            default: { NV = 1; result = NN ? 32hffffffff : { {32{~fp32( a ).sign}} };  }
        }
    }
}

// ADDSUB ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm equaliseexpaddsub(
    input   int10   expA,
    input   uint48  sigA,
    input   int10   expB,
    input   uint48  sigB,
    output  int10   newexpA,
    output  uint48  newsigA,
    output  int10   newexpB,
    output  uint48  newsigB
) <autorun> {
    always {
        // EQUALISE THE EXPONENTS BY SHIFT SMALLER NUMBER FRACTION PART TO THE RIGHT
        if( expA < expB ) {
            newsigA = sigA >> ( expB - expA ); newexpA = expB; newsigB = sigB; newexpB = expB;
        } else {
            newsigB = sigB >> ( expA - expB ); newexpB = expA; newsigA = sigA; newexpA = expA;
        }
    }
}
algorithm dofloataddsub(
    input   uint1   signA,
    input   uint48  sigA,
    input   uint1   signB,
    input   uint48  sigB,
    output  uint1   resultsign,
    output  uint48  resultfraction
) <autorun> {
    uint48  sigAminussigB <:: sigA - sigB;
    uint48  sigBminussigA <:: sigB - sigA;

    always {
        // PERFORM ADDITION HANDLING SIGNS
        switch( { signA, signB } ) {
            case 2b01: { resultsign = ( sigB > sigA ); resultfraction = resultsign ? sigBminussigA : sigAminussigB; }
            case 2b10: { resultsign = ( sigA > sigB ); resultfraction = resultsign ? sigAminussigB : sigBminussigA; }
            default: { resultsign = signA; resultfraction = sigA + sigB; }
        }
    }
}

algorithm floataddsub(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint32  b,
    input   uint1   addsub,
    output  uint7   flags,
    output  uint32  result
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS - SWITCH SIGN OF B IF SUBTRACTION
    uint1   signA <:: fp32( a ).sign;
    int10   expA <:: fp32( a ).exponent - 127;
    uint48  sigA <:: { 2b01, fp32(a).fraction, 23b0 };
    uint1   signB <:: addsub ? ~fp32( b ).sign : fp32( b ).sign;
    int10   expB <:: fp32( b ).exponent - 127;
    uint48  sigB <:: { 2b01, fp32(b).fraction, 23b0 };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF - INF )
    uint1   IF <:: ( aINF | bINF );
    uint1   NN <:: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV <:: ( aINF & bINF) & ( signA != signB );
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );
    uint1   bINF = uninitialised;
    uint1   bsNAN = uninitialised;
    uint1   bqNAN = uninitialised;
    uint1   bZERO = uninitialised;
    classify B(
        a <: b,
        INF :> bINF,
        sNAN :> bsNAN,
        qNAN :> bqNAN,
        ZERO :> bZERO
    );

    // EQUALISE THE EXPONENTS
    int10   eqexpA = uninitialised;
    uint48  eqsigA = uninitialised;
    int10   eqexpB = uninitialised;
    uint48  eqsigB = uninitialised;
    equaliseexpaddsub EQUALISEEXP(
        expA <: expA,
        sigA <: sigA,
        expB <: expB,
        sigB <: sigB,
        newexpA :> eqexpA,
        newsigA :> eqsigA,
        newexpB :> eqexpB,
        newsigB :> eqsigB
    );

    // PERFORM THE ADDITION/SUBTRACION USING THE EQUALISED FRACTIONS, 1 IS ADDED TO THE EXPONENT IN CASE OF OVERFLOW - NORMALISING WILL ADJUST WHEN SHIFTING
    uint1   resultsign = uninitialised;
    int10   resultexp <:: eqexpA + 1;
    uint48  resultfraction = uninitialised;
    dofloataddsub ADDSUB(
        signA <: signA,
        sigA <: eqsigA,
        signB <: signB,
        sigB <: eqsigB,
        resultsign :> resultsign,
        resultfraction :> resultfraction
    );

    // NORMALISE THE RESULTING FRACTION AND ADJUST THE EXPONENT IF SMALLER ( ie, MSB is not 1 )
    int10   normalexp = uninitialised;
    uint48  normalfraction = uninitialised;
    uint1   NORMALISEstart = uninitialised;
    uint1   NORMALISEbusy = uninitialised;
    donormalise48_adjustexp NORMALISE(
        exp <: resultexp,
        bitstream <: resultfraction,
        newexp :> normalexp,
        normalised :> normalfraction,
        start <: NORMALISEstart,
        busy :> NORMALISEbusy
    );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    int10   roundexponent = uninitialised;
    uint48  roundfraction = uninitialised;
    doround48 ROUND(
        exponent <: normalexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float32
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint32  f32 = uninitialised;
    docombinecomponents32 COMBINE(
        sign <: resultsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f32 :> f32
    );

    NORMALISEstart := 0; flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 2 CYCLES FOR EQUALISING EXPONENTS AND TO PERFORM THE ADDITION/SUBTRACTION
            ++:
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    switch( resultfraction ) {
                        case 0: { result = 0; }
                        default: {
                            NORMALISEstart = 1; while( NORMALISEbusy ) {}
                            OF = cOF; UF = cUF; result = f32;
                        }
                    }
                }
                case 2b01: { result = ( aZERO & bZERO ) ? 0 : ( bZERO ) ? a : addsub ? { ~fp32( b ).sign, b[0,31] } : b; }
                default: {
                    switch( { IF, NN } ) {
                        case 2b10: { result = ( aINF & bINF) ? ( signA == signB ) ? a : 32hffc00000 : aINF ? a : b; }
                        default: { result = 32hffc00000; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// UNSIGNED / SIGNED 24 by 24 bit multiplication giving 48 bit product using DSP blocks
algorithm dofloatmul(
    input   uint24  factor_1,
    input   uint24  factor_2,
    output  uint48  product
) <autorun> {
    always {
        product = factor_1 * factor_2;
    }
}
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint32  b,

    output  uint7   flags,
    output  uint32  result
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF PRODUCT ( + 1 IF PRODUCT OVERFLOWS, MSB == 1 )
    uint1   productsign <:: fp32( a ).sign ^ fp32( b ).sign;
    int10   productexp <:: (fp32( a ).exponent - 127) + (fp32( b ).exponent - 127) + product[47,1];
    uint24  sigA <:: { 1b1, fp32( a ).fraction };
    uint24  sigB <:: { 1b1, fp32( b ).fraction };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF x ZERO )
    uint1   IF <:: ( aINF | bINF );
    uint1   NN <:: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV <:: ( aINF | bINF ) & ( aZERO | bZERO );
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );
    uint1   bINF = uninitialised;
    uint1   bsNAN = uninitialised;
    uint1   bqNAN = uninitialised;
    uint1   bZERO = uninitialised;
    classify B(
        a <: b,
        INF :> bINF,
        sNAN :> bsNAN,
        qNAN :> bqNAN,
        ZERO :> bZERO
    );

    uint48  product = uninitialised;
    dofloatmul UINTMUL(
        factor_1 <: sigA,
        factor_2 <: sigB,
        product :> product
    );

    // FAST NORMALISATION - MULTIPLICATION RESULTS IN 1x.xxx or 01.xxxx
    uint48  normalfraction <:: product[47,1] ? product : { product[0,47], 1b0 };

    int10   roundexponent = uninitialised;
    uint48  roundfraction = uninitialised;
    doround48 ROUND(
        exponent <: productexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float32
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint32  f32 = uninitialised;
    docombinecomponents32 COMBINE(
        sign <: productsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f32 :> f32
    );

    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 3 CYLES TO PERFORM THE MULTIPLICATION, NORMALISATION AND ROUNDING
            ++:
            ++:
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    // STEPS: SETUP -> DOMUL -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                    OF = cOF; UF = cUF; result = f32;
                }
                case 2b01: { result = { productsign, 31b0 }; }
                default: {
                    switch( { IF, aZERO | bZERO } ) {
                        case 2b11: { result = 32hffc00000; }
                        case 2b10: { result = NN ? 32hffc00000 : { productsign, 8b11111111, 23b0 }; }
                        default: { result = 32hffc00000; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// DIVIDE TWO FLOATING POINT NUMBERS
algorithm dofloatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint50  sigA,
    input   uint50  sigB,
    output  uint50  quotient
) <autorun> {
    uint50  remainder = uninitialised;
    uint50  temporary <:: { remainder[0,49], sigA[bit,1] };
    uint1   bitresult <:: __unsigned(temporary) >= __unsigned(sigB);
    uint6   bit(63);

    busy := start | ( bit != 63 ) | ( quotient[48,2] != 0 );
    while(1) {
        // FIND QUOTIENT AND ENSURE 48 BIT FRACTION ( ie BITS 48 and 49 clear )
        if( start ) {
            bit = 49; quotient = 0; remainder = 0;
            while( bit != 63 ) {
                remainder = __unsigned(temporary) - ( bitresult ? __unsigned(sigB) : 0 );
                quotient[bit,1] = bitresult;
                bit = bit - 1;
            }
            while( quotient[48,2] != 00 ) { quotient = quotient >> 1; }
        }
    }
}

algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint32  b,

    output  uint7   flags,
    output  uint32  result
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF QUOTIENT ( -1 IF DIVISOR > DIVIDEND )
    uint1   quotientsign <:: fp32( a ).sign ^ fp32( b ).sign;
    int10   quotientexp <:: ((fp32( a ).exponent - 127) - (fp32( b ).exponent - 127)) - ( fp32(b).fraction > fp32(a).fraction );
    uint50  sigA <:: { 1b1, fp32(a).fraction, 26b0 };
    uint50  sigB <:: { 27b1, fp32(b).fraction };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND DIVIDE ZERO
    uint1   IF <:: ( aINF | bINF );
    uint1   NN <:: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV = uninitialised;
    uint1   DZ <:: bZERO;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );
    uint1   bINF = uninitialised;
    uint1   bsNAN = uninitialised;
    uint1   bqNAN = uninitialised;
    uint1   bZERO = uninitialised;
    classify B(
        a <: b,
        INF :> bINF,
        sNAN :> bsNAN,
        qNAN :> bqNAN,
        ZERO :> bZERO
    );

    uint48  quotient = uninitialised;
    uint1   DODIVIDEstart = uninitialised;
    uint1   DODIVIDEbusy = uninitialised;
    dofloatdivide DODIVIDE(
        sigA <: sigA,
        sigB <: sigB,
        quotient :> quotient,
        start <: DODIVIDEstart,
        busy :> DODIVIDEbusy
    );

    uint48  normalfraction = uninitialised;
    uint1   NORMALISEstart = uninitialised;
    uint1   NORMALISEbusy = uninitialised;
    donormalise48 NORMALISE(
        bitstream <: quotient,
        normalised :> normalfraction,
        start <: NORMALISEstart,
        busy :> NORMALISEbusy
    );

    int10   roundexponent = uninitialised;
    uint48  roundfraction = uninitialised;
    doround48 ROUND(
        exponent <: quotientexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float32
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint32  f32 = uninitialised;
    docombinecomponents32 COMBINE(
        sign <: quotientsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f32 :> f32
    );

    DODIVIDEstart := 0; NORMALISEstart := 0; flags := { IF, NN, 1b0, DZ, OF, UF, 1b0};
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    DODIVIDEstart = 1; while( DODIVIDEbusy ) {}
                    NORMALISEstart = 1; while( NORMALISEbusy ) {}
                    OF = cOF; UF = cUF; result = f32;
                }
                case 2b01: { result = ( aZERO & bZERO ) ? 32hffc00000 : ( bZERO ) ? { quotientsign, 8b11111111, 23b0 } : { quotientsign, 31b0 }; }
                default: { result = ( aINF &bINF ) | NN | bZERO ? 32hffc00000 : aZERO | bINF ? { quotientsign, 31b0 } : { quotientsign, 8b11111111, 23b0 }; }
            }
            busy = 0;
        }
    }
}

// ADAPTED FROM https://projectf.io/posts/square-root-in-verilog/
//
// MIT License
//
// Copyright (c) 2021 Will Green, Project F
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
algorithm dofloatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint50  start_ac,
    input   uint48  start_x,
    output  uint48  q
) <autorun> {
    uint50  test_res <:: ac - { q, 2b01 };
    uint50  ac = uninitialised;
    uint48  x = uninitialised;
    uint6   i(47);

    busy := start | ( i != 47 );
    while(1) {
        if( start ) {
            i = 0; q = 0; ac = start_ac; x = start_x;
            while( i != 47 ) {
                ac = { test_res[49,1] ? ac[0,47] : test_res[0,47], x[46,2] };
                q = { q[0,47], ~test_res[49,1] };
                x = { x[0,46], 2b00 };
                i = i + 1;
            }
        }
    }
}

algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun> {
    uint1   sign <:: fp32( a ).sign;             // SIGN OF INPUT
    int10   exp  <:: fp32( a ).exponent - 127;   // EXPONENT OF INPUT ( used to determine if 1x.xxxxx or 01.xxxxx for fixed point fraction to sqrt )

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND NOT VALID
    uint1   IF <:: aINF;
    uint1   NN <:: asNAN | aqNAN;
    uint1   NV <:: IF | NN | sign;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;

    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );

    // SQUARE ROOT EXPONENT IS HALF OF INPUT EXPONENT
    uint50  start_ac <:: ~exp[0,1] ? 1 : { 48b0, 1b1, a[22,1] };
    uint48  start_x <:: ~exp[0,1] ? { fp32( a ).fraction, 25b0 } : { a[0,22], 26b0 };
    uint48  squareroot = uninitialised;
    int10   squarerootexp <:: ( exp >>> 1 );
    uint1   DOSQRTstart = uninitialised;
    uint1   DOSQRTbusy = uninitialised;
    dofloatsqrt DOSQRT(
        start_ac <: start_ac,
        start_x <: start_x,
        q :> squareroot,
        start <: DOSQRTstart,
        busy :> DOSQRTbusy
    );

    // FAST NORMALISATION - SQUARE ROOT RESULTS IN 1x.xxx or 01.xxxx
    uint48  normalfraction <:: squareroot[47,1] ? squareroot : { squareroot[0,47], 1b0 };

    int10   roundexponent = uninitialised;
    uint48  roundfraction = uninitialised;
    doround48 ROUND(
        exponent <: squarerootexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float32
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint32  f32 = uninitialised;
    docombinecomponents32 COMBINE(
        sign <: sign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f32 :> f32
    );

    DOSQRTstart := 0; flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, aZERO } ) {
                case 2b00: {
                    if( sign ) {
                        // DETECT NEGATIVE -> qNAN
                        result = 32hffc00000;
                    } else {
                        // STEPS: SETUP -> DOSQRT -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                        DOSQRTstart = 1; while( DOSQRTbusy ) {}
                        OF = cOF; UF = cUF; result = f32;
                    }
                }
                // DETECT sNAN, qNAN, -INF, -0 -> qNAN AND  INF -> INF, 0 -> 0
                default: { result = sign ? 32hffc00000 : a; }
            }
            busy = 0;
        }
    }
}

// FLOATING POINT COMPARISONS - ADAPTED FROM SOFT-FLOAT

/*============================================================================

License for Berkeley SoftFloat Release 3e

John R. Hauser
2018 January 20

The following applies to the whole of SoftFloat Release 3e as well as to
each source file individually.

Copyright 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018 The Regents of the
University of California.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
    this list of conditions, and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions, and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

 3. Neither the name of the University nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS "AS IS", AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ARE
DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=============================================================================*/

algorithm floatcompare(
    input   uint32  a,
    input   uint32  b,
    output  uint1   less,
    output  uint7   flags,
    output  uint1   equal
) <autorun> {
    uint1   aINF = uninitialised;
    uint1   asNAN = uninitialised;
    uint1   aqNAN = uninitialised;
    uint1   aZERO = uninitialised;
    classify A(
        a <: a,
        INF :> aINF,
        sNAN :> asNAN,
        qNAN :> aqNAN,
        ZERO :> aZERO
    );
    uint1   bINF = uninitialised;
    uint1   bsNAN = uninitialised;
    uint1   bqNAN = uninitialised;
    uint1   bZERO = uninitialised;
    classify B(
        a <: b,
        INF :> bINF,
        sNAN :> bsNAN,
        qNAN :> bqNAN,
        ZERO :> bZERO
    );

    // IDENTIFY NaN, RETURN 0 IF NAN, OTHERWISE RESULT OF COMPARISONS
    always {
        flags = { aINF | bINF, asNAN | bsNAN | aqNAN | bqNAN, asNAN | bsNAN | aqNAN | bqNAN, 4b0000 };
        if( flags[5,1] ) {
            // NAN
            less = 0;
            equal = 0;
        } else {
            less = ( fp32( a ).sign != fp32( b ).sign ) ? fp32( a ).sign & ((( a | b ) << 1) != 0 ) : ( a != b ) & ( fp32( a ).sign ^ ( a < b));
            equal = ( a == b ) | ((( a | b ) << 1) == 0 );
        }
    }
}
