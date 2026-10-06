// File: mult_32b.v
// Description: 32-bit Multiplier unit
// ============================================================================
module mult_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [1:0]  cmd,
    input  wire [31:0] op1,
    input  wire [31:0] op2,
    output reg  [63:0] res,
    output reg         done
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res  <= 64'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (start && cmd == `CMD_MULT) begin
                res  <= op1 * op2;
                done <= 1'b1; // Modeled as a single-cycle multiplier per the lab specs
            end
        end
    end
endmodule

// ============================================================================
