// @sylefeb 2022-01-10

volatile int* const LEDS     = (int*)0x2004;

static inline unsigned int rdcycle()
{
   unsigned int cycles;
   asm volatile ("rdcycle %0" : "=r"(cycles));
   return cycles;
}

static inline void wait(int ncycles)
{
  unsigned int start = rdcycle();
  while ( rdcycle() - start < ncycles ) { }
}

void main()
{
	int i = 0;
	while (1) {
		*LEDS = i;
		++i;
    wait(1000000);
	}
}
