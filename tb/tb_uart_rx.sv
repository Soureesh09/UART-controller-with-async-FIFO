//------------------------------------------------------------------------
// tb_uart_rx.sv
//
// Unit test for uart_rx in isolation. The driver bit-bangs rxd directly
// from an expected byte using only tick16 timing -- it does not
// instantiate uart_tx, for the same "don't let one module's bugs hide
// the other's" reason given in tb_uart_tx.sv.
//
// Runs NUM_BYTES random good frames back-to-back, then one deliberately
// malformed frame (stop bit forced low) to check frame_error actually
// fires when it should -- and does not fire on any of the good frames.
//------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_uart_rx;

    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int NUM_BYTES   = 60;
    localparam int DIVISOR     = CLK_FREQ_HZ / (BAUD_RATE * 16);  // must match baud_gen's math

    logic clk = 0;
    logic rst_n;
    always #5 clk = ~clk;   // 100 MHz

    logic       tick16;
    logic       rxd = 1'b1;
    logic [7:0] rx_data;
    logic       rx_done, frame_error;

    baud_gen #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .BAUD_RATE(BAUD_RATE)) u_baud (
        .clk(clk), .rst_n(rst_n), .tick16(tick16)
    );

    uart_rx dut (
        .clk(clk), .rst_n(rst_n),
        .tick16(tick16), .rxd(rxd),
        .rx_data(rx_data), .rx_done(rx_done), .frame_error(frame_error)
    );

    int pass_count = 0;
    int fail_count = 0;
    int unexpected_frame_errors = 0;

    // Independent reference driver: pushes a full 8N1 frame onto rxd using
    // only tick16 as a time base.
    task automatic bitbang_send(input logic [7:0] data, input bit bad_stop);
        integer i;
        rxd = 1'b0;                         // start bit
        repeat (16) @(posedge tick16);
        for (i = 0; i < 8; i++) begin
            rxd = data[i];
            repeat (16) @(posedge tick16);
        end
        rxd = bad_stop ? 1'b0 : 1'b1;        // stop bit (or a deliberately bad one)
        repeat (16) @(posedge tick16);
        rxd = 1'b1;                          // back to idle
    endtask

    logic [7:0] expected_q[$];

    // Monitor: tallies every rx_done alongside any frame_error seen while
    // the corresponding frame was in flight.
    always @(posedge clk) begin
        if (frame_error && expected_q.size() > 0)
            unexpected_frame_errors++;  // only meaningful during the good-frame phase below
    end

    initial begin
        logic [7:0] b;
        @(posedge rst_n);
        @(posedge clk);

        // Phase 1: NUM_BYTES random good frames, back-to-back.
        for (int i = 0; i < NUM_BYTES; i++) begin
            b = $urandom_range(0, 255);
            expected_q.push_back(b);
            bitbang_send(b, 1'b0);
        end

        // Let the last frame's rx_done/checker settle before phase 2. Wait
        // on the plain int tally rather than the queue's size(): Icarus
        // does not reliably wake a wait() on a queue mutated by pop_front()
        // in another process, so a plain integer is the robust choice here.
        wait ((good_pass + good_fail) == NUM_BYTES);
        repeat (4) @(posedge clk);

        // Phase 2: one deliberately malformed frame -- frame_error must fire.
        fork
            bitbang_send(8'hA5, 1'b1);
            begin : wait_for_frame_error
                bit seen;
                seen = 0;
                // Cover a full 10-bit-period frame (start+8 data+stop) plus
                // margin, in clk cycles, so this doesn't time out before
                // the stop bit (where frame_error can assert) is even sent.
                repeat (11 * 16 * DIVISOR) begin
                    @(posedge clk);
                    if (frame_error) seen = 1;
                end
                if (seen) begin
                    pass_count++;
                    $display("[%0t] PASS: frame_error correctly asserted for bad stop bit", $time);
                end else begin
                    fail_count++;
                    $display("[%0t] FAIL: frame_error did NOT assert for a bad stop bit", $time);
                end
            end
        join

        $display("--------------------------------------------------");
        $display(" tb_uart_rx: %0d/%0d good frames correct, %0d mismatch(es)",
                  pass_count_good(), NUM_BYTES, fail_count_good());
        $display(" tb_uart_rx: frame_error check -- %0s",
                  (pass_count > 0 && fail_count == 0) ? "PASS" : "FAIL");
        $display(" tb_uart_rx: spurious frame_error during good frames -- %0d (want 0)",
                  unexpected_frame_errors);
        $display("--------------------------------------------------");
        if (fail_count_good() == 0 && fail_count == 0 && unexpected_frame_errors == 0)
            $display(" RESULT: PASS");
        else
            $display(" RESULT: FAIL");
        $finish;
    end

    // Checker for phase 1 (good frames): runs concurrently with the driver
    // above, consuming rx_done pulses in order.
    int good_pass = 0;
    int good_fail = 0;
    function automatic int pass_count_good(); return good_pass; endfunction
    function automatic int fail_count_good(); return good_fail; endfunction

    always @(posedge rx_done) begin
        if (expected_q.size() > 0) begin
            if (rx_data === expected_q[0]) begin
                good_pass++;
            end else begin
                good_fail++;
                $display("[%0t] FAIL: expected 0x%02h, got 0x%02h", $time, expected_q[0], rx_data);
            end
            void'(expected_q.pop_front());
        end
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
