unsigned char* const FRAMEBUFFER = (unsigned char*)0x4000000;

unsigned int test  = 0xffaa2211;
unsigned int foo   = 0x00000000;
unsigned int space = 0x00000000;

void main() 
{

  // *(FRAMEBUFFER) = *(((unsigned char*)&test) + 1);

  *(((unsigned short*)(FRAMEBUFFER))+1) = *(((unsigned short*)&test) + 1);

  foo = *(((unsigned int*)(FRAMEBUFFER)));

  *(((unsigned int*)(FRAMEBUFFER)) + 1) = foo;

  foo = *(((unsigned int*)(FRAMEBUFFER+1)));

  asm(".word 0\n"); // SL: halts CPU
}
