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

// CLZ CIRCUITS - TRANSLATED BY @sylefeb
// From recursive Verilog module
// https://electronics.stackexchange.com/questions/196914/verilog-synthesize-high-speed-leading-zero-count

// Create a LUA pre-processor function that recursively writes
// circuitries counting the number of leading zeros in variables
// of decreasing width.
// Note: this could also be made in-place without wrapping in a
// circuitry, directly outputting a hierarchical set of trackers (<:)
$$function generate_clz(name,w_in,recurse)
$$ local w_out = clog2(w_in)
$$ local w_h   = w_in//2
$$ if w_in > 2 then generate_clz(name,w_in//2,1) end
circuitry $name$_$w_in$ (input in,output out)
{
$$ if w_in == 2 then
   out = !in[1,1];
$$ else
   uint$clog2(w_in)-1$ half_count = uninitialized;
   uint$w_h$           lhs        <: in[$w_h$,$w_h$];
   uint$w_h$           rhs        <: in[    0,$w_h$];
   uint$w_h$           select     <: left_empty ? rhs : lhs;
   uint1               left_empty <: ~|lhs;
   (half_count) = $name$_$w_h$(select);
   out          = {left_empty,half_count};
$$ end
}
$$end

// Produce a circuit for 32 bits numbers ( and 16, 8, 4, 2 )
$$generate_clz('clz_silice',32)

// BITFIELD FOR FLOATING POINT NUMBER - IEEE-754 32 bit format
bitfield fp32{
    uint1   sign,
    uint8   exponent,
    uint23  fraction
}

// REFERENCE, NOT USED IN THIS MODULE
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
) <autorun,reginputs> {
    // CHECK FOR 8hff ( signals INF/NAN )
    uint1   expFF <:: &fp32(a).exponent;
    uint1   NAN <:: expFF & a[22,1];
    always {
        INF = expFF & ~a[22,1];
        sNAN = NAN & a[21,1];
        qNAN = NAN & ~a[21,1];
        ZERO = ~|( fp32(a).exponent );
    }
}

// NORMALISE A 48 BIT MANTISSA SO THAT THE MSB IS ONE, FOR ADDSUB ALSO DECREMENT THE EXPONENT FOR EACH SHIFT LEFT
// EXTRACT THE 24 BITS FOLLOWING THE MSB (1.xxxx) FOR ROUNDING
algorithm clz48(
    input   uint48  bitstream,
    output! uint6   count
) <autorun,reginputs> {
    uint16  bitstreamh <:: bitstream[32,16];
    uint32  bitstreaml <:: bitstream[0,32];
    uint1   zerohigh <:: ( ~|bitstreamh );
    uint6   clz = uninitialised;
    always {
        if( zerohigh ) {
            ( clz ) = clz_silice_32( bitstreaml );
            count = 16 + clz;
        } else {
            ( count ) = clz_silice_16( bitstreamh );
        }
    }
}
algorithm donormalise24_adjustexp(
    input   int10   exp,
    input   uint48  bitstream,
    output  int10   newexp,
    output  uint24  normalised
) <autorun,reginputs> {
    // COUNT LEADING ZEROS
    clz48 CLZ48( bitstream <: bitstream );
    uint48  temporary <:: bitstream << CLZ48.count;
    always {
        normalised = temporary[23,24];
        newexp = exp - CLZ48.count;
    }
}
algorithm donormalise24(
    input   uint48  bitstream,
    output  uint24  normalised
) <autorun,reginputs> {
    // COUNT LEADING ZEROS
    clz48 CLZ48( bitstream <: bitstream );
    uint48  temporary <:: bitstream << CLZ48.count;
    always {
        normalised = temporary[23,24];
    }
}

// ROUND 23 BIT FRACTION FROM NORMALISED FRACTION USING NEXT TRAILING BIT
// ADD BIAS TO EXPONENT AND ADJUST EXPONENT IF ROUNDING FORCES
algorithm doround24(
    input   uint24  bitstream,
    input   int10   exponent,
    output  uint23  roundfraction,
    output  int10   newexponent
) <autorun,reginputs> {
    always {
        roundfraction = bitstream[1,23] + bitstream[0,1];
        newexponent = ( ( ~|roundfraction  & bitstream[0,1] ) ? 128 : 127 ) + exponent;
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
) <autorun,reginputs> {
    always {
        OF = ( exp > 254 ); UF = exp[9,1];
        f32 = UF ? 0 : { sign, OF ? 31h7f800000 : { exp[0,8], fraction } };
    }
}

// CONVERT SIGNED/UNSIGNED INTEGERS TO FLOAT
// dounsigned == 1 for signed conversion (31 bit plus sign), == 0 for dounsigned conversion (32 bit)
algorithm clz32(
    input   uint32  bitstream,
    output! uint6   zeros
) <autorun,reginputs> {
    always {
        ( zeros ) = clz_silice_32( bitstream );
    }
}
algorithm prepitof(
    input   uint32  a,
    input   uint1   dounsigned,
    output  uint1   sign,
    output  uint32  number,
    output  uint23  fraction,
    output  int10   exponent,
    output  uint1   NX
) <autorun> {
    // COUNT LEADING ZEROS
    clz32 CLZ32( bitstream <: number );
    always {
        NX = ( ~|CLZ32.zeros[3,3] ); // CLZ32.zeros < 8, top 3 bits clear
        sign = ~dounsigned & a[31,1];
        number = sign ? -a : a;
        fraction= NX ? number >> ( 8 - CLZ32.zeros ) : ( CLZ32.zeros == 8 ) ? number : number << ( CLZ32.zeros - 8 );
        exponent = 158 - CLZ32.zeros;
    }
}
algorithm inttofloat(
    input   uint32  a,
    input   uint1   dounsigned,
    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    uint1   OF = uninitialised; uint1 UF = uninitialised;
    prepitof PREP( a <: a, dounsigned <: dounsigned );
    docombinecomponents32 COMBINE( sign <: PREP.sign, exp <: PREP.exponent, fraction <: PREP.fraction );

    flags := { 4b0, OF, UF, PREP.NX }; OF := 0; UF := 0;

    always {
        if( |PREP.number ) {
            OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f32;
        } else {
            result = 0;
        }
    }
}

// BREAK DOWN FLOAT READY FOR CONVERSION TO INTEGER
algorithm prepftoi(
    input   uint32  a,
    output  int10   exp,
    output  uint32  unsignedfraction
) <autorun,reginputs> {
    uint33  sig <:: ( exp < 24 ) ? { 9b1, fp32( a ).fraction, 1b0 } >> ( 23 - exp ) : { 9b1, fp32( a ).fraction, 1b0 } << ( exp - 24);
    always {
        exp = fp32( a ).exponent - 127;
        unsignedfraction = ( sig[1,32] + sig[0,1] );
    }
}

// CONVERT FLOAT TO SIGNED INTEGERS
algorithm floattoint(
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUT
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: ( PREP.exp > 30 ) | A.INF | NN;
    classify A( a <: a );

    // PREPARE THE CONVERSION
    prepftoi PREP( a <: a );

    flags := { A.INF, NN, NV, 4b0000 };
    always {
        if (A.ZERO ) {
            result = 0;
        } else {
            if( A.INF | NN ) {
                result = { ~NN & fp32( a ).sign, 31h7fffffff };
            } else {
                result = { fp32( a ).sign, NV ? 31h7fffffff : fp32( a ).sign ? -PREP.unsignedfraction : PREP.unsignedfraction };
            }
        }
    }
}

// CONVERT FLOAT TO UNSIGNED INTEGERS
algorithm floattouint(
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUT
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: ( PREP.exp > 31 ) | fp32( a ).sign | A.INF | NN;
    classify A( a <: a );

    // PREPARE THE CONVERSION
    prepftoi PREP( a <: a );

    flags := { A.INF, NN, NV, 4b0000 };
    always {
        if( A.ZERO ) {
            result = 0;
        } else {
            if( A.INF | NN ) {
                result = NN ? 32hffffffff : { {32{~fp32( a ).sign}} };
            } else {
                result = ( fp32( a ).sign ) ? 0 : NV ? 32hffffffff : PREP.unsignedfraction;
            }
        }
    }
}

// ADDSUB ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm equaliseexpaddsub(
    input   int10   expA,
    input   uint48  sigA,
    input   int10   expB,
    input   uint48  sigB,
    output  uint48  newsigA,
    output  uint48  newsigB,
    output  int10   resultexp,
) <autorun,reginputs> {
    always {
        if( expA < expB ) {
            newsigA = sigA >> ( expB - expA ); resultexp = expB - 126; newsigB = sigB;
        } else {
            newsigB = sigB >> ( expA - expB ); resultexp = expA - 126; newsigA = sigA;
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
) <autorun,reginputs> {
    uint48  sigAminussigB <:: sigA - sigB;
    uint48  sigBminussigA <:: sigB - sigA;
    uint48  sigAplussigB <:: sigA + sigB;
    uint1   AvB <:: ( sigA > sigB );

    always {
        // PERFORM ADDITION HANDLING SIGNS
        switch( { signA, signB } ) {
            case 2b01: { resultsign = ( ~AvB ); resultfraction = resultsign ? sigBminussigA : sigAminussigB; }
            case 2b10: { resultsign = ( AvB ); resultfraction = resultsign ? sigAminussigB : sigBminussigA; }
            default: { resultsign = signA; resultfraction = sigAplussigB; }
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
) <autorun,reginputs> {
    // BREAK DOWN INITIAL float32 INPUTS - SWITCH SIGN OF B IF SUBTRACTION
    uint48  sigA <:: { 2b01, fp32(a).fraction, 23b0 };
    uint1   signB <:: addsub ^ fp32( b ).sign;
    uint48  sigB <:: { 2b01, fp32(b).fraction, 23b0 };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF - INF )
    uint1   IF <:: ( A.INF | B.INF );
    uint1   NN <:: ( A.sNAN | A.qNAN | B.sNAN | B.qNAN );
    uint1   NV <:: ( A.INF & B.INF) & ( fp32( a ).sign ^ signB );
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );
    classify B( a <: b );

    // EQUALISE THE EXPONENTS
    equaliseexpaddsub EQUALISEEXP( expA <: fp32( a ).exponent, sigA <: sigA,  expB <: fp32( b ).exponent, sigB <: sigB );

    // PERFORM THE ADDITION/SUBTRACION USING THE EQUALISED FRACTIONS, 1 IS ADDED TO THE EXPONENT IN CASE OF OVERFLOW - NORMALISING WILL ADJUST WHEN SHIFTING
    dofloataddsub ADDSUB( signA <: fp32( a ).sign, sigA <: EQUALISEEXP.newsigA, signB <: signB, sigB <: EQUALISEEXP.newsigB );

    // NORMALISE THE RESULTING FRACTION AND ADJUST THE EXPONENT IF SMALLER ( ie, MSB is not 1 )
    donormalise24_adjustexp NORMALISE( exp <: EQUALISEEXP.resultexp, bitstream <: ADDSUB.resultfraction );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    doround24 ROUND( exponent <: NORMALISE.newexp, bitstream <: NORMALISE.normalised );

    // COMBINE TO FINAL float32
    docombinecomponents32 COMBINE( sign <: ADDSUB.resultsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 1 CYCLES FOR CLASSIFICATION AND EQUALISING EXPONENTS
            switch( { IF | NN, A.ZERO | B.ZERO } ) {
                case 2b00: {
                    ++: // ALLOW 1 CYCLE TO PERFORM THE ADDITION/SUBTRACTION
                    if( |ADDSUB.resultfraction ) {
                        ++: ++: ++: // ALLOW FOR NORMALISATION AND COMBINING OF FINAL RESULT
                        OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f32;
                    } else {
                        result = 0;
                    }
                }
                case 2b01: { result = ( A.ZERO & B.ZERO ) ? 0 : ( B.ZERO ) ? a : { signB, b[0,31] }; }
                default: {
                    switch( { IF, NN } ) {
                        case 2b10: { result = NV ? 32hffc00000 : A.INF ? a : b; }
                        default: { result = 32hffc00000; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
algorithm prepmul(
    input   uint32  a,
    input   uint32  b,
    output  uint1   productsign,
    output  int10   productexp,
    output  uint24  normalfraction
) <autorun,reginputs> {
    uint24  sigA <:: { 1b1, fp32( a ).fraction };
    uint24  sigB <:: { 1b1, fp32( b ).fraction };
    uint48  product <:: sigA * sigB;
    always {
        productsign = fp32( a ).sign ^ fp32( b ).sign;
        productexp = fp32( a ).exponent + fp32( b ).exponent - ( product[47,1] ? 253 : 254 );
        normalfraction = product[ product[47,1] ? 23 : 22, 24 ];
    }
}
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint32  b,

    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF PRODUCT ( + 1 IF PRODUCT OVERFLOWS, MSB == 1 )
    // NORMALISE THE RESULTING PRODUCT AND EXTRACT THE 24 BITS AFTER THE LEADING 1.xxxx
    prepmul PREP( a <: a, b <: b );

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF x ZERO )
    uint1   ZERO <:: ( A.ZERO | B.ZERO );
    uint1   IF <:: ( A.INF | B.INF );
    uint1   NN <:: ( A.sNAN | A.qNAN | B.sNAN | B.qNAN );
    uint1   NV <:: IF & ZERO;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );
    classify B( a <: b  );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    doround24 ROUND( exponent <: PREP.productexp, bitstream <: PREP.normalfraction );

    // COMBINE TO FINAL float32
    docombinecomponents32 COMBINE( sign <: PREP.productsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 1 CYCLE TO PERFORM CALSSIFICATIONS
            switch( { IF | NN, ZERO } ) {
                case 2b00: {
                    // STEPS: SETUP -> DOMUL -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                    ++: // ALLOW 2 CYCLES TO PERFORM THE MULTIPLICATION, NORMALISATION AND ROUNDING
                    ++:
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f32;
                }
                case 2b01: { result = { PREP.productsign, 31b0 }; }
                default: {
                    switch( { IF, ZERO } ) {
                        case 2b11: { result = 32hffc00000; }
                        case 2b10: { result = NN ? 32hffc00000 : { PREP.productsign, 31h7f800000 }; }
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
) <autorun,reginputs> {
    uint50  remainder = uninitialised;
    uint50  temporary <:: { remainder[0,49], sigA[bit,1] };
    uint1   bitresult <:: __unsigned(temporary) >= __unsigned(sigB);
    uint2   normalshift <:: quotient[49,1] ? 2 : quotient[48,1];
    uint6   bit(63);
    uint6   bitNEXT <:: bit - 1;

    busy := start | ( ~&bit ) | ( quotient[48,2] != 0 );

    always {
        // FIND QUOTIENT AND ENSURE 48 BIT FRACTION ( ie BITS 48 and 49 clear )
        if( ~&bit ) {
            remainder = __unsigned(temporary) - ( bitresult ? __unsigned(sigB) : 0 );
            quotient[bit,1] = bitresult;
            bit = bitNEXT;
        } else {
            quotient = quotient >> normalshift;
        }
    }

    if( ~reset ) { bit = 63; quotient = 0; }

    while(1) {
        if( start ) {
            bit = 49; quotient = 0; remainder = 0;
        }
    }
}
algorithm prepdivide(
    input   uint32  a,
    input   uint32  b,
    output  uint1   quotientsign,
    output  int10   quotientexp,
    output  uint50  sigA,
    output  uint50  sigB
) <autorun,reginputs> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF QUOTIENT ( -1 IF DIVISOR > DIVIDEND )
    // ALIGN DIVIDEND TO THE LEFT, DIVISOR TO THE RIGHT
    uint1   AvB <:: ( fp32(b).fraction > fp32(a).fraction );
    always {
        quotientsign = fp32( a ).sign ^ fp32( b ).sign;
        quotientexp = fp32( a ).exponent - fp32( b ).exponent - AvB;
        sigA = { 1b1, fp32(a).fraction, 26b0 };
        sigB = { 27b1, fp32(b).fraction };
    }
}

algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    input   uint32  b,
    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND DIVIDE ZERO
    uint1   IF <:: ( A.INF | B.INF );
    uint1   NN <:: ( A.sNAN | A.qNAN | B.sNAN | B.qNAN );
    uint1   NV = uninitialised;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );
    classify B( a <: b );

    // PREPARE THE DIVISION, DO THE DIVISION, NORMALISE THE RESULT
    prepdivide PREP( a <: a, b <: b );
    dofloatdivide DODIVIDE( sigA <: PREP.sigA, sigB <: PREP.sigB );
    donormalise24 NORMALISE( bitstream <: DODIVIDE.quotient );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    doround24 ROUND( exponent <: PREP.quotientexp, bitstream <: NORMALISE.normalised );

    // COMBINE TO FINAL float32
    docombinecomponents32 COMBINE( sign <: PREP.quotientsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    DODIVIDE.start := 0; flags := { IF, NN, 1b0, B.ZERO, OF, UF, 1b0};
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, A.ZERO | B.ZERO } ) {
                case 2b00: {
                    DODIVIDE.start = 1; while( DODIVIDE.busy ) {}
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f32;
                }
                case 2b01: { result = ( A.ZERO & B.ZERO ) ? 32hffc00000 : { PREP.quotientsign, B.ZERO ? 31h7f800000 : 31h0 }; }
                default: { result = ( A.INF & B.INF ) | NN | B.ZERO ? 32hffc00000 : { PREP.quotientsign, ( A.ZERO | B.INF ) ? 31b0 : 31h7f800000 }; }
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
    output  uint48  squareroot
) <autorun,reginputs> {
    uint50  test_res <:: ac - { squareroot, 2b01 };
    uint50  ac = uninitialised;
    uint48  x = uninitialised;
    uint6   i(47);
    uint6   iNEXT <:: i + 1;

    busy := start | ( i != 47 );

    always {
        if( i != 47 ) {
            ac = { test_res[49,1] ? ac[0,47] : test_res[0,47], x[46,2] };
            squareroot = { squareroot[0,47], ~test_res[49,1] };
            x = { x[0,46], 2b00 };
            i = iNEXT;
        }
    }

    if( ~reset ) { i = 47; }

    while(1) {
        if( start ) {
            i = 0; squareroot = 0; ac = start_ac; x = start_x;
        }
    }
}
algorithm prepsqrt(
    input   uint32  a,
    output  uint50  start_ac,
    output  uint48  start_x,
    output  int10   squarerootexp
) <autorun,reginputs> {
    // EXPONENT OF INPUT ( used to determine if 1x.xxxxx or 01.xxxxx for fixed point fraction to sqrt )
    // SQUARE ROOT EXPONENT IS HALF OF INPUT EXPONENT
    int10   exp  <:: fp32( a ).exponent - 127;
    always {
        start_ac = exp[0,1] ? { 48b0, 1b1, a[22,1] } : 1;
        start_x = exp[0,1] ? { a[0,22], 26b0 } : { fp32( a ).fraction, 25b0 };
        squarerootexp = ( exp >>> 1 );
    }
}

algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint32  a,
    output  uint7   flags,
    output  uint32  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND NOT VALID
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: A.INF | NN | fp32( a ).sign;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );

    // PREPARE AND PERFORM THE SQUAREROOT
    prepsqrt PREP( a <: a );
    dofloatsqrt DOSQRT( start_ac <: PREP.start_ac, start_x <: PREP.start_x );

    // FAST NORMALISATION - SQUARE ROOT RESULTS IN 1x.xxx or 01.xxxx
    // EXTRACT 24 BITS FOR ROUNDING FOLLOWING THE NORMALISED 1.xxxx
    uint24  normalfraction <:: DOSQRT.squareroot[ DOSQRT.squareroot[47,1] ? 23 : 22,24 ];
    doround24 ROUND( exponent <: PREP.squarerootexp, bitstream <: normalfraction );

    // COMBINE TO FINAL float32
    docombinecomponents32 COMBINE( sign <: fp32( a ).sign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    DOSQRT.start := 0; flags := { A.INF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { A.INF | NN, A.ZERO | fp32( a ).sign } ) {
                case 2b00: {
                    // STEPS: SETUP -> DOSQRT -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                    DOSQRT.start = 1; while( DOSQRT.busy ) {}
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f32;
                }
                // DETECT sNAN, qNAN, -INF, -x -> qNAN AND  INF -> INF, 0 -> 0
                default: { result = fp32( a ).sign ? 32hffc00000 : a; }
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
    output  uint7   flags,
    output  uint1   less,
    output  uint1   equal
) <autorun,reginputs> {
    // CLASSIFY THE INPUTS AND DETECT INFINITY OR NAN
    classify A( a <: a );
    classify B( a <: b );
    uint1   INF <:: A.INF | B.INF;
    uint1   NAN <:: A.sNAN | B.sNAN | A.qNAN | B.qNAN;

    uint1   aequalb <:: ( a == b );
    uint1   aorbleft1equal0 <:: ~|( ( a | b ) << 1 );
    uint1   avb <:: ( a < b );

    // IDENTIFY NaN, RETURN 0 IF NAN, OTHERWISE RESULT OF COMPARISONS
    flags := { INF, {2{NAN}}, 4b0000 };
    less := NAN ? 0 : ( ( fp32( a ).sign ^ fp32( b ).sign ) ? fp32( a ).sign & ~aorbleft1equal0 : ~aequalb & ( fp32( a ).sign ^ avb ) );
    equal := NAN ? 0 : ( aequalb | aorbleft1equal0 );
}
