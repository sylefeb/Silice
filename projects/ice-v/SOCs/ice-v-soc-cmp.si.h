#pragma once
// SL 2022-05-13

void cpu_retires(int id,unsigned int pc,unsigned int instr,unsigned int rd,unsigned int val);
int  cpu_reinstr(int id);
void cpu_putc(int id,int c);