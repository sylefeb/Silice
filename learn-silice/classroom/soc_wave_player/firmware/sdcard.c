/*
SL - 2020-01-24

SDCARD bit-banging from RV32I CPU

I went through the trouble of equalizing all delays to have a clean
sdcard clock period, but maybe that was not necessary.
These delays are tunned to the Fire-V and likely not portable.

Useful Links
http://www.rjhcoding.com/avrc-sd-interface-1.php
http://www.dejazzer.com/ee379/lecture_notes/lec12_sd_card.pdf
http://chlazza.nfshost.com/sdcardinfo.html

// https://github.com/sylefeb/Silice
// MIT license, see LICENSE_MIT in Silice repo root

*/

const unsigned char cmd0[]   = {0x40,0x00,0x00,0x00,0x00,0x95};
const unsigned char cmd8[]   = {0x48,0x00,0x00,0x01,0xAA,0x87};
const unsigned char cmd55[]  = {0x77,0x00,0x00,0x00,0x00,0x01};
const unsigned char acmd41[] = {0x69,0x40,0x00,0x00,0x00,0x01};
const unsigned char cmd16[]  = {0x50,0x00,0x00,0x02,0x00,0x15};
const unsigned char cmd17[]  = {0x51,0x00,0x00,0x00,0x00,0x55};

#define SD_DELAY() asm volatile ("nop;");

void sdcard_select()
{
    *SDCARD = 2;
}

// Keep the clock running a bit
//   unclear whether this is really important https://electronics.stackexchange.com/questions/303745/sd-card-initialization-problem-cmd8-wrong-response
void sdcard_ponder()
{
  int clk = 0;
  for (int i = 0; i < 16 ; i++) {
      *SDCARD = 4 | 2 | clk;
      clk     = 1 - clk;
      SD_DELAY();
  }
}

void sdcard_unselect()
{
  *SDCARD = 4 | 2;
}

#define sdcard_send_step(data) \
    mosi        = (data >> 7)&1;\
    data        = data << clk;\
    *SDCARD     = (mosi<<1) | clk;\
    clk         = 1-clk;\
    asm volatile ("nop; nop; nop; nop;");\
    SD_DELAY()

void sdcard_send(int indata)
{
  int clk  = 0;
  int mosi = 0;
  int data = indata;
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  sdcard_send_step(data); asm volatile ("nop;nop;"); sdcard_send_step(data);
  *SDCARD = 2; // mosi = 1
}

#define sdcard_read_step_L() \
    *SDCARD     = 2;\
    ud          = *SDCARD;\
    answer      = (answer << 1) | (ud);\
    SD_DELAY()

#define sdcard_read_step_H() \
    *SDCARD     = 3;\
    n ++;\
    asm volatile ("nop; nop; nop; nop; nop; nop;");\
    SD_DELAY()

unsigned char sdcard_read(unsigned char in_len,unsigned char in_wait)
{
    int wait = in_wait;
    int len  = in_len;
    int ud;
    int n = 0;
    int answer = 0xff;
    while (
          (wait && (answer&(1<<(len-1)))) || (!wait && n < len)) {
        sdcard_read_step_H();
        sdcard_read_step_L();
    }
    return answer;
}

unsigned char sdcard_get(unsigned char len,unsigned char wait)
{
    unsigned char status;
    sdcard_select();
    status = sdcard_read(len,wait);
    for (int i=1;i<len>>3;i++) {
        status = sdcard_read(8,0);
    }
    sdcard_unselect();
    return status;
}

void sdcard_cmd(const unsigned char *cmd)
{
    sdcard_select();
    for (int i=0;i<6;i++) {
        sdcard_send(cmd[i]);
    }
    sdcard_unselect();
}

unsigned char sdcard_start_sector(int sector)
{
    sdcard_select();
    sdcard_send(cmd17[0]);
    sdcard_send((sector>>24)&255);
    sdcard_send((sector>>16)&255);
    sdcard_send((sector>> 8)&255);
    sdcard_send((sector    )&255);
    sdcard_send(cmd17[5]);
    sdcard_unselect();
    return sdcard_get(8,1);
}

unsigned char *sdcard_copy_sector(int sector,unsigned char *dst)
{
  unsigned char status = sdcard_start_sector(sector);
  if (status != 0) {
    return dst;
  } else {
    sdcard_get(1,1); // start token
    for (int i=0;i<512;i++) {
      unsigned char by = sdcard_get(8,0);
      *(dst++)         = by;
    }
    sdcard_get(16,1); // CRC
  }
  return dst;
}

void sdcard_preinit()
{
  *SDCARD = 4 | 2;
  pause(20000000);
  {
    int clk = 0;
    for (int i = 0; i < 160 ; i++) {
      *SDCARD = 4 | 2 | clk;
      clk     = 1 - clk;
      asm volatile ("nop; nop; nop;");
      SD_DELAY();
    }
  }
  *SDCARD = 4 | 2;
}

void sdcard_init()
{
  unsigned char status;
  while (1) {
    sdcard_preinit();
    sdcard_cmd(cmd0);
    status = sdcard_get(8,1);
    sdcard_ponder();
    if (status != 0xff) {
        break;
    }
    pause(20000000);
  }
  sdcard_cmd(cmd8);
  status = sdcard_get(40,1);
  sdcard_ponder();
  while (1) {
    sdcard_cmd(cmd55);
    sdcard_get(8,1);
    sdcard_ponder();
    sdcard_cmd(acmd41);
    status = sdcard_get(8,1);
    sdcard_ponder();
    if (status == 0) {
      break;
    }
    pause(2000000);
  }
  sdcard_cmd(cmd16);
  sdcard_get(8,1);
  sdcard_ponder();
}
