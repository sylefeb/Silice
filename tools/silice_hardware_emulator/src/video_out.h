/*

    Silice FPGA language and compiler
    (c) Sylvain Lefebvre - @sylefeb

This work and all associated files are under the

     GNU AFFERO GENERAL PUBLIC LICENSE
        Version 3, 19 November 2007
        
A copy of the license full text is included in 
the distribution, please refer to it for details.

(header_1_0)
*/
//
// Implements VGA emulation for Verilator.
// Emulates front/back porch on horizontal and vertical synch.
//
// Based on code from the MCC216 project (https://github.com/fredrequin/fpga_1943)
// (c) Frederic Requin, GPL v3 license
//

#pragma once

#include <LibSL/LibSL.h>

#define HS_POS_POL 1
#define HS_NEG_POL 0
#define VS_POS_POL 2
#define VS_NEG_POL 0

class VideoOut
{
    public:
        typedef struct {
          uchar Red;
          uchar Green;
          uchar Blue;
          uchar Alpha;
        } RGBApixel;

        // Constructor and destructor
        VideoOut(
          uint8_t debug, 
          uint8_t depth, 
          uint8_t polarity, 
          uint16_t hactive, uint16_t hfporch_, uint16_t hspulse_, uint16_t hbporch_,
          uint16_t vactive, uint16_t vfporch_, uint16_t vspulse_, uint16_t vbporch_,
          const char *file);
        ~VideoOut();
        // Methods
        void eval_RGB_HV(uint8_t clk, uint8_t vs,   uint8_t hs,   uint8_t red,  uint8_t green, uint8_t blue);
        uint16_t get_hcount();
        uint16_t get_vcount();

        bool                        frameBufferChanged() const { return image_changed; }
        LibSL::Image::ImageRGBA_Ptr frameBuffer()              { image_changed = false; return image; }

    private:
        RGBApixel yuv2rgb(int lum, int cb, int cr);
        // Color depth
        int        bit_shift;
        uint8_t  bit_mask;
        // Synchros polarities
        uint8_t  hs_pol;
        uint8_t  vs_pol;
        // Debug mode
        uint8_t  dbg_on;
        // H synch
        uint16_t hfporch;
        uint16_t hspulse; 
        uint16_t hbporch;
        // V synch
        uint16_t vfporch;
        uint16_t vspulse; 
        uint16_t vbporch;
        // Image format
        uint16_t hor_size;
        uint16_t ver_size;
        // Image file
        bool                        image_changed = true;
        LibSL::Image::ImageRGBA_Ptr image;
        // Image file name
        char       filename[256];
        // Internal variable
        uint16_t hcount;
        uint16_t vcount;
        uint8_t  prev_clk;
        uint8_t  prev_hs;
        uint8_t  prev_vs;
        int        dump_ctr;
        
        enum e_Synch {e_Front=0,e_SynchPulseUp=1,e_SynchPulseDown=2,e_Back=3,e_Done=4};

        e_Synch    v_sync_stage;
        e_Synch    h_sync_stage;
        int        v_sync_count;
        int        h_sync_count;
};

