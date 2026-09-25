//------------------------------------------------------------------------
// baud_gen.sv
//
// Produces a single-cycle pulse, tick16, at 16x the target baud rate.
// Everything downstream (uart_tx, uart_rx) is built around counting 16
// of these ticks per UART bit -- 1x for the actual bit rate, and a further
// division inside uart_rx to sample each bit at its midpoint instead of
// right on its edge. Oversampling this way is what lets the receiver
// tolerate a start bit that doesn't land exactly on a tick boundary and
// still decide correctly where the middle of each bit is.
//
// DIVISOR is computed with integer (truncating) division, so the realized
// baud rate is very slightly off from the requested one. At the default
// 100 MHz / 115200 baud this works out to DIVISOR = 54, i.e. an actual
// rate of 100e6 / (54*16) = 115740.7 baud -- 0.47% high, well inside the
// ~2% a UART link tolerates before bit sampling starts drifting into the
// wrong bit.
//------------------------------------------------------------------------
module baud_gen #(
    parameter int CLK_FREQ_HZ = 100_000_000,
    parameter int BAUD_RATE   = 115_200
)(
    input  logic clk,
    input  logic rst_n,
    output logic tick16
);

    localparam int DIVISOR = CLK_FREQ_HZ / (BAUD_RATE * 16);

    // Sanity net for simulation only: if someone sets CLK_FREQ_HZ too low
    // relative to BAUD_RATE, DIVISOR truncates to 0 and this whole module
    // stops meaning anything. Loud and immediate beats a silently-wrong baud.
    initial begin
        if (DIVISOR < 1) begin
            $error("baud_gen: CLK_FREQ_HZ (%0d) is too low for BAUD_RATE (%0d) -- need CLK_FREQ_HZ >= BAUD_RATE*16",
                    CLK_FREQ_HZ, BAUD_RATE);
        end
    end

    logic [$clog2(DIVISOR+1)-1:0] count;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count  <= '0;
            tick16 <= 1'b0;
        end else if (count == DIVISOR - 1) begin
            count  <= '0;
            tick16 <= 1'b1;
        end else begin
            count  <= count + 1'b1;
            tick16 <= 1'b0;
        end
    end

endmodule
