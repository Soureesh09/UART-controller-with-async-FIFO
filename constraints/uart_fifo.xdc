## uart_fifo.xdc
##
## Timing constraints mirror the FIFO project's own constraints/timing.xdc:
## declare core_clk and uart_clk as an asynchronous clock group so static
## timing analysis doesn't try (and fail) to time the intentional CDC
## paths through the two async_fifo instances.
##
## Adjust the periods to whatever your actual clocks will be -- these
## match the RTL's own defaults (100 MHz core_clk, ~142.857 MHz uart_clk,
## the same "deliberately unrelated" pairing used in simulation).
create_clock -period 10.000 -name core_clk [get_ports core_clk]
create_clock -period 7.000  -name uart_clk [get_ports uart_clk]
set_clock_groups -asynchronous -group [get_clocks core_clk] -group [get_clocks uart_clk]

## ---------------------------------------------------------------------
## Pin locations below are PLACEHOLDERS -- copy the real ones from your
## board's master XDC (e.g. the Cmod A7 / Nexys A7 file matching the
## xc7a35tcpg236-1 target the FIFO project already used) before running
## implementation. Uncomment and fill in once you know your board's UART
## header / USB-UART bridge pins and a spare push-button or switch for
## reset.
## ---------------------------------------------------------------------
# set_property PACKAGE_PIN <core_clk_pin> [get_ports core_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports core_clk]
#
# set_property PACKAGE_PIN <uart_clk_pin> [get_ports uart_clk]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_clk]
#
# set_property PACKAGE_PIN <reset_button_pin> [get_ports core_rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports core_rst_n]
# set_property PACKAGE_PIN <reset_button_pin> [get_ports uart_rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_rst_n]
#
# set_property PACKAGE_PIN <usb_uart_txd_pin> [get_ports uart_txd]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]
# set_property PACKAGE_PIN <usb_uart_rxd_pin> [get_ports uart_rxd]
# set_property IOSTANDARD LVCMOS33 [get_ports uart_rxd]
