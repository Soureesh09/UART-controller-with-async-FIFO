//------------------------------------------------------------------------
// uart_rx.sv
//
// Recovers an 8N1 UART frame from an asynchronous serial input: detects
// the start bit, samples all 8 data bits (LSB-first) and the stop bit at
// their midpoints using baud_gen's 16x tick, and reassembles the byte.
//
// Sampling at the middle of each bit (tick_cnt == 7, i.e. 7-8 ticks into
// a 16-tick bit) rather than right at its edge is what makes this robust
// to rxd not being perfectly phase-aligned with tick16 -- it never comes
// from the same clock domain as clk here, so that misalignment is
// guaranteed, not just possible.
//------------------------------------------------------------------------
module uart_rx (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       tick16,   // 16x-oversample tick from baud_gen
    input  logic       rxd,      // asynchronous serial input; idles high

    output logic [7:0] rx_data,
    output logic       rx_done,      // 1-cycle pulse: rx_data is valid
    output logic       frame_error   // 1-cycle pulse: stop bit read back 0
);

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_e;

    rx_state_e  state;
    logic [3:0] tick_cnt;
    logic [2:0] bit_idx;
    logic [7:0] shift_reg;

    // 2-flop synchronizer on the serial input. rxd comes from off-chip (or
    // at least from outside this clock domain), so it gets exactly the
    // same treatment as any other async signal in this project -- see
    // sync_2ff.v in the FIFO, which does the identical job for the gray
    // pointers.
    logic rxd_ff1, rxd_ff2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) {rxd_ff2, rxd_ff1} <= 2'b11;
        else        {rxd_ff2, rxd_ff1} <= {rxd_ff1, rxd};
    end
    wire rxd_s = rxd_ff2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= RX_IDLE;
            tick_cnt    <= '0;
            bit_idx     <= '0;
            shift_reg   <= '0;
            rx_data     <= '0;
            rx_done     <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            rx_done     <= 1'b0;  // both default low -- pulse for 1 cycle only
            frame_error <= 1'b0;

            unique case (state)
                // Idle high; a falling edge is a candidate start bit. This
                // is a level check evaluated every clk, not gated by
                // tick16, so back-to-back frames with no idle gap are
                // caught immediately.
                RX_IDLE: begin
                    tick_cnt <= '0;
                    if (!rxd_s) state <= RX_START;
                end

                // Run the start bit for a full 16-tick period, checking at
                // the midpoint (tick 7) that the line is still low. If it
                // isn't, this was a glitch, not a real start bit -- bail
                // back to idle instead of decoding garbage.
                RX_START: begin
                    if (tick16) begin
                        if (tick_cnt == 4'd7 && rxd_s) begin
                            state <= RX_IDLE;
                        end else if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            bit_idx  <= '0;
                            state    <= RX_DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                // Each data bit gets a full 16-tick period. Sample at the
                // midpoint (tick 7) and shift it in at the top; keep
                // counting to 15 to close out the bit period before
                // moving to the next bit (or the stop bit after bit 7).
                // Shifting new bits in at the MSB while the register
                // shifts right reconstructs the byte correctly LSB-first,
                // since the first bit received (bit 0) ends up having
                // shifted all the way down to position 0 by the time all
                // 8 have arrived.
                RX_DATA: begin
                    if (tick16) begin
                        if (tick_cnt == 4'd7)
                            shift_reg <= {rxd_s, shift_reg[7:1]};

                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            if (bit_idx == 3'd7)
                                state <= RX_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                // Check the stop bit at its midpoint; a 0 there means the
                // frame is misaligned (framing error) rather than a clean
                // byte, but the shifted-in data is still published --
                // the caller decides what to do with a flagged byte.
                RX_STOP: begin
                    if (tick16) begin
                        if (tick_cnt == 4'd7 && !rxd_s)
                            frame_error <= 1'b1;

                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            rx_data  <= shift_reg;
                            rx_done  <= 1'b1;
                            state    <= RX_IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= RX_IDLE;
            endcase
        end
    end

endmodule
