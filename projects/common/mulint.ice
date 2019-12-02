// Sylvain Lefebvre; simple parallel multiplication; 2019-12-02
//
// Why? The goal is to achieve a multi-cycle multiplication
// with small combinational chains
//

algorithm mul(input uint8 m0,input uint8 m1,output! uint8 ret)
{
  uint8 sum01 = 0;
  uint8 sum23 = 0;
  uint8 sum45 = 0;
  uint8 sum67 = 0;

  uint8 sum0123 = 0;
  uint8 sum4567 = 0;

  switch (m1[0,2]) {
  case 2b00: { }
  case 2b10: { sum01 = m0 << 1; }
  case 2b01: { sum01 = m0; }
  case 2b11: { sum01 = m0 + (m0 << 1); }
  }
  switch (m1[2,2]) {
  case 2b00: { }
  case 2b10: { sum23 = m0 << 3; }
  case 2b01: { sum23 = m0 << 2; }
  case 2b11: { sum23 = (m0 << 2) + (m0 << 3); }
  }
  switch (m1[4,2]) {
  case 2b00: { }
  case 2b10: { sum45 = m0 << 5; }
  case 2b01: { sum45 = m0 << 4; }
  case 2b11: { sum45 = (m0 << 4) + (m0 << 5); }
  }
  switch (m1[6,2]) {
  case 2b00: { }
  case 2b10: { sum67 = m0 << 7; }
  case 2b01: { sum67 = m0 << 6; }
  case 2b11: { sum67 = (m0 << 6) + (m0 << 7); }
  }
++: // two stages at once? todo: make it configurable with pre-processor
  sum0123 = sum01 + sum23;
  sum4567 = sum45 + sum67;
  ret = sum0123 + sum4567;
}

