`timescale 1ns/1ps

module top_32b_tb;

    // Clock and Global Control
    reg        clk;
    reg        rst;
    reg        global_en;

    // Scheduler / Top Commands
    reg        alu_compute_start;
    reg        rd_mem_start;
    reg        wr_mem_start;
    reg [1:0]  array_select;
    reg [1:0]  cmd_top;
    reg        mode_top;

    // Data Buses
    reg  [63:0] data_in_top;
    wire [63:0] pin_data_out_mem0;
    wire [63:0] pin_data_out_mem1;
    wire [63:0] pin_data_out_mem2;

    parameter T = 10; // 100 MHz clock period

    // UUT Instance
    top_32b uut (
        .clk               (clk),
        .rst               (rst),
        .global_en         (global_en),
        .alu_compute_start (alu_compute_start),
        .rd_mem_start      (rd_mem_start),
        .wr_mem_start      (wr_mem_start),
        .data_in_top       (data_in_top),
        .pin_data_out_mem0 (pin_data_out_mem0),
        .pin_data_out_mem1 (pin_data_out_mem1),
        .pin_data_out_mem2 (pin_data_out_mem2)
    );

    // Continuous Clock Generation
    always #(T/2) clk = ~clk;

    integer i;

    initial begin
        $dumpfile("top_32b_tb.vcd");
        $dumpvars(0, top_32b_tb);

        // ====================================================================
        // PHASE 1: Testbench Init
        // ====================================================================
        clk               = 0;
        rst               = 1;
        global_en         = 0;
        alu_compute_start = 0;
        rd_mem_start      = 0;
        wr_mem_start      = 0;
        array_select      = 2'b11; // ARRAY_NONE
        cmd_top           = 2'b00;
        mode_top          = 0;
        data_in_top       = 64'h0;

        #(2.5 * T);
        rst       = 0;
        global_en = 1;
        #(T);

        // ====================================================================
        // PHASE 2: Write to MEM0 (Populate Operand 0 Array)
        // ====================================================================
        array_select = 2'b00; // Select MEM0
        wr_mem_start = 1;
        
        for (i = 0; i < 16; i = i + 1) begin
            data_in_top = i; // Assign integer directly to 64-bit bus
            #(T);
        end
        
        wr_mem_start = 0;
        array_select = 2'b11;
        #(2 * T);

        // ====================================================================
        // PHASE 3: Write to MEM1 (Populate Operand 1 Array)
        // ====================================================================
        array_select = 2'b01; // Select MEM1
        wr_mem_start = 1;

        for (i = 0; i < 16; i = i + 1) begin
            data_in_top = i + 16; // Direct arithmetic assignment
            #(T);
        end

        wr_mem_start = 0;
        array_select = 2'b11;
        #(2 * T);

        // ====================================================================
        // PHASE 4: Compute And write MEM2
        // ====================================================================
        alu_compute_start = 1;
        #(T);
        alu_compute_start = 0;

        // Wait for scheduler to complete 16 arithmetic ops & MEM2 writes
        #(64 * T);

        // ====================================================================
        // PHASE 5: Read from MEM2 (Burst Read Results)
        // ====================================================================
        array_select = 2'b10; // Select MEM2
        rd_mem_start = 1;

        #(16 * T);

        rd_mem_start = 0;
        array_select = 2'b11;
        #(5 * T);

        $display("Full 5-phase testbench execution completed successfully.");
        $finish;
    end

endmodule
