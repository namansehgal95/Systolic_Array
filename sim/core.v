module core (
    input   clk,
    input   reset,
    input   start,
    input   TB_CL_SELECT,
    output op_done,

    //  {I_SRAM -> Weight SRAM and ACT_SRAM combined 
    output  [31:0]  TB_I_Q,
    input   [31:0]  TB_I_D,  
    input   [6:0]   TB_I_ADDR,
    input           TB_I_CEN,
    input           TB_I_WEN,
    //  }
    
    //  {O_SRAM -> Output SRAM
    output  [127:0]  TB_O_Q,
    input   [127:0]  TB_O_D,
    input   [3:0]   TB_O_ADDR,
    input           TB_O_CEN,
    input           TB_O_WEN
    //  }
    
    );

    wire    [31:0]  I_Q;
    wire    [6:0]   CL_I_ADDR;
    wire            CL_I_CEN;
    wire            CL_I_WEN;
    
    wire    [127:0]  O_Q;
    wire    [127:0]  CL_O_D;
    wire    [3:0]   CL_O_ADDR;
    wire            CL_O_CEN;
    wire            CL_O_WEN;

//    wire    [31:0]  MUX_I_Q;
    wire    [31:0]  MUX_I_D;  
    wire    [6:0]   MUX_I_ADDR;
    wire            MUX_I_CEN;
    wire            MUX_I_WEN;
    
//    wire    [31:0]  MUX_O_Q;
    wire    [127:0]  MUX_O_D;
    wire    [3:0]   MUX_O_ADDR;
    wire            MUX_O_CEN;
    wire            MUX_O_WEN;

corelet u_corelet (
   .clk         (clk),
   .reset       (reset),
   .start       (start),
   .op_done     (op_done),

    //  {I_SRAM -> Weight SRAM and ACT_SRAM combined 
    .I_Q        (I_Q),
    .I_ADDR     (CL_I_ADDR),
    .I_CEN      (CL_I_CEN),
    .I_WEN      (CL_I_WEN),
    //  }
    
    //  {O_SRAM -> Output SRAM
    .O_Q        (O_Q),
    .O_D        (CL_O_D),
    .O_ADDR     (CL_O_ADDR),
    .O_CEN      (CL_O_CEN),
    .O_WEN      (CL_O_WEN)
    //  }
    
    );


    //assign MUX_I_Q      =   TB_CL_SELECT    ?   TB_I_Q      :   CL_I_Q      ;
    assign MUX_I_D      =   TB_I_D ; 
    assign MUX_I_ADDR   =   TB_CL_SELECT    ?   TB_I_ADDR   :   CL_I_ADDR   ;
    assign MUX_I_CEN    =   TB_CL_SELECT    ?   TB_I_CEN    :   CL_I_CEN    ;
    assign MUX_I_WEN    =   TB_CL_SELECT    ?   TB_I_WEN    :   CL_I_WEN    ;
                                                                
    //assign MUX_O_Q      =   TB_CL_SELECT    ?   TB_O_Q      :   CL_O_Q      ;
    assign MUX_O_D      =   TB_CL_SELECT    ?   TB_O_D      :   CL_O_D      ;
    assign MUX_O_ADDR   =   TB_CL_SELECT    ?   TB_O_ADDR   :   CL_O_ADDR   ;
    assign MUX_O_CEN    =   TB_CL_SELECT    ?   TB_O_CEN    :   CL_O_CEN    ;
    assign MUX_O_WEN    =   TB_CL_SELECT    ?   TB_O_WEN    :   CL_O_WEN    ;

    assign TB_I_Q       =   I_Q;
    assign TB_O_Q       =   O_Q;

    sram #(
        .P_DATA_BW   (32),
        .P_ROWS (108)
        ) u_I_SRAM (
        .CLK    (clk),
        .WEN    (MUX_I_WEN),
        .CEN    (MUX_I_CEN),
        .D      (MUX_I_D),
        .A      (MUX_I_ADDR),
        .Q      (I_Q)
        );

    sram #(
        .P_DATA_BW   (128),
        .P_ROWS (16)
        ) u_O_SRAM (
        .CLK    (clk),
        .WEN    (MUX_O_WEN),
        .CEN    (MUX_O_CEN),
        .D      (MUX_O_D),
        .A      (MUX_O_ADDR),
        .Q      (O_Q)
        );

endmodule
