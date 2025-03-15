`timescale 1ns / 1ps

// This module is a UART transmitter
// that transmits data from a memory buffer
// continuously once the transmit input is asserted
module transmitter(
    input clk,              // Reference clock
    input [15:0] data,      // Data input (from memory)
    input transmit,         // Begin transmitting signal
    input reset,            // Reset transmitter
    output reg TxD,         // UART register    
    output reg read_en,     // Read enable for memory
    output reg [14:0] addr, // Address to read in memory
    output wire enb         // Secondary read enable for memory
    );
    
    // Local state variables
    reg [3:0] counter;              
    reg [13:0] baudrate_counter; 
    reg [9:0] shift_reg; 
    reg [1:0] state;
    reg first_half_read;
    reg t_begun;
    
    // Local FSM parameters
    localparam IDLE = 0;
    localparam TRANSMITTING = 1;
    
    initial
    begin
        read_en <= 0;
        state <= IDLE;
        t_begun <= 0;
        first_half_read <= 0;
        addr <= 0;
    end
    
    //UART transmission
    always @ (posedge clk)
    begin
        // Once we receive transmission signal, we begin transmitting forever
        if (transmit)
        begin
            t_begun <= 1;
        end
        
        // When resetting, reset all states
        if (reset) 
        begin
            state <= 0;             //idle
            counter <= 0;           // counter for bit transmission
            baudrate_counter <= 0;     
            first_half_read <= 0;
        end
        else
        begin
            baudrate_counter <= baudrate_counter + 1;
            if(baudrate_counter >= 867) // 100 * 10^6 / 9600 = 10416, only process updates at this rate
            begin
                baudrate_counter <= 0;                   // Reset baudrate counter
                if (state == TRANSMITTING)               // If transmitting, check counter
                begin
                    if (counter >= 10)                   // Transmission is done, move to IDLE
                    begin
                        counter <= 0;
                        state <= IDLE;
                    end
                    else
                    begin                                // Transmission ongoing, shift register and write out
                        state <= TRANSMITTING;
                        TxD <= shift_reg[0]; 
                        shift_reg <= shift_reg >> 1;     // start transmitting bit by bit    
                        counter <= 1 + counter;
                    end
                    read_en <= 0;                       // Stop reading from memory
                end
                else                                    // State is IDLE
                begin
                    if (!t_begun)                       // Stay IDLE until transmission should begin
                    begin
                        state <= IDLE;
                        TxD <= 1;
                    end
                    else
                    begin                               // Otherwise, immediately transmit again
                        state <= TRANSMITTING;
                        read_en <= 1;
                        if (first_half_read)            // Have we transmitted the first 8 of a 16 bit block?
                        begin
                            shift_reg <= {1'b1, data[15:8], 1'b0}; // Load from memory output
                            first_half_read <= 0;
                            
                            // Compute address
                            if (addr == 19199)
                            begin
                                addr <= 0;
                            end
                            else
                            begin
                                addr <= 1 + addr;
                            end
                        end
                        else
                        begin
                            shift_reg <= {1'b1, data[7:0], 1'b0};       // data is still in buffer 
                            first_half_read <= 1;
                        end
                    end
                end
            end            
        end
    end   
    
    assign enb = 1; // Always read in from memory
   
endmodule