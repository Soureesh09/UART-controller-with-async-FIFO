@echo off
REM Compiles and runs all three testbenches using Vivado's xvlog/xelab/xsim
REM command-line flow -- the same flow already in use for HOLY_CORE.
REM
REM Usage (from a Vivado 2025.1 command shell, "Vivado HLS/Vivado Tcl Shell"
REM or with settings64.bat already sourced, from the repo root):
REM   sim\run_vivado.bat
REM
REM Each testbench gets its own work library and snapshot so they don't
REM collide; -R runs the compiled snapshot immediately in batch mode and
REM prints straight to this console.

setlocal enabledelayedexpansion
cd /d "%~dp0\.."

set FIFO_SRC=rtl\fifo\async_fifo.v rtl\fifo\fifo_mem.v rtl\fifo\sync_2ff.v rtl\fifo\wptr_handler.v rtl\fifo\rptr_handler.v
set UART_SRC=rtl\baud_gen.sv rtl\uart_tx.sv rtl\uart_rx.sv

echo ==================================================
echo  tb_uart_tx
echo ==================================================
call xvlog --sv %UART_SRC% tb\tb_uart_tx.sv
call xelab tb_uart_tx -s snap_uart_tx
call xsim snap_uart_tx -R

echo ==================================================
echo  tb_uart_rx
echo ==================================================
call xvlog --sv %UART_SRC% tb\tb_uart_rx.sv
call xelab tb_uart_rx -s snap_uart_rx
call xsim snap_uart_rx -R

echo ==================================================
echo  tb_uart_fifo_top  (real async_fifo + uart_tx + uart_rx, full loopback)
echo ==================================================
call xvlog %FIFO_SRC%
call xvlog --sv rtl\uart_fifo_top.sv tb\tb_uart_fifo_top.sv
call xelab tb_uart_fifo_top -s snap_uart_fifo_top
call xsim snap_uart_fifo_top -R

echo ==================================================
echo  Done. Check each RESULT line above.
echo ==================================================
endlocal
