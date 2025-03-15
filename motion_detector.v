//// simple_motion_detector.v
//// Extremely simplified motion detector without forced detection
//module motion_detector (
//    input               clk,
//    input               rst,            // Reset signal
//    input       [7:0]   current_gradient, // incoming gradient (greyscale)
//    input               valid_pixel,      // asserted when current_gradient is valid
//    input               frame_start,      // pulse at the start of each frame (e.g., cam_vsync)
//    input       [10:0]  current_x,        // current pixel x-coordinate
//    input       [10:0]  current_y,        // current pixel y-coordinate
//    output reg          motion_detected,  // asserted if valid motion is found in the frame
//    output reg [10:0]   bbox_min_x,       // bounding box left coordinate
//    output reg [10:0]   bbox_min_y,       // bounding box top coordinate
//    output reg [10:0]   bbox_max_x,       // bounding box right coordinate
//    output reg [10:0]   bbox_max_y,       // bounding box bottom coordinate
//    output reg          bbox_valid,       // asserted if the bounding box is valid
//    output reg [15:0]   change_count,     // counts the number of pixels with significant change
//    output reg [15:0]   active_cells      // count of active grid cells (for multi-point motion detection)
//);

////------------------------------------------------------------------------------
//// Very simple parameters for maximum sensitivity
////------------------------------------------------------------------------------
//parameter IMAGE_WIDTH      = 640;    // image width (pixels)
//parameter IMAGE_HEIGHT     = 480;    // image height (pixels)
//parameter MOTION_THRESHOLD = 8'd2;   // Detect any change
//parameter MIN_AREA         = 1;      // Single pixel is enough
//parameter GRID_WIDTH       = 8;      // For grid cell counting
//parameter GRID_HEIGHT      = 6;
//parameter HYSTERESIS       = 30;     // Very long persistence

////------------------------------------------------------------------------------
//// Minimal internal registers
////------------------------------------------------------------------------------
//reg [15:0] pixel_count;             // Simple counter for pixels with motion
//reg [5:0] motion_persistence;       // Counter for maintaining motion state

//// Grid cell activity for active_cells output
//reg [GRID_WIDTH*GRID_HEIGHT-1:0] grid_activity;
//reg [5:0] cell_x, cell_y;

////------------------------------------------------------------------------------
//// Ultra-simple motion detection logic
////------------------------------------------------------------------------------
//always @(posedge clk) begin
//    if (rst) begin
//        // Initialize all registers
//        bbox_min_x <= IMAGE_WIDTH - 1;
//        bbox_min_y <= IMAGE_HEIGHT - 1;
//        bbox_max_x <= 0;
//        bbox_max_y <= 0;
//        change_count <= 0;
//        active_cells <= 0;
//        motion_detected <= 0;
//        bbox_valid <= 0;
//        pixel_count <= 0;
//        motion_persistence <= 0;
//        grid_activity <= 0;
//    end
//    else begin
//        // Process each valid pixel
//        if (valid_pixel) begin
//            // ANY non-zero gradient counts as motion
//            if (current_gradient > MOTION_THRESHOLD) begin
//                // Count motion pixels
//                pixel_count <= pixel_count + 1;
                
//                // Calculate grid cell position
//                cell_x <= current_x / (IMAGE_WIDTH / GRID_WIDTH);
//                cell_y <= current_y / (IMAGE_HEIGHT / GRID_HEIGHT);
                
//                // Mark grid cell as active
//                grid_activity[cell_y * GRID_WIDTH + cell_x] <= 1;
                
//                // Update bounding box - ALWAYS update for any motion
//                if (current_x < bbox_min_x)
//                    bbox_min_x <= current_x;
//                if (current_y < bbox_min_y)
//                    bbox_min_y <= current_y;
//                if (current_x > bbox_max_x)
//                    bbox_max_x <= current_x;
//                if (current_y > bbox_max_y)
//                    bbox_max_y <= current_y;
//            end
//        end
        
//        // At frame start, evaluate motion
//        if (frame_start) begin
//            // Copy pixel count to change_count for visibility
//            change_count <= pixel_count;
            
//            // Count active grid cells
//            active_cells <= 0;
//            for (integer i = 0; i < GRID_WIDTH*GRID_HEIGHT; i = i + 1) begin
//                if (grid_activity[i])
//                    active_cells <= active_cells + 1;
//            end
            
//            // ULTRA-SIMPLE detection criteria - ANY motion
//            if (pixel_count >= MIN_AREA) begin
//                motion_detected <= 1;
//                bbox_valid <= 1;
//                motion_persistence <= HYSTERESIS;
//            end else if (motion_persistence > 0) begin
//                motion_persistence <= motion_persistence - 1;
//                motion_detected <= 1;
//                bbox_valid <= 1;
//            end else begin
//                motion_detected <= 0;
//                bbox_valid <= 0;
                
//                // Only reset bbox when not in persistence mode
//                bbox_min_x <= IMAGE_WIDTH - 1;
//                bbox_min_y <= IMAGE_HEIGHT - 1;
//                bbox_max_x <= 0;
//                bbox_max_y <= 0;
//            end
            
//            // Reset for next frame
//            pixel_count <= 0;
//            grid_activity <= 0;
//        end
//    end
//end

//endmodule



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
