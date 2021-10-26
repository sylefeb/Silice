bitfield Node {
  uint16 right,
  uint16 left
}

algorithm main(output uint8 leds)
{
  uint32 data = Node(left=16hffff,right=16hab34);

  __display("%x", Node(data).right[8,8] );
 }
 