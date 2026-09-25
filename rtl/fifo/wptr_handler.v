module wptr_handler #(
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,
    input  wire                  wrst_n,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH:0]   wq2_rptr, 
    output wire [ADDR_WIDTH-1:0] waddr,
    output reg  [ADDR_WIDTH:0]   wptr_gray,
    output reg                   full       // 1. CHANGE TO REG
);
    reg  [ADDR_WIDTH:0] wbin;
    wire [ADDR_WIDTH:0] wbin_next = wbin + (wr_en & ~full);
    wire [ADDR_WIDTH:0] wgray_next = (wbin_next >> 1) ^ wbin_next;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin      <= 0;
            wptr_gray <= 0;
            full      <= 1'b0; // 2. FIFO STARTS NOT FULL
        end else begin
            wbin      <= wbin_next;
            wptr_gray <= wgray_next;
            full      <= (wgray_next == {~wq2_rptr[ADDR_WIDTH:ADDR_WIDTH-1], wq2_rptr[ADDR_WIDTH-2:0]}); // 3. MOVE LOGIC HERE
        end
    end

    assign waddr = wbin[ADDR_WIDTH-1:0];

    // REMOVE the "assign full = ..." line that used to be here

endmodule