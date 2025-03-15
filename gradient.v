`timescale 1ns / 1ps

module gradient(
    input clk,                          // Reference clock
    input [15:0] data,                  // Data read from memory
    output enr,                         // Read enable for frame buffer
    output reg [14:0] addr,             // Read address in frame buffer
    output reg ena,                     // Enable writing out
    output reg [14:0] addr_write,       // Write address output
    output reg [15:0] dout,             // Data to write out
    input select,                       // Select between x and y directions
    output reg [9:0] current_x,         // Current X coordinate (0-319)
    output reg [9:0] current_y          // Current Y coordinate (0-239)
    );
    
    // Local state variables
    reg [9:0] vc;
    reg [9:0] hc;
    reg [1:0] data_ind;
    reg [1:0] state;
    
    // Loaded data of neighboring ideas
    reg [15:0] data_above;
    reg [15:0] data_below;
    reg [15:0] next_data;
    
    // FSM parameters
    localparam GETTING_DATA_ABOVE = 0;
    localparam GETTING_DATA_BELOW = 1;
    localparam COMPUTING_GRADIENT = 3;
   
    initial
    begin
        vc <= 0;
        hc <= 0;
        data_ind <= 0;
        state <= 0;
        current_x <= 0;
        current_y <= 0;
    end
    
    always @ (posedge clk)
    begin
        case(state) 
        GETTING_DATA_ABOVE: begin // Load the data above the current row by computing address
            if (vc == 239)
            begin
                addr <= 0;
            end
            else
            begin
                addr <= 80*(vc + 1) + hc;
            end
            data_above <= data;
            ena <= 0;
            state <= GETTING_DATA_BELOW;
        end
        GETTING_DATA_BELOW: begin  // Load the data below of the current row by computing address
            data_below <= data;
            addr <= 80*vc + hc;
            state <= COMPUTING_GRADIENT;
        end
        COMPUTING_GRADIENT: begin   // Compute the gradient 
            // Calculate current position - each address has 4 pixels packed
            // We're tracking the middle of the current block
            current_x <= hc * 4 + 2;  
            current_y <= vc;
            
            if (select) // Select is asserted, use Y direction
            begin
                if (vc == 239)  // Last row, ignore data below 
                begin
                    dout <= {data_above[15:12] - data[15:12], data_above[11:8] - data[11:8],
                             data_above[7:4] - data[7:4], data_above[3:0] - data[3:0]};
                end
                else if (vc == 0)   // First row, ignore data above
                begin
                    dout <= {data[15:12] - data[15:12], data[11:8] - data[11:8],
                             data[7:4] - data[7:4], data[3:0] - data[3:0]};
                end
                else
                begin   // Row inbetween, use both to convert gradient
                    dout <= {data_above[15:12] - data_below[15:12], data_above[11:8] - data_below[11:8],
                             data_above[7:4] - data_below[7:4], data_above[3:0] - data_below[3:0]};
                end
                
                // Increment hc and vc appropriately and set address based on new values
                if (hc == 79)
                begin
                    hc <= 0;
                    if (vc == 239)
                    begin
                        vc <= 0;
                        addr <= 0;
                    end
                    else
                    begin
                        vc <= vc + 1;
                        addr <= 80*vc;
                    end
                end
                else
                begin
                    hc <= hc + 1;
                    addr <= 80*(vc - 1) + hc + 1;
                end
            end
            else
            begin
                // Compute horizontal gradient
                dout[3:0] <= data[7:4] - data[3:0];
                dout[15:12] <= data[15:12] - data[11:8];
                dout[11:8] <= data[15:12] - data[7:4];
                dout[7:4] <= data[11:8] - data[3:0];
                
                // Increment hc and vc appropriately, computing next address
                if (hc == 79)
                begin
                    hc <= 0;
                    if (vc == 239)
                    begin
                        vc <= 0;
                    end
                    else
                    begin
                        vc <= vc + 1;
                    end
                end
                else
                begin
                    hc <= hc + 1;
                end
            end
            
            // Set address to write to, enable writing out, and continue cycle
            addr_write <= 80*vc + hc;
            ena <= 1;
            state <= GETTING_DATA_ABOVE;
        end
        endcase  
    end
    
    assign enr = 1; // Always enable reading
endmodule