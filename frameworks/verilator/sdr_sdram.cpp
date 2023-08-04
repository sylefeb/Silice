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
//  - Based on the verilog model from Micron : "mt48lc8m16a2.v"
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

#include "verilated.h"
#include "sdr_sdram.h"
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

#include <iostream>

// SDRAM commands
#define CMD_LMR  ((vluint8_t)0)
#define CMD_REF  ((vluint8_t)1)
#define CMD_PRE  ((vluint8_t)2)
#define CMD_ACT  ((vluint8_t)3)
#define CMD_WR   ((vluint8_t)4)
#define CMD_RD   ((vluint8_t)5)
#define CMD_BST  ((vluint8_t)6)
#define CMD_NOP  ((vluint8_t)7)

// Data lanes
#define DATA_MSB ((vluint8_t)0x01)
#define DATA_MSW ((vluint8_t)0x02)
#define DATA_MSL ((vluint8_t)0x04)

// Constructor
SimulSDRAM::SimulSDRAM(vluint8_t log2_rows, vluint8_t log2_cols, vluint8_t flags, char *logfile)
{
    // memory size
    int s       = (int)1 << (log2_rows + log2_cols);
    // SDRAM capacity initialized
    bus_mask    =  flags & (DATA_MSB | DATA_MSW | DATA_MSL);
    bus_log2    = (flags & DATA_MSB) ? 1 : 0;
    bus_log2    = (flags & DATA_MSW) ? 2 : bus_log2;
    bus_log2    = (flags & DATA_MSL) ? 3 : bus_log2;
    bit_rows    = (int)log2_rows;
    bit_cols    = (int)log2_cols;
    num_rows    = (int)1 << log2_rows;
    num_cols    = (int)1 << log2_cols;
    mask_cols   = (num_cols - 1) << bus_log2;
    if (flags & FLAG_BANK_INTERLEAVING)
    {
        // Banks are interleaved
        mask_rows = (vluint32_t)(num_rows        - 1) << (log2_cols + bus_log2 + SDRAM_BIT_BANKS);
        mask_bank = (vluint32_t)(SDRAM_NUM_BANKS - 1) << (log2_cols + bus_log2                  );
    }
    else
    {
        // Banks are contiguous
        mask_rows = (vluint32_t)(num_rows        - 1) << (log2_cols + bus_log2                  );
        mask_bank = (vluint32_t)(SDRAM_NUM_BANKS - 1) << (log2_cols + bus_log2 + SDRAM_BIT_BANKS);
    }
    mem_size    = s << (bus_log2 + SDRAM_BIT_BANKS);
    // Init message
    printf("Instantiating %d MB SDRAM : %d banks x %d rows x %d cols x %d bits\n",
           (mem_size >> 20),SDRAM_NUM_BANKS,num_rows,num_cols,8<<bus_log2);
    // byte reading function
    switch (flags & (DATA_MSB | DATA_MSW | DATA_MSL | FLAG_BANK_INTERLEAVING | FLAG_BIG_ENDIAN))
    {
        // Little endian, contiguous banks
        case 0x00 : read_byte_priv = &SimulSDRAM::read_byte_c_le_8;  break;
        case 0x01 : read_byte_priv = &SimulSDRAM::read_byte_c_le_16; break;
        case 0x02 : read_byte_priv = &SimulSDRAM::read_byte_c_le_32; break;
        case 0x03 : read_byte_priv = &SimulSDRAM::read_byte_c_le_32; break;
        case 0x04 : read_byte_priv = &SimulSDRAM::read_byte_c_le_64; break;
        case 0x05 : read_byte_priv = &SimulSDRAM::read_byte_c_le_64; break;
        case 0x06 : read_byte_priv = &SimulSDRAM::read_byte_c_le_64; break;
        case 0x07 : read_byte_priv = &SimulSDRAM::read_byte_c_le_64; break;
        // Little endian, interleaved banks
        case 0x08 : read_byte_priv = &SimulSDRAM::read_byte_i_le_8;  break;
        case 0x09 : read_byte_priv = &SimulSDRAM::read_byte_i_le_16; break;
        case 0x0A : read_byte_priv = &SimulSDRAM::read_byte_i_le_32; break;
        case 0x0B : read_byte_priv = &SimulSDRAM::read_byte_i_le_32; break;
        case 0x0C : read_byte_priv = &SimulSDRAM::read_byte_i_le_64; break;
        case 0x0D : read_byte_priv = &SimulSDRAM::read_byte_i_le_64; break;
        case 0x0E : read_byte_priv = &SimulSDRAM::read_byte_i_le_64; break;
        case 0x0F : read_byte_priv = &SimulSDRAM::read_byte_i_le_64; break;
        // Big endian, contiguous banks
        case 0x10 : read_byte_priv = &SimulSDRAM::read_byte_c_be_8;  break;
        case 0x11 : read_byte_priv = &SimulSDRAM::read_byte_c_be_16; break;
        case 0x12 : read_byte_priv = &SimulSDRAM::read_byte_c_be_32; break;
        case 0x13 : read_byte_priv = &SimulSDRAM::read_byte_c_be_32; break;
        case 0x14 : read_byte_priv = &SimulSDRAM::read_byte_c_be_64; break;
        case 0x15 : read_byte_priv = &SimulSDRAM::read_byte_c_be_64; break;
        case 0x16 : read_byte_priv = &SimulSDRAM::read_byte_c_be_64; break;
        case 0x17 : read_byte_priv = &SimulSDRAM::read_byte_c_be_64; break;
        // Big endian, interleaved banks
        case 0x18 : read_byte_priv = &SimulSDRAM::read_byte_i_be_8;  break;
        case 0x19 : read_byte_priv = &SimulSDRAM::read_byte_i_be_16; break;
        case 0x1A : read_byte_priv = &SimulSDRAM::read_byte_i_be_32; break;
        case 0x1B : read_byte_priv = &SimulSDRAM::read_byte_i_be_32; break;
        case 0x1C : read_byte_priv = &SimulSDRAM::read_byte_i_be_64; break;
        case 0x1D : read_byte_priv = &SimulSDRAM::read_byte_i_be_64; break;
        case 0x1E : read_byte_priv = &SimulSDRAM::read_byte_i_be_64; break;
        case 0x1F : read_byte_priv = &SimulSDRAM::read_byte_i_be_64; break;
    }

    // debug mode
    if (logfile)
    {
        fh_log   = fopen(logfile, "w");
        log_buf  = new char[2048];
        log_size = 0;
        if ((fh_log) && (log_buf))
        {
            printf("SDRAM log file \"%s\" created\n", logfile);
            dbg_on = 1;
        }
        else
        {
            dbg_on = 0;
        }
    }
    else
    {
        fh_log   = (FILE *)NULL;
        log_buf  = (char *)NULL;
        log_size = 0;
        dbg_on   = 0;
    }

    // special flags
    mem_flags   = flags;

    // mode register cleared
    cas_lat     = 0;
    bst_len_rd  = (int)0;
    bst_len_wr  = (int)0;
    bst_type    = (vluint8_t)0;

    // internal variables cleared
    prev_clk    = (vluint8_t)0;
    for (int i = 0; i < CMD_PIPE_DEPTH; i++)
    {
        cmd_pipe[i] = CMD_NOP;
        col_pipe[i] = (int)0;
        ba_pipe[i]  = (vluint8_t)0;
        bap_pipe[i] = (vluint8_t)0;
        a10_pipe[i] = (vluint16_t)0;
    }
    dqm_pipe[0] = (vluint8_t)0;
    dqm_pipe[1] = (vluint8_t)0;
    for (int i = 0; i < SDRAM_NUM_BANKS; i++)
    {
        row_act[i]  = (vluint8_t)1;
        row_pre[i]  = (vluint8_t)0;
        row_addr[i] = (int)0;
        ap_bank[i]  = (vluint8_t)0;
    }
    bank        = (int)0;
    row         = (int)0;
    col         = (int)0;
    bst_ctr_rd  = (int)0;
    bst_ctr_wr  = (int)0;

    // one array per byte lane and per bank (up to 16 arrays)
    for (int i = 0; i < SDRAM_NUM_BANKS; i++)
    {
                              mem_array_0[i] = new vluint8_t[s];
        if (flags & DATA_MSB) mem_array_1[i] = new vluint8_t[s];
        if (flags & DATA_MSW) mem_array_2[i] = new vluint8_t[s];
        if (flags & DATA_MSW) mem_array_3[i] = new vluint8_t[s];
        if (flags & DATA_MSL) mem_array_4[i] = new vluint8_t[s];
        if (flags & DATA_MSL) mem_array_5[i] = new vluint8_t[s];
        if (flags & DATA_MSL) mem_array_6[i] = new vluint8_t[s];
        if (flags & DATA_MSL) mem_array_7[i] = new vluint8_t[s];
    }

    if (flags & FLAG_RANDOM_FILLED)
    {
        // fill the arrays with random numbers
        srand (time (NULL));
        for (int i = 0; i < SDRAM_NUM_BANKS; i++)
        {
            for (int j = 0; j < s; j++)
            {
                                      mem_array_0[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSB) mem_array_1[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSW) mem_array_2[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSW) mem_array_3[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSL) mem_array_4[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSL) mem_array_5[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSL) mem_array_6[i][j] = (vluint8_t)rand() & 0xFF;
                if (flags & DATA_MSL) mem_array_7[i][j] = (vluint8_t)rand() & 0xFF;
            }
        }
    }
    else
    {
        // clear the arrays
        for (int i = 0; i < SDRAM_NUM_BANKS; i++)
        {
            for (int j = 0; j < s; j++)
            {
                                      mem_array_0[i][j] = (vluint8_t)0;
                if (flags & DATA_MSB) mem_array_1[i][j] = (vluint8_t)0;
                if (flags & DATA_MSW) mem_array_2[i][j] = (vluint8_t)0;
                if (flags & DATA_MSW) mem_array_3[i][j] = (vluint8_t)0;
                if (flags & DATA_MSL) mem_array_4[i][j] = (vluint8_t)0;
                if (flags & DATA_MSL) mem_array_5[i][j] = (vluint8_t)0;
                if (flags & DATA_MSL) mem_array_6[i][j] = (vluint8_t)0;
                if (flags & DATA_MSL) mem_array_7[i][j] = (vluint8_t)0;
            }
        }
    }
}

// Destructor
SimulSDRAM::~SimulSDRAM()
{
    // free the memory
    for (int i = 0; i < SDRAM_NUM_BANKS; i++)
    {
                                  delete[] mem_array_0[i];
        if (mem_flags & DATA_MSB) delete[] mem_array_1[i];
        if (mem_flags & DATA_MSW) delete[] mem_array_2[i];
        if (mem_flags & DATA_MSW) delete[] mem_array_3[i];
        if (mem_flags & DATA_MSL) delete[] mem_array_4[i];
        if (mem_flags & DATA_MSL) delete[] mem_array_5[i];
        if (mem_flags & DATA_MSL) delete[] mem_array_6[i];
        if (mem_flags & DATA_MSL) delete[] mem_array_7[i];
    }
}

// Binary file loading
void SimulSDRAM::load(const char *name, vluint32_t size, vluint32_t addr)
{
    FILE *fh;

    fh = fopen(name, "rb");
    if (fh)
    {
        int        row_size; // Row size (num_cols * 1, 2 or 4)
        vluint8_t *row_buf;  // Row buffer
        int        row_pos;  // Row position (0 to num_rows - 1)
        int        bank_nr;  // Bank number (0 to 3)
        int        idx;      // Array index (0 to num_cols * num_rows - 1)

        // Row size computation based on data bus width
        row_size = (int)1 << (bit_cols + bus_log2);
        // Allocate one full row
        row_buf = new vluint8_t[row_size];

        // Row position
        row_pos = (int)addr >> (bit_cols + bus_log2);
        // Banks layout
        if (mem_flags & FLAG_BANK_INTERLEAVING)
        {
            // Banks are interleaved
            bank_nr = row_pos & (SDRAM_NUM_BANKS - 1);
            row_pos = row_pos >> SDRAM_BIT_BANKS;
        }
        else
        {
            // Banks are contiguous
            bank_nr = row_pos >> bit_rows;
            row_pos = row_pos & (num_rows - 1);
        }
        idx = row_pos << bit_cols;

        printf("Starting row : %d, starting bank : %d\n", row_pos, bank_nr);
        printf("Loading 0x%08X bytes @ 0x%08X from binary file \"%s\"...", size, addr, name);
        for (int i = 0; i < (int)size; i += row_size)
        {
            // Read one full row from the binary file
            fread((void *)row_buf, row_size, 1, fh);

            // Here, we take care of the endianness
            if (mem_flags & FLAG_BIG_ENDIAN)
            {
                // MSB first (motorola's way)
                for (int j = 0; j < row_size; )
                {
                    // Write MSL (if present)
                    if (mem_flags & DATA_MSL)
                    {
                        mem_array_7[bank_nr][idx] = row_buf[j++];
                        mem_array_6[bank_nr][idx] = row_buf[j++];
                        mem_array_5[bank_nr][idx] = row_buf[j++];
                        mem_array_4[bank_nr][idx] = row_buf[j++];
                    }
                    // Write MSW (if present)
                    if (mem_flags & DATA_MSW)
                    {
                        mem_array_3[bank_nr][idx] = row_buf[j++];
                        mem_array_2[bank_nr][idx] = row_buf[j++];
                    }
                    // Write MSB (if present)
                    if (mem_flags & DATA_MSB)
                    {
                        mem_array_1[bank_nr][idx] = row_buf[j++];
                    }
                    // Write LSB
                    mem_array_0[bank_nr][idx] = row_buf[j++];
                    // Next word
                    idx++;
                }
            }
            else
            {
                // LSB first (intel's way)
                for (int j = 0; j < row_size; )
                {
                    // Write LSB
                    mem_array_0[bank_nr][idx] = row_buf[j++];
                    // Write MSB (if present)
                    if (mem_flags & DATA_MSB)
                    {
                        mem_array_1[bank_nr][idx] = row_buf[j++];
                    }
                    // Write MSW (if present)
                    if (mem_flags & DATA_MSW)
                    {
                        mem_array_2[bank_nr][idx] = row_buf[j++];
                        mem_array_3[bank_nr][idx] = row_buf[j++];
                    }
                    // Write MSL (if present)
                    if (mem_flags & DATA_MSL)
                    {
                        mem_array_4[bank_nr][idx] = row_buf[j++];
                        mem_array_5[bank_nr][idx] = row_buf[j++];
                        mem_array_6[bank_nr][idx] = row_buf[j++];
                        mem_array_7[bank_nr][idx] = row_buf[j++];
                    }
                    // Next word
                    idx++;
                }
            }

            // Compute next row's address
            if (mem_flags & FLAG_BANK_INTERLEAVING)
            {
                // Increment bank number
                bank_nr = (bank_nr + 1) & (SDRAM_NUM_BANKS - 1);

                // Bank #3 -> bank #0
                if (!bank_nr)
                {
                    row_pos ++;
                    if ((row_pos == (int)num_rows) && ((i + row_size) < (int)size))
                    {
                        printf("Memory overflow while loading !!\n");
                        return;
                    }
                }
                else
                {
                    idx -= (int)num_cols;
                }
            }
            else
            {
                // Increment row position
                row_pos = (row_pos + 1) & ((int)num_rows - 1);

                // Last row in a bank
                if (!row_pos)
                {
                    idx = 0;
                    bank_nr++;
                    if ((bank_nr == SDRAM_NUM_BANKS) && ((i + row_size) < (int)size))
                    {
                        printf("Memory overflow while loading !!\n");
                        return;
                    }
                }
            }
        }
        printf("OK\n");

        delete[] row_buf;
    }
    else
    {
        printf("Cannot load binary file \"%s\" !!\n", name);
    }
}

// Binary file saving
void SimulSDRAM::save(const char *name, vluint32_t size, vluint32_t addr)
{
    FILE *fh;

    fh = fopen(name, "wb");
    if (fh)
    {
        int        row_size; // Row size (num_cols * 1, 2 or 4)
        vluint8_t *row_buf;  // Row buffer
        int        row_pos;  // Row position (0 to num_rows - 1)
        int        bank_nr;  // Bank number (0 to 3)
        int        idx;      // Array index (0 to num_cols * num_rows - 1)

        // Row size computation based on data bus width
        row_size = (int)1 << (bit_cols + bus_log2);
        // Allocate one full row
        row_buf = new vluint8_t[row_size];

        // Row position
        row_pos = (int)addr >> (bus_log2 + bit_cols);
        // Banks layout
        if (mem_flags & FLAG_BANK_INTERLEAVING)
        {
            // Banks are interleaved
            bank_nr = row_pos & (SDRAM_NUM_BANKS - 1);
            row_pos = row_pos >> SDRAM_BIT_BANKS;
        }
        else
        {
            // Banks are contiguous
            bank_nr = row_pos >> bit_rows;
            row_pos = row_pos & (num_rows - 1);
        }
        idx = row_pos << bit_cols;

        printf("Saving 0x%08X bytes @ 0x%08X to binary file \"%s\"...", size, addr, name);
        for (int i = 0; i < (int)size; i += row_size)
        {
            // Here, we take care of the endianness
            if (mem_flags & FLAG_BIG_ENDIAN)
            {
                // MSB first (motorola's way)
                for (int j = 0; j < row_size; )
                {
                    // Read MSL (if present)
                    if (mem_flags & DATA_MSL)
                    {
                        row_buf[j++] = mem_array_7[bank_nr][idx];
                        row_buf[j++] = mem_array_6[bank_nr][idx];
                        row_buf[j++] = mem_array_5[bank_nr][idx];
                        row_buf[j++] = mem_array_4[bank_nr][idx];
                    }
                    // Read MSW (if present)
                    if (mem_flags & DATA_MSW)
                    {
                        row_buf[j++] = mem_array_3[bank_nr][idx];
                        row_buf[j++] = mem_array_2[bank_nr][idx];
                    }
                    // Read MSB (if present)
                    if (mem_flags & DATA_MSB)
                    {
                        row_buf[j++] = mem_array_1[bank_nr][idx];
                    }
                    // Read LSB
                    row_buf[j++] = mem_array_0[bank_nr][idx];
                    // Next word
                    idx++;
                }
            }
            else
            {
                // LSB first (intel's way)
                for (int j = 0; j < row_size; )
                {
                    // Read LSB
                    row_buf[j++] = mem_array_0[bank_nr][idx];
                    // Read MSB (if present)
                    if (mem_flags & DATA_MSB)
                    {
                        row_buf[j++] = mem_array_1[bank_nr][idx];
                    }
                    // Read MSW (if present)
                    if (mem_flags & DATA_MSW)
                    {
                        row_buf[j++] = mem_array_2[bank_nr][idx];
                        row_buf[j++] = mem_array_3[bank_nr][idx];
                    }
                    // Read MSL (if present)
                    if (mem_flags & DATA_MSL)
                    {
                        row_buf[j++] = mem_array_4[bank_nr][idx];
                        row_buf[j++] = mem_array_5[bank_nr][idx];
                        row_buf[j++] = mem_array_6[bank_nr][idx];
                        row_buf[j++] = mem_array_7[bank_nr][idx];
                    }
                    // Next word
                    idx++;
                }
            }

            // Compute next row's address
            if (mem_flags & FLAG_BANK_INTERLEAVING)
            {
                // Increment bank number
                bank_nr = (bank_nr + 1) & (SDRAM_NUM_BANKS - 1);

                // Bank #3 -> bank #0
                if (!bank_nr)
                {
                    row_pos ++;
                    if ((row_pos == (int)num_rows) && ((i + row_size) < (int)size))
                    {
                        printf("Memory overflow while saving !!\n");
                        return;
                    }
                }
                else
                {
                    idx -= (int)num_cols;
                }
            }
            else
            {
                // Increment row position
                row_pos = (row_pos + 1) & ((int)num_rows - 1);

                // Last row in a bank
                if (!row_pos)
                {
                    idx = 0;
                    bank_nr++;
                    if ((bank_nr == SDRAM_NUM_BANKS) && ((i + row_size) < (int)size))
                    {
                        printf("Memory overflow while saving !!\n");
                        return;
                    }
                }
            }

            // Write one full row to the binary file
            fwrite((void *)row_buf, row_size, 1, fh);
        }
        printf("OK\n");

        delete[] row_buf;
        fclose(fh);
    }
    else
    {
        printf("Cannot save binary file \"%s\" !!\n", name);
    }
}

// Read a byte
vluint8_t SimulSDRAM::read_byte(vluint32_t addr)
{
    return (this->*read_byte_priv)(addr);
}

// Read a word
vluint16_t SimulSDRAM::read_word(vluint32_t addr)
{
    if (mem_flags & FLAG_BIG_ENDIAN)
    {
        return ((vluint16_t)(this->*read_byte_priv)(addr    ) << 8) |
                (vluint16_t)(this->*read_byte_priv)(addr + 1);
    }
    else
    {
        return ((vluint16_t)(this->*read_byte_priv)(addr + 1) << 8) |
                (vluint16_t)(this->*read_byte_priv)(addr    );
    }
}

// Read a long
vluint32_t SimulSDRAM::read_long(vluint32_t addr)
{
    if (mem_flags & FLAG_BIG_ENDIAN)
    {
        return ((vluint32_t)(this->*read_byte_priv)(addr    ) << 24) |
               ((vluint32_t)(this->*read_byte_priv)(addr + 1) << 16) |
               ((vluint32_t)(this->*read_byte_priv)(addr + 2) <<  8) |
                (vluint32_t)(this->*read_byte_priv)(addr + 3);
    }
    else
    {
        return ((vluint32_t)(this->*read_byte_priv)(addr + 3) << 24) |
               ((vluint32_t)(this->*read_byte_priv)(addr + 2) << 16) |
               ((vluint32_t)(this->*read_byte_priv)(addr + 1) <<  8) |
                (vluint32_t)(this->*read_byte_priv)(addr    );
    }
}

// Read a quad
vluint64_t SimulSDRAM::read_quad(vluint32_t addr)
{
    if (mem_flags & FLAG_BIG_ENDIAN)
    {
        return ((vluint64_t)(this->*read_byte_priv)(addr    ) << 56) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) << 48) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) << 40) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) << 32) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) << 24) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) << 16) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) <<  8) |
                (vluint64_t)(this->*read_byte_priv)(addr + 3);
    }
    else
    {
        return ((vluint64_t)(this->*read_byte_priv)(addr + 3) << 56) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) << 48) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) << 40) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) << 32) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) << 24) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 2) << 16) |
               ((vluint64_t)(this->*read_byte_priv)(addr + 1) <<  8) |
                (vluint64_t)(this->*read_byte_priv)(addr    );
    }
}

// Cycle evaluate
void SimulSDRAM::eval
(
    vluint64_t ts,
    // Clock
    vluint8_t clk,
    vluint8_t cke,
    // Commands
    vluint8_t cs_n,
    vluint8_t ras_n,
    vluint8_t cas_n,
    vluint8_t we_n,
    // Address
    vluint8_t ba,
    vluint16_t addr,
    // Data
    vluint8_t dqm,
    vluint64_t dq_in,
    vluint64_t &dq_out
)
{
    // Clock enabled
    if (cke)
    {
        // Rising edge on clock
        if (clk && !(prev_clk))
        {
            vluint8_t  cmd;
            vluint8_t  a10;

            // Decode SDRAM command
            if (!cs_n)
                cmd = (ras_n << 2) | (cas_n << 1) | we_n;
            else
                cmd = CMD_NOP;

            // A[10] wire
            a10 = (vluint8_t)((addr >> 10) & 1);
            // Mask out extra bits
            ba &= (SDRAM_NUM_BANKS - 1);

            // Command pipeline
            for (int i = 0; i < CMD_PIPE_DEPTH; i++)
            {
                if (i == (CMD_PIPE_DEPTH - 1))
                {
                    cmd_pipe[i] = CMD_NOP;
                    col_pipe[i] = (int)0;
                    ba_pipe[i]  = (vluint8_t)0;
                    bap_pipe[i] = (vluint8_t)0;
                    a10_pipe[i] = (vluint16_t)0;
                }
                else
                {
                    cmd_pipe[i] = cmd_pipe[i+1];
                    col_pipe[i] = col_pipe[i+1];
                    ba_pipe[i]  = ba_pipe[i+1];
                    bap_pipe[i] = bap_pipe[i+1];
                    a10_pipe[i] = a10_pipe[i+1];
                }
            }

            // DQM pipeline
            dqm_pipe[0] = dqm_pipe[1];
            dqm_pipe[1] = dqm;

            // Process SDRAM command (immediate)
            switch (cmd)
            {
                // 000 : Load mode register
                case CMD_LMR:
                {
                    if (dbg_on)
                    {
                        printf("Load Std Mode Register @ %lu ps\n", ts);
                        log_size += sprintf(log_buf + log_size, "Load Std Mode Register @ %lu ps\n", ts);
                    }

                    // CAS latency
                    switch((addr >> 4) & 7)
                    {
                        case 2:
                        {
                            if (dbg_on)
                            {
                                printf("CAS latency        = 2 cycles\n");
                                log_size += sprintf(log_buf + log_size, "CAS latency        = 2 cycles\n");
                            }
                            cas_lat = (int)2;
                            break;
                        }
                        case 3:
                        {
                            if (dbg_on)
                            {
                                printf("CAS latency        = 3 cycles\n");
                                log_size += sprintf(log_buf + log_size, "CAS latency        = 3 cycles\n");
                            }
                            cas_lat = (int)3;
                            break;
                        }
                        default:
                        {
                            if (dbg_on)
                            {
                                printf("CAS latency        = ???\n");
                                log_size += sprintf(log_buf + log_size, "CAS latency        = ???\n");
                            }
                            cas_lat = (int)0; // This disables pipelined commands
                        }
                    }

                    // Burst length
                    switch (addr & 7)
                    {
                        case 0:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = 1 word\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = 1 word\n");
                            }
                            bst_len_rd = (int)1;
                            break;
                        }
                        case 1:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = 2 words\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = 2 words\n");
                            }
                            bst_len_rd = (int)2;
                            break;
                        }
                        case 2:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = 4 words\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = 4 words\n");
                            }
                            bst_len_rd = (int)4;
                            break;
                        }
                        case 3:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = 8 words\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = 8 words\n");
                            }
                            bst_len_rd = (int)8;
                            break;
                        }
                        case 7:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = continuous\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = continuous\n");
                            }
                            bst_len_rd = (int)num_cols;
                            break;
                        }
                        default:
                        {
                            if (dbg_on)
                            {
                                printf("Read burst length  = ???\n");
                                log_size += sprintf(log_buf + log_size, "Read burst length  = ???\n");
                            }
                            bst_len_rd = (int)0; // This will disable burst read
                        }
                    }

                    // Burst type
                    if (addr & 8)
                    {
                        if (dbg_on)
                        {
                            printf("Burst type         = interleaved (NOT SUPPORTED !)\n");
                            log_size += sprintf(log_buf + log_size, "Burst type         = interleaved (NOT SUPPORTED !)\n");
                        }
                        bst_type = (vluint8_t)1;
                    }
                    else
                    {
                        if (dbg_on)
                        {
                            printf("Burst type         = sequential\n");
                            log_size += sprintf(log_buf + log_size, "Burst type         = sequential\n");
                        }
                        bst_type = (vluint8_t)0;
                    }

                    // Write burst
                    if (addr & 0x200)
                    {
                        if (dbg_on)
                        {
                            printf("Write burst length = 1\n");
                            log_size += sprintf(log_buf + log_size, "Write burst length = 1\n");
                        }
                        bst_len_wr = (int)1;
                    }
                    else
                    {
                        if (dbg_on)
                        {
                            if (bst_len_rd)
                            {
                                if (bst_len_rd <= (int)8)
                                {
                                    printf("Write burst length = %d word(s)\n", bst_len_rd);
                                    log_size += sprintf(log_buf + log_size, "Write burst length = %d word(s)\n", bst_len_rd);
                                }
                                else
                                {
                                    printf("Write burst length = continuous\n");
                                    log_size += sprintf(log_buf + log_size, "Write burst length = continuous\n");
                                }
                            }
                            else
                            {
                                // This disables burst write
                                printf("Write burst length = ???\n");
                                log_size += sprintf(log_buf + log_size, "Write burst length = ???\n");
                            }
                        }
                        bst_len_wr = bst_len_rd;
                    }
                    break;
                }
                // 001 : Auto refresh
                case CMD_REF:
                {
                    if (dbg_on)
                        log_size += sprintf(log_buf + log_size, "Auto Refresh @ %lu ps\n", ts);

                    for (int i = 0; i < SDRAM_NUM_BANKS; i++)
                    {
                        if (!row_pre[i])
                        {
                            printf("ERROR @ %lu ps : All banks must be Precharge before Auto Refresh\n", ts);
                            break;
                        }
                    }
                    break;
                }
                // 010 : Precharge
                case CMD_PRE:
                {
                    if (a10)
                    {
                        if (dbg_on)
                            log_size += sprintf(log_buf + log_size, "Precharge all banks @ %lu ps\n", ts);

                        if (ap_bank[0] || ap_bank[1] || ap_bank[2] || ap_bank[3])
                        {
                            printf("ERROR @ %lu ps : at least one bank is auto-precharged !\n", ts);
                            break;
                        }

                        // Precharge all banks
                        for (int i = 0; i < SDRAM_NUM_BANKS; i++)
                        {
                            row_act[i] = 0;
                            row_pre[i] = 1;
                        }
                    }
                    else
                    {
                        if (dbg_on)
                            log_size += sprintf(log_buf + log_size, "Precharge bank #%d @ %lu ps\n", ba, ts);

                        if (ap_bank[ba])
                        {
                            printf("ERROR @ %lu ps : cannot apply a precharge to auto-precharged bank %d !\n", ts, ba);
                            break;
                        }

                        // Precharge one bank
                        row_act[ba] = 0;
                        row_pre[ba] = 1;
                    }

                    // Terminate a WRITE immediately
                    if ((a10) || (bank == (int)ba))
                        bst_ctr_wr = 0;

                    // CAS latency pipeline for READ
                    if (cas_lat)
                    {
                        cmd_pipe[cas_lat] = CMD_PRE;
                        bap_pipe[cas_lat] = ba;
                        a10_pipe[cas_lat] = a10;
                    }

                    break;
                }
                // 011 : Activate
                case CMD_ACT:
                {
                    // Mask out extra bits
                    addr &= (num_rows - 1);

                    if (dbg_on)
                        log_size += sprintf(log_buf + log_size, "Activate bank #%d, row #%d @ %lu ps\n", ba, addr, ts);

                    if (row_act[ba])
                    {
                        printf("ERROR @ %lu ps : bank %d already active !\n", ts, ba);
                        break;
                    }

                    row_act[ba]  = 1;
                    row_pre[ba]  = 0;
                    row_addr[ba] = (int)addr << bit_cols;

                    break;
                }
                // 100 : Write
                case CMD_WR:
                {
                    // Mask out extra bits
                    addr &= (mask_cols >> bus_log2);

                    if (dbg_on)
                        log_size += sprintf(log_buf + log_size, "Write bank #%d, col #%d @ %lu ps\n", ba, addr, ts);

                    if (!row_act[ba])
                    {
                        printf("ERROR @ %lu ps : bank %d is not activated for WRITE !\n", ts, ba);
                        break;
                    }

                    // Latch command right away
                    cmd_pipe[0] = CMD_WR;
                    col_pipe[0] = (int)addr;
                    ba_pipe[0]  = ba;

                    // Auto-precharge
                    ap_bank[ba] = a10;

                    break;
                }
                // 101 : Read
                case CMD_RD:
                {
                    // Mask out extra bits
                    addr &= (mask_cols >> bus_log2);

                    if (dbg_on)
                        log_size += sprintf(log_buf + log_size, "Read bank #%d, col #%d @ %lu ps\n", ba, addr, ts);

                    if (!row_act[ba])
                    {
                        printf("ERROR @ %lu ps : bank %d is not activated for READ !\n", ts, ba);
                        break;
                    }

                    // CAS latency pipeline
                    if (cas_lat)
                    {
                        cmd_pipe[cas_lat] = CMD_RD;
                        col_pipe[cas_lat] = (int)addr;
                        ba_pipe[cas_lat]  = ba;
                    }

                    // Auto-precharge
                    ap_bank[ba] = a10;

                    break;
                }
                // 110 : Burst stop
                case CMD_BST:
                {
                    if (dbg_on)
                        log_size += sprintf(log_buf + log_size, "Burst Stop bank #%d @ %lu ps\n", ba, ts);

                    if (ap_bank[ba])
                    {
                        printf("ERROR @ %lu ps : cannot apply a burst stop to auto-precharged bank %d !\n", ts, ba);
                        break;
                    }

                    // Terminate a WRITE immediately
                    bst_ctr_wr = (vluint16_t)0;

                    // CAS latency for READ
                    if (cas_lat)
                    {
                        cmd_pipe[cas_lat] = CMD_BST;
                    }
                    break;
                }
                // 111 : No operation
                default: ;
            }

            // Process SDRAM command (pipelined)
            switch (cmd_pipe[0])
            {
                // 010 : Precharge
                case CMD_PRE:
                {
                    if ((a10_pipe[0]) || (bap_pipe[0] == (vluint8_t)bank))
                        bst_ctr_rd = (int)0;
                    break;
                }
                // 100 : Write
                case CMD_WR:
                {
                    // Bank, row and column addresses in memory array
                    bank       = (int)ba_pipe[0];
                    row        = row_addr[bank] + (col_pipe[0] & ~(bst_len_wr - 1));
                    col        = col_pipe[0] & (bst_len_wr - 1);
                    bst_ctr_rd = (int)0;
                    bst_ctr_wr = bst_len_wr;

                    if (dbg_on)
                    {
                        if (mem_flags & FLAG_BANK_INTERLEAVING)
                            fprintf(fh_log, "%08X : ", ((row_addr[bank] << SDRAM_BIT_BANKS) + (bank << bit_cols) + col_pipe[0]) << bus_log2);
                        else
                            fprintf(fh_log, "%08X : ", (row_addr[bank] + (bank << (bit_rows + bit_cols)) + col_pipe[0]) << bus_log2);
                    }

                    break;
                }
                // 101 : Read
                case CMD_RD:
                {
                    if (dbg_on)
                    {
                        if (bst_ctr_rd) fprintf(fh_log, "\n");
                        if (log_size && fh_log) fprintf(fh_log, "%s", log_buf);
                        log_size = 0;
                    }

                    // Bank, row and column addresses in memory array
                    bank       = (int)ba_pipe[0];
                    row        = row_addr[bank] + (col_pipe[0] & ~(bst_len_rd - 1));
                    col        = col_pipe[0] & (bst_len_rd - 1);
                    bst_ctr_rd = bst_len_rd;
                    bst_ctr_wr = (int)0;

                    if (dbg_on)
                    {
                        if (mem_flags & FLAG_BANK_INTERLEAVING)
                            fprintf(fh_log, "%08X : ", ((row_addr[bank] << SDRAM_BIT_BANKS) + (bank << bit_cols) + col_pipe[0]) << bus_log2);
                        else
                            fprintf(fh_log, "%08X : ", (row_addr[bank] + (bank << (bit_rows + bit_cols)) + col_pipe[0]) << bus_log2);
                    }

                    break;
                }
                // 110 : Burst stop
                case CMD_BST:
                {
                    bst_ctr_rd = (int)0;
                    break;
                }
                // 111 : No operation
                default: ;
            }

            // Write to memory
            if (bst_ctr_wr)
            {
                // Write MSL (if present)
                if (mem_flags & DATA_MSL)
                {
                    if (dqm & 0x80)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_7[bank][row + col] = (vluint8_t)(dq_in >> 56);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_7[bank][row + col]);
                    }
                    if (dqm & 0x40)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_6[bank][row + col] = (vluint8_t)(dq_in >> 48);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_6[bank][row + col]);
                    }
                    if (dqm & 0x20)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_5[bank][row + col] = (vluint8_t)(dq_in >> 40);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_5[bank][row + col]);
                    }
                    if (dqm & 0x10)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_4[bank][row + col] = (vluint8_t)(dq_in >> 32);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_4[bank][row + col]);
                    }
                }
                // Write MSW (if present)
                if (mem_flags & DATA_MSW)
                {
                    if (dqm & 0x08)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_3[bank][row + col] = (vluint8_t)(dq_in >> 24);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_3[bank][row + col]);
                    }
                    if (dqm & 0x04)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_2[bank][row + col] = (vluint8_t)(dq_in >> 16);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_2[bank][row + col]);
                    }
                }
                // Write MSB (if present)
                if (mem_flags & DATA_MSB)
                {
                    if (dqm & 0x02)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        mem_array_1[bank][row + col] = (vluint8_t)(dq_in >> 8);
                        if (dbg_on) fprintf(fh_log, "%02X", mem_array_1[bank][row + col]);
                    }
                }
                // Write LSB
                if (dqm & 0x01)
                {
                    if (dbg_on) fprintf(fh_log, "XX ");
                }
                else
                {
                    mem_array_0[bank][row + col] = (vluint8_t)dq_in;
                    if (dbg_on) fprintf(fh_log, "%02X ", mem_array_0[bank][row + col]);
                }

                // Burst counter (only sequential burst supported)
                col = (col + 1) & (bst_len_wr - 1);
                bst_ctr_wr--;

                // End of burst
                if (bst_ctr_wr == (int)0)
                {
                    // Auto-precharge case
                    if (ap_bank[bank])
                    {
                        if (fh_log) fprintf(fh_log, "%s", "PRE\n\n");
                        ap_bank[bank] = (vluint8_t)0;
                        row_act[bank] = (vluint8_t)0;
                        row_pre[bank] = (vluint8_t)1;
                    }
                    else
                    {
                        if (fh_log) fprintf(fh_log, "%s", "\n");
                    }
                    if (log_size && fh_log)
                    {
                        fprintf(fh_log, "%s", log_buf);
                        log_size = 0;
                    }
                }
            }

            // Read from memory
            if (bst_ctr_rd)
            {
                vluint8_t dq_tmp[8];

                dq_tmp[7] = (vluint8_t)0x00;
                dq_tmp[6] = (vluint8_t)0x00;
                dq_tmp[5] = (vluint8_t)0x00;
                dq_tmp[4] = (vluint8_t)0x00;
                dq_tmp[3] = (vluint8_t)0x00;
                dq_tmp[2] = (vluint8_t)0x00;
                dq_tmp[1] = (vluint8_t)0x00;
                dq_tmp[0] = (vluint8_t)0x00;

                // Read MSL (if present)
                if (mem_flags & DATA_MSL)
                {
                    if (dqm_pipe[0] & 0x80)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[7] = mem_array_7[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[7]);
                    }
                    if (dqm_pipe[0] & 0x40)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[6] = mem_array_6[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[6]);
                    }
                    if (dqm_pipe[0] & 0x20)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[5] = mem_array_5[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[5]);
                    }
                    if (dqm_pipe[0] & 0x10)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[4] = mem_array_4[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[4]);
                    }
                }

                // Read MSW (if present)
                if (mem_flags & DATA_MSW)
                {
                    if (dqm_pipe[0] & 0x08)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[3] = mem_array_3[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[3]);
                    }
                    if (dqm_pipe[0] & 0x04)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[2] = mem_array_2[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[2]);
                    }
                }

                // Read MSB (if present)
                if (mem_flags & DATA_MSB)
                {
                    if (dqm_pipe[0] & 0x02)
                    {
                        if (dbg_on) fprintf(fh_log, "XX");
                    }
                    else
                    {
                        dq_tmp[1] = mem_array_1[bank][row + col];
                        if (dbg_on) fprintf(fh_log, "%02X", dq_tmp[1]);
                    }
                }

                // Read LSB
                if (dqm_pipe[0] & 0x01)
                {
                    if (dbg_on) fprintf(fh_log, "XX ");
                }
                else
                {
                    dq_tmp[0] = mem_array_0[bank][row + col];
                    if (dbg_on) fprintf(fh_log, "%02X ", dq_tmp[0]);
                }

                dq_out = ((vluint64_t)dq_tmp[0]      )
                       | ((vluint64_t)dq_tmp[1] << 8 )
                       | ((vluint64_t)dq_tmp[2] << 16)
                       | ((vluint64_t)dq_tmp[3] << 24)
                       | ((vluint64_t)dq_tmp[4] << 32)
                       | ((vluint64_t)dq_tmp[5] << 40)
                       | ((vluint64_t)dq_tmp[6] << 48)
                       | ((vluint64_t)dq_tmp[7] << 56);

                // Burst counter (only sequential supported)
                col = (col + 1) & (bst_len_rd - 1);
                bst_ctr_rd--;

                // End of burst
                if (bst_ctr_rd == (int)0)
                {
                    // Auto-precharge case
                    if (ap_bank[bank])
                    {
                        if (dbg_on) fprintf(fh_log, "PRE\n");
                        ap_bank[bank] = (vluint8_t)0;
                        row_act[bank] = (vluint8_t)0;
                        row_pre[bank] = (vluint8_t)1;
                    }
                    else
                    {
                        if (dbg_on) fprintf(fh_log, "\n");
                    }
                    if (log_size && fh_log)
                    {
                        fprintf(fh_log, "%s", log_buf);
                        log_size = 0;
                    }
                }
            }
        }

        if ((bst_ctr_wr == (int)0) && (bst_ctr_rd == (int)0) && (log_size != (int)0))
        {
            if (log_buf) {
                fprintf(fh_log, "%s", log_buf);
            }
            log_size = 0;
        }

        // For edge detection
        prev_clk = clk;
    }
    // Clock disabled
    else
    {
        prev_clk = (vluint8_t)0;
    }
}

// Read a byte, interleaved banks, big endian, 8-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_be_8(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> bit_cols;
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS));

    return mem_array_0[bank_nr][idx];
}

// Read a byte, interleaved banks, big endian, 16-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_be_16(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 1);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 1;

    if (addr & 1)
        return mem_array_0[bank_nr][idx];
    else
        return mem_array_1[bank_nr][idx];
}

// Read a byte, interleaved banks, big endian, 32-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_be_32(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 2);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 2;

    switch (addr & 3)
    {
        case 0 : return mem_array_3[bank_nr][idx];
        case 1 : return mem_array_2[bank_nr][idx];
        case 2 : return mem_array_1[bank_nr][idx];
        case 3 : return mem_array_0[bank_nr][idx];
    }
    return 0;
}

// Read a byte, interleaved banks, big endian, 64-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_be_64(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 3);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 3;

    switch (addr & 7)
    {
        case 0 : return mem_array_7[bank_nr][idx];
        case 1 : return mem_array_6[bank_nr][idx];
        case 2 : return mem_array_5[bank_nr][idx];
        case 3 : return mem_array_4[bank_nr][idx];
        case 4 : return mem_array_3[bank_nr][idx];
        case 5 : return mem_array_2[bank_nr][idx];
        case 6 : return mem_array_1[bank_nr][idx];
        case 7 : return mem_array_0[bank_nr][idx];
    }
    return 0;
}

// Read a byte, interleaved banks, little endian, 8-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_le_8(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> bit_cols;
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS));

    return mem_array_0[bank_nr][idx];
}

// Read a byte, interleaved banks, little endian, 16-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_le_16(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 1);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 1;

    if (addr & 1)
        return mem_array_1[bank_nr][idx];
    else
        return mem_array_0[bank_nr][idx];
}

// Read a byte, interleaved banks, little endian, 32-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_le_32(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 2);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 2;

    switch (addr & 3)
    {
        case 0 : return mem_array_0[bank_nr][idx];
        case 1 : return mem_array_1[bank_nr][idx];
        case 2 : return mem_array_2[bank_nr][idx];
        case 3 : return mem_array_3[bank_nr][idx];
    }
    return 0;
}

// Read a byte, interleaved banks, little endian, 64-bit SDRAM
vluint8_t SimulSDRAM::read_byte_i_le_64(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + 3);
    idx     = (int)((addr & mask_cols) | ((addr & mask_rows) >> SDRAM_BIT_BANKS)) >> 3;

    switch (addr & 7)
    {
        case 0 : return mem_array_0[bank_nr][idx];
        case 1 : return mem_array_1[bank_nr][idx];
        case 2 : return mem_array_2[bank_nr][idx];
        case 3 : return mem_array_3[bank_nr][idx];
        case 4 : return mem_array_4[bank_nr][idx];
        case 5 : return mem_array_5[bank_nr][idx];
        case 6 : return mem_array_6[bank_nr][idx];
        case 7 : return mem_array_7[bank_nr][idx];
    }
    return 0;
}

// Read a byte, contiguous banks, big endian, 8-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_be_8(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows);
    idx     = (int)(addr & (mask_cols | mask_rows));

    return mem_array_0[bank_nr][idx];
}

// Read a byte, contiguous banks, big endian, 16-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_be_16(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 1);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 1;

    if (addr & 1)
        return mem_array_0[bank_nr][idx];
    else
        return mem_array_1[bank_nr][idx];
}

// Read a byte, contiguous banks, big endian, 32-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_be_32(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 2);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 2;

    switch (addr & 3)
    {
        case 0 : return mem_array_3[bank_nr][idx];
        case 1 : return mem_array_2[bank_nr][idx];
        case 2 : return mem_array_1[bank_nr][idx];
        case 3 : return mem_array_0[bank_nr][idx];
    }
    return 0;
}

// Read a byte, contiguous banks, big endian, 64-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_be_64(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 3);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 3;

    switch (addr & 7)
    {
        case 0 : return mem_array_7[bank_nr][idx];
        case 1 : return mem_array_6[bank_nr][idx];
        case 2 : return mem_array_5[bank_nr][idx];
        case 3 : return mem_array_4[bank_nr][idx];
        case 4 : return mem_array_3[bank_nr][idx];
        case 5 : return mem_array_2[bank_nr][idx];
        case 6 : return mem_array_1[bank_nr][idx];
        case 7 : return mem_array_0[bank_nr][idx];
    }
    return 0;
}

// Read a byte, contiguous banks, little endian, 8-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_le_8(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows);
    idx     = (int)(addr & (mask_cols | mask_rows));

    return mem_array_0[bank_nr][idx];
}

// Read a byte, contiguous banks, little endian, 16-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_le_16(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 1);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 1;

    if (addr & 1)
        return mem_array_1[bank_nr][idx];
    else
        return mem_array_0[bank_nr][idx];
}

// Read a byte, contiguous banks, little endian, 32-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_le_32(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 2);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 2;

    switch (addr & 3)
    {
        case 0 : return mem_array_0[bank_nr][idx];
        case 1 : return mem_array_1[bank_nr][idx];
        case 2 : return mem_array_2[bank_nr][idx];
        case 3 : return mem_array_3[bank_nr][idx];
    }
    return 0;
}

// Read a byte, contiguous banks, little endian, 64-bit SDRAM
vluint8_t SimulSDRAM::read_byte_c_le_64(vluint32_t addr)
{
    int        bank_nr;  // Bank number (0 to 3)
    int        idx;      // Array index (0 to num_cols * num_rows - 1)

    bank_nr = (int)(addr & mask_bank) >> (bit_cols + bit_rows + 3);
    idx     = (int)(addr & (mask_cols | mask_rows)) >> 3;

    switch (addr & 7)
    {
        case 0 : return mem_array_0[bank_nr][idx];
        case 1 : return mem_array_1[bank_nr][idx];
        case 2 : return mem_array_2[bank_nr][idx];
        case 3 : return mem_array_3[bank_nr][idx];
        case 4 : return mem_array_4[bank_nr][idx];
        case 5 : return mem_array_5[bank_nr][idx];
        case 6 : return mem_array_6[bank_nr][idx];
        case 7 : return mem_array_7[bank_nr][idx];
    }
    return 0;
}
