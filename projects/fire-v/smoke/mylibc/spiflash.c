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

#define DELAY() asm volatile ("addi t0,zero,1; 0: addi t0,t0,-1; bne t0,zero,0b;");

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
    DELAY()

    /*asm volatile ("nop");*/

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
  *SPIFLASH = 2; // mosi = 1
}

#define spiflash_read_step_L() \
    *SPIFLASH    = 2;\
    asm volatile ("rdtime %0" : "=r"(ud));\
    answer      = (answer << 1) | ((ud>>3)&1);\
    asm volatile ("addi t0,zero,2; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

#define spiflash_read_step_H() \
    *SPIFLASH    = 3;\
    n ++;\
    asm volatile ("addi t0,zero,5; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

unsigned char spiflash_read()
{
    register int ud;
    register int n = 0;
    register int answer = 0xff;
    while (n < 8) {
        spiflash_read_step_H();
        spiflash_read_step_L();
    }
    return answer;
}

void spiflash_init()
{

}
