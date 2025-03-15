`timescale 1ns / 1ps


// This module reads the input from an OV7670 camera
// to a 16x19200 memory buffer and a 4x4800 running minimum
// and maximum memory buffer

// All pixels are converted to grayscale, and downsampling occurs
// in both the horizontal and the vertical direction 

// The running minimum and maximum buffer stores the local min and max
// values in a 4x4 area around each pixel

// To get only the memory values, just remove any reference to the 
// min/max memory
module camera_read(
    // Clock input/outputs
	input wire p_clock,        // Pixel clock (XCLK)
	input wire vsync,          // Camera vsync (vsync)
	input wire href,           // Camera hsync (href)
	input wire [7:0] p_data,   // Pixel data data[0:7]
	
	// Memory interface (frame buffer)
	output reg [15:0] dout,
	output reg write_out,
	output reg [14:0] addr,
	output wire ena,
	
	// Memory interface (min/max memory)
	input wire [3:0] max_read,
	input wire [3:0] min_read,
    output reg [12:0] min_max_addr_read, 
    output reg [12:0] min_max_addr_write,
    output wire [3:0] max_out, 
    output wire [3:0] min_out, 
    output wire min_max_write_enable 
    );
	 
	assign ena = 1;                // Always write to frame buffer 
	
	// Local state variables
	reg [1:0] FSM_state = 0;
    reg pixel_half = 0;
    reg [1:0] data_ind = 0;
    reg [9:0] hc;
    reg [9:0] vc;
    reg prev_hsync;
    reg pixel_valid;
    
    // Min-max state variables
    reg [3:0] curr_max;
    reg [3:0] curr_min;
    reg [3:0] running_max;
    reg [3:0] running_min;
    
    // Buffer for pixel data
    reg [15:0] pixel_data;
	
	// FSM constants
	localparam WAIT_FRAME_START = 0;
	localparam ROW_CAPTURE = 1;
	
	always@(posedge p_clock)
	begin 
	
	case(FSM_state)
	
	WAIT_FRAME_START: begin // Wait for vsync to be negated, indicating new frame
	   if (!vsync) // vsync negated, frame starts
	   begin
	       FSM_state <= ROW_CAPTURE; 
	       vc <= 0;
	       hc <= 0;
	   end
	   pixel_half <= 0;
	   prev_hsync <= 0;
	   write_out <= 0;
	end
	
	ROW_CAPTURE: begin 
	   if (vsync) // vsync asserted, frame has ended
	   begin
	       FSM_state <= WAIT_FRAME_START;
	       pixel_valid <= 0;
	       data_ind <= 0;
	       write_out <= 0;
	   end

	   pixel_valid <= (href && pixel_half) ? 1 : 0; 
	   
	   if (href) begin                         // href asserted, this is a valid pixel
	       pixel_half <= ~ pixel_half;         // Each pixel is transmitted over two clock signals
	       if (pixel_half)                     // Take the second pixel
	       begin
	           if (hc[0])                      // Downsample horizontally by 1
	           begin
                   case(data_ind)
                       3: begin                 // Already buffered 3 values, time to write out
                           dout <= {p_data[7:4], pixel_data[11:0]};     // Set data out
                           pixel_data[15:12] <= p_data[7:4];
                           write_out <= 1;                              // Set write out
                           min_max_addr_read <= 80*(vc / 8) + ((hc+1) / 8);     // Set read address for min/max
                           
                       end
                       2: begin     // If 3 values aren't buffered, we save the next value and move on
                           pixel_data[11:8] <= p_data[7:4];
                       end
                       1: begin
                           pixel_data[7:4] <= p_data[7:4];
                       end
                       0: begin
                           pixel_data[3:0] <= p_data[7:4];
                           write_out <= 0;                  // Stop writing out (before data changes)
                       end
                   endcase
                   // Set current min/max based on loaded pixel
                   curr_max <= curr_max > p_data[7:4] ? curr_max : p_data[7:4];
                   curr_min <= curr_min < p_data[7:4] ? curr_min : p_data[7:4];
                   addr <= 80*(vc / 2) + (hc / 8);      // Update address for current pixel
                   data_ind <= 1 + data_ind;            // Increment local buffer address
	           end
	           else    // Don't sample pixels with horizontal index starting with 1
	           begin
	               if (data_ind == 0)      // Is it time to save the previous min/max block?
	               begin
	                   min_max_addr_write <= 80*(vc / 8) + (hc / 8);   // Set min/max data out
	                   if (vc[1:0] != 0)                               // Read in previous row's min/max values
                          begin                                        // only if this isn't the first row 
                              curr_max <= max_read;                    // in a 4x4 block
                              curr_min <= min_read;
                          end
                          else
                          begin
                              curr_max <= 4'b0;
                              curr_min <= 4'b1111;
                       end
	               end
	           end
	           hc <= 1 + hc;  // Increment hc after processing the pixel
	       end
	   end
	   else // hsync is negated, indicating waiting for row to begin
	   begin
	       hc <= 0;                // Reset horizontal counter
	       write_out <= 0;         // Don't write anything out
	       data_ind <= 0;          // Reset local data index
	       curr_min <= 4'b1111;    // Current min/max set to max/min possible values
	       curr_max <= 4'b0;
	       if (prev_hsync)         // If a row just ended, increment vertical counter
	       begin
	           vc <= 1 + vc;
	       end
	       min_max_addr_read <= 80*(vc / 8); // Read from min/max memory
	   end
	   prev_hsync <= href;         // Set previous hsync value
	end
	
	endcase
	end
	
	// Continuous assignment for min-max memory
    assign max_out = curr_max;
    assign min_out = curr_min;
    assign min_max_write_enable = write_out;
endmodule