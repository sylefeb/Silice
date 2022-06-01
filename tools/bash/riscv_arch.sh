if type "riscv64-unknown-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv64-unknown-elf"
elif type "riscv64-unknown-gnu-gcc" > /dev/null 2>&1; then
  ARCH="riscv64-unknown-gnu"
elif type "riscv64-linux-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv64-linux-elf"
elif type "riscv64-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv64-elf"
elif type "riscv32-unknown-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv32-unknown-elf"
elif type "riscv32-unknown-gnu-gcc" > /dev/null 2>&1; then
  ARCH="riscv32-unknown-gnu"
elif type "riscv32-linux-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv32-linux-elf"
elif type "riscv32-elf-gcc" > /dev/null 2>&1; then
  ARCH="riscv32-elf"
else
  ARCH="riscv64-linux-gnu"
fi
echo $ARCH
