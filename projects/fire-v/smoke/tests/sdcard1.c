volatile unsigned char* const LEDS        = (unsigned char*)0x90000000;
volatile unsigned int*  const SDCARD      = (unsigned int* )0x90000008;

const unsigned char cmd0[]   = {0x40,0x00,0x00,0x00,0x00,0x95};
const unsigned char cmd8[]   = {0x48,0x00,0x00,0x01,0xAA,0x87};
const unsigned char cmd55[]  = {0x77,0x00,0x00,0x00,0x00,0x01};
const unsigned char acmd41[] = {0x69,0x40,0x00,0x00,0x00,0x01};
const unsigned char cmd16[]  = {0x50,0x00,0x00,0x02,0x00,0x15};
const unsigned char cmd17[]  = {0x51,0x00,0x00,0x00,0x00,0x55};

long time() 
{
   int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

long userdata() 
{
  int id;
  asm volatile ("rdtime %0" : "=r"(id));
  return id;
}

void pause(int cycles)
{ 
  long tm_start = time();
  while (time() - tm_start < cycles) { }
}

unsigned char sdcard_miso()
{
    return (userdata()>>3)&1;
}

#define DELAY() asm volatile ("addi t0,zero,1; 0: addi t0,t0,-1; bne t0,zero,0b;");

#define sdcard_send_step(data) \
    mosi        = (data >> 7)&1;\
    data        = data << clk;\
    *SDCARD     = (mosi<<1) | clk;\
    clk         = 1-clk;\
    asm volatile ("nop; nop; nop; addi t0,zero,3; 0: addi t0,t0,-1; bne t0,zero,0b;");\
    DELAY()

void sdcard_select()
{
    *SDCARD = 2;
}

void sdcard_unselect()
{
    *SDCARD = 4 | 2;
}

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
//  *LEDS = 127;
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
//    *LEDS = 255;
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

void sdcard_init()
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

void main()
{
#if 1

  *LEDS = 255;
  sdcard_select();
  {
    register int clk = 0;
    for (int i = 0; i < 6 ; i++) {
      *SDCARD = 4 | 2 | clk;
      clk     = 1 - clk;
      DELAY();
    }
  }
  *LEDS=127;
  sdcard_send(170);
  *LEDS=3;
  sdcard_get(8,1);
  *LEDS=255;
  sdcard_unselect();
  *LEDS=1;

#else

  for (int k=0;k<4;k++) {
    pause(10000000); 
    *LEDS = 255;
    pause(10000000); 
    *LEDS = 0;
  }

  unsigned char status;

  while (1) {
    *LEDS = 1;
    sdcard_init();
    *LEDS = 2;
    sdcard_cmd(cmd0);
    *LEDS = 3;
    status = sdcard_get(8,1);
    *LEDS = status;
    if (status != 0xff) {
        break;
    }
    *LEDS = 255;
    pause(10000000); 
  }

  *LEDS = 4;
  
  sdcard_cmd(cmd8);
  *LEDS = 0;
  status = sdcard_get(40,1);
  *LEDS = status;

  while (1) {
    sdcard_cmd(cmd55);
    sdcard_get(8,1);
    sdcard_cmd(acmd41);
    status = sdcard_get(8,1);
    *LEDS = status;
    if (status == 0) {
      break;
    }
    *LEDS = 255;
    pause(10000000);
  }

  *LEDS = 7;
  sdcard_cmd(cmd16);
  *LEDS = 8;
  sdcard_get(8,1);
  *LEDS = 170;

  //set_cursor(8,8);
  //for (int i  = 0; i < 16 ; i++) {
  //    printf("init sdcard %d -- cycle %d\n",i,time());
  //}

  while (1) { }

#endif

/*
    while (1) {
        sdcard_send((cmd55>>32),cmd55);
        sdcard_read(8,1);
        sdcard_send((acmd41>>32),acmd41);
        unsigned char v = sdcard_read(8,1);
        if (v == 0) {
            break;
        }
    }

    sdcard_send((cmd16>>32),cmd16);
    sdcard_read(8,1);

    // wait for vsync
    while ((userdata()&2) == 0) {  }    
    // swap buffers
    *(LEDS+4) = 1;
    fbuffer = 1-fbuffer;
*/

  // *(SDCARD) = 0;
  //*(SDCARD+ 4) = 1;
  //*(SDCARD+ 8) = 2;

  /*
  *(SDCARD+16) = 3;
  *(SDCARD+32) = 0x03FFFFF8;
  *LEDS= 3;
  while ((userdata()&8) == 0) { *LEDS= userdata(); }
  *LEDS= 5;
  unsigned char v = *((unsigned char *)0x03FFFFF8);
  *LEDS= v;
  */
}
