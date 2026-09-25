//------------------------------------------------------------------------
// tb_uart_tx.sv
//
// Unit test for uart_tx in isolation. Deliberately does NOT instantiate
// uart_rx to check the serial output -- that would let a bug in one mask
// or fake-fix a bug in the other. Instead this checker bit-bangs its own
// independent decode of txd, driven only by tick16 timing, and compares
// against the byte that was actually requested.
//
// NUM_BYTES random frames are sent back-to-back (next tx_start as soon as
// tx_busy drops) to also exercise continuous back-to-back transmission,
// not just isolated single bytes.
//------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_uart_tx;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int NUM_BYTES   = 60;

    logic clk = 0;
    logic rst_n;
    always #5 clk = ~clk;   // 100 MHz

    logic       tick16;
    logic       tx_start;
    logic [7:0] tx_data;
    logic       tx_busy, tx_done, txd;

    baud_gen #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_baud (
        .clk(clk), .rst_n(rst_n), .tick16(tick16)
    );

    uart_tx dut (
        .clk(clk), .rst_n(rst_n),
        .tick16(tick16), .tx_start(tx_start), .tx_data(tx_data),
        .tx_busy(tx_busy), .tx_done(tx_done), .txd(txd)
    );

    int pass_count = 0;
    int fail_count = 0;

    // Independent reference receiver: samples txd at the middle of each
    // bit using only tick16 as a time base. See rtl/uart_rx.sv for the
    // real DUT-facing implementation of the same idea -- this one exists
    // purely to check uart_tx and is written from scratch.
    task automatic bitbang_receive(output logic [7:0] data, output logic stop_ok);
        integer i;
        @(negedge txd);                  // start bit begins
        repeat (8)  @(posedge tick16);    // -> middle of the start bit
        for (i = 0; i < 8; i++) begin
            repeat (16) @(posedge tick16);  // -> middle of data bit i
            data[i] = txd;
        end
        repeat (16) @(posedge tick16);    // -> middle of the stop bit
        stop_ok = txd;
    endtask

    logic [7:0] expected_q[$];
    int         pushed_count = 0;

    // Driver: keep the TX pipe full -- push a new random byte the moment
    // uart_tx goes idle, so consecutive frames back onto each other with
    // zero idle gap.
    initial begin
        tx_start = 1'b0;
        tx_data  = '0;
        @(posedge rst_n);
        @(posedge clk);
        for (int i = 0; i < NUM_BYTES; i++) begin
            logic [7:0] b;
            b = $urandom_range(0, 255);
            wait (!tx_busy);
            @(posedge clk);
            tx_data          = b;
            tx_start         = 1'b1;
            expected_q.push_back(b);
            pushed_count++;
            @(posedge clk);
            tx_start = 1'b0;
        end
    end

    // Checker: runs concurrently, pulls one decoded byte per frame and
    // compares it to what the driver actually asked for. Waits on the
    // plain int pushed_count rather than expected_q.size(): the push always
    // happens before the corresponding frame finishes transmitting, so
    // this never actually blocks, but a plain int is the robust choice
    // for a wait() regardless (see the note in tb_uart_rx.sv for why).
    initial begin
        logic [7:0] got;
        logic       stop_ok;
        @(posedge rst_n);
        for (int i = 0; i < NUM_BYTES; i++) begin
            bitbang_receive(got, stop_ok);
            wait (pushed_count > i);
            if (got === expected_q[0] && stop_ok === 1'b1) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("[%0t] FAIL frame %0d: expected 0x%02h, got 0x%02h, stop_ok=%b",
                          $time, i, expected_q[0], got, stop_ok);
            end
            void'(expected_q.pop_front());
        end

        $display("--------------------------------------------------");
        $display(" tb_uart_tx: %0d/%0d frames correct, %0d mismatch(es)",
                  pass_count, NUM_BYTES, fail_count);
        $display("--------------------------------------------------");
        if (fail_count == 0) $display(" RESULT: PASS");
        else                 $display(" RESULT: FAIL");
        $finish;
    end

    // Reset
    initial begin
        rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
    end

    // Safety timeout
    initial begin
        #200_000_000;
        $display(" RESULT: FAIL (timeout -- simulation did not complete)");
        $finish;
    end

endmodule
