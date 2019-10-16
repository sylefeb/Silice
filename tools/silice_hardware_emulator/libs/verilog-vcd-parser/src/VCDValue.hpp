
#ifndef VCDValue_HPP
#define VCDValue_HPP

#include "VCDTypes.hpp"

/*!
@brief Represents a single value found in a VCD File.
@details Can contain a single bit (a scalar), a bti vector, or an
IEEE floating point number.
*/
class VCDValue {


    //! Convert a VCDBit to a single char
    static char VCDBit2Char(VCDBit b) {
        switch(b) {
            case(VCD_0):
                return '0';
            case(VCD_1):
                return '1';
            case(VCD_Z):
                return 'Z';
            case(VCD_X):
            default:
                return 'X';
        }
    }

    public:
        
        /*!
        @brief Create a new VCDValue with the type VCD_SCALAR
        */
        VCDValue    (
            VCDBit  value
        );

        /*!
        @brief Create a new VCDValue with the type VCD_VECTOR
        */
        VCDValue    (
            VCDBitVector * value
        );

        /*!
        @brief Create a new VCDValue with the type VCD_VECTOR
        */
        VCDValue    (
            VCDReal value
        );


        ~VCDValue () {
            if(this -> type == VCD_VECTOR) {
                delete this -> value.val_vector;
            }
        }
        

        //! Return the type of value stored by this class instance.
        VCDValueType   get_type();
        
        //! Get the bit value of the instance.
        VCDBit       get_value_bit();
        
        //! Get the vector value of the instance.
        VCDBitVector * get_value_vector();

        //! Get the real value of the instance.
        VCDReal      get_value_real();


    protected:

        //! The type of value this instance stores.
        VCDValueType    type;
        
        //! The actual value stored, as identified by type.
        union valstore {
            VCDBit         val_bit;   //!< Value as a bit
            VCDBitVector * val_vector;//!< Value as a bit vector
            VCDReal        val_real;  //!< Value as a real number (double).
        } value;
};



#endif
