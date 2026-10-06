// File: mult_32b.v
// Description: 32-bit Multiplier unit
// ============================================================================
module mult_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [1:0]  cmd,
    input  wire [63:0] op1,
    input  wire [63:0] op2,
    output reg  [63:0] res,
    output reg         done
);

    reg [127:0] full_prod;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            full_prod <= 128'd0;
            res       <= 64'd0;
            done      <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && (cmd == `CMD_MULT)) begin
                full_prod = op1 * op2;
                res       <= full_prod[127:64]; // Extract upper 64 MSBs
                done      <= 1'b1;
            end
        end
    end

endmodule

// ============================================================================
