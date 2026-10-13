(* blackbox *)
module sramHD_64x64 (
    input  wire        CLK,
    input  wire        ME,  // Memory Enable
    input  wire        WE,  // Write Enable
    input  wire [5:0]  ADR, // 64 words = 6-bit address
    input  wire [63:0] D,   // Data in
    output reg  [63:0] Q    // Data out
);
    reg [63:0] mem_core_array [0:63];

    // Declare loop variable for initialization
    integer j;

    // Initialize memory array and output to 0 at time 0
    initial begin
        for (j = 0; j < 64; j = j + 1) begin
            mem_core_array[j] = 64'h0;
        end
        Q = 64'h0;
    end

    // Clocked Read / Write Logic
    always @(posedge CLK) begin
        if (ME) begin
            if (WE)
                mem_core_array[ADR] <= D;
            else
                Q <= mem_core_array[ADR];
        end
    end

endmodule
