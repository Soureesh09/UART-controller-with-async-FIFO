//------------------------------------------------------------------------
// uart_fifo_top.sv
//
// A UART controller whose TX and RX data paths are each buffered by an
// instance of the existing async_fifo -- unmodified, reused exactly as
// verified in the standalone FIFO project. That's not decoration: in a
// real SoC the UART peripheral clock and the core clock are two genuinely
// independent clock domains, so something has to safely cross bytes
// between them, and a Gray-code dual-clock FIFO is the standard answer.
// This module is that answer, using the FIFO this repo already trusts.
//
//   core_clk domain                       uart_clk domain
//  -----------------                     -----------------
//  tx_wdata -> [ async_fifo #1 ] -> tx_fifo_rdata -> uart_tx -> uart_txd
//  rx_rdata <- [ async_fifo #2 ] <- rx_data_w      <- uart_rx <- uart_rxd
//
// Both async_fifo instances are FWFT ("first word fall through"): rdata
// is already valid combinationally whenever the FIFO isn't empty, so
// popping a word and consuming it happen on the same clock edge -- there
// is no extra "wait a cycle after rd_en" step anywhere below.
//------------------------------------------------------------------------
module uart_fifo_top #(
    parameter int CLK_FREQ_HZ = 100_000_000,  // uart_clk frequency
    parameter int BAUD_RATE   = 115_200,
    parameter int FIFO_ADDR_W = 4             // FIFO depth = 2**FIFO_ADDR_W = 16
)(
    // ---- Core / system-side domain -------------------------------------
    input  logic       core_clk,
    input  logic       core_rst_n,

    input  logic       tx_wr_en,      // core enqueues a byte to transmit
    input  logic [7:0] tx_wdata,
    output logic       tx_fifo_full,  // back-pressure -- don't write while high

    input  logic       rx_rd_en,      // core dequeues a received byte
    output logic [7:0] rx_rdata,
    output logic       rx_fifo_empty,

    // ---- UART-side domain ------------------------------------------------
    input  logic       uart_clk,
    input  logic       uart_rst_n,

    output logic       uart_txd,
    input  logic       uart_rxd,

    // ---- Status (uart_clk domain) -- exposed for a future register map
    // and used directly by the verification testbench
    output logic       rx_fifo_overflow,  // a received byte was dropped: RX FIFO was full
    output logic       rx_frame_error     // a received frame's stop bit was wrong
);

    // Single baud reference shared by both TX and RX -- there's only one
    // uart_clk domain here, so there's no reason for two dividers.
    logic tick16;
    baud_gen #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE)
    ) u_baud (
        .clk    (uart_clk),
        .rst_n  (uart_rst_n),
        .tick16 (tick16)
    );

    // ---------------------------------------------------------------
    // TX path
    // ---------------------------------------------------------------
    logic       tx_fifo_rd_en;
    logic [7:0] tx_fifo_rdata;
    logic       tx_fifo_empty;
    logic       tx_busy, tx_done;

    async_fifo #(
        .WIDTH      (8),
        .ADDR_WIDTH (FIFO_ADDR_W)
    ) u_tx_fifo (
        .wclk   (core_clk),
        .wrst_n (core_rst_n),
        .wr_en  (tx_wr_en),
        .wdata  (tx_wdata),
        .full   (tx_fifo_full),

        .rclk   (uart_clk),
        .rrst_n (uart_rst_n),
        .rd_en  (tx_fifo_rd_en),
        .rdata  (tx_fifo_rdata),
        .empty  (tx_fifo_empty)
    );

    // Pop one byte and kick off uart_tx on the same cycle, whenever it's
    // idle and there's something waiting. FWFT means tx_fifo_rdata is
    // already the right value the instant tx_fifo_rd_en goes high.
    assign tx_fifo_rd_en = !tx_busy && !tx_fifo_empty;

    uart_tx u_tx (
        .clk      (uart_clk),
        .rst_n    (uart_rst_n),
        .tick16   (tick16),
        .tx_start (tx_fifo_rd_en),
        .tx_data  (tx_fifo_rdata),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done),
        .txd      (uart_txd)
    );

    // ---------------------------------------------------------------
    // RX path
    // ---------------------------------------------------------------
    logic [7:0] rx_data_w;
    logic       rx_done_w;
    logic       rx_fifo_full_w;

    uart_rx u_rx (
        .clk         (uart_clk),
        .rst_n       (uart_rst_n),
        .tick16      (tick16),
        .rxd         (uart_rxd),
        .rx_data     (rx_data_w),
        .rx_done     (rx_done_w),
        .frame_error (rx_frame_error)
    );

    // async_fifo itself gates its internal write with wr_en & ~full, so a
    // byte that arrives while the RX FIFO is full is already dropped
    // safely -- this flag just makes that visible instead of silent.
    assign rx_fifo_overflow = rx_done_w && rx_fifo_full_w;

    async_fifo #(
        .WIDTH      (8),
        .ADDR_WIDTH (FIFO_ADDR_W)
    ) u_rx_fifo (
        .wclk   (uart_clk),
        .wrst_n (uart_rst_n),
        .wr_en  (rx_done_w),
        .wdata  (rx_data_w),
        .full   (rx_fifo_full_w),

        .rclk   (core_clk),
        .rrst_n (core_rst_n),
        .rd_en  (rx_rd_en),
        .rdata  (rx_rdata),
        .empty  (rx_fifo_empty)
    );

endmodule
