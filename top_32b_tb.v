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

    // Testbench memory arrays declared outside procedural blocks
    reg [63:0] mem0_test_data [0:15];
    reg [63:0] mem1_test_data [0:15];

    reg [2:0] test_instructions [0:15];
    

    parameter T = 10; // 100 MHz clock period

    // UUT Instance
    top_32b uut (
        .clk               (clk),
        .rst               (rst),
        .global_en         (global_en),
        .alu_compute_start (alu_compute_start),
        .rd_mem_start      (rd_mem_start),
        .wr_mem_start      (wr_mem_start),
        .array_select      (array_select),
        .cmd_top           (cmd_top),    // Connected
        .mode_top          (mode_top),   // Connected
        .data_in_top       (data_in_top),
        .pin_data_out_mem0 (pin_data_out_mem0),
        .pin_data_out_mem1 (pin_data_out_mem1),
        .pin_data_out_mem2 (pin_data_out_mem2),
        .current_instruction_cmd (tb_instruction_cmd)
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
        // STIMULUS MEMORY ARRAYS (Table 16 Operations Data)
        // ====================================================================
       

        // Populate Operand 0 and Operand 1 arrays
        mem0_test_data[0]  = 64'h0000_0000_0000_000F; mem1_test_data[0]  = 64'h0000_0000_0000_00F0; // ADD
        mem0_test_data[1]  = 64'h0000_0000_0000_0000; mem1_test_data[1]  = 64'h0000_0000_0000_0000; // MULT
        mem0_test_data[2]  = 64'h0000_FFFF_0000_0000; mem1_test_data[2]  = 64'h0000_0000_FFFF_0000; // ADD
        mem0_test_data[3]  = 64'h0000_0000_FFFF_FFFF; mem1_test_data[3]  = 64'h0000_0000_FFFF_FFFF; // SUB
        mem0_test_data[4]  = 64'h0000_0000_FFFF_FFFF; mem1_test_data[4]  = 64'h0000_0000_0000_0000; // NOOP
        mem0_test_data[5]  = 64'h0000_0000_FFFF_FFFF; mem1_test_data[5]  = 64'h0000_0000_FFFF_FFFF; // MULT
        mem0_test_data[6]  = 64'h0000_0000_0000_000F; mem1_test_data[6]  = 64'h0000_0000_0000_000F; // MULT
        mem0_test_data[7]  = 64'h0000_0000_0000_0000; mem1_test_data[7]  = 64'h0000_0000_0000_0000; // MULT
        mem0_test_data[8]  = 64'h0000_0000_0000_FFFF; mem1_test_data[8]  = 64'h0000_0000_0000_FFFF; // MULT
        mem0_test_data[9]  = 64'h0000_0000_0000_0000; mem1_test_data[9]  = 64'h0000_0000_0000_0000; // MULT
        mem0_test_data[10] = 64'h0000_0000_0FFF_FFFF; mem1_test_data[10] = 64'h0000_0000_0FFF_FFFF; // MULT
        mem0_test_data[11] = 64'h0000_0000_0000_0000; mem1_test_data[11] = 64'h0000_0000_0000_0000; // MULT
        mem0_test_data[12] = 64'h0000_0000_FFFF_FFFF; mem1_test_data[12] = 64'h0000_0000_FFFF_FF00; // MULT
        mem0_test_data[13] = 64'h0000_0000_0000_0000; mem1_test_data[13] = 64'h0000_0000_0000_0000; // MULT
        mem0_test_data[14] = 64'h0000_0000_FFFF_FFFF; mem1_test_data[14] = 64'h0000_0000_FFFF_FFFF; // MULT
        mem0_test_data[15] = 64'h0000_0000_0000_0000; mem1_test_data[15] = 64'h0000_0000_0000_0000; // MULT
    

        test_instructions[0]  = `CMD_ADD;  // 000000000000000F + 00000000000000F0
        test_instructions[1]  = `CMD_MULT; // 0000000000000000 * 0000000000000000
        test_instructions[2]  = `CMD_ADD;  // 0000FFFF00000000 + 00000000FFFF0000
        test_instructions[3]  = `CMD_SUB;  // 00000000FFFFFFFF - 00000000FFFFFFFF -> 0x0
        test_instructions[4]  = `CMD_ADD;  // NOOP / Default ADD
        test_instructions[5]  = `CMD_MULT; // 00000000FFFFFFFF * 00000000FFFFFFFF
        test_instructions[6]  = `CMD_MULT; // 000000000000000F * 000000000000000F
        test_instructions[7]  = `CMD_MULT; // 0000000000000000 * 0000000000000000
        test_instructions[8]  = `CMD_MULT; // 000000000000FFFF * 000000000000FFFF
        test_instructions[9]  = `CMD_MULT; // 0000000000000000 * 0000000000000000
        test_instructions[10] = `CMD_MULT; // 000000000FFF_FFFF * 000000000FFF_FFFF
        test_instructions[11] = `CMD_MULT; // 0000000000000000 * 0000000000000000
        test_instructions[12] = `CMD_MULT; // 00000000FFFFFFFF * 00000000FFFFFF00
        test_instructions[13] = `CMD_MULT; // 0000000000000000 * 0000000000000000
        test_instructions[14] = `CMD_MULT; // 00000000FFFFFFFF * 00000000FFFFFFFF
        test_instructions[15] = `CMD_MULT; // 0000000000000000 * 0000000000000000   


    // ====================================================================
    // PHASE 1: Write to MEM0 (Populate Operand 0 Array)
    // ====================================================================
    array_select = 2'b00;
    wr_mem_start = 1;

    for (i = 0; i < 16; i = i + 1) begin
        data_in_top = mem0_test_data[i];
        #(T);
    end

    wr_mem_start = 0;
    array_select = 2'b11;
    #(2 * T);

    // ====================================================================
    // PHASE 2: Write to MEM1 (Populate Operand 1 Array)
    // ====================================================================
    array_select = 2'b01; // Select MEM1
    wr_mem_start = 1;

    for (i = 0; i < 16; i = i + 1) begin
        data_in_top = mem1_test_data[i];
        #(T);
    end

    wr_mem_start = 0;
    array_select = 2'b11;
    #(2 * T);

    // ====================================================================
    // PHASE 3: Execute ALU Computation Sequence
    // ====================================================================
    // Testbench Instruction Array
    

    initial begin
        // Reset and initialization sequences...
        alu_compute_start = 1'b0;
        tb_instruction_cmd = `CMD_ADD;
        
        // Wait for reset to complete
        wait(!rst);
        #20;

        $display("--- Starting Step-by-Step Hardware Execution ---");

        for (i = 0; i < 16; i = i + 1) begin
            // 1. Set command for current operation BEFORE start pulse
            @(posedge clk);
            tb_instruction_cmd = test_instructions[i];

            // 2. Pulse alu_compute_start high for exactly 1 clock cycle
            alu_compute_start = 1'b1;
            @(posedge clk);
            alu_compute_start = 1'b0;

            // 3. Wait for FSM to leave IDLE, complete execution, and return to IDLE
            @(posedge clk);
            while (I_TOP_SCHEDULER.state_current != 3'd0) begin
                @(posedge clk);
            end

            $display("Completed Op %0d with Cmd %b", i, test_instructions[i]);
            #10; // Brief pause between operations
        end

        $display("--- All 16 Operations Completed ---");
        $finish;
    end

    // Wait for SCHEDULER to complete all 16 operations & writes to MEM2
    // Adjust total cycles depending on Multiplier/ALU execution latency
    #(128 * T); 

    // ====================================================================
    // PHASE 4: Read from MEM2 (Burst Read Results)
    // ====================================================================
    array_select = 2'b10; // Select MEM2
    rd_mem_start = 1;

    #(16 * T);

    rd_mem_start = 0;
    array_select = 2'b11;
    #(5 * T);

    $display("Full 4-phase testbench execution completed successfully.");
    $finish;
end

endmodule
