// File: top_32b.v
// Description: Top-level integration matching Control Registers, SRAMs, ALU, MULT, and Scheduler
// ============================================================================
module top_32b (
    input  wire        clk,
    input  wire        rst,
    input  wire        global_en,
    input  wire        alu_compute_start,
    input  wire        rd_mem_start,
    input  wire        wr_mem_start,
    input  wire [1:0]  array_select,
    input  wire [1:0]  cmd_top,       // Control and Status Register input
    input  wire        mode_top,      // Control and Status Register input
    input  wire [63:0] data_in_top,
    input  wire [2:0]  current_instruction_cmd,
    output wire [63:0] pin_data_out_mem0,
    output wire [63:0] pin_data_out_mem1,
    output wire [63:0] pin_data_out_mem2,
    output wire        wr_mem2_start
);

    // Gated Clocking
    wire gated_clk = clk & global_en;

    // ============================================================
    // Control & Status Registers Interconnects
    // ============================================================
    reg [1:0] reg_cmd;
    reg       reg_mode;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            reg_cmd  <= 2'b00;
            reg_mode <= 1'b0;
        end else begin
            reg_cmd  <= cmd_top;
            reg_mode <= mode_top;
        end
    end

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
    wire [2:0] state_current;

    // ============================================================
    // Memory Output & Execution Unit Signals
    // ============================================================
    wire [63:0] mem0_q;
    wire [63:0] mem1_q;
    wire [63:0] mem2_q;
    wire [63:0] alu_res;
    wire [63:0] mult_res;
    wire        alu_done;
    wire        mult_done;

    // ============================================================
    // Host Burst Address Counter (Auto-increments for TB)
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
    // Host Control vs. Scheduler Control Multiplexing
    // ============================================================
    wire host_active = wr_mem_start || rd_mem_start;

    wire [1:0] effective_array_select = host_active ? array_select      : scheduler_array_select;
    wire [5:0] effective_mem_addr     = host_active ? host_addr         : scheduler_mem_addr;
    wire       effective_mem_we       = host_active ? wr_mem_start      : scheduler_mem_we;
    wire       effective_mem_me       = host_active ? 1'b1              : scheduler_mem_me;

    // Memory Enables & Write Enables
    wire mem0_me = host_active ? (array_select == `ARRAY_SEL0) : effective_mem_me;
    wire mem1_me = host_active ? (array_select == `ARRAY_SEL1) : effective_mem_me;
    wire mem2_me = host_active ? (array_select == `ARRAY_SEL2) : (effective_mem_me && (scheduler_array_select == `ARRAY_SEL2));

    wire mem0_we = host_active ? (wr_mem_start && (array_select == `ARRAY_SEL0)) : (effective_mem_we && (scheduler_array_select == `ARRAY_SEL0));
    wire mem1_we = host_active ? (wr_mem_start && (array_select == `ARRAY_SEL1)) : (effective_mem_we && (scheduler_array_select == `ARRAY_SEL1));
    wire mem2_we = host_active ? (wr_mem_start && (array_select == `ARRAY_SEL2)) : (effective_mem_we && (scheduler_array_select == `ARRAY_SEL2));

    // ============================================================
    // Input Data Demultiplexer (Control & Status Registers routing)
    // ============================================================
    wire [63:0] data_in_mem0      = (wr_mem_start && (array_select == `ARRAY_SEL0)) ? data_in_top : 64'h0;
    wire [63:0] data_in_mem1      = (wr_mem_start && (array_select == `ARRAY_SEL1)) ? data_in_top : 64'h0;
    wire [63:0] data_in_mem2_host = (wr_mem_start && (array_select == `ARRAY_SEL2)) ? data_in_top : 64'h0;



    // ============================================================
    // Result MUX (res_sel) & MEM2 Input MUX
    // ============================================================
    // res_sel multiplexes execution results from ADD/SUB and MULT32b
    wire [63:0] res_sel_out = (scheduler_cmd == `CMD_MULT) ? mult_res : alu_res;

    // MUX into MEM2 D input: Chooses between external data_in_top and computation result
    wire [63:0] data_in_mem2 = (wr_mem2_start && (array_select == `ARRAY_SEL2)) 
                             ? data_in_top 
                             : res_sel_out;

    // ============================================================
    // Submodule Instantiations
    // ============================================================

    // Scheduler Unit
    top_scheduler I_TOP_SCHEDULER (
        .clk               (clk),
        .rst               (rst),
        .alu_compute_start (alu_compute_start),
        
        .alu_done          (alu_done),
        .mult_done         (mult_done),
        .cmd_out           (scheduler_cmd),
        .current_instruction_cmd (current_instruction_cmd),
        .en_addsub         (en_addsub),
        .en_mult           (en_mult),
        .array_select      (scheduler_array_select),
        .mem_addr          (scheduler_mem_addr),
        .mem_we            (scheduler_mem_we),
        .mem_me            (scheduler_mem_me),
        .state_current            (state_current),
        .wr_mem2_start (wr_mem2_start)
        );

    // Adder / Subtractor Unit
    addsub_32b I_ADDSUB (
        .clk    (gated_clk),
        .rst    (rst),
        .en_ALU (en_addsub),
        .cmd    (scheduler_cmd),
        .op1    (mem0_q),
        .op2    (mem1_q),
        .res    (alu_res),
        .done   (alu_done)
    );

    // Multiplier Unit
    mult_32b I_MULT (
        .clk    (gated_clk),
        .rst    (rst),
        .start  (en_mult),
        .cmd    (scheduler_cmd),
        .op1    (mem0_q),
        .op2    (mem1_q),
        .res    (mult_res),
        .done   (mult_done)
    );

    // MEM0: Stores Operand 0
    sramHD_64x64 MEM0 (
        .CLK (gated_clk),
        .ME  (mem0_me),
        .WE  (mem0_we),
        .ADR (effective_mem_addr),
        .D   (data_in_mem0), // Dedicated input stream for MEM0
        .Q   (mem0_q)
    );

    // MEM1: Stores Operand 1
    sramHD_64x64 MEM1 (
        .CLK (gated_clk),
        .ME  (mem1_me),
        .WE  (mem1_we),
        .ADR (effective_mem_addr),
        .D   (data_in_mem1), // Dedicated input stream for MEM1
        .Q   (mem1_q)
    );

    // MEM2: Stores Computation Results or Host Writes
    sramHD_64x64 MEM2 (
        .CLK (gated_clk),
        .ME  (mem2_me),
        .WE  (mem2_we),
        .ADR (effective_mem_addr),
        .D   (data_in_mem2), // MUX output (res_sel_out vs data_in_mem2_host)
        .Q   (mem2_q)
    );

    // Top Output Ports
    assign pin_data_out_mem0 = mem0_q;
    assign pin_data_out_mem1 = mem1_q;
    assign pin_data_out_mem2 = mem2_q;

endmodule