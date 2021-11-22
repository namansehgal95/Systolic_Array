`timescale 1ns/100ps

module corelet (
    input   clk,
    input   reset,
    input   start,
    output  logic op_done,

    //  {I_SRAM -> Weight SRAM and ACT_SRAM combined 
    input   [31:0]  I_Q,
    //output  [31:0]  I_D, Not required 
    output  [6:0]   I_ADDR,
    output          I_CEN,
    output          I_WEN,
    //  }
    
    //  {O_SRAM -> Output SRAM
    input   [127:0]  O_Q,
    output  [127:0]  O_D,
    output  [3:0]   O_ADDR,
    output          O_CEN,
    output          O_WEN
    //  }
    
    );

    parameter P_ROW = 8;
    parameter P_BW  = 4;
    
    //{ FSM states
    localparam IDLE         = 4'b0000  ;
    localparam WEIGHT_L0    = 4'b0001  ; 
    localparam WEIGHT_ARRAY = 4'b0010  ;
    localparam ACT_L0       = 4'b0011  ;
    localparam ACT_ARRAY    = 4'b0100  ;
    localparam RET_OUT       = 4'b0101  ; 
    //}

    logic [4:0] state_next;
    logic [4:0] state;
    logic [5:0] counter, counter_next;
    logic [1:0] in_instr, in_instr_next;
    logic [3:0] kij, kij_next;
    logic write, write_next;
    logic read, read_next;
    logic [P_ROW*P_BW-1 : 0] Q_MUX;
    logic [3:0] lut_ptr;

    always @(posedge clk or posedge reset)      // abstraction of SRAM interface that loads the L0 block
    begin
        if(reset)
            Q_MUX <= 'h0;
        else
        begin
            if(state==ACT_L0 || state==WEIGHT_L0)
                Q_MUX <= #1 Q_MUX + 1;
            else
                Q_MUX <= #1 'd0;
        end
    end

wire temp = state ==ACT_L0;
wire [31:0] ARRAY_IN;
wire [127:0] ARRAY_OUT;
wire [7:0] SFU_VALID;

l0 #(
        .row(P_ROW),
        .bw(P_BW)
    ) u_l0  (
        .clk(clk), 
        .reset(reset),
        .wr(write), 
        .rd(read), 
        .in(I_Q), //Q_MUX),  
        .out(ARRAY_IN), 
        .o_full(), 
        .o_ready()
            );


mac_array #(
                .bw(4),
                .psum_bw(16),
                .col(8),
                .row(8)
            ) u_mac_array (
                .clk(clk), 
                .reset(reset),            
                .out_s(ARRAY_OUT),
                .in_w(ARRAY_IN), // inst[1]:execute, inst[0]: kernel loading
                .inst_w(in_instr),
                .in_n(128'd0),
                .valid(SFU_VALID)
            );



//**********SFU******************

logic [3:0] pointer_sfu [0:7];
//logic signed [15:0] sfu_reg [0:15] [0:7]; 
logic [127:0] sfu_reg [0:15]; 
integer j;


genvar i;
for (i=0; i < 8 ; i=i+1) 
begin 
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
            pointer_sfu[i]  = 'd0;
            sfu_reg[0]   = 'd0;
        end
        else 
        begin
            if (SFU_VALID[i] == 1'b1)
            begin
                sfu_reg[pointer_sfu[i]][16*(i+1)-1 : 16*i] = $signed(sfu_reg[pointer_sfu[i]][16*(i+1)-1: 16*i]) +  $signed(ARRAY_OUT[16*(i+1)-1:16*i]);
               //sfu_reg[i][pointer_sfu[i]] = sfu_reg[i][pointer_sfu[i]] + ARRAY_OUT[16*(i+1)-1:16*i];
                pointer_sfu[i] = pointer_sfu[i] + 1'b1;
            end
        end
    end
end

wire [3:0] pointer0, pointer1, pointer2, pointer3, pointer4, pointer5, pointer6, pointer7;
wire [15:0] psum0, psum1,psum2,  psum3, psum4, psum5, psum6, psum7;

assign psum0 = $signed(ARRAY_OUT[16*(0+1)-1:16*0]);
assign psum1 = $signed(ARRAY_OUT[16*(1+1)-1:16*1]);
assign psum2 = $signed(ARRAY_OUT[16*(2+1)-1:16*2]);
assign psum3 = $signed(ARRAY_OUT[16*(3+1)-1:16*3]);
assign psum4 = $signed(ARRAY_OUT[16*(4+1)-1:16*4]);
assign psum5 = $signed(ARRAY_OUT[16*(5+1)-1:16*5]);
assign psum6 = $signed(ARRAY_OUT[16*(6+1)-1:16*6]);
assign psum7 = $signed(ARRAY_OUT[16*(7+1)-1:16*7]);

assign pointer0 = pointer_sfu[0];
assign pointer1 = pointer_sfu[1];
assign pointer2 = pointer_sfu[2];
assign pointer3 = pointer_sfu[3];
assign pointer4 = pointer_sfu[4];
assign pointer5 = pointer_sfu[5];
assign pointer6 = pointer_sfu[6];
assign pointer7 = pointer_sfu[7];

wire [15:0] sfu_reg0_0;
wire [15:0] sfu_reg0_1;
wire [15:0] sfu_reg0_2;
wire [15:0] sfu_reg0_3;
wire [15:0] sfu_reg0_4;
wire [15:0] sfu_reg0_5;
wire [15:0] sfu_reg0_6;
wire [15:0] sfu_reg0_7;

wire [15:0] sfu_reg1_0;
wire [15:0] sfu_reg1_1;
wire [15:0] sfu_reg1_2;
wire [15:0] sfu_reg1_3;
wire [15:0] sfu_reg1_4;
wire [15:0] sfu_reg1_5;
wire [15:0] sfu_reg1_6;
wire [15:0] sfu_reg1_7;

assign sfu_reg0_0   =   $signed(sfu_reg[0][16*(0+1)-1 : 16*0]);
assign sfu_reg0_1   =   $signed(sfu_reg[0][16*(1+1)-1 : 16*1]);
assign sfu_reg0_2   =   $signed(sfu_reg[0][16*(2+1)-1 : 16*2]);
assign sfu_reg0_3   =   $signed(sfu_reg[0][16*(3+1)-1 : 16*3]);
assign sfu_reg0_4   =   $signed(sfu_reg[0][16*(4+1)-1 : 16*4]);
assign sfu_reg0_5   =   $signed(sfu_reg[0][16*(5+1)-1 : 16*5]);
assign sfu_reg0_6   =   $signed(sfu_reg[0][16*(6+1)-1 : 16*6]);
assign sfu_reg0_7   =   $signed(sfu_reg[0][16*(7+1)-1 : 16*7]);

assign sfu_reg1_0   =   $signed(sfu_reg[1][16*(0+1)-1 : 16*0]);
assign sfu_reg1_1   =   $signed(sfu_reg[1][16*(1+1)-1 : 16*1]);
assign sfu_reg1_2   =   $signed(sfu_reg[1][16*(2+1)-1 : 16*2]);
assign sfu_reg1_3   =   $signed(sfu_reg[1][16*(3+1)-1 : 16*3]);
assign sfu_reg1_4   =   $signed(sfu_reg[1][16*(4+1)-1 : 16*4]);
assign sfu_reg1_5   =   $signed(sfu_reg[1][16*(5+1)-1 : 16*5]);
assign sfu_reg1_6   =   $signed(sfu_reg[1][16*(6+1)-1 : 16*6]);
assign sfu_reg1_7   =   $signed(sfu_reg[1][16*(7+1)-1 : 16*7]);


//initial
//begin
//    #9123
//    $display("sfu_reg data %h.....pointer_sfu ", sfu_reg[0]);
//    #5
//    $display("sfu_reg data %h ", sfu_reg[0]);
//    #5
//    $display("sfu_reg data %h ", sfu_reg[0]);
//    #5
//    $display("sfu_reg data %h ", sfu_reg[0]);
//
//end
//**********Control Logic******************
    
    always @(posedge clk or posedge reset)
    begin
        if(reset)
        begin
            counter <= 'd0;
            state   <= 'd0;
            write   <= 'd0;
            read    <= 'd0;
            in_instr<= 'd0;
            kij     <= 'd0;
        end
        else
        begin
            counter <= #1 counter_next ;
            state   <= #1 state_next   ;
            write   <= #1 write_next   ;
            read   <= #1 read_next   ;
            in_instr<= #1 in_instr_next;
            kij     <= #1 kij_next;
        end
    end 
    


    always @ * 
    begin
        state_next      = state;
        counter_next    = counter;
        in_instr_next   = 2'd0;
        write_next      = 'b0;
        read_next       = 'b0;
        kij_next        = kij;
        case(state)
            IDLE:   
                if(start)
                begin
                    state_next      = WEIGHT_L0;
                    counter_next    = 'd0;      //initialise to 0 when start
                    kij_next        = 'd0;      //initialise to 0 when start
                end
                else
                    state_next = IDLE;
            WEIGHT_L0:  //'d1
                if(counter>'d7)
                begin    
                    state_next      = WEIGHT_ARRAY;
                    counter_next    = 'd0;
                    write_next      = 'b0;
                end
                else
                begin
                    state_next      = state;
                    counter_next    = counter+'d1;
                    write_next      = 'b1;
                end
            WEIGHT_ARRAY:   //'d2
                if(counter>'d23)
                begin
                    state_next      = ACT_L0;
                    counter_next    = 'd0;
                    in_instr_next   = 2'b00;
                    read_next       = 1'b0;
                end
                else if(counter>'d7)
                begin
                    state_next      = state;
                    counter_next    = counter+'d1;
                    in_instr_next   = 2'b00;
                    read_next       = 1'b0;
                end
                else
                begin
                    state_next      = state;
                    counter_next    = counter+'d1;
                    in_instr_next   = 2'b01;
                    read_next       = 1'b1;
                end
            ACT_L0:     //'d3
                if(counter>'d15)
                begin
                    state_next      = ACT_ARRAY;
                    counter_next    = 'd0;
//                    in_instr_next   = 2'b00;
                    write_next      = 'b0;
                end
                else
                begin
                    state_next      = state;
                    counter_next    = counter+'d1;
//                    in_instr_next   = 2'b00;
                    write_next      = 'b1;
                end
            ACT_ARRAY:  //'d4
                if(counter>'d35)   //Add more cycles to this to allow SFU to complete
                begin
                    state_next      = kij=='d8 ? RET_OUT : WEIGHT_L0;
                    counter_next    = 'h0;
                    in_instr_next   = 2'b00;
                    read_next       = 1'b0;
                    kij_next        = kij=='d8 ? 'd8 : kij+'d1;
                end
                else if(counter>'d15)  
                begin
                    state_next      = state;
                    counter_next    = counter+1;
                    in_instr_next   = 2'b00;
                    read_next       = 1'b0;
                end
                else
                begin
                    state_next      = state;
                    counter_next    = counter+'d1;
                    in_instr_next   = 2'b10;
                    read_next       = 1'b1;
                end
           RET_OUT: //'d5
            if(counter>'d15)
            begin
                state_next = IDLE;
                counter_next = 'd0;
            end
            else
            begin
                state_next = state;
                counter_next = counter + 'd1;
            end
        endcase
    end

    always @ (posedge clk or negedge reset)
    begin
        if(reset)
            op_done <= 'd0;
        else
            op_done <= #1 (state_next==IDLE && state==RET_OUT);
    end

//**********Index of Weight******************

    logic [6:0] ACT_ADDR;
    logic [6:0] WEIGHT_ADDR;
    logic [6:0] AW_ADDR_MUX;

    always @*
    begin
        case(kij)
            'd0: lut_ptr = 'd0;
            'd1: lut_ptr = 'd1;
            'd2: lut_ptr = 'd2;
            'd3: lut_ptr = 'd6;
            'd4: lut_ptr = 'd7;
            'd5: lut_ptr = 'd8;
            'd6: lut_ptr = 'd12;
            'd7: lut_ptr = 'd13;
            'd8: lut_ptr = 'd14;
        endcase
        ACT_ADDR = lut_ptr + counter + {counter[3:2],1'b0};
        WEIGHT_ADDR = {kij,3'b0} + counter;
        AW_ADDR_MUX = (state==ACT_L0) ? ACT_ADDR + 72 : WEIGHT_ADDR;
    end

     // I_Q     //input   [31:0]
     // I_D     //output  [31:0]
    assign I_ADDR    = AW_ADDR_MUX;    //output  [6:0] 
    assign I_CEN     = !write_next;    //output        
    assign I_WEN     = 1'b1;           //output       

    assign  O_D     =   sfu_reg[counter];
    assign  O_ADDR  =   counter;
    assign  O_CEN   =   (state!=RET_OUT);
    assign  O_WEN   =   (state!=RET_OUT);




endmodule
