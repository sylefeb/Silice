// Copyright 2013 Frederic Requin
//
// This file is part of the MCC216 project (www.arcaderetrogaming.com)
//
// The SDRAM C++ model is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 3 of the License, or
// (at your option) any later version.
//
// The SDRAM C++ model is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
// SDRAM C++ model:
// ----------------
//  - Based on the verilog model from Micron : "mt48lc8m16a2.v" // 2 meg x 16 x 4 banks
//  - Designed to work with "Verilator" tool (www.veripool.org)
//  - 8/16/32-bit data bus supported
//  - 4 banks only
//  - Two memory layouts : interleaved banks or contiguous banks
//  - Sequential burst only, no interleaved burst yet
//  - Binary images can be loaded to and saved from SDRAM
//  - Debug mode to trace every SDRAM access
//  - Endianness support for 16 and 32-bit memories
//
// TODO:
//  - Add interleaved burst support
//
// 2020-03-03 - included in silice project, Sylvain Lefebvre, @sylefeb

#ifndef _SDR_SDRAM_H_
#define _SDR_SDRAM_H_

#include "verilated.h"

#define SDRAM_NUM_BANKS        (4)
#define SDRAM_BIT_BANKS        (2)
#define CMD_PIPE_DEPTH         (4)
#define DQM_PIPE_DEPTH         (2)

#define FLAG_DATA_WIDTH_8      ((vluint8_t)0x00)
#define FLAG_DATA_WIDTH_16     ((vluint8_t)0x01)
#define FLAG_DATA_WIDTH_32     ((vluint8_t)0x03)
#define FLAG_DATA_WIDTH_64     ((vluint8_t)0x07)
#define FLAG_BANK_INTERLEAVING ((vluint8_t)0x08)
#define FLAG_BIG_ENDIAN        ((vluint8_t)0x10)
#define FLAG_RANDOM_FILLED     ((vluint8_t)0x20)
#define FLAG_DEBUG_ON          ((vluint8_t)0x40)

class SimulSDRAM
{
    public:
        // Constructor and destructor
        SimulSDRAM(vluint8_t log2_rows, vluint8_t log2_cols, vluint8_t flags, char *logfile);
        ~SimulSDRAM();
        // Methods
        void load(const char *name, vluint32_t size,  vluint32_t addr);
        void save(const char *name, vluint32_t size,  vluint32_t addr);
        void eval(vluint64_t ts,    vluint8_t clk,    vluint8_t  cke,
                  vluint8_t  cs_n,  vluint8_t ras_n,  vluint8_t  cas_n, vluint8_t we_n,
                  vluint8_t  ba,    vluint16_t addr,
                  vluint8_t  dqm,   vluint64_t dq_in, vluint64_t &dq_out);
        vluint8_t  read_byte(vluint32_t addr);
        vluint16_t read_word(vluint32_t addr);
        vluint32_t read_long(vluint32_t addr);
        vluint64_t read_quad(vluint32_t addr);
        vluint32_t mem_size;
    private:
        // Byte reading functions (to speedup access)
        vluint8_t  (SimulSDRAM::*read_byte_priv)(vluint32_t);
        vluint8_t  read_byte_i_be_8(vluint32_t addr);
        vluint8_t  read_byte_i_be_16(vluint32_t addr);
        vluint8_t  read_byte_i_be_32(vluint32_t addr);
        vluint8_t  read_byte_i_be_64(vluint32_t addr);
        vluint8_t  read_byte_i_le_8(vluint32_t addr);
        vluint8_t  read_byte_i_le_16(vluint32_t addr);
        vluint8_t  read_byte_i_le_32(vluint32_t addr);
        vluint8_t  read_byte_i_le_64(vluint32_t addr);
        vluint8_t  read_byte_c_be_8(vluint32_t addr);
        vluint8_t  read_byte_c_be_16(vluint32_t addr);
        vluint8_t  read_byte_c_be_32(vluint32_t addr);
        vluint8_t  read_byte_c_be_64(vluint32_t addr);
        vluint8_t  read_byte_c_le_8(vluint32_t addr);
        vluint8_t  read_byte_c_le_16(vluint32_t addr);
        vluint8_t  read_byte_c_le_32(vluint32_t addr);
        vluint8_t  read_byte_c_le_64(vluint32_t addr);
        // SDRAM capacity
        int        bus_mask;                     // Data bus width (bytes - 1)
        int        bus_log2;                     // Data bus width (log2(bytes))
        int        num_rows;                     // Number of rows
        int        num_cols;                     // Number of columns
        int        bit_rows;                     // Number of rows (log 2)
        int        bit_cols;                     // Number of columns (log 2)
        vluint32_t mask_bank;                    // Bit mask for banks
        vluint32_t mask_rows;                    // Bit mask for rows
        vluint32_t mask_cols;                    // Bit mask for columns
        // Memory arrays
        vluint8_t *mem_array_7[SDRAM_NUM_BANKS]; // MSB
        vluint8_t *mem_array_6[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_5[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_4[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_3[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_2[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_1[SDRAM_NUM_BANKS];
        vluint8_t *mem_array_0[SDRAM_NUM_BANKS]; // LSB
        // Mode register
        int        cas_lat;                      // CAS latency (2 or 3)
        int        bst_len_rd;                   // Burst length during read
        int        bst_len_wr;                   // Burst length during write
        vluint8_t  bst_type;                     // Burst type
        // Debug mode
        vluint8_t  dbg_on;
        // Special memory flags
        vluint8_t  mem_flags;
        // Internal variables
        vluint8_t  prev_clk;                     // Previous clock state
        vluint8_t  cmd_pipe[CMD_PIPE_DEPTH];     // Command pipeline
        int        col_pipe[CMD_PIPE_DEPTH];     // Column address pipeline
        vluint8_t  ba_pipe[CMD_PIPE_DEPTH];      // Bank address pipeline
        vluint8_t  bap_pipe[CMD_PIPE_DEPTH];     // Bank precharge pipeline
        vluint8_t  a10_pipe[CMD_PIPE_DEPTH];     // A[10] wire pipeline
        vluint8_t  dqm_pipe[DQM_PIPE_DEPTH];     // DQM pipeline (for read)
        vluint8_t  row_act[SDRAM_NUM_BANKS];     // Bank activate
        vluint8_t  row_pre[SDRAM_NUM_BANKS];     // Bank precharge
        int        row_addr[SDRAM_NUM_BANKS];    // Row address during activate
        vluint8_t  ap_bank[SDRAM_NUM_BANKS];     // Bank being auto-precharged
        int        bank;                         // Current bank during read/write
        int        row;                          // Current row during read/write
        int        col;                          // Current column during read/write
        int        bst_ctr_rd;                   // Burst counter (read)
        int        bst_ctr_wr;                   // Burst counter (write)
public:
        // Log file
        FILE      *fh_log;
        char      *log_buf;
        int        log_size;
};

#endif /* _SDR_SDRAM_H_ */
