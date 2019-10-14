algorithm main(output int8 led)
{

  uint28 counter = 0;      // a 28 bits unsigned integer
  led := counter[20,8];    // LEDs track the 8 most significant bits  
  while (1) {              // forever
    counter = counter + 1; // count
  }

}
