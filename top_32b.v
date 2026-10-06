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

    // Clock Gating
    wire gated_clk = clk & global_en;

    // ============================================================
    // Scheduler Interconnect Wires
    // ============================================================
    wire [1:0]  scheduler_cmd;
    wire [1:0]  scheduler_array_select;
    wire [5:0]  scheduler_mem_addr;
    wire        scheduler_mem_we;
    wire        scheduler_mem_me;
    wire        en_addsub;
    wire        en_mult;
    wire [31:0] state_name;

    // ============================================================
    // Sub-Module Data & Control Wires
    // ============================================================
    wire [63:0] mem0_q;
    wire [63:0] mem1_q;
    wire [63:0] alu_res;
    wire [63:0] mult_res;
    wire        alu_done;
    wire        mult_done;

    // ============================================================
    // Host Burst Address Counter (Auto-increments during TB operations)
    // ============================================================
    reg [5:0] host_addr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            host_addr <= 6'd0;
        end else if (wr_mem_start || rd_mem_start) begin
            host_addr <= host_addr + 1'b1;
        end else begin
            host_addr <= 6'd0;
        end
    end

    // ============================================================
    // External Host Access vs. Scheduler Control Multiplexing
    // ============================================================
    wire [1:0] effective_array_select;
    wire       effective_mem_we;
    wire       effective_mem_me;
    wire [5:0] effective_mem_addr;

    // Defer array selection to testbench during manual burst access
    assign effective_array_select = (wr_mem_start || rd_mem_start)
                                  ? array_select
                                  : scheduler_array_select;

    // Override Write Enable during external write phase
    assign effective_mem_we = wr_mem_start
                            ? 1'b1
                            : scheduler_mem_we;

    // Enable Memory Chip Select during host access or scheduler cycles
    assign effective_mem_me = (wr_mem_start || rd_mem_start)
                            ? 1'b1
                            : scheduler_mem_me;

    // Select host auto-increment counter during burst transfers
    assign effective_mem_addr = (wr_mem_start || rd_mem_start)
                              ? host_addr
                              : scheduler_mem_addr;

    // ============================================================
    // Memory Selection Decoding
    // ============================================================
    wire mem0_we = effective_mem_we && (effective_array_select == `ARRAY_SEL0);
    wire mem1_we = effective_mem_we && (effective_array_select == `ARRAY_SEL1);
    wire mem2_we = effective_mem_we && (effective_array_select == `ARRAY_SEL2);

    wire mem0_me = effective_mem_me && (effective_array_select == `ARRAY_SEL0);
    wire mem1_me = effective_mem_me && (effective_array_select == `ARRAY_SEL1);
    wire mem2_me = effective_mem_me && (effective_array_select == `ARRAY_SEL2);

    // Result Write-Back Routing for MEM2
    wire [63:0] wb_data = (scheduler_cmd == `CMD_MULT) ? mult_res : alu_res;

    // ============================================================
    // Submodule Instantiations
    // ============================================================

    // Scheduler Control Unit
    top_scheduler I_TOP_SCHEDULER (
        .clk               (clk),
        .rst               (rst),
        .alu_compute_start (alu_compute_start),
        .alu_done          (alu_done),
        .mult_done         (mult_done),
        .cmd_out           (scheduler_cmd),
        .en_addsub         (en_addsub),
        .en_mult           (en_mult),
        .array_select      (scheduler_array_select),
        .mem_addr          (scheduler_mem_addr),
        .mem_we            (scheduler_mem_we),
        .mem_me            (scheduler_mem_me),
        .state_name        (state_name)
    );

    // Adder / Subtractor Unit
    addsub_32b I_ADDSUB (
        .clk    (gated_clk),
        .rst    (rst),
        .en_ALU (en_addsub),
        .cmd    (scheduler_cmd),
        .op1    (mem0_q[31:0]),
        .op2    (mem1_q[31:0]),
        .res    (alu_res),
        .done   (alu_done)
    );

    // Multiplier Unit
    mult_32b I_MULT (
        .clk    (gated_clk),
        .rst    (rst),
        .start  (en_mult),
        .cmd    (scheduler_cmd),
        .op1    (mem0_q[31:0]),
        .op2    (mem1_q[31:0]),
        .res    (mult_res),
        .done   (mult_done)
    );

    // MEM0: Stores Operand 0
    sramHD_64x64 MEM0 (
        .CLK (gated_clk),
        .ME  (mem0_me),
        .WE  (mem0_we),
        .ADR (effective_mem_addr),
        .D   (data_in_top),
        .Q   (mem0_q)
    );

    // MEM1: Stores Operand 1
    sramHD_64x64 MEM1 (
        .CLK (gated_clk),
        .ME  (mem1_me),
        .WE  (mem1_we),
        .ADR (effective_mem_addr),
        .D   (data_in_top),
        .Q   (mem1_q)
    );

    // MEM2: Stores ALU / Multiplier Computation Results
    sramHD_64x64 MEM2 (
        .CLK (gated_clk),
        .ME  (mem2_me),
        .WE  (mem2_we),
        .ADR (effective_mem_addr),
        .D   (wb_data),
        .Q   (pin_data_out_mem2)
    );

    // Output Pin Routing
    assign pin_data_out_mem0 = mem0_q;
    assign pin_data_out_mem1 = mem1_q;

endmodule