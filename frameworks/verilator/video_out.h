//
// 2019-09-26 Sylvain Lefebvre
// 
// Implements VGA emulation for Verilator
// emulates front/back porch on horizontal and vertical synch
//
// Based on code from the MCC216 project (https://github.com/fredrequin/fpga_1943)
// 2013 (c) Frederic Requin, GPL v3 licence
//

#pragma once

#include "verilated.h"
#include "LibSL/Image/Image.h"

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
          vluint8_t debug, 
          vluint8_t depth, 
          vluint8_t polarity, 
          vluint16_t hactive, vluint16_t hfporch_, vluint16_t hspulse_, vluint16_t hbporch_,
          vluint16_t vactive, vluint16_t vfporch_, vluint16_t vspulse_, vluint16_t vbporch_,
          const char *file);
        ~VideoOut();
        // Methods
        void eval_RGB_HV(vluint64_t cycle, vluint8_t clk, vluint8_t vs,   vluint8_t hs,   vluint8_t red,  vluint8_t green, vluint8_t blue);
        vluint16_t get_hcount();
        vluint16_t get_vcount();
    private:
        RGBApixel yuv2rgb(int lum, int cb, int cr);
        // Color depth
        int        bit_shift;
        vluint8_t  bit_mask;
        // Synchros polarities
        vluint8_t  hs_pol;
        vluint8_t  vs_pol;
        // Debug mode
        vluint8_t  dbg_on;
        // H synch
        vluint16_t hfporch;
        vluint16_t hspulse; 
        vluint16_t hbporch;
        // V synch
        vluint16_t vfporch;
        vluint16_t vspulse; 
        vluint16_t vbporch;
        // Image format
        vluint16_t hor_size;
        vluint16_t ver_size;
        // Image file
        LibSL::Image::ImageRGB_Ptr image;
        // Image file name
        char       filename[256];
        // Internal variable
        vluint16_t hcount;
        vluint16_t vcount;
        vluint8_t  prev_clk;
        vluint8_t  prev_hs;
        vluint8_t  prev_vs;
        int        dump_ctr;
        
        enum e_Synch {e_Front=0,e_SynchPulseUp=1,e_SynchPulseDown=2,e_Back=3,e_Done=4};

        e_Synch    v_sync_stage;
        e_Synch    h_sync_stage;
        int        v_sync_count;
        int        h_sync_count;
};

