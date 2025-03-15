`timescale 1ns / 1ps

// This module is a 19200x16 memory block with 1 read and 1 write port
// The access pattern is synthesizable by BRAM
module memory (
    input clk,
    input ena,
    input enb,
    input wea,
    input [14:0] addra,
    input [14:0] addrb,
    input [15:0] dia,
    output reg [15:0] dob
    );
    
    reg [15:0] ram [19199:0];

    // Write to write port if enabled
    always @(posedge clk) begin
        if (ena) begin
            if (wea)
                ram[addra] <= dia;
        end
    end

    // Read from read port if enabled
    always @(posedge clk) begin
        if (enb)
        begin
            dob <= ram[addrb];
        end
    end

endmodule
