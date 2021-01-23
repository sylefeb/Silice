const unsigned char cmd0[]   = {0x40,0x00,0x00,0x00,0x00,0x95};
const unsigned char cmd8[]   = {0x48,0x00,0x00,0x01,0xAA,0x87};
const unsigned char cmd55[]  = {0x77,0x00,0x00,0x00,0x00,0x01};
const unsigned char acmd41[] = {0x69,0x40,0x00,0x00,0x00,0x01};
const unsigned char cmd16[]  = {0x50,0x00,0x00,0x02,0x00,0x15};
const unsigned char cmd17[]  = {0x51,0x00,0x00,0x00,0x00,0x55};

#define DELAY() asm volatile ("addi t0,zero,1; 0: addi t0,t0,-1; bne t0,zero,0b;");

void sdcard_select()
{
    *SDCARD = 2;
}

// keep the clock running a bit
// https://electronics.stackexchange.com/questions/303745/sd-card-initialization-problem-cmd8-wrong-response
void sdcard_ponder()
{
  register int clk = 0;
  for (int i = 0; i < 16 ; i++) {
      *SDCARD = 4 | 2 | clk;
      clk     = 1 - clk;
      DELAY();
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
    asm volatile ("nop; nop; nop; addi t0,zero,3; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

    /*asm volatile ("nop");*/

void sdcard_send(int indata)
{
  register int clk  = 0;
  register int mosi = 0;
  register int data = indata;
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  sdcard_send_step(data); sdcard_send_step(data);
  *SDCARD = 2; // mosi = 1
}

#define sdcard_read_step_L() \
    *SDCARD     = 2;\
    asm volatile ("rdtime %0" : "=r"(ud));\
    answer      = (answer << 1) | ((ud>>3)&1);\
    asm volatile ("addi t0,zero,2; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

#define sdcard_read_step_H() \
    *SDCARD     = 3;\
    n ++;\
    asm volatile ("addi t0,zero,5; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

unsigned char sdcard_read(unsigned char in_len,unsigned char in_wait)
{
    register int wait = in_wait;
    register int len  = in_len;
    register int ud;
    register int n = 0;
    register int answer = 0xff;

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
  pause(10000000); // 0.1 sec @100MHz
  {
    register int clk = 0;
    for (int i = 0; i < 160 ; i++) {
      *SDCARD = 4 | 2 | clk;
      clk     = 1 - clk;
      DELAY();
    }
  }
  *SDCARD = 4 | 2;
}

void sdcard_init()
{
  unsigned char status;
  *LEDS = 128 | 1;
  while (1) {
    sdcard_preinit();
    sdcard_cmd(cmd0);
    status = sdcard_get(8,1);
    sdcard_ponder();    
  *LEDS = 128 | 2;
    if (status != 0xff) {
        break;
    }
    pause(10000000); 
  }  
  *LEDS = 128 | 3;
  sdcard_cmd(cmd8);
  status = sdcard_get(40,1);
  sdcard_ponder();
  *LEDS = 128 | 4;  
  while (1) {
    sdcard_cmd(cmd55);
    sdcard_get(8,1);
  *LEDS = 128 | 5;  
    sdcard_ponder();
    sdcard_cmd(acmd41);
    status = sdcard_get(8,1);
  *LEDS = 128 | 6;  
    sdcard_ponder();    
    if (status == 0) {
      break;
    }
    pause(1000000);
  }
  *LEDS = 128 | 7;  
  sdcard_cmd(cmd16);
  sdcard_get(8,1);
  sdcard_ponder();
}
