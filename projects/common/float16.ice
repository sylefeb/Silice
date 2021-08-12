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
) <autorun> {
    uint1   expFF <: ( floatingpointnumber(a).exponent == 5b11111 );
    INF := expFF & ~a[9,1];
    sNAN := expFF & a[9,1] & a[8,1];
    qNAN := expFF & a[9,1] & ~a[8,1];
    ZERO := ( floatingpointnumber(a).exponent == 0 );
}

// ALGORITHMS TO DEAL WITH 22 BIT FRACTIONS TO 10 BIT FRACTIONS
// NORMALISE A 22 BIT MANTISSA SO THAT THE MSB IS ONE
// FOR ADDSUB ALSO DECREMENT THE EXPONENT FOR EACH SHIFT LEFT
algorithm donormalise22(
    input   uint1   start,
    output  uint1   busy(0),
    input   int7    exp,
    input   uint22  bitstream,
    output  int7    newexp,
    output  uint22  normalised
) <autorun> {
    uint4   shiftcount <:: { normalised[7,15] == 0, normalised[15,7] == 0, normalised[19,3] == 0, 1b1 };
    while(1) {
        if( start ) {
            busy = 1;
            normalised = bitstream; newexp = exp;
            // NORMALISE BY SHIFT 1, 3, 7 OR 15 ZEROS LEFT
            while( ~normalised[21,1] ) { normalised = normalised << shiftcount; newexp = newexp - shiftcount; }
            busy = 0;
        }
    }
}

// EXTRACT 10 BIT FRACTION FROM LEFT ALIGNED 22 BIT FRACTION WITH ROUNDING
// ADD BIAS TO EXPONENT AND ADJUST EXPONENT IF ROUNDING FORCES
algorithm doround22(
    input   uint22  bitstream,
    input   int7    exponent,
    output  uint10  roundfraction,
    output  int7    newexponent
) <autorun> {
    always {
        roundfraction = bitstream[11,10] + bitstream[10,1];
        newexponent = 15 + exponent + ( ( roundfraction == 0 ) & bitstream[10,1] );
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
) <autorun> {
    OF := ( exp > 30 ); UF := exp[6,1];
    f16 := UF ? 0 : OF ? { sign, 5b11111, 10h0 } : { sign, exp[0,5], fraction[0,10] };
}

// CONVERT SIGNED/UNSIGNED INTEGERS TO FLOAT
// dounsigned == 1 for signed conversion (15 bit plus sign), == 0 for dounsigned conversion (16 bit)
algorithm inttofloat(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    input   uint1   dounsigned,
    output  uint7   flags,
    output  uint16  result
) <autorun> {
    uint1   OF = uninitialised; uint1 UF = uninitialised; uint1 NX = uninitialised;
    uint1   sign <: dounsigned ? 0 : floatingpointnumber( a ).sign;
    uint5   zeros = uninitialised;
    uint16  number <: dounsigned ? a : ( floatingpointnumber( a ).sign ? -a : a );
    uint10  fraction <: NX ? number >> ( 5 - zeros ) : ( zeros > 5 ) ? number << ( zeros - 5 ) : number;
    int7    exponent <: 30 - zeros;

    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint16  f16 = uninitialised;
    docombinecomponents16 COMBINE(
        sign <: sign,
        exp <: exponent,
        fraction <: fraction,
        OF :> cOF,
        UF :> cUF,
        f16 :> f16
    );
    flags := { 4b0, OF, UF, NX };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0; NX = 0;
            switch( number ) {
                case 0: { result = 0; }
                default: {
                    // CHECK FOR 8 LEADING ZEROS, CONTINUE COUNTING FROM THERE
                    zeros = number[8,8] == 0 ? 8 : 0;
                    while( ~number[15-zeros,1] ) { zeros = zeros + 1; } NX = ( zeros < 5 );
                    ++:
                    OF = cOF; UF = cUF; result = f16;
                }
            }
            busy = 0;
        }
    }
}

// CONVERT FLOAT TO SIGNED INTEGERS
algorithm floattoint(
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun> {
    int7    exp <: floatingpointnumber( a ).exponent - 15;
    uint17  sig = uninitialised;
    uint1   IF <: aINF;
    uint1   NN <: asNAN | aqNAN;
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
        NV = 0;
        switch( { IF | NN, aZERO } ) {
            case 2b00: {
                sig = ( exp < 11 ) ? { 5b1, floatingpointnumber( a ).fraction, 1b0 } >> ( 10 - exp ) : { 5b1, floatingpointnumber( a ).fraction, 1b0 } << ( exp - 11);
                result = ( exp > 14 ) ? ( floatingpointnumber( a ).sign ? 16hffff : 16h7fff ) : floatingpointnumber( a ).sign ? -( sig[1,16] + sig[0,1] ) : ( sig[1,16] + sig[0,1] );
                NV = ( exp > 14 );
            }
            case 2b01: { result = 0; }
            default: { NV = 1; result = NN ? 16h7fff : floatingpointnumber( a ).sign ? 16hffff : 16h7fff; }
        }
    }
}

// CONVERT FLOAT TO UNSIGNED INTEGERS
algorithm floattouint(
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun> {
    int7    exp <: floatingpointnumber( a ).exponent - 15;
    uint17  sig = uninitialised;
    uint1   IF <: aINF;
    uint1   NN <: asNAN | aqNAN;
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
        NV = 0;
        switch( { IF | NN, aZERO } ) {
            case 2b00: {
                switch( floatingpointnumber( a ).sign ) {
                    case 1: { result = 0; }
                    default: {
                        sig = ( exp < 11 ) ? { 5b1, floatingpointnumber( a ).fraction, 1b0 } >> ( 10 - exp ) : { 5b1, floatingpointnumber( a ).fraction, 1b0 } << ( exp - 11 );
                        result = ( exp > 15 ) ? 16hffff : ( sig[1,16] + sig[0,1] );
                        NV = ( exp > 15 );
                    }
                }
            }
            case 2b01: { result = 0; }
            default: { NV = 1; result = NN ? 16hffff : floatingpointnumber( a ).sign ? 0 : 16hffff;  }
        }
    }
}

// ADDSUB
// ADD/SUBTRACT ( addsub == 0 add, == 1 subtract) TWO FLOATING POINT NUMBERS
algorithm equaliseexpaddsub(
    input   int7    expA,
    input   uint22  sigA,
    input   int7    expB,
    input   uint22  sigB,
    output  int7    newexpA,
    output  uint22  newsigA,
    output  int7    newexpB,
    output  uint22  newsigB
) <autorun> {
    always {
        // EQUALISE THE EXPONENTS BY SHIFT SMALLER NUMBER FRACTION PART TO THE RIGHT
        switch( { expA < expB, expB < expA } ) {
            case 2b10: { newsigA = sigA >> ( expB - expA ); newexpA = expB; newsigB = sigB; newexpB = expB; }
            case 2b01: { newsigB = sigB >> ( expA - expB ); newexpB = expA; newsigA = sigA; newexpA = expA; }
            default: { newsigA = sigA; newexpA = expA; newsigB = sigB; newexpB = expB; }
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
) <autorun> {
    always {
        // PERFORM ADDITION HANDLING SIGNS
        switch( { signA, signB } ) {
            case 2b01: {
                switch( sigB > sigA ) {
                    case 1: { resultsign = 1; resultfraction = sigB - sigA; }
                    case 0: { resultsign = 0; resultfraction = sigA - sigB; }
                }
            }
            case 2b10: {
                switch(  sigA > sigB ) {
                    case 1: { resultsign = 1; resultfraction = sigA - sigB; }
                    case 0: { resultsign = 0; resultfraction = sigB - sigA; }
                }
            }
            default: { resultsign = signA; resultfraction = sigA + sigB; }
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
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS - SWITCH SIGN OF B IF SUBTRACTION
    uint1   signA <: a[15,1];
    int7    expA <: floatingpointnumber( a ).exponent - 15;
    uint22  sigA <: { 2b01, floatingpointnumber(a).fraction, 10b0 };
    uint1   signB <: addsub ? ~b[15,1] : b[15,1];
    int7    expB <: floatingpointnumber( b ).exponent - 15;
    uint22  sigB <: { 2b01, floatingpointnumber(b).fraction, 10b0 };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF - INF )
    uint1   IF <: ( aINF | bINF );
    uint1   NN <: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV <: ( aINF & bINF) & ( signA != signB );
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
    int7    eqexpA = uninitialised;
    uint22  eqsigA = uninitialised;
    int7    eqexpB = uninitialised;
    uint22  eqsigB = uninitialised;
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
    int7    resultexp <: eqexpA + 1;
    uint22  resultfraction = uninitialised;
    dofloataddsub ADDSUB(
        signA <: signA,
        sigA <: eqsigA,
        signB <: signB,
        sigB <: eqsigB,
        resultsign :> resultsign,
        resultfraction :> resultfraction
    );

    // NORMALISE THE RESULTING FRACTION AND ADJUST THE EXPONENT IF SMALLER ( ie, MSB is not 1 )
    int7    normalexp = uninitialised;
    uint22  normalfraction = uninitialised;
    donormalise22 NORMALISE(
        exp <: resultexp,
        bitstream <: resultfraction,
        newexp :> normalexp,
        normalised :> normalfraction
    );

    // ROUND THE NORMALISED FRACTION AND ADJUST EXPONENT IF OVERFLOW
    int7    roundexponent = uninitialised;
    uint22  roundfraction = uninitialised;
    doround22 ROUND(
        exponent <: normalexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float16
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint16  f16 = uninitialised;
    docombinecomponents16 COMBINE(
        sign <: resultsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f16 :> f16
    );

    NORMALISE.start := 0;
    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 2 CYCLES FOR EQUALISING EXPONENTS AND TO PERFORM THE ADDITION/SUBTRACTION
            ++:
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    switch( ADDSUB.resultfraction ) {
                        case 0: { result = 0; }
                        default: {
                            NORMALISE.start = 1; while( NORMALISE.busy ) {}
                            OF = cOF; UF = cUF; result = f16;
                        }
                    }
                }
                case 2b01: { result = ( aZERO & bZERO ) ? 0 : ( bZERO ) ? a : addsub ? { ~floatingpointnumber( b ).sign, b[0,15] } : b; }
                default: {
                    switch( { IF, NN } ) {
                        case 2b10: { result = ( aINF & bINF) ? ( signA == signB ) ? a : 16hfe00 : aINF ? a : b; }
                        default: { result = 16hfe00; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// MULTIPLY TWO FLOATING POINT NUMBERS
algorithm dofloatmul(
    input   uint11  factor_1,
    input   uint11  factor_2,
    output  uint22  product
) <autorun> {
    product := factor_1 * factor_2;
}
algorithm floatmultiply(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    input   uint16  b,

    output  uint7   flags,
    output  uint16  result
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF PRODUCT ( + 1 IF PRODUCT OVERFLOWS, MSB == 1 )
    uint1   productsign <: floatingpointnumber( a ).sign ^ floatingpointnumber( b ).sign;
    int7    productexp <: (floatingpointnumber( a ).exponent - 15) + (floatingpointnumber( b ).exponent - 15) + product[21,1];
    uint11  sigA <: { 1b1, floatingpointnumber( a ).fraction };
    uint11  sigB <: { 1b1, floatingpointnumber( b ).fraction };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND INVALID ( INF x ZERO )
    uint1   IF <: ( aINF | bINF );
    uint1   NN <: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV <: ( aINF | bINF ) & ( aZERO | bZERO );
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

    uint22  product = uninitialised;
    dofloatmul UINTMUL(
        factor_1 <: sigA,
        factor_2 <: sigB,
        product :> product
    );

    uint22  normalfraction = uninitialised;
    donormalise22 NORMALISE(
        bitstream <: product,
        normalised :> normalfraction
    );

    int7    roundexponent = uninitialised;
    uint22  roundfraction = uninitialised;
    doround22 ROUND(
        exponent <: productexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float16
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint16  f16 = uninitialised;
    docombinecomponents16 COMBINE(
        sign <: productsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f16 :> f16
    );

    NORMALISE.start := 0;
    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            ++: // ALLOW 1 CYLE TO PERFORM THE MULTIPLICATION
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    // STEPS: SETUP -> DOMUL -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                    NORMALISE.start = 1; while( NORMALISE.busy ) {}
                    OF = cOF; UF = cUF; result = f16;
                }
                case 2b01: { result = { productsign, 15b0 }; }
                default: {
                    switch( { IF, aZERO | bZERO } ) {
                        case 2b11: { result = 16hfe00; }
                        case 2b10: { result = NN ? 16hfe00 : { productsign, 5b11111, 10b0 }; }
                        default: { result = 16hfe00; }
                    }
                }
            }
            busy = 0;
        }
    }
}

// DIVIDE TWO FLOATING POINT NUMBERS
algorithm dofloatdivbit(
    input   uint24  quotient,
    input   uint24  remainder,
    input   uint24  top,
    input   uint24  bottom,
    input   uint5   bit,
    output  uint24  newquotient,
    output  uint24  newremainder,
 ) <autorun> {
    uint24  temporary = uninitialised;
    uint1   bitresult = uninitialised;
    always {
        temporary = { remainder[0,23], top[bit,1] };
        bitresult = __unsigned(temporary) >= __unsigned(bottom);
        newremainder = __unsigned(temporary) - ( bitresult ? __unsigned(bottom) : 0 );
        newquotient = quotient | ( bitresult << bit );
    }
}
algorithm dofloatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint24  sigA,
    input   uint24  sigB,
    output  uint24  quotient
) <autorun> {
    uint24  remainder <: start ? 0 : newremainder;
    uint24  newquotient = uninitialised;
    uint24  newremainder = uninitialised;
    dofloatdivbit DIVBIT(
        quotient <: quotient,
        remainder <: remainder,
        top <: sigA,
        bottom <: sigB,
        bit <: bit,
        newquotient :> newquotient,
        newremainder :> newremainder
    );
    uint5   bit(31);

    busy := start | ( bit != 31 ) | ( quotient[22,2] != 0 );
    while(1) {
        // FIND QUOTIENT AND ENSURE 22 BIT FRACTION ( ie BITS 21 and 22 clear )
        if( start ) {
            bit = 23; quotient = 0; while( bit != 31 ) { quotient = newquotient; bit = bit - 1; } while( quotient[22,2] != 0 ) { quotient = quotient >> 1; }
        }
    }
}

algorithm floatdivide(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    input   uint16  b,

    output  uint7   flags,
    output  uint16  result
) <autorun> {
    // BREAK DOWN INITIAL float32 INPUTS AND FIND SIGN OF RESULT AND EXPONENT OF QUOTIENT ( -1 IF DIVISOR > DIVIDEND )
    uint1   quotientsign <: floatingpointnumber( a ).sign ^ floatingpointnumber( b ).sign;
    int10   quotientexp <: ((floatingpointnumber( a ).exponent - 127) - (floatingpointnumber( b ).exponent - 127)) - ( floatingpointnumber(b).fraction > floatingpointnumber(a).fraction );
    uint24  sigA <: { 1b1, floatingpointnumber(a).fraction, 13b0 };
    uint24  sigB <: { 14b1, floatingpointnumber(b).fraction };

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND DIVIDE ZERO
    uint1   IF <: ( aINF | bINF );
    uint1   NN <: ( asNAN | aqNAN | bsNAN | bqNAN );
    uint1   NV = uninitialised;
    uint1   DZ <: bZERO;
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

    uint24  quotient = uninitialised;
    dofloatdivide DODIVIDE(
        sigA <: sigA,
        sigB <: sigB,
        quotient :> quotient
    );

    uint22  normalfraction = uninitialised;
    donormalise22 NORMALISE(
        bitstream <: quotient,
        normalised :> normalfraction
    );

    int7    roundexponent = uninitialised;
    uint22  roundfraction = uninitialised;
    doround22 ROUND(
        exponent <: quotientexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float16
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint16  f16 = uninitialised;
    docombinecomponents16 COMBINE(
        sign <: quotientsign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f16 :> f16
    );

    DODIVIDE.start := 0; NORMALISE.start := 0;
    flags := { IF, NN, 1b0, DZ, OF, UF, 1b0};

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, aZERO | bZERO } ) {
                case 2b00: {
                    DODIVIDE.start = 1; while( DODIVIDE.busy ) {}
                    switch( quotient ) {
                        case 0: { result = { quotientsign, 15b0 }; }
                        default: {
                            NORMALISE.start = 1; while( NORMALISE.busy ) {}
                            OF = cOF; UF = cUF; result = f16;
                        }
                    }
                }
                case 2b01: { result = ( aZERO & bZERO ) ? 16hfe00 : ( bZERO ) ? { quotientsign, 5b11111, 10b0 } : { quotientsign, 15b0 }; }
                default: { result = ( aINF &bINF ) | NN | bZERO ? 16hfe00 : aZERO | bINF ? { quotientsign, 15b0 } : { quotientsign, 5b11111, 10b0 }; }
            }
            busy = 0;
        }
    }
}

// ADAPTED FROM https://projectf.io/posts/square-root-in-verilog/
algorithm dofloatsqrtbit(
    input   uint24  ac,
    input   uint22  x,
    input   uint22  q,
    output  uint24  newac,
    output  uint22  newq,
    output  uint22  newx
 ) <autorun> {
    uint24  test_res = uninitialised;
    always {
        test_res = ac - { q, 2b01 };
        newac = { test_res[23,1] ? ac[0,21] : test_res[0,21], x[20,2] };
        newq = { q[0,21], ~test_res[23,1] };
        newx = { x[0,20], 2b00 };
    }
}
algorithm dofloatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint24  start_ac,
    input   uint22  start_x,
    output  uint22  q
) <autorun> {
    uint24  ac <: start ? start_ac : newac;
    uint22  x <:  start ? start_x : newx;
    uint24  newac = uninitialised;
    uint22  newq = uninitialised;
    uint22  newx = uninitialised;
    dofloatsqrtbit SQRTBIT( ac <: ac, x <: x, q <: q, newac :> newac, newx :> newx, newq :> newq );

    uint5   i(21);
    busy := start | ( i != 21 );
    while(1) {
        if( start ) {
            i = 0; q = 0; while( i != 21 ) { q = newq; i = i + 1; }
        }
    }
}

algorithm floatsqrt(
    input   uint1   start,
    output  uint1   busy(0),
    input   uint16  a,
    output  uint7   flags,
    output  uint16  result
) <autorun> {
    uint1   sign <: floatingpointnumber( a ).sign;              // SIGN OF INPUT
    int7   exp  <: floatingpointnumber( a ).exponent - 15  ;    // EXPONENT OF INPUT ( used to determine if 1x.xxxxx or 01.xxxxx for fixed point fraction to sqrt )

    // CLASSIFY THE INPUTS AND FLAG INFINITY, NAN, ZERO AND NOT VALID
    uint1   IF <: aINF;
    uint1   NN <: asNAN | aqNAN;
    uint1   NV <: IF | NN | sign;
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
    uint24  start_ac <: ~exp[0,1] ? 1 : { 22b0, 1b1, a[9,1] };
    uint22  start_x <: ~exp[0,1] ? { a[0,10], 12b0 } : { a[0,9], 13b0 };
    uint22  squareroot = uninitialised;
    int7    squarerootexp <: ( exp >>> 1 );
    dofloatsqrt DOSQRT(
        start_ac <: start_ac,
        start_x <: start_x,
        q :> squareroot
    );

    uint22  normalfraction = uninitialised;
    donormalise22 NORMALISE(
        bitstream <: squareroot,
        normalised :> normalfraction
    );

    int7    roundexponent = uninitialised;
    uint22  roundfraction = uninitialised;
    doround22 ROUND(
        exponent <: squarerootexp,
        bitstream <: normalfraction,
        newexponent :> roundexponent,
        roundfraction :> roundfraction
    );

    // COMBINE TO FINAL float16
    uint1   cOF = uninitialised;
    uint1   cUF = uninitialised;
    uint16  f16 = uninitialised;
    docombinecomponents16 COMBINE(
        sign <: sign,
        exp <: roundexponent,
        fraction <: roundfraction,
        OF :> cOF,
        UF :> cUF,
        f16 :> f16
    );

    DOSQRT.start := 0; NORMALISE.start := 0;
    flags := { IF, NN, NV, 1b0, OF, UF, 1b0 };

    while(1) {
        if( start ) {
            busy = 1;
            OF = 0; UF = 0;
            switch( { IF | NN, aZERO } ) {
                case 2b00: {
                    switch( sign ) {
                        // DETECT NEGATIVE -> qNAN
                        case 1: { result = 16hfe00; }
                        case 0: {
                            // STEPS: SETUP -> DOSQRT -> NORMALISE -> ROUND -> ADJUSTEXP -> COMBINE
                            DOSQRT.start = 1; while( DOSQRT.busy ) {}
                            NORMALISE.start = 1; while( NORMALISE.busy ) {}
                            OF = cOF; UF = cUF; result = f16;
                        }
                    }
                }
                // DETECT sNAN, qNAN, -INF, -0 -> qNAN AND  INF -> INF, 0 -> 0
                default: { result = sign ? 16hfe00 : a; }
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

algorithm floatcompare(
    input   uint16  a,
    input   uint16  b,
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
    flags := { aINF | bINF, asNAN | bsNAN | aqNAN | bqNAN, asNAN | bsNAN | aqNAN | bqNAN, 4b0000 };
    less := flags[5,1] ? 0 : ( floatingpointnumber( a ).sign != floatingpointnumber( b ).sign ) ? floatingpointnumber( a ).sign & ((( a | b ) << 1) != 0 ) : ( a != b ) & ( floatingpointnumber( a ).sign ^ ( a < b));
    equal := flags[5,1] ? 0 : ( a == b ) | ((( a | b ) << 1) == 0 );
}

