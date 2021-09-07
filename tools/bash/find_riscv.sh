if type "riscv64-unknown-elf-as" > /dev/null; then
  ARCH="riscv64-unknown-elf"
elif type "riscv64-unknown-gnu-as" > /dev/null; then
  ARCH="riscv64-unknown-gnu"
elif type "riscv64-linux-elf-as" > /dev/null; then
  ARCH="riscv64-linux-elf"
else
  ARCH="riscv64-linux-gnu"
fi
