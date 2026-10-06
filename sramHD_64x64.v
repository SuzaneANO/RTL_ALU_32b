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
