// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module sram (CLK, D, Q, CEN, WEN, A);
    parameter P_DATA_BW     = 32;
    parameter P_ROWS        = 1024;
    localparam P_DATA_MSB   = P_DATA_BW - 1;
    localparam P_ADDR_MSB   = P_ROWS<=1     ?   0   :
                              P_ROWS<=2     ?   0   :
                              P_ROWS<=4     ?   1   :
                              P_ROWS<=8     ?   2   :
                              P_ROWS<=16    ?   3   :
                              P_ROWS<=32    ?   4   :
                              P_ROWS<=64    ?   5   :
                              P_ROWS<=128   ?   6   :
                              P_ROWS<=256   ?   7   :   0;

    input  CLK;
    input  WEN;
    input  CEN;
    input  [P_DATA_MSB:0] D;
    input  [P_ADDR_MSB:0] A;
    output [P_DATA_MSB:0] Q;

    reg [P_DATA_MSB:0] memory [P_ROWS-1:0];
    reg [P_DATA_MSB:0] add_q;
    assign Q = memory[add_q];

    always @ (posedge CLK) begin
        if (!CEN && WEN) // read 
            add_q <= A;
        if (!CEN && !WEN) // write
            memory[A] <= D; 
    end

endmodule
