`timescale 1ns / 1ps

// Multiplexer for memory control
module mem_ctrl_mux(
        input en1,
        input en2,
        output en,
        input [14:0] addr1,
        input [14:0] addr2,
        output [14:0] addr,
        input select
    );
    
    assign addr = select ? addr2 : addr1;
    assign en = select ? en2 : en1;
    
endmodule
