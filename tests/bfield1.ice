bitfield Node {
  uint16 right,
  uint16 left
}

algorithm main()
{
  uint32 data = Node(left=16hffff,right=16h1234);

  uint16 l = 0;
  uint16 r = 0;
 
  l = Node(data).left;
  r = Node(data).right;
 
  __display("%x %x",l,r);  
}