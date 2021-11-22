// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ns

module corelet_tb;

logic CLK;
logic RESET;
logic START;

corelet u_corelet(
    .clk(CLK),
    .reset(RESET),
    .start(START)
    );


initial 
begin

    $dumpfile("corelet_tb.vcd");
    $dumpvars(0,corelet_tb);
 
    CLK = 0;
    RESET = 1;
    START = 0;

    #101 RESET = 0;
    #100 START = 1;

    #20000 $finish;
end

initial
begin
#10
forever
    #10 CLK = ~CLK;
end
endmodule





