//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

#pragma once

void           sdcard_init();
unsigned char  sdcard_start_sector(int sector);
unsigned char *sdcard_copy_sector(int sector,unsigned char *dst);

void           sdcard_cmd(const unsigned char *cmd);
unsigned char  sdcard_get(unsigned char len,unsigned char wait);
