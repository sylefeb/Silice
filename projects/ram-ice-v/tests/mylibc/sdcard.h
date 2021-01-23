#pragma once

void           sdcard_init();
unsigned char  sdcard_start_sector(int sector);
unsigned char *sdcard_copy_sector(int sector,unsigned char *dst);

void           sdcard_cmd(const unsigned char *cmd);
unsigned char  sdcard_get(unsigned char len,unsigned char wait);
