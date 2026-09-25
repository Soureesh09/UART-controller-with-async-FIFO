`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.08.2026 23:59:28
// Design Name: 
// Module Name: async_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module async_fifo #(
    parameter WIDTH      = 8,
    parameter ADDR_WIDTH = 4        // depth = 2**ADDR_WIDTH
)(
    input                   wclk,
    input                   wrst_n,
    input                   wr_en,
    input      [WIDTH-1:0]  wdata,
    output                  full,

    input                   rclk,
    input                   rrst_n,
    input                   rd_en,
    output     [WIDTH-1:0]  rdata,
    output                  empty
);
    wire [ADDR_WIDTH-1:0] waddr, raddr;
    wire [ADDR_WIDTH:0]   wptr_gray, rptr_gray;
    wire [ADDR_WIDTH:0]   wq2_rptr, rq2_wptr;
    wire                  wr_en_int = wr_en & ~full;

    fifo_mem #(.WIDTH(WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) u_mem (
        .wclk  (wclk),
        .wr_en (wr_en_int),
        .waddr (waddr),
        .wdata (wdata),
        .raddr (raddr),
        .rdata (rdata)
    );

    wptr_handler #(.ADDR_WIDTH(ADDR_WIDTH)) u_wptr (
        .wclk      (wclk),
        .wrst_n    (wrst_n),
        .wr_en     (wr_en),
        .wq2_rptr  (wq2_rptr),
        .waddr     (waddr),
        .wptr_gray (wptr_gray),
        .full      (full)
    );

    rptr_handler #(.ADDR_WIDTH(ADDR_WIDTH)) u_rptr (
        .rclk      (rclk),
        .rrst_n    (rrst_n),
        .rd_en     (rd_en),
        .rq2_wptr  (rq2_wptr),
        .raddr     (raddr),
        .rptr_gray (rptr_gray),
        .empty     (empty)
    );

    // write pointer's gray code crosses INTO the read domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_w2r (
        .clk      (rclk),
        .rst_n    (rrst_n),
        .async_in (wptr_gray),
        .sync_out (rq2_wptr)
    );

    // read pointer's gray code crosses INTO the write domain
    sync_2ff #(.WIDTH(ADDR_WIDTH+1)) u_sync_r2w (
        .clk      (wclk),
        .rst_n    (wrst_n),
        .async_in (rptr_gray),
        .sync_out (wq2_rptr)
    );
endmodule