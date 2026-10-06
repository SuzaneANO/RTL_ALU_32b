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
    input  wire [1:0]  array_select,
    input  wire [63:0] data_in_top,
    output wire [63:0] pin_data_out_mem0,
    output wire [63:0] pin_data_out_mem1,
    output wire [63:0] pin_data_out_mem2
);
    // Internal gating
    wire gated_clk = clk & global_en;

    // Scheduler interconnects
    wire [1:0] cmd;
    wire [1:0] scheduler_array_select;
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
    .clk               (clk),
    .rst               (rst),
    .alu_compute_start (alu_compute_start),
    .alu_done          (alu_done),
    .mult_done         (mult_done),

    .cmd_out           (cmd_out),
    .en_addsub         (en_addsub),
    .en_mult           (en_mult),

    .array_select      (scheduler_array_select),

    .mem_addr          (mem_addr),
    .mem_we            (mem_we),
    .mem_me            (mem_me),
    .state_name        (state_name)
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
    .ME  ((sram_me & (arr_sel == `ARRAY_SEL0)) | (wr_mem_start & (arr_sel == `ARRAY_SEL0))),
    .WE  ((sram_we & (arr_sel == `ARRAY_SEL0)) | (wr_mem_start & (arr_sel == `ARRAY_SEL0))),
    .ADR (sram_addr),
    .D   (data_in_top),
    .Q   (mem0_q)
);

// MEM1: Stores Operand 1
sramHD_64x64 MEM1 (
    .CLK (gated_clk),
    .ME  ((sram_me & (arr_sel == `ARRAY_SEL1)) | (wr_mem_start & (arr_sel == `ARRAY_SEL1))),
    .WE  ((sram_we & (arr_sel == `ARRAY_SEL1)) | (wr_mem_start & (arr_sel == `ARRAY_SEL1))),
    .ADR (sram_addr),
    .D   (data_in_top),
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
