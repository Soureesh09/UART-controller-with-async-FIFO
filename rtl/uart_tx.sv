//------------------------------------------------------------------------
// uart_tx.sv
//
// Serializes one 8-bit word into a UART frame: 1 start bit (0), 8 data
// bits LSB-first, no parity, 1 stop bit (1) -- the fixed "8N1" format
// this whole project targets. txd idles high, as the UART spec requires.
//
// Every bit -- start, all 8 data bits, and stop -- is held for exactly
// 16 tick16 pulses from baud_gen, so the frame's bit rate is entirely
// baud_gen's responsibility; this module just counts ticks.
//------------------------------------------------------------------------
module uart_tx (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       tick16,    // 16x-oversample tick from baud_gen
    input  logic       tx_start,  // pulse: latch tx_data and begin a frame
    input  logic [7:0] tx_data,

    output logic       tx_busy,   // high for the whole frame; gate tx_start with this
    output logic       tx_done,   // 1-cycle pulse when the stop bit completes
    output logic       txd        // serial output; idles high
);

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_e;

    tx_state_e  state;
    logic [3:0] tick_cnt;   // 0..15 within the current bit
    logic [2:0] bit_idx;    // which data bit (0=LSB .. 7=MSB) is being sent
    logic [7:0] shift_reg;
    logic       txd_r;

    assign txd     = txd_r;
    assign tx_busy = (state != TX_IDLE);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= TX_IDLE;
            tick_cnt  <= '0;
            bit_idx   <= '0;
            shift_reg <= '0;
            txd_r     <= 1'b1;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;  // default -- only pulses for exactly 1 cycle

            unique case (state)
                // Wait for the caller to hand us a byte. tx_start must only
                // be pulsed while tx_busy is low -- the top-level FIFO glue
                // guarantees that; this module doesn't re-check it.
                TX_IDLE: begin
                    txd_r <= 1'b1;
                    if (tx_start) begin
                        shift_reg <= tx_data;
                        tick_cnt  <= '0;
                        state     <= TX_START;
                    end
                end

                // Drive the start bit low for one full bit period.
                TX_START: begin
                    txd_r <= 1'b0;
                    if (tick16) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            bit_idx  <= '0;
                            state    <= TX_DATA;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                // Shift one data bit out per 16 ticks, LSB first.
                TX_DATA: begin
                    txd_r <= shift_reg[0];
                    if (tick16) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt  <= '0;
                            shift_reg <= shift_reg >> 1;
                            if (bit_idx == 3'd7)
                                state <= TX_STOP;
                            else
                                bit_idx <= bit_idx + 1'b1;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                // Drive the stop bit high for one full bit period, then
                // signal done and go idle (ready to send the next byte
                // immediately -- back-to-back frames are fine).
                TX_STOP: begin
                    txd_r <= 1'b1;
                    if (tick16) begin
                        if (tick_cnt == 4'd15) begin
                            tick_cnt <= '0;
                            tx_done  <= 1'b1;
                            state    <= TX_IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= TX_IDLE;
            endcase
        end
    end

endmodule
