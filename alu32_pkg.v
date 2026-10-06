// ============================================================================
// File: alu32_pkg.vh
// Description: Global constants and definitions for the 32-bit Semicustom ALU
// ============================================================================
`define CMD_NOOP 2'b00
`define CMD_ADD  2'b01
`define CMD_SUB  2'b10
`define CMD_MULT 2'b11

`define ARRAY_SEL0 2'b00
`define ARRAY_SEL1 2'b01
`define ARRAY_SEL2 2'b10
`define ARRAY_NONE 2'b11

// ============================================================================
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
// File: sramHD_64x64.v
// Description: Behavioral wrapper for the 64x64 SRAM IP
// ============================================================================
module sramHD_64x64 (
    input  wire        CLK,
    input  wire        ME,  // Memory Enable
    input  wire        WE,  // Write Enable
    input  wire [5:0]  ADR, // 64 words = 6-bit address
    input  wire [63:0] D,   // Data in
    output reg  [63:0] Q    // Data out
);
    reg [63:0] mem_core_array [0:63];

    always @(posedge CLK) begin
        if (ME) begin
            if (WE)
                mem_core_array[ADR] <= D;
            else
                Q <= mem_core_array[ADR];
        end
    end
endmodule

// ============================================================================
// File: top_scheduler.v
// Description: Central FSM controller for sequence scheduling and memory routing
// ============================================================================
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
    output reg         mem_me
);
    // FSM States
    localparam IDLE        = 3'd0,
               READ_MEMS   = 3'd1,
               WAIT_MEM    = 3'd2,
               EXECUTE     = 3'd3,
               WRITE_MEM2  = 3'd4;
               
    reg [2:0] state_current, state_next;
    reg [4:0] reg_counter; // Tracks 16 operations (0 to 15)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state_current <= IDLE;
            reg_counter   <= 5'd0;
        end else begin
            state_current <= state_next;
            if (state_current == WRITE_MEM2)
                reg_counter <= reg_counter + 1;
            else if (state_current == IDLE)
                reg_counter <= 5'd0;
        end
    end

    always @(*) begin
        // Default outputs
        state_next   = state_current;
        cmd_out      = `CMD_NOOP;
        en_addsub    = 1'b0;
        en_mult      = 1'b0;
        array_select = `ARRAY_NONE;
        mem_we       = 1'b0;
        mem_me       = 1'b0;
        mem_addr     = reg_counter[5:0];

        case (state_current)
            IDLE: begin
                if (alu_compute_start)
                    state_next = READ_MEMS;
            end

            READ_MEMS: begin
                // Issue read command to MEM0 and MEM1
                mem_me = 1'b1;
                mem_we = 1'b0; 
                state_next = WAIT_MEM;
            end
            
            WAIT_MEM: begin
                // 1 cycle delay for SRAM read data to appear on Q
                state_next = EXECUTE;
            end

            EXECUTE: begin
                // Decode operation based on counter/ROM (Hardcoded sequence 0-15 per lab table)
                // For brevity, assuming an internal decode logic sets `cmd_out`
                // Example simplified trigger:
                cmd_out = `CMD_ADD; // In actual RTL, this is driven by an instruction ROM
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
                
                if (reg_counter == 5'd15)
                    state_next = IDLE;
                else
                    state_next = READ_MEMS;
            end
        endcase
    end
endmodule

// ============================================================================
// File: top_32b.v
// Description: Top-level integration of SRAMs, ALU, Multiplier, and Scheduler
// ============================================================================
module top_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        global_en,
    input  wire        alu_compute_start,
    input  wire        rd_mem_start,
    input  wire        wr_mem_start,
    input  wire [63:0] data_in_top,
    output wire [63:0] pin_data_out_mem0,
    output wire [63:0] pin_data_out_mem1,
    output wire [63:0] pin_data_out_mem2
);
    // Internal gating
    wire gated_clk = clk & global_en;

    // Scheduler interconnects
    wire [1:0] cmd;
    wire [1:0] arr_sel;
    wire [5:0] sram_addr;
    wire       sram_we, sram_me;
    wire       en_alu, en_mult;
    
    // ALU/Mult interconnects
    wire [63:0] mem0_q, mem1_q;
    wire [63:0] alu_res, mult_res;
    wire        alu_done, mult_done;
    
    // Write-back multiplexing
    wire [63:0] wb_data = (cmd == `CMD_MULT) ? mult_res : alu_res;

    // Scheduler Instance
    top_scheduler I_TOP_SCHEDULER (
        .clk               (gated_clk),
        .rst               (rst),
        .alu_compute_start (alu_compute_start),
        .alu_done          (alu_done),
        .mult_done         (mult_done),
        .cmd_out           (cmd),
        .en_addsub         (en_alu),
        .en_mult           (en_mult),
        .array_select      (arr_sel),
        .mem_addr          (sram_addr),
        .mem_we            (sram_we),
        .mem_me            (sram_me)
    );

    // ALU Instance
    addsub_32b I_ADDSUB (
        .clk    (gated_clk),
        .rst    (rst),
        .en_ALU (en_alu),
        .cmd    (cmd),
        .op1    (mem0_q[31:0]),
        .op2    (mem1_q[31:0]),
        .res    (alu_res),
        .done   (alu_done)
    );

    // Multiplier Instance
    mult_32b I_MULT (
        .clk    (gated_clk),
        .rst    (rst),
        .start  (en_mult),
        .cmd    (cmd),
        .op1    (mem0_q[31:0]),
        .op2    (mem1_q[31:0]),
        .res    (mult_res),
        .done   (mult_done)
    );

    // MEM0: Stores Operand 0
    sramHD_64x64 MEM0 (
        .CLK (gated_clk),
        .ME  (sram_me | wr_mem_start),
        .WE  (sram_we | wr_mem_start),
        .ADR (sram_addr),
        .D   (wr_mem_start ? data_in_top : 64'd0),
        .Q   (mem0_q)
    );

    // MEM1: Stores Operand 1
    sramHD_64x64 MEM1 (
        .CLK (gated_clk),
        .ME  (sram_me | wr_mem_start),
        .WE  (sram_we | wr_mem_start),
        .ADR (sram_addr),
        .D   (wr_mem_start ? data_in_top : 64'd0),
        .Q   (mem1_q)
    );

    // MEM2: Stores Results
    sramHD_64x64 MEM2 (
        .CLK (gated_clk),
        .ME  ((sram_me & (arr_sel == `ARRAY_SEL2)) | rd_mem_start),
        .WE  (sram_we & (arr_sel == `ARRAY_SEL2)),
        .ADR (sram_addr),
        .D   (wb_data),
        .Q   (pin_data_out_mem2)
    );

    // Routing for top-level memory output pins
    assign pin_data_out_mem0 = mem0_q;
    assign pin_data_out_mem1 = mem1_q;

endmodule
