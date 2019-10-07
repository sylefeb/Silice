algorithm main(output int8 led)
{
int22 data  = 0;
int8  myled = 0;

led  := myled;

data  = 1;
myled = 0;

start:

  data = data + 1;
  if (data == 0) {
    myled = myled << 1;
    if (myled == 0) {
      myled = 1;
    }
  }

goto start;
}
