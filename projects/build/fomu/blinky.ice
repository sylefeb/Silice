algorithm main(output uint3 led) {   
  uint28 counter = 0;      // a 28 bits unsigned integer
  led := counter[25,3];    // LEDs updated every clock with the 8 most significant bits  
   while (1) {              // forever
    counter = counter + 1; // increment counter
  }  
}
