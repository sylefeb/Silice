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
// Based on code from the MCC216 project (https://github.com/fredrequin/fpga_1943)
// (c) Frederic Requin, GPL v3 license
//

#include "video_out.h"

#include <LibSL/LibSL.h>

#include <stdlib.h>
#include <stdio.h>
#include <time.h>

using namespace LibSL::Image;
using namespace LibSL::Math;

ImageFormat_TGA g_RegisterFormat_TGA;

// Constructor
VideoOut::VideoOut(uint8_t debug, uint8_t depth, uint8_t polarity,
                   uint16_t hactive, uint16_t hfporch_, uint16_t hspulse_, uint16_t hbporch_,
                   uint16_t vactive, uint16_t vfporch_, uint16_t vspulse_, uint16_t vbporch_,
                   const char *file)
{
    // color depth
    if (depth <= 8) {
        bit_mask  = (1 << depth) - 1;
        bit_shift = (int)(8 - depth);
    } else {
        bit_mask  = (uint8_t)0xFF;
        bit_shift = (int)0;
    }
    // synchros polarities
    hs_pol      = (polarity & HS_POS_POL) ? (uint8_t)1 : (uint8_t)0;
    vs_pol      = (polarity & VS_POS_POL) ? (uint8_t)1 : (uint8_t)0;
    // screen format initialized
    hor_size    = hactive;
    ver_size    = vactive;
    // record synch values
    hfporch = hfporch_;
    hspulse = hspulse_;
    hbporch = hbporch_;
    vfporch = vfporch_;
    vspulse = vspulse_;
    vbporch = vbporch_;
    // debug mode
    dbg_on      = debug;
    // create the image
    image       = ImageRGBA_Ptr(new ImageRGBA((int)hactive, (int)vactive));
    // copy the filename
    strncpy(filename, file, 255);
    // internal variables cleared
    hcount      = (uint16_t)hor_size;
    vcount      = (uint16_t)ver_size;
    prev_clk    = (uint8_t)0;
    prev_hs     = (uint8_t)0;
    prev_vs     = (uint8_t)0;
    dump_ctr    = (int)0;
    // synch
    v_sync_stage = e_Front;
    h_sync_stage = e_Front;
    v_sync_count = 0;
    h_sync_count = 0;
}

// Destructor
VideoOut::~VideoOut()
{

}

// evaluate : RGB with synchros
void VideoOut::eval_RGB_HV
(
    // Clock
    uint8_t  clk,
    // Synchros
    uint8_t  vs,
    uint8_t  hs,
    // RGB colors
    uint8_t  red,
    uint8_t  green,
    uint8_t  blue
)
{

    // Rising edge on clock
    if (clk && !prev_clk) {
        //printf("\nh stage %d, v stage %d, hs %d (prev:%d), vs %d (prev:%d), hcount %d, vcount %d, hsync_cnt:%d, vsync_cnt:%d\n",
        //       h_sync_stage,v_sync_stage,hs,prev_hs,vs,prev_vs,hcount,vcount,h_sync_count,v_sync_count);

        // Horizontal synch update
        bool h_sync_achieved = false;
        switch (h_sync_stage)
        {
        case e_Front:
            h_sync_count ++;
            if (h_sync_count == hfporch-1) {
                h_sync_stage = e_SynchPulseUp;
                h_sync_count = 0;
            }
            break;
        case e_SynchPulseUp:
            if ((hs == hs_pol) && (prev_hs != hs_pol)) {
                // raising edge on hs
                h_sync_stage = e_SynchPulseDown;
                if (dbg_on) printf(" Rising edge on HS @\n");
            }
            break;
        case e_SynchPulseDown:
            if ((hs != hs_pol) && (prev_hs != hs_pol)) {
                // falling edge on hs
                h_sync_stage = e_Back;
                h_sync_count ++;
            }
            break;
        case e_Back:
            h_sync_count ++;
            if (h_sync_count == hbporch) {
                h_sync_stage = e_Done;
                h_sync_count = 0;
                hcount = 0;
                // just achived hsynch
                h_sync_achieved = true;
                // end of frame?
                if (vcount >= ver_size) {
                    // yes, trigger vsynch
                    vcount = 0;
                    h_sync_stage = e_Front;
                }
            }
            break;
        case e_Done: break;
        }

        // Vertical synch update, if horizontal synch achieved
        if (h_sync_achieved) {

            switch (v_sync_stage)
            {
            case e_Front:
                v_sync_count ++;
                if (v_sync_count == vfporch-1) {
                    v_sync_stage = e_SynchPulseUp;
                    v_sync_count = 0;
                }
                break;
            case e_SynchPulseUp:
                if ((vs == vs_pol) && (prev_vs != vs_pol)) {
                    // raising edge on vs
                    v_sync_stage = e_SynchPulseDown;
                    if (dbg_on) printf(" Rising edge on VS @\n");
                }
                break;
            case e_SynchPulseDown:
                if ((vs != vs_pol) && (prev_vs != vs_pol)) {
                    // falling edge on vs
                    v_sync_stage = e_Back;
                    v_sync_count ++;

                }
                break;
            case e_Back:
                v_sync_count ++;
                if (v_sync_count == vbporch) {
                    vcount = 0;
                    v_sync_stage = e_Done;
                    v_sync_count = 0;
                    if (1) {
                        char tmp[264];
                        sprintf(tmp, "%s_%04d.tga", filename, dump_ctr);
                        printf(" Save snapshot in file \"%s\"\n", tmp);
                        saveImage(tmp,image);
                        dump_ctr++;
                    }
                }
                break;
            case e_Done: break;
            }

            prev_vs = vs;

        }

        // reset horizontal synchro
        if (h_sync_stage == e_Done) {
            if (hcount >= hor_size) {
                h_sync_stage = e_Front;
                vcount ++;
            }
        }
        // reset vertical synchro
        if (v_sync_stage == e_Done) {
            if (vcount >= ver_size) {
                h_sync_stage = e_Front;
                v_sync_stage = e_Front;
            }
        }

        // Grab active area
        if (v_sync_stage == e_Done && h_sync_stage == e_Done) {

            if (vcount < ver_size) {
                if (hcount < hor_size) {
                    RGBApixel pixel;

                    pixel.Red   = (red   & bit_mask) << bit_shift;
                    pixel.Green = (green & bit_mask) << bit_shift;
                    pixel.Blue  = (blue  & bit_mask) << bit_shift;

                    image->pixel((int)(hcount), (int)(vcount)) = v4b(pixel.Red,pixel.Green,pixel.Blue,255);
                    image_changed = true;
//                    printf("*** [pixel write at %d,%d]\n",hcount,vcount);
                }
            }
        }

        hcount ++;

        prev_hs = hs;

    }

    prev_clk = clk;

}

uint16_t VideoOut::get_hcount()
{
    return hcount;
}

uint16_t VideoOut::get_vcount()
{
    return vcount;
}

