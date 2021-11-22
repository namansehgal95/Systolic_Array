// Created by prof. Mingu Kang @VVIP Lab in UCSD ECE department
// Please do not spread this code without permission 
module mac_tile (clk, out_s, in_w, out_e, in_n, inst_w, inst_e, reset);

parameter bw = 4;
parameter psum_bw = 16;

output [psum_bw-1:0] 	out_s;
input  [bw-1:0] 		in_w; 	// inst[1]:execute, inst[0]: kernel loading
output [bw-1:0] 		out_e; 	// latched version of in_w;
input  [1:0] 			inst_w; 
output [1:0] 			inst_e;	//latched version of inst_w;
input  [psum_bw-1:0] 	in_n;	//in_n is input psum
input  					clk;
input  					reset;


reg 		[1:0] 			inst_q; 	//connected to inst_e ; latched from inst_w;  when reset : make inst_q='h0 and load_ready_q=1'b1 (basically means ready to accept new weight, if it is 0 it won't update the weights);
reg 		[bw-1:0] 		a_q;		//connected to out_e ; latched from in_w; when (inst_w[0]=='b1 ||inst_w[1]=='b1) load; During kernel loading also we need to pass x;
reg signed 	[bw-1:0] 		b_q;		//if (inst_w[0]=='b1&&load_ready_q=='b1), then accept the latch from in_w; Also, make load_ready_q='b0 after the operation 
reg signed 	[psum_bw-1:0] 	c_q;		
reg 						load_ready_q;
wire signed [psum_bw-1:0] 	mac_out;


always @(posedge clk)
begin
	if(reset)
	begin
		inst_q <= 'h0;
		load_ready_q <= 'b1;
	end
	else
	begin
		inst_q[1] <= inst_w[1];
		if(load_ready_q=='b0)
			inst_q[0] <= inst_w[0];
		if(load_ready_q=='b1 && inst_w[0]=='b1)
			load_ready_q <= 'b0;
	end
end


always @(posedge clk)
begin
	if(inst_w[0]=='b1 || inst_w[1]=='b1)
		a_q <= in_w;
end

always @(posedge clk)
begin
	if(inst_w[0]=='b1 && load_ready_q=='b1)
		b_q	<=	in_w;
end

always @(posedge clk)
begin
	c_q	<=	in_n;
end

mac #(.bw(bw), .psum_bw(psum_bw)) mac_instance (
        .a(a_q), 
        .b(b_q),
        .c(c_q),
	.out(mac_out)
); 

assign out_e = a_q;
assign out_s = mac_out;
assign inst_e = inst_q;

endmodule
