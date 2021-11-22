// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
`timescale 1ns/1ns

module core_tb;

logic CLK;
logic RESET;
logic START;

logic   [31:0]  TB_I_D;
wire    [31:0]  TB_I_Q;  //logic can't be connected to output port for some reason
logic   [6:0]   TB_I_ADDR;
logic           TB_I_CEN;
logic           TB_I_WEN;

logic   [127:0] TB_O_D;
wire    [127:0] TB_O_Q;
logic   [3:0]   TB_O_ADDR;
logic           TB_O_CEN;
logic           TB_O_WEN;

logic           TB_CL_SELECT;
logic   [31:0]  D_2D [63:0];

integer x_file, x_scan_file ; // file_handler
integer i;
integer captured_data;
integer error;

core u_core(
    .clk        (CLK),
    .reset      (RESET),
    .start      (START),

    .TB_I_ADDR  (TB_I_ADDR),
    .TB_I_CEN   (TB_I_CEN),
    .TB_I_WEN   (TB_I_WEN),
    .TB_I_D     (TB_I_D),
    .TB_I_Q     (TB_I_Q),

    .TB_O_ADDR  (TB_O_ADDR),
    .TB_O_CEN   (TB_O_CEN),
    .TB_O_WEN   (TB_O_WEN),
    .TB_O_D     (TB_O_D),
    .TB_O_Q     (TB_O_Q),

    .TB_CL_SELECT(TB_CL_SELECT)
    );


initial 
begin

    $dumpfile("core_tb.vcd");
    $dumpvars(0,core_tb);
 
    CLK = 0;
    RESET = 1;
    START = 0;
  
    x_file = $fopen("activation.txt", "r");

    // Following three lines are to remove the first three comment lines of the file
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);
    x_scan_file = $fscanf(x_file,"%s", captured_data);

    #101 RESET = 0;
    #10
    TB_I_CEN = 0;
    TB_I_WEN = 0;
    TB_CL_SELECT = 1;
    TB_O_WEN = 1;
    TB_O_CEN = 1;

    for (i=0; i<108 ; i=i+1)
    begin
        #10
        TB_I_ADDR   = i;
        x_scan_file = $fscanf(x_file,"%32b", TB_I_D);
        D_2D[i][31:0] = TB_I_D;
    end
    
    #10
    TB_I_CEN = 1;
    TB_I_WEN = 1;
    TB_CL_SELECT = 1;
    TB_O_WEN = 1;
    TB_O_CEN = 1;
    //for (i=0; i<8 ; i=i+1)
    //begin
    //    #5
    //    TB_I_CEN = 0;
    //    TB_I_WEN = 1;
    //    TB_I_ADDR   = i;
    //    #5
    //    if (D_2D[i][31:0] == TB_I_Q)
    //        $display("%2d-th read data is %h --- Data matched", i, TB_I_Q);
    //    else begin
    //        $display("%2d-th read data is %h, expected data is %h --- Data ERROR !!!", i, TB_I_Q, D_2D[i]);
    //        error = error+1;
    //    end
    //end
    
    TB_CL_SELECT = 0;
    TB_I_WEN = 1;
    TB_I_CEN = 1;
    
    #100 START = 1;
    #100 START = 0;

    #20000
    
    #500
    TB_CL_SELECT = 1;
    TB_O_WEN = 1;
    TB_O_CEN = 0;

    #500

     $finish;
end

initial
begin
#5
forever
    #5 CLK = ~CLK;
end

endmodule
