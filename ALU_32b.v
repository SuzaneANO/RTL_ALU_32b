// File: ALU_32b.v
// Description: 32-bit Addition/Subtraction unit
// ============================================================================
module addsub_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        en_ALU,
    input  wire [1:0]  cmd,
    input  wire [31:0] op1,
    input  wire [31:0] op2,
    output reg  [63:0] res, // Extended to 64-bit to match datapath/MEM writes
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
                        res  <= {32'd0, (op1 + op2)};
                        done <= 1'b1;
                    end
                    `CMD_SUB: begin
                        res  <= {32'd0, (op1 - op2)};
                        done <= 1'b1;
                    end
                    default: begin
                        res  <= 64'd0;
                        done <= 1'b1; // Complete NOOP immediately
                    end
                endcase
            end
        end
    end
endmodule

// ============================================================================
