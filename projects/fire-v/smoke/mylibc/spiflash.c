/*
SL - 2021-02-03

SPIFLASH bit-banging from RV32I CPU

I went through the trouble of equalizing all delays to have a clean
spiflash clock period, but maybe that was not necessary.
These delays are tunned to the Fire-V and likely not portable.

//      GNU AFFERO GENERAL PUBLIC LICENSE
//        Version 3, 19 November 2007
//      
//  A copy of the license full text is included in 
//  the distribution, please refer to it for details.

*/

void spiflash_select()
{
  *SPIFLASH = 2;
}

void spiflash_unselect()
{
  *SPIFLASH = 4 | 2;
}

#define spiflash_send_step(data) \
    mosi        = (data >> 7)&1;\
    data        = data << clk;\
    *SPIFLASH   = (mosi<<1) | clk;\
    clk         = 1-clk;\
    asm volatile ("nop; nop; nop; addi t0,zero,3; 0: addi t0,t0,-1; bne t0,zero,0b;");\

void spiflash_send(int indata)
{
  register int clk  = 0;
  register int mosi = 0;
  register int data = indata;
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
  spiflash_send_step(data); spiflash_send_step(data);
}

#define spiflash_read_step_L() \
    *SPIFLASH    = 2;\
    asm volatile ("rdtime %0" : "=r"(ud));\
    answer      = (answer << 1) | ((ud>>3)&1);\
    asm volatile ("addi t0,zero,2; 0: addi t0,t0,-1; bne t0,zero,0b;");\

#define spiflash_read_step_H() \
    *SPIFLASH    = 3;\
    n ++;\
    asm volatile ("addi t0,zero,5; 0: addi t0,t0,-1; bne t0,zero,0b;");\

unsigned char spiflash_read()
{
    register int ud;
    register int n = 0; 
    register int answer = 0xff;
    spiflash_read_step_L();
    while (n < 8) {
        spiflash_read_step_H();
        spiflash_read_step_L();
    }
    return answer & 255;
}

void spiflash_init()
{
  spiflash_select();
  spiflash_send(0xAB);
  spiflash_unselect();
}

unsigned char *spiflash_copy(int addr,unsigned char *dst,int len)
{
  spiflash_select();
  spiflash_send(0x03);
  spiflash_send((addr>>16)&255);
  spiflash_send((addr>> 8)&255);
  spiflash_send((addr    )&255);
  while (len > 0) {
    *dst  = spiflash_read();
    ++ dst;
    -- len;
  }
  spiflash_unselect();
  return dst;
}
