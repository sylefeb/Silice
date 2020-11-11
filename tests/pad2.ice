algorithm main()
{
//  uint8 table[16] = {}; // error
//  uint8 table[16] = {0,1,2}; // error
  uint8 table[16] = {0,1,2,pad(255)};
//  uint8 table[16] = {pad(31)};
//  uint8 table[16] = {0,1,2,pad(uninitialized)};
//  uint8 table[16] = {pad(uninitialized)};
//  uint8 table[16] = uninitialized;
 
 uint8 next = 0;
 while (next < 16) {
   uint8 v = 0;
   v = table[next];
   __display("%d",v);
   next = next + 1;
 }

}
