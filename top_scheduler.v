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
    output reg         en_addsub,
    output reg         en_mult,
    output reg  [1:0]  array_select,
    output reg  [5:0]  mem_addr,
    output reg         mem_we,
    output reg         mem_me,
    output reg [127:0] state_name // String output for text rendering in GTKWave
);
    // FSM States
    localparam IDLE        = 3'd0,
               READ_MEMS   = 3'd1,
               WAIT_MEM    = 3'd2,
               EXECUTE     = 3'd3,
               WRITE_MEM2  = 3'd4;
               
    reg [2:0] state_current, state_next;
    reg [5:0] reg_counter; // FIXED: Expanded from 5 bits to 6 bits to match mem_addr[5:0]

    // Sequential State & Address Counter Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_current <= IDLE;
            reg_counter   <= 6'd0; // FIXED: Explicit 6-bit reset value
        end else begin
            state_current <= state_next;
            if (state_current == WRITE_MEM2)
                reg_counter <= reg_counter + 1'b1;
            else if (state_current == IDLE)
                reg_counter <= 6'd0; // FIXED: Explicit 6-bit reset in IDLE
        end
    end

    // Combinatorial ASCII State Converter for GTKWave Text Display
    always @(*) begin
        case (state_current)
            IDLE:       state_name = "IDLE";
            READ_MEMS:  state_name = "READ_MEMS";
            WAIT_MEM:   state_name = "WAIT_MEM";
            EXECUTE:    state_name = "EXECUTE";
            WRITE_MEM2: state_name = "WRITE_MEM2";
            default:    state_name = "UNKNOWN";
        endcase
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
        mem_addr     = reg_counter; // FIXED: Clean 6-bit vector assignment without bit slice errors

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
                cmd_out = `CMD_ADD; // Driven by instruction sequence/ROM
                if (cmd_out == `CMD_MULT)
                    en_mult = 1'b1;
                else
                    en_addsub = 1'b1;

                if (alu_done || mult_done)
                    state_next = WRITE_MEM2;
            end

            WRITE_MEM2: begin
                mem_me       = 1'b1;
                mem_we       = 1'b1;
                array_select = `ARRAY_SEL2; // Route results to MEM2
                
                if (reg_counter == 6'd15) // FIXED: 6-bit literal comparison
                    state_next = IDLE;
                else
                    state_next = READ_MEMS;
            end

            default: state_next = IDLE;
        endcase
    end
endmodule