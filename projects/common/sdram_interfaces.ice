// -----------------------------------------------------------
// @sylefeb A SDRAM controller in Silice
//
// SDRAM interface definitions
//

// -----------------------------------------------------------

// SDRAM, raw data exchange (1 byte write, 16 bytes read)
group sdram_raw_io
{
  uint26  addr       = 0,  // addressable bytes (internally deals with 16 bits wide sdram)
  uint1   rw         = 0,
  uint8   data_in    = 0,  //   8 bits write
  uint128 data_out   = 0,  // 128 bits read (8x burst of 16 bits)
  uint1   busy       = 1,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// SDRAM, byte data exchange
// emulates a simple byte rw interface
// reads are cached (burst length)

group sdram_byte_io
{
  uint26  addr       = 0,  // addressable bytes
  uint1   rw         = 0,
  uint8   data_in    = 0,  // write byte
  uint8   data_out   = 0,  // read byte
  uint1   busy       = 1,
  uint1   in_valid   = 0,
  uint1   out_valid  = 0
}

// => NOTE how sdram_raw_io and sdram_byte_io are compatible in terms of named members
//         this allows using the same interface for both

// Interfaces

// interface for user
interface sdram_user {
  output  addr,
  output  rw,
  output  data_in,
  output  in_valid,
  input   data_out,
  input   busy,
  input   out_valid,
}

// interface for provider
interface sdram_provider {
  input   addr,
  input   rw,
  input   data_in,
  output  data_out,
  output  busy,
  input   in_valid,
  output  out_valid
}

// -----------------------------------------------------------
