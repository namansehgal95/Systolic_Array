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
    localparam WEIGHT_CLEAR = 4'b0101  ;
    localparam RET_OUT      = 4'b0110  ; 
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
	logic reset_mac;

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
                .reset(reset || reset_mac),            
                .out_s(ARRAY_OUT),
                .in_w(ARRAY_IN), // inst[1]:execute, inst[0]: kernel loading
                .inst_w(in_instr),
                .in_n(128'd0),
                .valid(SFU_VALID)
            );


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
	reset_mac       = 'b0;
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
                    state_next      = WEIGHT_CLEAR;
                    counter_next    = 'h0;
                    in_instr_next   = 2'b00;
                    read_next       = 1'b0;
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
			WEIGHT_CLEAR: //'d5
				if(counter>'d15)
				begin
					state_next      = kij=='d8 ? RET_OUT : WEIGHT_L0;
					counter_next 	= 'd0;
					reset_mac		= 'b0;
                    kij_next        = kij=='d8 ? 'd8 : kij+'d1;
				end
				else if(counter>'d12)
				begin
					state_next 		= state;
					counter_next 	= counter + 'd1;
					reset_mac 		= 'b0;
				end	
				else if(counter>'d8)
				begin
					state_next 		= state;
					counter_next 	= counter + 'd1;
					reset_mac 		= 'b1;
				end
				else
				begin
					state_next 		= state;
					counter_next 	= counter + 'd1;
					reset_mac 		= 'b0;
				end
			RET_OUT: //'d6
				if(counter>='d15)
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

	//Signal to the testbench to convey end of all execution....Can read outputs from ORAM and compare
    always @ (posedge clk or negedge reset)
    begin
        if(reset)
            op_done <= 'd0;
        else
            op_done <= #1 (state_next==IDLE && state==RET_OUT);
    end
//***********End of Control Logic*******************




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



//**********SFU******************

logic [3:0] pointer_sfu [0:7];
logic signed [15:0] sfu_reg [0:7] [0:15]; 
//logic [127:0] sfu_reg [0:15]; 
integer j;

integer n_file, n_scan_file ; // file_handler
integer nmn_i, nmn_j;

initial 
begin
    #12940;
    
    n_file = $fopen("nmn.txt", "w");
    for (nmn_i=0 ; nmn_i <8; nmn_i=nmn_i+1)
    begin
        for (nmn_j=0; nmn_j <  16 ; nmn_j++)
        begin
            $fwrite(n_file, "%d, " , sfu_reg[nmn_i][nmn_j]);
        end
        $fwrite(n_file, "\n "); 
    end
    $fclose(n_file);

            
end


genvar i;
for (i=0; i < 8 ; i=i+1) 
begin 
    always @(posedge clk or posedge reset)
    begin
        if (reset)
        begin
	    pointer_sfu[i]  <= 'd0;
	    for(j=0 ; j<16 ; j=j+1)
	        sfu_reg[i][j]  <= 'd0;
        end
        else 
        begin
            if (SFU_VALID[i] == 1'b1)
            begin
                //sfu_reg[pointer_sfu[i]][16*(i+1)-1 : 16*i] = $signed(sfu_reg[pointer_sfu[i]][16*(i+1)-1: 16*i]) +  $signed(ARRAY_OUT[16*(i+1)-1:16*i]);
                sfu_reg[i][pointer_sfu[i]] <= #1 sfu_reg[i][pointer_sfu[i]] + $signed(ARRAY_OUT[16*(i+1)-1:16*i]);
                pointer_sfu[i] <= #1 pointer_sfu[i] + 1'b1;
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

wire signed [15:0] sfu_reg_0_0;
wire signed [15:0] sfu_reg_0_1;
wire signed [15:0] sfu_reg_0_2;
wire signed [15:0] sfu_reg_0_3;
wire signed [15:0] sfu_reg_0_4;
wire signed [15:0] sfu_reg_0_5;
wire signed [15:0] sfu_reg_0_6;
wire signed [15:0] sfu_reg_0_7;
wire signed [15:0] sfu_reg_0_8;
wire signed [15:0] sfu_reg_0_9;
wire signed [15:0] sfu_reg_0_10;
wire signed [15:0] sfu_reg_0_11;
wire signed [15:0] sfu_reg_0_12;
wire signed [15:0] sfu_reg_0_13;
wire signed [15:0] sfu_reg_0_14;
wire signed [15:0] sfu_reg_0_15;
wire signed [15:0] sfu_reg_1_0;
wire signed [15:0] sfu_reg_1_1;
wire signed [15:0] sfu_reg_1_2;
wire signed [15:0] sfu_reg_1_3;
wire signed [15:0] sfu_reg_1_4;
wire signed [15:0] sfu_reg_1_5;
wire signed [15:0] sfu_reg_1_6;
wire signed [15:0] sfu_reg_1_7;
wire signed [15:0] sfu_reg_1_8;
wire signed [15:0] sfu_reg_1_9;
wire signed [15:0] sfu_reg_1_10;
wire signed [15:0] sfu_reg_1_11;
wire signed [15:0] sfu_reg_1_12;
wire signed [15:0] sfu_reg_1_13;
wire signed [15:0] sfu_reg_1_14;
wire signed [15:0] sfu_reg_1_15;
wire signed [15:0] sfu_reg_2_0;
wire signed [15:0] sfu_reg_2_1;
wire signed [15:0] sfu_reg_2_2;
wire signed [15:0] sfu_reg_2_3;
wire signed [15:0] sfu_reg_2_4;
wire signed [15:0] sfu_reg_2_5;
wire signed [15:0] sfu_reg_2_6;
wire signed [15:0] sfu_reg_2_7;
wire signed [15:0] sfu_reg_2_8;
wire signed [15:0] sfu_reg_2_9;
wire signed [15:0] sfu_reg_2_10;
wire signed [15:0] sfu_reg_2_11;
wire signed [15:0] sfu_reg_2_12;
wire signed [15:0] sfu_reg_2_13;
wire signed [15:0] sfu_reg_2_14;
wire signed [15:0] sfu_reg_2_15;
wire signed [15:0] sfu_reg_3_0;
wire signed [15:0] sfu_reg_3_1;
wire signed [15:0] sfu_reg_3_2;
wire signed [15:0] sfu_reg_3_3;
wire signed [15:0] sfu_reg_3_4;
wire signed [15:0] sfu_reg_3_5;
wire signed [15:0] sfu_reg_3_6;
wire signed [15:0] sfu_reg_3_7;
wire signed [15:0] sfu_reg_3_8;
wire signed [15:0] sfu_reg_3_9;
wire signed [15:0] sfu_reg_3_10;
wire signed [15:0] sfu_reg_3_11;
wire signed [15:0] sfu_reg_3_12;
wire signed [15:0] sfu_reg_3_13;
wire signed [15:0] sfu_reg_3_14;
wire signed [15:0] sfu_reg_3_15;
wire signed [15:0] sfu_reg_4_0;
wire signed [15:0] sfu_reg_4_1;
wire signed [15:0] sfu_reg_4_2;
wire signed [15:0] sfu_reg_4_3;
wire signed [15:0] sfu_reg_4_4;
wire signed [15:0] sfu_reg_4_5;
wire signed [15:0] sfu_reg_4_6;
wire signed [15:0] sfu_reg_4_7;
wire signed [15:0] sfu_reg_4_8;
wire signed [15:0] sfu_reg_4_9;
wire signed [15:0] sfu_reg_4_10;
wire signed [15:0] sfu_reg_4_11;
wire signed [15:0] sfu_reg_4_12;
wire signed [15:0] sfu_reg_4_13;
wire signed [15:0] sfu_reg_4_14;
wire signed [15:0] sfu_reg_4_15;
wire signed [15:0] sfu_reg_5_0;
wire signed [15:0] sfu_reg_5_1;
wire signed [15:0] sfu_reg_5_2;
wire signed [15:0] sfu_reg_5_3;
wire signed [15:0] sfu_reg_5_4;
wire signed [15:0] sfu_reg_5_5;
wire signed [15:0] sfu_reg_5_6;
wire signed [15:0] sfu_reg_5_7;
wire signed [15:0] sfu_reg_5_8;
wire signed [15:0] sfu_reg_5_9;
wire signed [15:0] sfu_reg_5_10;
wire signed [15:0] sfu_reg_5_11;
wire signed [15:0] sfu_reg_5_12;
wire signed [15:0] sfu_reg_5_13;
wire signed [15:0] sfu_reg_5_14;
wire signed [15:0] sfu_reg_5_15;
wire signed [15:0] sfu_reg_6_0;
wire signed [15:0] sfu_reg_6_1;
wire signed [15:0] sfu_reg_6_2;
wire signed [15:0] sfu_reg_6_3;
wire signed [15:0] sfu_reg_6_4;
wire signed [15:0] sfu_reg_6_5;
wire signed [15:0] sfu_reg_6_6;
wire signed [15:0] sfu_reg_6_7;
wire signed [15:0] sfu_reg_6_8;
wire signed [15:0] sfu_reg_6_9;
wire signed [15:0] sfu_reg_6_10;
wire signed [15:0] sfu_reg_6_11;
wire signed [15:0] sfu_reg_6_12;
wire signed [15:0] sfu_reg_6_13;
wire signed [15:0] sfu_reg_6_14;
wire signed [15:0] sfu_reg_6_15;
wire signed [15:0] sfu_reg_7_0;
wire signed [15:0] sfu_reg_7_1;
wire signed [15:0] sfu_reg_7_2;
wire signed [15:0] sfu_reg_7_3;
wire signed [15:0] sfu_reg_7_4;
wire signed [15:0] sfu_reg_7_5;
wire signed [15:0] sfu_reg_7_6;
wire signed [15:0] sfu_reg_7_7;
wire signed [15:0] sfu_reg_7_8;
wire signed [15:0] sfu_reg_7_9;
wire signed [15:0] sfu_reg_7_10;
wire signed [15:0] sfu_reg_7_11;
wire signed [15:0] sfu_reg_7_12;
wire signed [15:0] sfu_reg_7_13;
wire signed [15:0] sfu_reg_7_14;
wire signed [15:0] sfu_reg_7_15;


assign sfu_reg_0_0 = sfu_reg[0][0];
assign sfu_reg_0_1 = sfu_reg[0][1];
assign sfu_reg_0_2 = sfu_reg[0][2];
assign sfu_reg_0_3 = sfu_reg[0][3];
assign sfu_reg_0_4 = sfu_reg[0][4];
assign sfu_reg_0_5 = sfu_reg[0][5];
assign sfu_reg_0_6 = sfu_reg[0][6];
assign sfu_reg_0_7 = sfu_reg[0][7];
assign sfu_reg_0_8 = sfu_reg[0][8];
assign sfu_reg_0_9 = sfu_reg[0][9];
assign sfu_reg_0_10 = sfu_reg[0][10];
assign sfu_reg_0_11 = sfu_reg[0][11];
assign sfu_reg_0_12 = sfu_reg[0][12];
assign sfu_reg_0_13 = sfu_reg[0][13];
assign sfu_reg_0_14 = sfu_reg[0][14];
assign sfu_reg_0_15 = sfu_reg[0][15];
assign sfu_reg_1_0 = sfu_reg[1][0];
assign sfu_reg_1_1 = sfu_reg[1][1];
assign sfu_reg_1_2 = sfu_reg[1][2];
assign sfu_reg_1_3 = sfu_reg[1][3];
assign sfu_reg_1_4 = sfu_reg[1][4];
assign sfu_reg_1_5 = sfu_reg[1][5];
assign sfu_reg_1_6 = sfu_reg[1][6];
assign sfu_reg_1_7 = sfu_reg[1][7];
assign sfu_reg_1_8 = sfu_reg[1][8];
assign sfu_reg_1_9 = sfu_reg[1][9];
assign sfu_reg_1_10 = sfu_reg[1][10];
assign sfu_reg_1_11 = sfu_reg[1][11];
assign sfu_reg_1_12 = sfu_reg[1][12];
assign sfu_reg_1_13 = sfu_reg[1][13];
assign sfu_reg_1_14 = sfu_reg[1][14];
assign sfu_reg_1_15 = sfu_reg[1][15];
assign sfu_reg_2_0 = sfu_reg[2][0];
assign sfu_reg_2_1 = sfu_reg[2][1];
assign sfu_reg_2_2 = sfu_reg[2][2];
assign sfu_reg_2_3 = sfu_reg[2][3];
assign sfu_reg_2_4 = sfu_reg[2][4];
assign sfu_reg_2_5 = sfu_reg[2][5];
assign sfu_reg_2_6 = sfu_reg[2][6];
assign sfu_reg_2_7 = sfu_reg[2][7];
assign sfu_reg_2_8 = sfu_reg[2][8];
assign sfu_reg_2_9 = sfu_reg[2][9];
assign sfu_reg_2_10 = sfu_reg[2][10];
assign sfu_reg_2_11 = sfu_reg[2][11];
assign sfu_reg_2_12 = sfu_reg[2][12];
assign sfu_reg_2_13 = sfu_reg[2][13];
assign sfu_reg_2_14 = sfu_reg[2][14];
assign sfu_reg_2_15 = sfu_reg[2][15];
assign sfu_reg_3_0 = sfu_reg[3][0];
assign sfu_reg_3_1 = sfu_reg[3][1];
assign sfu_reg_3_2 = sfu_reg[3][2];
assign sfu_reg_3_3 = sfu_reg[3][3];
assign sfu_reg_3_4 = sfu_reg[3][4];
assign sfu_reg_3_5 = sfu_reg[3][5];
assign sfu_reg_3_6 = sfu_reg[3][6];
assign sfu_reg_3_7 = sfu_reg[3][7];
assign sfu_reg_3_8 = sfu_reg[3][8];
assign sfu_reg_3_9 = sfu_reg[3][9];
assign sfu_reg_3_10 = sfu_reg[3][10];
assign sfu_reg_3_11 = sfu_reg[3][11];
assign sfu_reg_3_12 = sfu_reg[3][12];
assign sfu_reg_3_13 = sfu_reg[3][13];
assign sfu_reg_3_14 = sfu_reg[3][14];
assign sfu_reg_3_15 = sfu_reg[3][15];
assign sfu_reg_4_0 = sfu_reg[4][0];
assign sfu_reg_4_1 = sfu_reg[4][1];
assign sfu_reg_4_2 = sfu_reg[4][2];
assign sfu_reg_4_3 = sfu_reg[4][3];
assign sfu_reg_4_4 = sfu_reg[4][4];
assign sfu_reg_4_5 = sfu_reg[4][5];
assign sfu_reg_4_6 = sfu_reg[4][6];
assign sfu_reg_4_7 = sfu_reg[4][7];
assign sfu_reg_4_8 = sfu_reg[4][8];
assign sfu_reg_4_9 = sfu_reg[4][9];
assign sfu_reg_4_10 = sfu_reg[4][10];
assign sfu_reg_4_11 = sfu_reg[4][11];
assign sfu_reg_4_12 = sfu_reg[4][12];
assign sfu_reg_4_13 = sfu_reg[4][13];
assign sfu_reg_4_14 = sfu_reg[4][14];
assign sfu_reg_4_15 = sfu_reg[4][15];
assign sfu_reg_5_0 = sfu_reg[5][0];
assign sfu_reg_5_1 = sfu_reg[5][1];
assign sfu_reg_5_2 = sfu_reg[5][2];
assign sfu_reg_5_3 = sfu_reg[5][3];
assign sfu_reg_5_4 = sfu_reg[5][4];
assign sfu_reg_5_5 = sfu_reg[5][5];
assign sfu_reg_5_6 = sfu_reg[5][6];
assign sfu_reg_5_7 = sfu_reg[5][7];
assign sfu_reg_5_8 = sfu_reg[5][8];
assign sfu_reg_5_9 = sfu_reg[5][9];
assign sfu_reg_5_10 = sfu_reg[5][10];
assign sfu_reg_5_11 = sfu_reg[5][11];
assign sfu_reg_5_12 = sfu_reg[5][12];
assign sfu_reg_5_13 = sfu_reg[5][13];
assign sfu_reg_5_14 = sfu_reg[5][14];
assign sfu_reg_5_15 = sfu_reg[5][15];
assign sfu_reg_6_0 = sfu_reg[6][0];
assign sfu_reg_6_1 = sfu_reg[6][1];
assign sfu_reg_6_2 = sfu_reg[6][2];
assign sfu_reg_6_3 = sfu_reg[6][3];
assign sfu_reg_6_4 = sfu_reg[6][4];
assign sfu_reg_6_5 = sfu_reg[6][5];
assign sfu_reg_6_6 = sfu_reg[6][6];
assign sfu_reg_6_7 = sfu_reg[6][7];
assign sfu_reg_6_8 = sfu_reg[6][8];
assign sfu_reg_6_9 = sfu_reg[6][9];
assign sfu_reg_6_10 = sfu_reg[6][10];
assign sfu_reg_6_11 = sfu_reg[6][11];
assign sfu_reg_6_12 = sfu_reg[6][12];
assign sfu_reg_6_13 = sfu_reg[6][13];
assign sfu_reg_6_14 = sfu_reg[6][14];
assign sfu_reg_6_15 = sfu_reg[6][15];
assign sfu_reg_7_0 = sfu_reg[7][0];
assign sfu_reg_7_1 = sfu_reg[7][1];
assign sfu_reg_7_2 = sfu_reg[7][2];
assign sfu_reg_7_3 = sfu_reg[7][3];
assign sfu_reg_7_4 = sfu_reg[7][4];
assign sfu_reg_7_5 = sfu_reg[7][5];
assign sfu_reg_7_6 = sfu_reg[7][6];
assign sfu_reg_7_7 = sfu_reg[7][7];
assign sfu_reg_7_8 = sfu_reg[7][8];
assign sfu_reg_7_9 = sfu_reg[7][9];
assign sfu_reg_7_10 = sfu_reg[7][10];
assign sfu_reg_7_11 = sfu_reg[7][11];
assign sfu_reg_7_12 = sfu_reg[7][12];
assign sfu_reg_7_13 = sfu_reg[7][13];
assign sfu_reg_7_14 = sfu_reg[7][14];
assign sfu_reg_7_15 = sfu_reg[7][15];

    //assign  O_D     =   {sfu_reg[7][counter], sfu_reg[6][counter], sfu_reg[5][counter], sfu_reg[4][counter], sfu_reg[3][counter], sfu_reg[2][counter], sfu_reg[1][counter], sfu_reg[0][counter]};

    wire signed [15:0] sfu_reg_0;
    wire signed [15:0] sfu_reg_1;
    wire signed [15:0] sfu_reg_2;
    wire signed [15:0] sfu_reg_3;
    wire signed [15:0] sfu_reg_4;
    wire signed [15:0] sfu_reg_5;
    wire signed [15:0] sfu_reg_6;
    wire signed [15:0] sfu_reg_7;

    assign sfu_reg_0 = (sfu_reg[0][counter][15])?('d0):(sfu_reg[0][counter]);
    assign sfu_reg_1 = (sfu_reg[1][counter][15])?('d0):(sfu_reg[1][counter]);
    assign sfu_reg_2 = (sfu_reg[2][counter][15])?('d0):(sfu_reg[2][counter]);
    assign sfu_reg_3 = (sfu_reg[3][counter][15])?('d0):(sfu_reg[3][counter]);
    assign sfu_reg_4 = (sfu_reg[4][counter][15])?('d0):(sfu_reg[4][counter]);
    assign sfu_reg_5 = (sfu_reg[5][counter][15])?('d0):(sfu_reg[5][counter]);
    assign sfu_reg_6 = (sfu_reg[6][counter][15])?('d0):(sfu_reg[6][counter]);
    assign sfu_reg_7 = (sfu_reg[7][counter][15])?('d0):(sfu_reg[7][counter]); 

    assign  O_D     =   {sfu_reg_7, sfu_reg_6, sfu_reg_5, sfu_reg_4, sfu_reg_3, sfu_reg_2, sfu_reg_1, sfu_reg_0};
    assign  O_ADDR  =   counter;
    assign  O_CEN   =   (state!=RET_OUT);
    assign  O_WEN   =   (state!=RET_OUT);




endmodule
