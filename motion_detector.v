
module motion_detector(
    input wire clk,
    input wire [15:0] current_gradient,
    input wire valid_pixel,
    input wire frame_start,
    output reg motion_detected
);
    // More conservative parameters
    parameter THRESHOLD = 16'd2000;      // Much higher threshold
    parameter PIXEL_COUNT = 16'd217000;  // Much higher pixel count //215000 works
    parameter CONSECUTIVE_FRAMES = 3;   // Must detect motion for multiple frames
    
    // Counter for changed pixels
    reg [15:0] change_count;
    reg [15:0] prev_gradient;
    reg prev_frame_start = 0;
    reg [3:0] frame_motion_count = 0;   // Count frames with detected motion
    
    always @(posedge clk) begin
        // Detect rising edge of frame_start
        if (frame_start && !prev_frame_start) begin
            // At end of frame, decide if significant motion occurred
            if (change_count >= PIXEL_COUNT) begin
                if (frame_motion_count < CONSECUTIVE_FRAMES)
                    frame_motion_count <= frame_motion_count + 1;
            end else begin
                frame_motion_count <= 0; // Reset if this frame didn't have enough motion
            end
            
            // Only signal motion after consecutive frames with motion
            motion_detected <= (frame_motion_count >= CONSECUTIVE_FRAMES-1);
            
            // Reset counter for new frame
            change_count <= 16'd0;
        end
        else if (valid_pixel) begin
            // Store previous gradient value
            prev_gradient <= current_gradient;
            
            // Only count very significant changes
            if ((current_gradient > prev_gradient && current_gradient - prev_gradient > THRESHOLD) ||
                (prev_gradient > current_gradient && prev_gradient - current_gradient > THRESHOLD)) begin
                change_count <= change_count + 1;
            end
        end
        
        // Remember previous frame_start state
        prev_frame_start <= frame_start;
    end
endmodule
