
#include <map>
#include <utility>
#include <string>
#include <vector>

/*!
@file VCDTypes.hpp
@brief A file for common types and data structures used by the VCD parser.
*/

#ifndef VCDTypes_HPP
#define VCDTypes_HPP

//! Friendly name for a signal
typedef std::string VCDSignalReference;

//! Friendly name for a scope
typedef std::string VCDScopeName;

//! Compressed hash representation of a signal.
typedef std::string VCDSignalHash;

//! Represents a single instant in time in a trace
typedef double VCDTime;

//! Specifies the timing resoloution along with VCDTimeUnit
typedef unsigned VCDTimeRes;

//! Width in bits of a signal.
typedef unsigned VCDSignalSize;

//! Represents the four-state signal values of a VCD file.
typedef enum {
    VCD_0 = 0,  //!< Logic zero
    VCD_1 = 1,  //!< Logic one
    VCD_X = 2,  //!< Unknown / Undefined
    VCD_Z = 3   //!< High Impedence.
} VCDBit;


//! A vector of VCDBit values.
typedef std::vector<VCDBit> VCDBitVector;

//! Typedef to identify a real number as stored in a VCD.
typedef double VCDReal;


//! Describes how a signal value is represented in the VCD trace.
typedef enum {
    VCD_SCALAR, //!< Single VCDBit
    VCD_VECTOR, //!< Vector of VCDBit
    VCD_REAL    //!< IEEE Floating point (64bit).
} VCDValueType;


// Forward declaration of class.
class VCDValue;


//! A signal value tagged with times.
typedef struct {
    VCDTime     time;
    VCDValue  * value;
} VCDTimedValue;


//! A vector of tagged time/value pairs, sorted by time values.
typedef std::vector<VCDTimedValue*> VCDSignalValues;


//! Variable types of a signal in a VCD file.
typedef enum {
    VCD_VAR_EVENT,
    VCD_VAR_INTEGER,
    VCD_VAR_PARAMETER,
    VCD_VAR_REAL,
    VCD_VAR_REALTIME,
    VCD_VAR_REG,
    VCD_VAR_SUPPLY0,
    VCD_VAR_SUPPLY1,
    VCD_VAR_TIME,
    VCD_VAR_TRI,
    VCD_VAR_TRIAND,
    VCD_VAR_TRIOR,
    VCD_VAR_TRIREG,
    VCD_VAR_TRI0,
    VCD_VAR_TRI1,
    VCD_VAR_WAND,
    VCD_VAR_WIRE,
    VCD_VAR_WOR
} VCDVarType;


//! Represents the possible time units a VCD file is specified in.
typedef enum {
    TIME_S,     //!< Seconds
    TIME_MS,    //!< Milliseconds
    TIME_US,    //!< Microseconds
    TIME_NS,    //!< Nanoseconds
    TIME_PS,    //!< Picoseconds
} VCDTimeUnit;


//! Represents the type of SV construct who's scope we are in.
typedef enum {
    VCD_SCOPE_BEGIN,
    VCD_SCOPE_FORK,
    VCD_SCOPE_FUNCTION,
    VCD_SCOPE_MODULE,
    VCD_SCOPE_TASK,
    VCD_SCOPE_ROOT
} VCDScopeType;


// Typedef over vcdscope to make it available to VCDSignal struct.
typedef struct vcdscope VCDScope;

//! Represents a single signal reference within a VCD file
typedef struct {
    VCDSignalHash       hash;
    VCDSignalReference  reference;
    VCDScope          * scope;
    VCDSignalSize       size;
    VCDVarType          type;
} VCDSignal;


//! Represents a scope type, scope name pair and all of it's child signals.
struct vcdscope {
    VCDScopeName              name;     //!< The short name of the scope
    VCDScopeType              type;     //!< Construct type
    VCDScope                * parent;   //!< Parent scope object
    std::vector<VCDScope*>    children; //!< Child scope objects.
    std::vector<VCDSignal*>   signals;  //!< Signals in this scope.
};


#endif
