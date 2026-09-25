module rptr_handler #(
    parameter ADDR_WIDTH = 4
)(
    input                       rclk,
    input                       rrst_n,
    input                       rd_en,
    input      [ADDR_WIDTH:0]   rq2_wptr,
    output     [ADDR_WIDTH-1:0] raddr,
    output reg [ADDR_WIDTH:0]   rptr_gray,
    output reg                  empty       // 1. CHANGE TO REG
);
    reg  [ADDR_WIDTH:0] rbin;
    wire [ADDR_WIDTH:0] rbin_next = rbin + (rd_en & ~empty);
    wire [ADDR_WIDTH:0] rgray_next = (rbin_next >> 1) ^ rbin_next;

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin      <= 0;
            rptr_gray <= 0;
            empty     <= 1'b1; // 2. FIFO STARTS EMPTY ON RESET
        end else begin
            rbin      <= rbin_next;
            rptr_gray <= rgray_next;
            empty     <= (rgray_next == rq2_wptr); // 3. MOVE LOGIC HERE
        end
    end

    assign raddr = rbin[ADDR_WIDTH-1:0];
    
    // REMOVE the "assign empty = ..." line that used to be here

endmodule