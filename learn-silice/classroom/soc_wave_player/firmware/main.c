// @sylefeb 2022-01-10

volatile int* const LEDS     = (int*)0x2004;

void main()
{
	int i = 0;
	while (1) {
		*LEDS = i;
		++i;
	}
}
