
$$error('foo\n'
$$    ..'bar.')

algorithm main(output uint8 l)
{
  $display()
	__verilog("\$c(\"f(\",a,\")\")");
}
