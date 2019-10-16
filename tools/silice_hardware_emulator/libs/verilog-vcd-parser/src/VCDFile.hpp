
#include <map>
#include <string>
#include <vector>

#include "VCDTypes.hpp"
#include "VCDValue.hpp"

#ifndef VCDFile_HPP
#define VCDFile_HPP


/*!
@brief Top level object to represent a single VCD file.
*/
class VCDFile {

    public:
        
        //! Instance a new VCD file container.
        VCDFile();
        
        //! Destructor
        ~VCDFile();
        
        //! Timescale of the VCD file.
        VCDTimeUnit time_units;

        //! Multiplier of the VCD file time units.
        VCDTimeRes  time_resolution;
        
        //! Date string of the VCD file.
        std::string date;

        //! Version string of the simulator which generated the VCD.
        std::string version;

        //! Root scope node of the VCD signals
        VCDScope * root_scope;

        /*!
        @brief Add a new scope object to the VCD file
        @param s in - The VCDScope object to add to the VCD file.
        */
        void add_scope(
            VCDScope * s
        );

        /*!
        @brief Add a new signal to the VCD file
        @param s in - The VCDSignal object to add to the VCD file.
        */
        void add_signal(
            VCDSignal * s
        );


        /*!
        @brief Add a new timestamp value to the VCD file.
        @details Add a time stamp to the sorted array of existing
        timestamps in the file.
        @param time in - The timestamp value to add to the file.
        */
        void add_timestamp(
            VCDTime time
        );
    

        /*!
        @brief Return the scope object in the VCD file with this name
        @param name in - The name of the scope to get and return.
        */
        VCDScope * get_scope(
            VCDScopeName name
        );


        /*!
        @brief Add a new signal value to the VCD file, tagged by time.
        @param time_val in - A signal value, tagged by the time it occurs.
        @param hash in - The VCD hash value representing the signal.
        */
        void add_signal_value(
            VCDTimedValue * time_val,
            VCDSignalHash   hash
        );
        

        /*!
        @brief Get the value of a particular signal at a specified time.
        @note The supplied time value does not need to exist in the
        vector returned by get_timestamps().
        @param hash in - The hashcode for the signal to identify it.
        @param time in - The time at which we want the value of the signal.
        @returns A pointer to the value at the supplie time, or nullptr if
        no such record can be found.
        */
        VCDValue * get_signal_value_at (
            VCDSignalHash hash,
            VCDTime       time
        );

        
        /*!
        @brief Return a pointer to the set of timestamp samples present in
               the VCD file.
        */
        std::vector<VCDTime>* get_timestamps();
        
        /*!
        @brief Get a vector of all scopes present in the file.
        */
        std::vector<VCDScope*>* get_scopes();
        
        /*!
        @brief Return a flattened vector of all signals in the file.
        */
        std::vector<VCDSignal*>* get_signals();

        /*!
        @brief Return the map of hash and values
        */
        std::map<VCDSignalHash, VCDSignalValues*>& get_hash_values() { return val_map; }

    protected:
        
        //! Flat vector of all signals in the file.
        std::vector<VCDSignal*> signals;
        
        //! Flat mao of all scope objects in the file, keyed by name.
        std::vector<VCDScope*>  scopes;

        //! Vector of time values present in the VCD file - sorted, asc
        std::vector<VCDTime>    times;

        //! Map of hashes onto vectors of times and signal values.
        std::map<VCDSignalHash, VCDSignalValues*> val_map;
};


#endif
