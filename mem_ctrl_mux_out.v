`timescale 1ns / 1ps

// Multiplexer for memory control
// including write control
module mem_ctrl_mux_out(
        input en1,
        input en2,
        output en,
        input [14:0] addr1,
        input [14:0] addr2,
        output [14:0] addr,
        input [15:0] dia1,
        input [15:0] dia2,
        output [15:0] dia,
        input select
    );
    
    assign addr = select ? addr2 : addr1;
    assign en = select ? en2 : en1;
    assign dia = select ? dia2 : dia1;
    
endmodule