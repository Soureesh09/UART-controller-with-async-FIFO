#!/usr/bin/env bash
# Compiles and runs all three testbenches with Icarus Verilog.
#
# This is the fast, free, cross-platform sanity check -- every result in
# the README came from this script. It's not the primary sim flow (see
# run_vivado.bat for that); it's what let this whole design get proven
# correct, bugs found and fixed, before ever opening Vivado.
#
# Usage (from the repo root, or from sim/ -- it cd's to the repo root
# itself so it works either way):
#   bash sim/run_icarus.sh
#
# Requires: iverilog + vvp on PATH (Icarus Verilog 11+; developed against
# 12.0). On Windows this runs fine under WSL or Git Bash with Icarus
# installed; native Windows users should use run_vivado.bat instead.

set -e
cd "$(dirname "$0")/.."

FIFO_SRC="rtl/fifo/async_fifo.v rtl/fifo/fifo_mem.v rtl/fifo/sync_2ff.v rtl/fifo/wptr_handler.v rtl/fifo/rptr_handler.v"
UART_SRC="rtl/baud_gen.sv rtl/uart_tx.sv rtl/uart_rx.sv"

mkdir -p sim/work

run_one () {
    local name=$1
    shift
    echo "=================================================="
    echo " Compiling & running: $name"
    echo "=================================================="
    iverilog -g2012 -o "sim/work/${name}.vvp" "$@"
    vvp "sim/work/${name}.vvp"
    echo
}

run_one tb_uart_tx       $UART_SRC tb/tb_uart_tx.sv
run_one tb_uart_rx       $UART_SRC tb/tb_uart_rx.sv
run_one tb_uart_fifo_top $FIFO_SRC $UART_SRC rtl/uart_fifo_top.sv tb/tb_uart_fifo_top.sv

echo "=================================================="
echo " All three testbenches finished. Check each RESULT"
echo " line above -- PASS/PASS/PASS is a clean run."
echo "=================================================="
