// File: top_scheduler.v
// Description: Central FSM controller for sequence scheduling and memory routing
// ============================================================================
`include "alu32_pkg.vh"

module top_scheduler (
    input  wire        clk,
    input  wire        rst,
    input  wire        alu_compute_start,
    input  wire        alu_done,
    input  wire        mult_done,
    output reg  [1:0]  cmd_out,
    input  wire [2:0]  current_instruction_cmd,
    output reg         en_addsub,
    output reg         en_mult,
    output reg  [1:0]  array_select,
    output reg  [5:0]  mem_addr,
    output reg         mem_we,
    output reg         mem_me,
    output reg  [2:0]  state_current,
    output reg         wr_mem_start
);
    // FSM States
    localparam IDLE        = 3'd0,
               READ_MEMS   = 3'd1,
               WAIT_MEM    = 3'd2,
               EXECUTE     = 3'd3,
               WRITE_MEM2  = 3'd4,
               HOLD_WRITE  = 3'd5;
               
    reg [2:0] state_next;
    reg [5:0] reg_counter;

    // Sequential State & Address Counter Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_current <= IDLE;
            reg_counter   <= 6'd0;
        end else begin
            state_current <= state_next;
            // Increment instruction/memory address counter when completing the write cycle
            if (state_current == HOLD_WRITE)
                reg_counter <= reg_counter + 1'b1;
        end
    end

    // Combinatorial Next-State and Output Logic
    always @(*) begin
        // Default outputs
        state_next   = state_current;
        cmd_out      = `CMD_NOOP;
        en_addsub    = 1'b0;
        en_mult      = 1'b0;
        array_select = `ARRAY_NONE;
        mem_we       = 1'b0;
        mem_me       = 1'b0;
        mem_addr     = reg_counter;

        case (state_current)
            IDLE: begin
                if (alu_compute_start)
                    state_next = READ_MEMS;
            end

            READ_MEMS: begin
                // Issue read command to MEM0 and MEM1
                mem_me     = 1'b1;
                mem_we     = 1'b0; 
                state_next = WAIT_MEM;
            end
            
            WAIT_MEM: begin
                // 1 cycle latency delay for SRAM read data to propagate to Q
                mem_me     = 1'b1;
                state_next = EXECUTE;
            end

            EXECUTE: begin
                cmd_out = current_instruction_cmd;
                if (cmd_out == `CMD_MULT)
                    en_mult = 1'b1;
                else
                    en_addsub = 1'b1 ;
                    

                if (alu_done || mult_done)
                    wr_mem_start = 1'b1;
                    state_next = WRITE_MEM2;
            end

            WRITE_MEM2: begin
                // Assert WE and ME while holding D on array_select
                wr_mem_start = 1'b1; 
                mem_me       = 1'b1;
                mem_we       = 1'b1;
                array_select = `ARRAY_SEL2;
                state_next   = HOLD_WRITE;
            end

            HOLD_WRITE: begin
                // Deassert WE while keeping array_select stable for SRAM hold time
                wr_mem_start = 1'b0;
                mem_me       = 1'b0;
                mem_we       = 1'b0;
                array_select = `ARRAY_SEL2;
                state_next   = IDLE;
            end

            default: state_next = IDLE;
        endcase
    end
endmodule