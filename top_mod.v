

`timescale 1ns / 1ps

module top_mod(
        // System clock
        input clk,
        
        // User inputs
        input begin_transmit,
        input [2:0] output_select,
        input wire clr,
        
        // UART inputs
        output wire txd,
         
        // Camera inputs
        input wire p_clk,
        input wire cam_hsync,
        input wire cam_vsync,
        input wire [7:0] cam_data,
        
        // Camera outputs
        output wire xclk,
        output wire pwdn,
        output wire reset,
        
        // VGA Outputs
        output wire hsync,          //horizontal sync out
        output wire vsync,          //vertical sync out
        output wire [3:0] red,      //red vga output
        output wire [3:0] green,    //green vga output
        output wire [3:0] blue,     //blue vga output
        
        // Debug outputs (not used anymore)
        output wire debug,
        output wire debug2,
        output wire debug3,
        output reg motion_led
    );
    
    // Divided clock signal for VGA and camera
    wire dclk;
        
    // Framebuffer values
    wire ena, enb, enb2, wea, en_comp;
    wire [14:0] addra;
    wire [14:0] addrb;
    wire [14:0] addrb2;
    wire [14:0] addr_comp;
    wire [15:0] dia;
    wire [15:0] dob;
    wire enb_s;
    wire [14:0] addrb_s;
    
    // Transmission buffer values
    wire tmem_ena, tmem_enb, tmem_wea;
    wire [14:0] tmem_addr;
    wire [14:0] tmem_addrb;
    wire [15:0] datatrans;
    wire [15:0] tmem_din;
    
    // Adaptive Thresholding Buffer values
    wire thresh_buf_ena, thresh_buf_enb;
    wire [14:0] thresh_buf_addra;
    wire [14:0] thresh_buf_addrb;
    wire [15:0] thresh_buf_dia;
    wire [15:0] thresh_buf_dob;
    
    // Min-Max Memory values
    wire mm_rea, mm_wea;
    wire [12:0] mm_addr_read;
    wire [12:0] mm_addr_read2;
    wire [12:0] mm_addr_write;
    wire [3:0] mm_din_max;
    wire [3:0] mm_din_min;
    wire [3:0] mm_dout_max;
    wire [3:0] mm_dout_max2;
    wire [3:0] mm_dout_min;
    wire [3:0] mm_dout_min2;
    
    // Output multiplexing
    wire en_out;
    wire [14:0] addr_out;
    
    // Gradient buffer values
    wire grad_enr, grad_ena;
    wire [14:0] grad_addr;
    wire [14:0] grad_addr_write;
    wire [15:0] grad_dout;
    
    // Intermediate values for memory control
    wire cbuf_en;
    wire [14:0] cbuf_addr;
    wire [15:0] cbuf_dia;
    
    // Motion detection signal
    wire motion_detected;
    
    // Instantiate clock divider
    clk_divider d(
        .clk(clk),
        .clr(clr),
        .dclk(dclk)
    );
    
    // Instantiate VGA driver with motion detection input
    vga640x480 U3(
        .dclk(dclk),
        .clr(clr),
        .hsync(hsync),
        .vsync(vsync),
        .red(red),
        .green(green),
        .blue(blue),
        .dob1(dob),
        .select(output_select[1]),
        .dob2(thresh_buf_dob),
        .motion_detected(motion_detected),  // Connect motion detection signal
        .enb(en_out),
        .addrb(addr_out),
        .t_addr(tmem_addrb),
        .tmem_data(tmem_din),
        .tmem_addr(tmem_addr),
        .tmem_wea(tmem_wea),
        .tmem_ena(tmem_ena)
        );
       
    // Frame buffer to store unprocessed images   
    memory frame_buffer(
        .clk(clk),
        .ena(ena), // Enable port A
        .enb(enb_s), // Enable port B
        .wea(wea), // Enable write to port A
        .addra(addra),
        .addrb(addrb_s),
        .dia(dia),
        .dob(dob)
    );
    
    // Multiplex read control of frame buffer between VGA and 
    // image processing modules
    mem_ctrl_mux fbmux (
        .en1(enb),
        .en2(en_comp),
        .en(enb_s),
        .addr1(addrb),
        .addr2(addr_comp),
        .addr(addrb_s),
        .select(output_select[1])
    );
    
    // Multiplex read control of frame buffer between gradient
    // and adaptive thresholding modules
    mem_ctrl_mux fbmux_comp (
        .en1(enb2),
        .en2(grad_enr),
        .en(en_comp),
        .addr1(addrb2),
        .addr2(grad_addr),
        .addr(addr_comp),
        .select(output_select[0])
    );
    
    
    // Multiplex write control of computed buffer between gradient
    // and adaptive thresholding modules
    mem_ctrl_mux_out cbmux (
        .en1(thresh_buf_ena),
        .en2(grad_ena),
        .en(cbuf_en),
        .addr1(thresh_buf_addra),
        .addr2(grad_addr_write),
        .addr(cbuf_addr),
        .dia1(thresh_buf_dia),
        .dia2(grad_dout),
        .dia(cbuf_dia),
        .select(output_select[0])
    );
    
    
    // Instantiate computed buffer
    memory computed_buffer (
        .clk(clk),
        .ena(cbuf_en),
        .enb(thresh_buf_enb),
        .wea(cbuf_en),
        .addra(cbuf_addr),
        .addrb(thresh_buf_addrb),
        .dia(cbuf_dia),
        .dob(thresh_buf_dob)
    );
    
    // Instantiate gradient computation module
    gradient g(
        .clk(clk),
        .data(dob),
        .enr(grad_enr),
        .addr(grad_addr),
        .ena(grad_ena),
        .addr_write(grad_addr_write),
        .dout(grad_dout),
        .select(output_select[2])
    );
    
    // Instantiate adaptive thresholding module
    adaptive_thresholding a (
        .clk(clk),
        .max(mm_dout_max),
        .min(mm_dout_min),
        .mm_addr_read(mm_addr_read),
        .ena(thresh_buf_ena),
        .addra(thresh_buf_addra),
        .dia(thresh_buf_dia),
        .data(dob),
        .en_read2(enb2),
        .addr_read(addrb2)
    );
    
    
    // Instantiate min/max block memory buffer
    memory_4x4 min_max_mem (
        .clk(clk),
        .rea(mm_rea),
        .wea(mm_wea),
        .addr_read(mm_addr_read),
        .addr_read2(mm_addr_read2),
        .addr_write(mm_addr_write),
        .din_max(mm_din_max),
        .din_min(mm_din_min),
        .dout_max(mm_dout_max),
        .dout_min(mm_dout_min),
        .dout_max2(mm_dout_max2),
        .dout_min2(mm_dout_min2)
    );
    
    // Instantiate motion detector that provides motion_detected signal
    motion_detector md(
        .clk(clk),
        .current_gradient(grad_dout),    // Output from gradient module
        .valid_pixel(grad_ena),          // When gradient is writing (valid data)
        .frame_start(cam_vsync),         // Camera vsync indicates new frame
        .motion_detected(motion_detected)
    );
    
    // Instantiate camera driver
    camera_read r(
        .p_clock(p_clk),
        .vsync(cam_vsync),
        .href(cam_hsync),
        .p_data(cam_data),
        .dout(dia),
        .write_out(wea),
        .addr(addra),
        .ena(ena),
        .max_read(mm_dout_max2),
        .min_read(mm_dout_min2),
        .min_max_addr_read(mm_addr_read2),
        .min_max_addr_write(mm_addr_write),
        .max_out(mm_din_max),
        .min_out(mm_din_min),
        .min_max_write_enable(mm_wea)
    );
    
    // Instantiate UART transmitter
    transmitter tr (
        .clk(clk),
        .reset(clr),
        .transmit(begin_transmit),
        .TxD(txd),
        .data(datatrans),
        .addr(tmem_addrb),
        .enb(tmem_enb)
    );
    
    // Instantiate transmission buffer
    memory tmem (
        .clk(clk),
        .ena(tmem_ena),
        .enb(tmem_enb),
        .wea(tmem_wea),
        .addra(tmem_addr),
        .addrb(tmem_addrb),
        .dia(tmem_din),
        .dob(datatrans)
    );
     
    // LED timer to control motion_led
    reg [24:0] led_timer = 0;
    always @(posedge clk) begin
        if (motion_detected) begin
            motion_led <= 1'b1;
            led_timer <= 25'd25000000; // Flash for ~0.5 sec at 50MHz
        end
        else if (led_timer > 0) begin
            led_timer <= led_timer - 1;
        end
        else begin
            motion_led <= 1'b0;
        end
    end
    
    // Assign constant camera values
    assign xclk = dclk;
    assign pwdn = 0;
    assign reset = 1;
    assign mm_rea = 1;

    // Assign constant memory buffer values
    assign thresh_buf_enb = en_out;
    assign enb = en_out;
    assign thresh_buf_addrb = addr_out;
    assign addrb = addr_out;
    
    // Assign debug outputs (not used but connected to avoid warnings)
    assign debug = motion_detected;
    assign debug2 = 0;
    assign debug3 = 0;

endmodule
