`timescale 1ns / 1ps

// Memory interface to deal with 4x4800 memory values (essentially
// one memory value for each 4x4 block in a 320x240 image)
// Note that this contains two buffers for both a min and max value
// so it duplicates the buffer accesses of the normal memory
module memory_4x4(
   input clk,
   input rea,
   input wea,
   input [12:0] addr_read,
   input [12:0] addr_read2,
   input [12:0] addr_write,
   input [3:0] din_max,
   input [3:0] din_min,
   output reg [3:0] dout_max,
   output reg [3:0] dout_max2,
   output reg [3:0] dout_min,
   output reg [3:0] dout_min2
   );
   
   // Buffers (BRAM)
   reg [3:0] ram_max [4799:0];
   reg [3:0] ram_min [4799:0];
   
   // Write when enabled
   always @(posedge clk) begin
       if (wea)
       begin
            ram_max[addr_write] <= din_max;
            ram_min[addr_write] <= din_min;
       end
   end

    // Read when enabled
   always @(posedge clk) begin
       if (rea)
       begin
           dout_max <= ram_max[addr_read];
           dout_min <= ram_min[addr_read];
           dout_max2 <= ram_max[addr_read2];
           dout_min2 <= ram_min[addr_read2];
       end
   end

    

endmodule
