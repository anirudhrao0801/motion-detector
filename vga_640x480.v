

`timescale 1ns / 1ps

// This module is a controller for a 640x480 VGA display
// Pixel data is read from one of two memory buffers and multiplexed
// based on the select signal
// This module also fills a transmission buffer used to send data
// over a UART transmission line

module vga640x480(
    input wire dclk,                // pixel clock: 25MHz
    input wire clr,                 // asynchronous reset
    input wire [15:0] dob1,         // current pixel values (from memory)
    input wire [15:0] dob2,     
    input wire select,              // Select between dob1 and dob2
    input wire motion_detected,     // Input to indicate when motion is detected
    input wire [14:0] t_addr,       // Current address of transmitter
    output wire enb,                // enable read port of memory
    output reg [14:0] addrb,        // address of next pixel
    output wire hsync,              // horizontal sync out
    output wire vsync,              // vertical sync out
    output reg [3:0] red,           // red vga output
    output reg [3:0] green,         // green vga output
    output reg [3:0] blue,          // blue vga output
    output reg [15:0] tmem_data,    // data to write to transmission buffer
    output reg [14:0] tmem_addr,    // address to write in transmission buffer  
    output reg tmem_wea,            // write enables of transmission buffer
    output wire tmem_ena
    );

// video structure constants
parameter hpixels = 800;// horizontal pixels per line
parameter vlines = 521; // vertical lines per frame
parameter hpulse = 96;  // hsync pulse length
parameter vpulse = 2;   // vsync pulse length
parameter hbp = 144;    // end of horizontal back porch
parameter hfp = 784;    // beginning of horizontal front porch
parameter vbp = 31;     // end of vertical back porch
parameter vfp = 511;    // beginning of vertical front porch
// active horizontal video is therefore: 784 - 144 = 640
// active vertical video is therefore: 511 - 31 = 480

// Bounding box parameters - set to create a prominent box
parameter BOX_BORDER = 8;           // Border width in pixels
parameter BOX_MARGIN = 60;          // Margin from edges of screen

// Pre-computed bounding box coordinates
parameter BOX_LEFT = (hbp + BOX_MARGIN);
parameter BOX_RIGHT = (hfp - BOX_MARGIN);
parameter BOX_TOP = (vbp + BOX_MARGIN);
parameter BOX_BOTTOM = (vfp - BOX_MARGIN);

// registers for storing the horizontal & vertical counters
reg [9:0] hc;
reg [9:0] vc;
reg [2:0] data_ind;
reg [15:0] ld_buf;

// Wire indicating if current pixel is on the bounding box border
wire on_bounding_box;

// Check if current pixel is on the bounding box border
assign on_bounding_box = motion_detected && (
    // Left border
    (hc >= BOX_LEFT && hc < BOX_LEFT + BOX_BORDER && vc >= BOX_TOP && vc <= BOX_BOTTOM) ||
    // Right border
    (hc >= BOX_RIGHT - BOX_BORDER && hc < BOX_RIGHT && vc >= BOX_TOP && vc <= BOX_BOTTOM) ||
    // Top border
    (hc >= BOX_LEFT && hc <= BOX_RIGHT && vc >= BOX_TOP && vc < BOX_TOP + BOX_BORDER) ||
    // Bottom border
    (hc >= BOX_LEFT && hc <= BOX_RIGHT && vc >= BOX_BOTTOM - BOX_BORDER && vc < BOX_BOTTOM)
);

always @(posedge dclk or posedge clr)
begin
    // reset condition, set all values to 0
    if (clr == 1)
    begin
        hc <= 0;
        vc <= 0;
        data_ind <= 0;
    end
    else
    begin
        // keep counting until the end of the line
        if (hc < hpixels - 1)
        begin
            hc <= hc + 1;
            if (hc < hbp)
            begin
             data_ind <= 3'b0;
            end
            else
            begin
             data_ind <= 1 + data_ind;
            end
        end
        else
        // When we hit the end of the line, reset the horizontal
        // counter and increment the vertical counter.
        // If vertical counter is at the end of the frame, then
        // reset that one too.
        begin
            hc <= 0;
            if (vc < vlines - 1)
            begin
                vc <= vc + 1;
            end
            else
                vc <= 0;
        end
    end
end

// Continuous assignment for sync signals
assign hsync = (hc < hpulse) ? 0:1;
assign vsync = (vc < vpulse) ? 0:1;

// Main driver logic
always @(*)
begin
    if (hc >= hbp && hc <= hfp && vc >= vbp && vc <= vfp)   // Are we at a valid pixel?
    begin
        // Check if current pixel is on the bounding box
        if (on_bounding_box) begin
            // Draw yellow border for motion bounding box
            red <= 4'hF;    // Full red
            green <= 4'hF;  // Full green
            blue <= 4'h0;   // No blue = yellow
            tmem_wea <= 0;  // Don't write to transmission memory during box drawing
        end else begin
            // Normal display logic
            if (data_ind[2] && data_ind[1]) // Take the upper 2 bits of data_ind so we handle the downsampling
            begin
                red <= ld_buf[15:12];
                green <= ld_buf[15:12];
                blue <= ld_buf[15:12];
            end
            else if (data_ind[2] == 1)
            begin
                red <= ld_buf[11:8];
                green <= ld_buf[11:8];
                blue <= ld_buf[11:8];
            end
            else if (data_ind[1] == 1)
            begin
                red <= ld_buf[7:4];
                green <= ld_buf[7:4];
                blue <= ld_buf[7:4];
                tmem_wea <= 0;
            end
            else
            begin
                // Before the first pixel in the local read buffer
                // Multiplex between the two memory buffers, and save
                // the pixel value locally
                if (select)
                begin
                    ld_buf <= dob2;
                    tmem_data <= dob2;
                    red <= dob2[3:0];
                    green <= dob2[3:0];
                    blue <= dob2[3:0];
                end
                else
                begin
                    ld_buf <= dob1;
                    tmem_data <= dob1;
                    red <= dob1[3:0];
                    green <= dob1[3:0];
                    blue <= dob1[3:0];
                end
                tmem_wea <= 1;
            end
        end
        
        // Set transmission and frame buffer addresses
        addrb <= 80*((vc-vbp)/2) + ((hc - hbp + 1) / 8);
        tmem_addr <= 80*((vc-vbp) / 2) + ((hc-hbp) / 8);
    end
    else 
    begin
        // Not at a valid pixel (outside of valid region), so we have to
        // set pixels to 0 and set the address to read to the first valid
        // pixel in the current row
        tmem_wea <= 0;
        addrb <= 80 * ((vc-vbp)/2);
        red <= 4'b0;
        green <= 4'b0;
        blue <= 4'b0;
    end
end

assign enb = 1;
assign tmem_ena = (t_addr <= 240);

endmodule
