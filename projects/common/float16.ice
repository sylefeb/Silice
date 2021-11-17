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

// BITFIELD FOR FLOATING POINT NUMBER - IEEE-754 16 bit format
bitfield fp16{
    uint1   sign,
    uint5   exponent,
    uint10  fraction
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
    input   uint16  a,
    output  uint1   INF,
    output  uint1   sNAN,
    output  uint1   qNAN,
    output  uint1   ZERO
) <autorun,reginputs> {
    uint1   expFF <:: ( &fp16(a).exponent );
    uint1   NAN <:: expFF & a[9,1];
    always {
        INF = expFF & ~a[9,1];
        sNAN = NAN & a[8,1];
        qNAN = NAN & ~a[8,1];
        ZERO = ~|( fp16(a).exponent );
    }
}

// NORMALISE A 22 BIT MANTISSA SO THAT THE MSB IS ONE
// FOR ADDSUB ALSO DECREMENT THE EXPONENT FOR EACH SHIFT LEFT
algorithm clz22(
    input   uint22  bitstream,
    output! uint5   count
) <autorun,reginputs> {
    uint2   bitstream2 <:: bitstream[20,2];
    uint4   bitstream4 <:: bitstream[16,4];
    uint16  bitstream16 <:: bitstream[0,16];

    uint5   clz = uninitialised;
    always {
        switch( { |bitstream2, |bitstream4 } ) {
            case 2b00: {
                 ( clz ) = clz_silice_16( bitstream16 );
                 count = 6 + clz;
            }
            case 2b01: {
                 ( clz ) = clz_silice_4( bitstream4 );
                 count = 2 + clz;
            }
            default: {
                ( count ) = clz_silice_2( bitstream2 );
            }
        }
    }
}
algorithm donormalise22_adjustexp(
    input   int7    exp,
    input   uint22  bitstream,
    output  int7    newexp,
    output  uint11  normalised
) <autorun,reginputs> {
    clz22 CLZ22( bitstream <: bitstream );
    uint22  temporary <:: bitstream << CLZ22.count;
    always {
        normalised = temporary[10,11];
        newexp = exp - CLZ22.count;
    }
}
algorithm donormalise22(
    input   uint22  bitstream,
    output  uint11  normalised
) <autorun,reginputs> {
    clz22 CLZ22( bitstream <: bitstream );
    uint22  temporary <:: bitstream << CLZ22.count;
    always {
        normalised = temporary[10,11];
    }
}

// EXTRACT 10 BIT FRACTION FROM LEFT ALIGNED 22 BIT FRACTION WITH ROUNDING
// ADD BIAS TO EXPONENT AND ADJUST EXPONENT IF ROUNDING FORCES
algorithm doround11(
    input   uint11  bitstream,
    input   int7    exponent,
    output  uint10  roundfraction,
    output  int7    newexponent
) <autorun,reginputs> {
    always {
        roundfraction = bitstream[1,10] + bitstream[0,1];
        newexponent = ( ( ~|roundfraction & bitstream[0,1] ) ? 16 : 15 ) + exponent;
    }
}
// COMBINE COMPONENTS INTO FLOATING POINT NUMBER
// UNDERFLOW return 0, OVERFLOW return infinity
algorithm docombinecomponents16(
    input   uint1   sign,
    input   int7    exp,
    input   uint10  fraction,
    output  uint1   OF,
    output  uint1   UF,
    output  uint16  f16
) <autorun,reginputs> {
    always {
        OF = ( exp > 30 ); UF = exp[6,1];
        f16 = UF ? 0 : OF ? { sign, 15h7c00 } : { sign, exp[0,5], fraction[0,10] };
    }
}

// CONVERT SIGNED/UNSIGNED INTEGERS TO FLOAT
// dounsigned == 0 for signed conversion (15 bit plus sign), == 1 for dounsigned conversion (16 bit)
algorithm clz16(
    input   uint16  bitstream,
    output! uint5   zeros
) <autorun,reginputs> {
    always {
        ( zeros ) = clz_silice_16( bitstream );
    }
}
algorithm prepitof(
    input   uint16  a,
    input   uint1   dounsigned,
    output  uint1   sign,
    output  uint16  number,
    output  uint10  fraction,
    output  int7    exponent,
    output  uint1   NX
) <autorun> {
    // COUNT LEADING ZEROS
    clz16 CLZ16( bitstream <: number );

    always {
        NX =( CLZ16.zeros < 5 );
        sign = ~dounsigned & fp16( a ).sign;
        number = sign ? -a : a;
        fraction= NX ? number >> ( 5 - CLZ16.zeros ) : ( CLZ16.zeros == 5 ) ? number : number << ( CLZ16.zeros - 5 );
        exponent = 30 - CLZ16.zeros;
    }
}
algorithm inttofloat(
    input   uint16  a,
    input   uint1   dounsigned,
    output  uint7   flags,
    output  uint16  result
) <autorun,reginputs> {
    uint1   OF = uninitialised; uint1 UF = uninitialised;
    prepitof PREP( a <: a, dounsigned <: dounsigned );
    docombinecomponents16 COMBINE( sign <: PREP.sign, exp <: PREP.exponent, fraction <: PREP.fraction );

    flags := { 4b0, OF, UF, PREP.NX }; OF := 0; UF := 0;
    always {
        if( |PREP.number ) {
            OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f16;
        } else {
            result = 0;
        }
    }
}

// BREAK DOWN FLOAT READY FOR CONVERSION TO INTEGER
algorithm prepftoi(
    input   uint16  a,
    output  int7    exp,
    output  uint16  unsignedfraction
) <autorun,reginputs> {
    uint17  sig <:: ( exp < 11 ) ? { 5b1, fp16( a ).fraction, 1b0 } >> ( 10 - exp ) : { 5b1, fp16( a ).fraction, 1b0 } << ( exp - 11);
    exp := fp16( a ).exponent - 15;
    unsignedfraction := ( sig[1,16] + sig[0,1] );
}

// CONVERT FLOAT TO SIGNED INTEGERS
algorithm floattoint(
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUT
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: ( PREP.exp > 14 ) | A.INF | NN;
    classify A( a <: a );

    // PREPARE THE CONVERSION
    prepftoi PREP( a <: a );

    flags := { A.INF, NN, NV, 4b0000 };

    always {
        if( A.ZERO ) {
            result = 0;
        } else {
           if( A.INF | NN ) {
               result = { ~NN & fp16( a ).sign, 15h7fff };
           } else {
               result = NV ? { fp16( a ).sign, 15h7fff } : fp16( a ).sign ? -PREP.unsignedfraction : PREP.unsignedfraction;
           }
        }
    }
}

// CONVERT FLOAT TO UNSIGNED INTEGERS
algorithm floattouint(
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUT
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: ( fp16( a ).sign ) | ( PREP.exp > 15 ) | A.INF | NN;
    classify A( a <: a );

    // PREPARE THE CONVERSION
    prepftoi PREP( a <: a );

    flags := { A.INF, NN, NV, 4b0000 };
    always {
        if( A.ZERO ) {
            result = 0;
        } else {
            if( A.INF | NN ) {
                result = NN ? 16hffff : { {16{~fp16( a ).sign}} };
            } else {
                result = ( fp16( a ).sign ) ? 0 : NV ? 16hffff : PREP.unsignedfraction;
            }
        }
    }
}

// ADDSUB ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm equaliseexpaddsub(
    input   int7    expA,
    input   uint22  sigA,
    input   int7    expB,
    input   uint22  sigB,
    output  uint22  newsigA,
    output  uint22  newsigB,
    output  int7    resultexp
) <autorun,reginputs> {
    always {
        // EQUALISE THE EXPONENTS BY SHIFT SMALLER NUMBER FRACTION PART TO THE RIGHT - REMOVE BIAS ( AND +1 TO ACCOUNT FOR POTENTIAL OVERFLOW )
        if( expA < expB ) {
            newsigA = sigA >> ( expB - expA ); resultexp = expB - 14; newsigB = sigB;
        } else {
            newsigB = sigB >> ( expA - expB ); resultexp = expA - 14; newsigA = sigA;
        }
    }
}
algorithm dofloataddsub(
    input   uint1   signA,
    input   uint22  sigA,
    input   uint1   signB,
    input   uint22  sigB,
    output  uint1   resultsign,
    output  uint22  resultfraction
) <autorun,reginputs> {
    uint22  sigAminussigB <:: sigA - sigB;
    uint22  sigBminussigA <:: sigB - sigA;
    uint22  sigAplussigB <:: sigA + sigB;
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
    input   uint16  a,
    input   uint16  b,
    input   uint1   addsub,
    output  uint7   flags,
    output  uint16  result
) <autorun,reginputs> {
    // BREAK DOWN INITIAL float32 INPUTS - SWITCH SIGN OF B IF SUBTRACTION
    uint22  sigA <:: { 2b01, fp16(a).fraction, 10b0 };
    uint1   signB <:: addsub ^  fp16( b ).sign;
    uint22  sigB <:: { 2b01, fp16(b).fraction, 10b0 };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF - INF )
    uint1   IF <:: ( A.INF | B.INF );
    uint1   NN <:: ( A.sNAN | A.qNAN | B.sNAN | B.qNAN );
    uint1   NV <:: ( A.INF & B.INF) & ( fp16( a ).sign ^ signB );
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );
    classify B( a <: b );

    // EQUALISE THE EXPONENTS
    equaliseexpaddsub EQUALISEEXP( expA <: fp16( a ).exponent, sigA <: sigA,  expB <: fp16( b ).exponent, sigB <: sigB );

    // PERFORM THE ADDITION/SUBTRACION USING THE EQUALISED FRACTIONS, 1 IS ADDED TO THE EXPONENT IN CASE OF OVERFLOW - NORMALISING WILL ADJUST WHEN SHIFTING
    dofloataddsub ADDSUB( signA <: fp16( a ).sign, sigA <: EQUALISEEXP.newsigA, signB <: signB, sigB <: EQUALISEEXP.newsigB );

    // NORMALISE THE RESULTING FRACTION AND ADJUST THE EXPONENT IF SMALLER ( ie, MSB is not 1 )
    donormalise22_adjustexp NORMALISE( exp <: EQUALISEEXP.resultexp, bitstream <: ADDSUB.resultfraction );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    doround11 ROUND( exponent <: NORMALISE.newexp, bitstream <: NORMALISE.normalised );

    // COMBINE TO FINAL float16
    docombinecomponents16 COMBINE( sign <: ADDSUB.resultsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 2 CYCLES FOR EQUALISING EXPONENTS AND TO PERFORM THE ADDITION/SUBTRACTION
            switch( { IF | NN, A.ZERO | B.ZERO } ) {
                case 2b00: {
                    ++:
                    if ( |ADDSUB.resultfraction ) {
                        ++: ++: ++:
                        OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f16;
                    } else {
                        result = 0;
                    }
                }
                case 2b01: { result = ( A.ZERO & B.ZERO ) ? 0 : ( B.ZERO ) ? a : { signB, b[0,15] }; }
                default: {
                    switch( { IF, NN } ) {
                        case 2b10: { result = NV ? 16hfe00 : A.INF ? a : b; }
                        default: { result = 16hfe00; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
algorithm prepmul(
    input   uint16  a,
    input   uint16  b,
    output  uint1   productsign,
    output  int7    productexp,
    output  uint11  normalfraction
) <autorun,reginputs> {
    uint11  sigA <:: { 1b1, fp16( a ).fraction };
    uint11  sigB <:: { 1b1, fp16( b ).fraction };
    uint22  product <:: sigA * sigB;
    always {
        productsign = fp16( a ).sign ^ fp16( b ).sign;
        productexp = fp16( a ).exponent + fp16( b ).exponent - ( product[21,1] ? 29 : 30 );
        normalfraction = product[ product[21,1] ? 10 : 9, 11 ];
    }
}
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    input   uint16  b,

    output  uint7   flags,
    output  uint16  result
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
    doround11 ROUND( exponent <: PREP.productexp, bitstream <: PREP.normalfraction );

    // COMBINE TO FINAL float16
    docombinecomponents16 COMBINE( sign <: PREP.productsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

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
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f16;
                }
                case 2b01: { result = { PREP.productsign, 15b0 }; }
                default: {
                    switch( { IF, ZERO } ) {
                        case 2b11: { result = 16hfe00; }
                        case 2b10: { result = NN ? 16hfe00 : { PREP.productsign, 5b11111, 10b0 }; }
                        default: { result = 16hfe00; }
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
    input   uint24  sigA,
    input   uint24  sigB,
    output  uint24  quotient
) <autorun,reginputs> {
    uint24  remainder = uninitialised;
    uint24  temporary <:: { remainder[0,23], sigA[bit,1] };
    uint1   bitresult <:: __unsigned(temporary) >= __unsigned(sigB);
    uint2   normalshift <:: quotient[23,1] ? 2 : quotient[22,1];
    uint5   bit(31);
    uint5   bitNEXT <:: bit - 1;

    busy := start | ( ~&bit ) | ( quotient[22,2] != 0 );
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

    if( ~reset ) { bit = 31; quotient = 0; }

    while(1) {
        if( start ) {
            bit = 23; quotient = 0; remainder = 0;
        }
    }
}
algorithm prepdivide(
    input   uint16  a,
    input   uint16  b,
    output  uint1   quotientsign,
    output  int7    quotientexp,
    output  uint24  sigA,
    output  uint24  sigB
) <autorun,reginputs> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF QUOTIENT ( -1 IF DIVISOR > DIVIDEND )
    // ALIGN DIVIDEND TO THE LEFT, DIVISOR TO THE RIGHT
    uint1   AvB <:: ( fp16(b).fraction > fp16(a).fraction );
    always {
        quotientsign = fp16( a ).sign ^ fp16( b ).sign;
        quotientexp = fp16( a ).exponent - fp16( b ).exponent - AvB;
        sigA = { 1b1, fp16(a).fraction, 13b0 };
        sigB = { 14b1, fp16(b).fraction };
    }
}
algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    input   uint16  b,

    output  uint7   flags,
    output  uint16  result
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
    donormalise22 NORMALISE( bitstream <: DODIVIDE.quotient );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    doround11 ROUND( exponent <: PREP.quotientexp, bitstream <: NORMALISE.normalised );

    // COMBINE TO FINAL float16
    docombinecomponents16 COMBINE( sign <: PREP.quotientsign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    DODIVIDE.start := 0; flags := { IF, NN, 1b0, B.ZERO, OF, UF, 1b0};
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, A.ZERO | B.ZERO } ) {
                case 2b00: {
                    DODIVIDE.start = 1; while( DODIVIDE.busy ) {}
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f16;
                }
                case 2b01: { result = ( A.ZERO & B.ZERO ) ? 16hfe00 : { PREP.quotientsign, B.ZERO ? 15h7c00 : 15h0 }; }
                default: { result = ( A.INF & B.INF ) | NN | B.ZERO ? 16hfe00 : { PREP.quotientsign, ( A.ZERO | B.INF ) ? 15b0 : 15h7c00 }; }
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
    input   uint24  start_ac,
    input   uint22  start_x,
    output  uint22  squareroot
) <autorun,reginputs> {
    uint24  test_res <:: ac - { squareroot, 2b01 };
    uint24  ac = uninitialised;
    uint22  x = uninitialised;
    uint5   i(21);
    uint5   iNEXT <:: i + 1;

    busy := start | ( i != 21 );

    always {
        if( i != 21 ) {
            ac = { test_res[23,1] ? ac[0,21] : test_res[0,21], x[20,2] };
            squareroot = { squareroot[0,21], ~test_res[23,1] };
            x = { x[0,20], 2b00 };
            i = iNEXT;
        }
    }

    if( ~reset ) { i = 21; }

    while(1) {
        if( start ) {
            i = 0; squareroot = 0; ac = start_ac; x = start_x;
        }
    }
}
algorithm prepsqrt(
    input   uint16  a,
    output  uint24  start_ac,
    output  uint22  start_x,
    output  int7    squarerootexp
) <autorun,reginputs> {
    // EXPONENT OF INPUT ( used to determine if 1x.xxxxx or 01.xxxxx for fixed point fraction to sqrt )
    // SQUARE ROOT EXPONENT IS HALF OF INPUT EXPONENT
    int7    exp  <:: fp16( a ).exponent - 15;
    always {
        start_ac = ~exp[0,1] ? 1 : { 22b0, 1b1, a[9,1] };
        start_x = ~exp[0,1] ? { a[0,10], 12b0 } : { a[0,9], 13b0 };
        squarerootexp = ( exp >>> 1 );
    }
}

algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun,reginputs> {
    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND NOT VALID
    uint1   NN <:: A.sNAN | A.qNAN;
    uint1   NV <:: A.INF | NN | fp16( a ).sign;
    uint1   OF = uninitialised;
    uint1   UF = uninitialised;
    classify A( a <: a );

    // PREPARE AND PERFORM THE SQUAREROOT
    prepsqrt PREP( a <: a );
    dofloatsqrt DOSQRT( start_ac <: PREP.start_ac, start_x <: PREP.start_x );

    // FAST NORMALISATION - SQUARE ROOT RESULTS IN 1x.xxx or 01.xxxx
    // EXTRACT 11 BITS FOR ROUNDING FOLLOWING THE NORMALISED 1.xxxx
    uint11  normalfraction <:: DOSQRT.squareroot[ DOSQRT.squareroot[21,1] ? 10 : 9,11 ];
    doround11 ROUND( exponent <: PREP.squarerootexp, bitstream <: normalfraction );

    // COMBINE TO FINAL float16
    docombinecomponents16 COMBINE( sign <: fp16( a ).sign, exp <: ROUND.newexponent, fraction <: ROUND.roundfraction );

    DOSQRT.start := 0; flags := { A.INF, NN, NV, 1b0, OF, UF, 1b0 };
    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { A.INF | NN, A.ZERO | fp16( a ).sign } ) {
                case 2b00: {
                    // STEPS: SETUP -> DOSQRT -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                    DOSQRT.start = 1; while( DOSQRT.busy ) {}
                    OF = COMBINE.OF; UF = COMBINE.UF; result = COMBINE.f16;
                }
                // DETECT sNAN, qNAN, -INF, -x -> qNAN AND  INF -> INF, 0 -> 0
                default: { result = fp16( a ).sign ? 16hfe00 : a; }
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
    input   uint16  a,
    input   uint16  b,
    output  uint1   less,
    output  uint7   flags,
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
    less := NAN ? 0 : ( ( fp16( a ).sign ^ fp16( b ).sign ) ? fp16( a ).sign & ~aorbleft1equal0 : ~aequalb & ( fp16( a ).sign ^ avb ) );
    equal := NAN ? 0 : ( aequalb | aorbleft1equal0 );
}
