// @sylefeb 2022
// MIT license, see LICENSE_MIT in Silice repo root
// https://github.com/sylefeb/Silice/

#pragma once

// --- basic functions, call sdcard_init then use sdcard_read_sector ---

void           sdcard_init();
unsigned char *sdcard_read_sector(int sector,unsigned char *dst);
unsigned char  sdcard_start_sector(int sector);
unsigned char  sdcard_get(unsigned char len,unsigned char wait);

// --- fat_io_lib sdcard implementation ---

int sdcard_readsector(
  long unsigned int start_block,
  unsigned char *buffer,
  long unsigned int sector_count);

int sdcard_writesector( // not implemented
  long unsigned int start_block,
  unsigned char *buffer,
  long unsigned int sector_count);
