module fifo_mem #(
    parameter WIDTH      = 8,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wclk,
    input  wire                  wr_en,
    input  wire [ADDR_WIDTH-1:0] waddr,
    input  wire [WIDTH-1:0]      wdata,
    input  wire [ADDR_WIDTH-1:0] raddr,
    output wire [WIDTH-1:0]      rdata
);

    reg [WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    always @(posedge wclk) begin
        if (wr_en) begin
            mem[waddr] <= wdata;
        end
    end

    assign rdata = mem[raddr];

endmodule