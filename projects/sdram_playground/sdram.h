#ifndef SDRAM_INSTRUCTIONS_H
#define SDRAM_INSTRUCTIONS_H

typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;

#define BWIDTH  38u

#define CMD_dummy_WAIT_init   0xFu   /* 1111 */
#define CMD_dummy_WAIT        0xDu   /* 1101 */
#define CMD_dummy_GET         0x9u   /* 1001 */
#define CMD_UNSELECTED        0x8u   /* 1000 */
#define CMD_NOP               0x7u   /* 0111 */
#define CMD_ACTIVATE          0x3u   /* 0011 */
#define CMD_READ              0x5u   /* 0101 */
#define CMD_WRITE             0x4u   /* 0100 */
#define CMD_TERMINATE         0x6u   /* 0110 */
#define CMD_PRECHARGE         0x2u   /* 0010 */
#define CMD_REFRESH           0x1u   /* 0001 */
#define CMD_LOAD_MODE_REG     0x0u   /* 0000 */

#define BANK0  0x0u
#define BANK1  0x1u
#define BANK2  0x2u
#define BANK3  0x3u

#define AddrZ              0x0000u
#define AddrA_row          0x0000u
#define AddrA_col          0x0000u
#define AddrB_row          0x0001u
#define AddrB_col          0x0000u

#define Addr_wait_init     0x1FFFu   /* 1111111111111 */
#define Addr_wait_2        0x0000u
#define Addr_wait_3        0x0001u
#define Addr_wait_4        0x0002u
#define Addr_wait_5        0x0003u
#define Addr_wait_6        0x0004u
#define Addr_wait_7        0x0005u
#define Addr_wait_8        0x0006u
#define Addr_wait_16       0x000Eu

#define Addr_precharge_all 0x0400u   /* 0010000000000 – A10 set */
#define Addr_mode_reg      0x0033u   /* 0001000110011 */

#define DataZ              0x0000u
#define DATA_PATTERN_A     0x5555u   /* 0101010101010101 */
#define DATA_PATTERN_B     0xAAAAu   /* 1010101010101010 */

#define DQM_NONE  0x0u   /* 00 – no masking  */
#define DQM_WRITE 0x2u   /* 10 – write mask  */

#ifdef ICARUS
#  define Addr_wait_R  Addr_wait_4
#else
#  define Addr_wait_R  Addr_wait_5
#endif

#define INSTR(cmd, bank, addr, dqm, data, last) \
    ( ((uint64_t)((cmd)  & 0xFu)     << 34) | \
      ((uint64_t)((bank) & 0x3u)     << 32) | \
      ((uint64_t)((addr) & 0x1FFFu)  << 19) | \
      ((uint64_t)((dqm)  & 0x3u)     << 17) | \
      ((uint64_t)((data) & 0xFFFFu)  <<  1) | \
      ((uint64_t)((last) & 0x1u)         ) )


#define INSTR_CMD(w)     (((w) >> 34) & 0xFu)
#define INSTR_BANK(w)    (((w) >> 32) & 0x3u)
#define INSTR_ADDR(w)    (((w) >> 19) & 0x1FFFu)
#define INSTR_DQM(w)     (((w) >> 17) & 0x3u)
#define INSTR_DATA(w)    (((w) >>  1) & 0xFFFFu)
#define INSTR_LAST(w)    ( (w)        & 0x1u)

#endif /* SDRAM_INSTRUCTIONS_H */
