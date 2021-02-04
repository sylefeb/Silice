// SL 2021-02-03
//
//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

#pragma once

void           spiflash_init();
unsigned char *spiflash_copy(int addr,unsigned char *dst,int len);
