// File: ALU_32b.v
// Description: 32-bit Addition/Subtraction unit
// ============================================================================
module addsub_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_ALU,
    input  wire [1:0]  cmd,
    input  wire [63:0] op1,
    input  wire [63:0] op2,
    output reg  [63:0] res,
    output reg         done
);



    always @(posedge clk or posedge rst) begin
        if (rst) begin
            res  <= 64'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (en_ALU) begin
                case (cmd)
                    `CMD_ADD: begin
                        res  <= op1 + op2;
                        done <= 1'b1;
                    end
                    `CMD_SUB: begin
                        res  <= op1 - op2;
                        done <= 1'b1;
                    end
                    default: begin
                        res  <= 64'd0;
                        done <= 1'b1;
                    end
                endcase
            end
        end
    end

endmodule

// ============================================================================
