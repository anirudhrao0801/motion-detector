`timescale 1ns / 1ps

// This module performs the adaptive thresholding algorithm on a buffer
module adaptive_thresholding(   
        input clk,
        
        // Interface with min-max buffer to read m memory
        input [3:0] max,
        input [3:0] min,
        output reg [12:0] mm_addr_read,
        
        // Interface with frame buffer to read data
        input [15:0] data,
        output en_read2,
        output [14:0] addr_read,
        
        // Interface with threshold buffer
        output ena,
        output [14:0] addra,
        output reg [15:0] dia 
    );
    
    // Local state variables
    reg [9:0] vc;
    reg [9:0] hc;
    reg [1:0] data_ind;
    reg [15:0] c_data;
    reg [1:0] state;
    
    // Local FSM parameters
    localparam GETTING_BLOCK_DATA = 0;
    localparam COMPUTING_THRESH = 1;
    
    initial
    begin
        vc <= 0;
        hc <= 0;
        data_ind <= 0;
        state <= GETTING_BLOCK_DATA;
    end
    
    always @ (posedge clk)
    begin
        case(state)
        
        GETTING_BLOCK_DATA: begin // Compute the address of the block the pixel is in
            mm_addr_read <= 80*(vc/4) + (hc/4);
            state <= COMPUTING_THRESH;
        end

        COMPUTING_THRESH: begin // Compute the threshold
        
            // Increment hc and vc appropriately
            if (hc < 319)
                hc <= hc + 1;
            else
            begin
                hc <= 0;
                if (vc < 239)
                    vc <= vc + 1;
                else
                    vc <= 0;
            end
            
            if (max - min <= 1) // If min and max values are too low, we set to gray
            begin
                case (data_ind)
                0: c_data[3:0] <= 4'b0111;
                1: c_data[7:4] <= 4'b0111;
                2: c_data[11:8] <= 4'b0111;
                3: dia[15:12] <= 4'b0111;
                endcase 
                
            end
            else if (
                    (data_ind == 0 && data[3:0] < min + (max - min) / 2) ||
                    (data_ind == 1 && data[7:4]  < min + (max - min) / 2) || 
                    (data_ind == 2 && data[11:8]  < min + (max - min) / 2) || 
                    (data_ind == 3 && data[15:12]  < min + (max - min) / 2)
            )   
            begin   // Check the current data index and compare to corresponding min/max vals
                case (data_ind) // Below min/max, set to black
                0: c_data[3:0] <= 4'b0000;
                1: c_data[7:4] <= 4'b0000;
                2: c_data[11:8] <= 4'b0000;
                3: dia[15:12] <= 4'b0000;
                endcase 
            end
            else
            begin   // Above min/max, set to white
                case (data_ind)
                0: c_data[3:0] <= 4'b1111;
                1: c_data[7:4] <= 4'b1111;
                2: c_data[11:8] <= 4'b1111;
                3: dia[15:12] <= 4'b1111;
                endcase 
            end
            if (data_ind == 3) // At the end of each local buffer, save the data
            begin
                dia[11:0] <= c_data[11:0];
            end
            data_ind <= 1 + data_ind;
            state <= GETTING_BLOCK_DATA;    // Return to local block state
        end
        
        endcase
    end
    
    // Continuous assignment to compute read/write addresses and to determine when to enable read/writing
    assign addr_read = addra;
    assign addra = 80*vc + (hc / 4);
    assign ena = (state == COMPUTING_THRESH) && (data_ind == 3);
    assign en_read2 = (state == GETTING_BLOCK_DATA);
    
endmodule
