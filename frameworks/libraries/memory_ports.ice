// ----------------------- memory_ports.ice -----------
// @sylefeb - Silice standard library
// Memory port interfaces
// 2020-09-03

// single port BRAM

interface bram_port {
  output! addr,
  output! wenable,
  input   rdata,
  output! wdata,
}

// single port BROM

interface brom_port {
  output! addr,
  input   rdata,
}

// dual port BRAM

interface dualbram_port0 {
  output! addr0,
  output! wenable0,
  input   rdata0,
  output! wdata0,
}

interface dualbram_port1 {
  output! addr1,
  output! wenable1,
  input   rdata1,
  output! wdata1,
}

// simple dual port BRAM

interface simple_dualbram_port0 {
  output! addr0,
  input   rdata0,
}

interface simple_dualbram_port1 {
  output! addr1,
  output! wenable1,
  output! wdata1,
}

interface bram_ports {
  output! addr0,
  output! wenable0,
  input   rdata0,
  output! wdata0,
  output! addr1,
  output! wenable1,
  input   rdata1,
  output! wdata1,
}

// ----------------------- end of memory_ports.ice ----
