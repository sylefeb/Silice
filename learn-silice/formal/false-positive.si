algorithm main() {}


algorithm# false_positive(input uint8 x) <#depth=5>
{
  uint8 cnt = 0;

  while (cnt < 10)
  {
    cnt = cnt + 1;
  }

  // Because the depth is set to 5, this #assert statement is never reached.
  // This is a problem, because Symbiyosys will report this design as passing all tests,
  // therefore returning an incorrect report.
  #assert(0);
}
