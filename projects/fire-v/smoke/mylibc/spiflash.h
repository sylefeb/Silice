// SL 2021-02-03
//
// MIT license, see LICENSE_MIT in Silice repo root

#pragma once

void           spiflash_init();
unsigned char *spiflash_copy(int addr,unsigned char *dst,int len);

void           spiflash_read_begin(int addr);
unsigned char  spiflash_read_next();
void           spiflash_read_end();

void           spiflash_write_begin(int addr);
void           spiflash_write_next(unsigned char v);
void           spiflash_write_end();

unsigned char  spiflash_status();
void           spiflash_busy_wait();
void           spiflash_erase4KB(int addr);
