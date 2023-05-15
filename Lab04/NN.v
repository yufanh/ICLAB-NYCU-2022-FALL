module NN(
	// Input signals
	clk,
	rst_n,
	in_valid_u,
	in_valid_w,
	in_valid_v,
	in_valid_x,
	weight_u,
	weight_w,
	weight_v,
	data_x,
	// Output signals
	out_valid,
	out
);

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------

// IEEE floating point paramenters
parameter inst_sig_width = 23;
parameter inst_exp_width = 8;
parameter inst_ieee_compliance = 0;
parameter inst_arch = 0;
parameter inst_faithful_round = 0;
parameter round = 3'b000;
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input  clk, rst_n, in_valid_u, in_valid_w, in_valid_v, in_valid_x;
input [inst_sig_width+inst_exp_width:0] weight_u, weight_w, weight_v;
input [inst_sig_width+inst_exp_width:0] data_x;
output reg	out_valid;
output reg [inst_sig_width+inst_exp_width:0] out;


/* FSM declaration */
reg [4:0] c_state;
reg [29:0]st;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------

// vector reg
reg [inst_sig_width+inst_exp_width:0] u [8:0];
reg [inst_sig_width+inst_exp_width:0] w [8:0];
reg [inst_sig_width+inst_exp_width:0] v [8:0];
reg [inst_sig_width+inst_exp_width:0] x_10, x_11, x_12, x_20, x_21, x_22, x_30, x_31, x_32;
reg [inst_sig_width+inst_exp_width:0] h_10, h_11, h_12, h_20, h_21, h_22, h_30, h_31, h_32;
reg [inst_sig_width+inst_exp_width:0] y_10, y_11, y_12;


genvar i;
integer i_f;


/*pipline reg*/
reg [inst_sig_width+inst_exp_width:0] ma1_a, ma1_b, ma1_c;
reg [inst_sig_width+inst_exp_width:0] ma2_a, ma2_b, ma2_c;
reg [inst_sig_width+inst_exp_width:0] ma3_a, ma3_b, ma3_c;
reg [inst_sig_width+inst_exp_width:0] exp_in;
reg [inst_sig_width+inst_exp_width:0] add_in, add_in_1;
reg [inst_sig_width+inst_exp_width:0] recip_in;


wire [inst_sig_width+inst_exp_width:0] ma1_out, ma2_out, ma3_out, exp_out, add_out, recip_out, relu_out;
wire [inst_sig_width+inst_exp_width:0] m1_out, m2_out, m3_out;
wire [7:0] status_ma1_m, status_ma1_a, status_ma2_m, status_ma2_a, status_ma3_m, status_ma3_a, status_exp, status_add, status_recip;

always @(*) begin
	if((c_state == 5'b0) && in_valid_x) st[0] = 1'b1;
	else st[0] = 1'b0;
end
generate
	for(i = 1; i < 30; i = i + 1) begin
		always @(*) begin
			if(c_state == i) st[i] = 1'b1;
			else st[i] = 1'b0;
		end
	end
endgenerate


// ma1 input reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma1_a <= 32'b0;
	// else if(st[0]) ma1_a <= weight_u;	// u_00
	else if(st[2] || st[4] || st[8]) ma1_a <= u[0];	// u_00
	else if(st[3]) ma1_a <= weight_u;		// u_10
	else if(st[5] || st[9]) ma1_a <= u[3];	// u_10
	else if(st[6]) ma1_a <= weight_u;		// u_20
	else if(st[7] || st[10]) ma1_a <= u[6];	// u_20

	else if(st[11] || st[17]) ma1_a <= w[0];	// w_00
	else if(st[12] || st[18]) ma1_a <= w[3];	// w_10
	else if(st[13] || st[19]) ma1_a <= w[6];	// w_20
	
	else if(st[14] || st[20] || st[23]) ma1_a <= v[0];	// v_00
	else if(st[15] || st[21] || st[24]) ma1_a <= v[3];	// v_10
	else if(st[16] || st[22] || st[25]) ma1_a <= v[6];	// v_20
	else ma1_a <= ma1_a;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma1_b <= 32'b0;
	// else if(st[0]) ma1_b <= data_x;	// x_10
	else if(st[2] || st[3] || st[7]) ma1_b <= x_10;	// x_10
	else if(st[4] || st[5] || st[6]) ma1_b <= x_20;	// x_20
	else if(st[8] || st[9] || st[10]) ma1_b <= x_30;	// x_30

	else if(st[11] || st[12] || st[13] || st[14] || st[15] || st[16]) ma1_b <= h_10;	// h_10

	else if(st[17]) ma1_b <= recip_out; // h_20
	else if(st[18] || st[19] || st[20] || st[21] || st[22]) ma1_b <= h_20;	// h_20

	else if(st[23]) ma1_b <= recip_out; // h_30
	else if(st[24] || st[25]) ma1_b <= h_30;	// h_30
	else ma1_b <= ma1_b;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma1_c <= 32'b0;
	else if(st[11]) ma1_c <= x_20;
	else if(st[12]) ma1_c <= x_21;
	else if(st[13]) ma1_c <= x_22;
	else if(st[17]) ma1_c <= x_30;
	else if(st[18]) ma1_c <= x_31;
	else if(st[19]) ma1_c <= x_32;
	else ma1_c <= 32'b0;
end

// ma2 input reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma2_a <= 32'b0;
	// else if(st[1]) ma2_a <= weight_u;	// u_01
	else if(st[3] || st[5] || st[9]) ma2_a <= u[1];	// u_01
	else if(st[4]) ma2_a <= weight_u;		// u_11
	else if(st[6] || st[10]) ma2_a <= u[4];	// u_11
	else if(st[7]) ma2_a <= weight_u;		// u_21
	else if(st[8] || st[11]) ma2_a <= u[7];	// u_21

	else if(st[12] || st[18]) ma2_a <= w[1];	// w_01
	else if(st[13] || st[19]) ma2_a <= w[4];	// w_11
	else if(st[14] || st[20]) ma2_a <= w[7];	// w_21
	
	else if(st[15] || st[21] || st[24]) ma2_a <= v[1];	// v_01
	else if(st[16] || st[22] || st[25]) ma2_a <= v[4];	// v_11
	else if(st[17] || st[23] || st[26]) ma2_a <= v[7];	// v_21
	else ma2_a <= ma2_a;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma2_b <= 32'b0;
	// else if(st[1]) ma2_b <= data_x;	// x_11
	else if(st[3] || st[4] || st[8]) ma2_b <= x_11;	// x_11
	else if(st[5] || st[6] || st[7]) ma2_b <= x_21;	// x_21
	else if(st[9] || st[10] || st[11]) ma2_b <= x_31;	// x_31

	else if(st[12] || st[13] || st[14] || st[15] || st[16] || st[17]) ma2_b <= h_11;	// h_11

	else if(st[18]) ma2_b <= recip_out;	// h_21
	else if(st[19] || st[20] || st[21] || st[22] || st[23]) ma2_b <= h_21;	// h_21

	else if(st[24]) ma2_b <= recip_out;	// h_31
	else if(st[25] || st[26]) ma2_b <= h_31;	// h_31
	else ma2_b <= ma2_b;
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma2_c <= 32'b0;
	else ma2_c <= ma1_out;
end

// ma3 input reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma3_a <= 32'b0;
	// else if(st[2]) ma3_a <= weight_u;	// u_02
	else if(st[4] || st[6] || st[10]) ma3_a <= u[2];	// u_02
	else if(st[5]) 	ma3_a <= weight_u;		// u_12
	else if(st[7] || st[11]) ma3_a <= u[5];	// u_12
	else if(st[8]) ma3_a <= weight_u;		// u_22
	else if(st[9] || st[12]) ma3_a <= u[8];	// u_22

	else if(st[13] || st[19]) ma3_a <= w[2];	// w_02
	else if(st[14] || st[20]) ma3_a <= w[5];	// w_12
	else if(st[15] || st[21]) ma3_a <= w[8];	// w_22
	
	else if(st[16] || st[22] || st[25]) ma3_a <= v[2];	// v_02
	else if(st[17] || st[23] || st[26]) ma3_a <= v[5];	// v_12
	else if(st[18] || st[24] || st[27]) ma3_a <= v[8];	// v_22

	else ma3_a <= ma3_a;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma3_b <= 32'b0;
	// else if(st[2]) ma3_b <= data_x;	// x_12
	else if(st[4] || st[5] || st[9]) ma3_b <= x_12;	// x_12
	else if(st[6] || st[7] || st[8]) ma3_b <= x_22;	// x_22
	else if(st[10] || st[11] || st[12]) ma3_b <= x_32;	// x_32

	else if(st[13]) ma3_b <= recip_out;	// h_12
	else if(st[14] || st[15] || st[16] || st[17] || st[18]) ma3_b <= h_12;	// h_12

	else if(st[19]) ma3_b <= recip_out;	// h_22
	else if(st[20] || st[21] || st[22] || st[23] || st[24]) ma3_b <= h_22;	// h_22

	else if(st[25]) ma3_b <= recip_out;	// h_32
	else if(st[26] || st[27]) ma3_b <= h_32;	// h_32
	else ma3_b <= ma3_b;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ma3_c <= 32'b0;
	else ma3_c <= ma2_out;
end

// exp reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) exp_in <= 32'b0;
	else exp_in <= {~ma3_out[31], ma3_out[30:0]};
end

// add reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) add_in <= 32'b0;
	else add_in <= exp_out;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) add_in_1 <= 32'b0;
	else add_in_1 <= 32'b00111111100000000000000000000000;
end

// redcip reg
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) recip_in <= 32'b0;
	else recip_in <= add_out;
end


// h
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_10 <= 32'b0;
	else if(st[8]) h_10 <= recip_out;
	else h_10 <= h_10;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_11 <= 32'b0;
	else if(st[9]) h_11 <= recip_out;
	else h_11 <= h_11;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_12 <= 32'b0;
	else if(st[13]) h_12 <= recip_out;
	else h_12 <= h_12;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_20 <= 32'b0;
	else if(st[17]) h_20 <= recip_out;
	else h_20 <= h_20;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_21 <= 32'b0;
	else if(st[18]) h_21 <= recip_out;
	else h_21 <= h_21;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_22 <= 32'b0;
	else if(st[19]) h_22 <= recip_out;
	else h_22 <= h_22;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_30 <= 32'b0;
	else if(st[23]) h_30 <= recip_out;
	else h_30 <= h_30;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_31 <= 32'b0;
	else if(st[24]) h_31 <= recip_out;
	else h_31 <= h_31;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) h_32 <= 32'b0;
	else if(st[25]) h_32 <= recip_out;
	else h_32 <= h_32;
end
/* FDSM */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= 5'b0;
	else begin
		if(c_state == 5'd0) begin
			if(!in_valid_x) c_state <= 5'd0;
			else c_state <= c_state + 1'b1;
		end
		else if(c_state == 5'd29) c_state <= 5'd0;
		else c_state <= c_state + 5'd1;

	end
end

/* input matrix */
generate
	for(i = 0; i < 9; i = i + 1) begin: matrix_u

		always @(posedge clk or negedge rst_n) begin
			if(!rst_n) u[i] <= 5'b0;
			else if(st[i] && in_valid_x) u[i] <= weight_u;
			else u[i] <= u[i];
		end
	end
endgenerate

generate
	for(i = 0; i < 9; i = i + 1) begin: matrix_w

		always @(posedge clk or negedge rst_n) begin
			if(!rst_n) w[i] <= 5'b0;
			else if(st[i] && in_valid_x) w[i] <= weight_w;
			else w[i] <= w[i];
		end
	end
endgenerate
generate
	for(i = 0; i < 9; i = i + 1) begin: matrix_v

		always @(posedge clk or negedge rst_n) begin
			if(!rst_n) v[i] <= 5'b0;
			else if(st[i] && in_valid_x) v[i] <= weight_v;
			else v[i] <= v[i];
		end
	end
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_10 <= 32'b0;
	else if(st[0] && in_valid_x) x_10 <= data_x;
	else x_10 <= x_10;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_11 <= 32'b0;
	else if(st[1] && in_valid_x) x_11 <= data_x;
	else x_11 <= x_11;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_12 <= 32'b0;
	else if(st[2] && in_valid_x) x_12 <= data_x;
	else x_12 <= x_12;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_20 <= 32'b0;
	else if(st[3] && in_valid_x) x_20 <= data_x;
	else if(st[7]) x_20 <= ma3_out;
	else x_20 <= x_20;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_21 <= 32'b0;
	else if(st[4] && in_valid_x) x_21 <= data_x;
	else if(st[8]) x_21 <= ma3_out;
	else x_21 <= x_21;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_22 <= 32'b0;
	else if(st[5] && in_valid_x) x_22 <= data_x;
	else if(st[9]) x_22 <= ma3_out;
	else x_22 <= x_22;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_30 <= 32'b0;
	else if(st[6] && in_valid_x) x_30 <= data_x;
	else if(st[11]) x_30 <= ma3_out;
	else x_30 <= x_30;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_31 <= 32'b0;
	else if(st[7] && in_valid_x) x_31 <= data_x;
	else if(st[12]) x_31 <= ma3_out;
	else x_31 <= x_31;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) x_32 <= 32'b0;
	else if(st[8] && in_valid_x) x_32 <= data_x;
	else if(st[13]) x_32 <= ma3_out;
	else x_32 <= x_32;
end


// y
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) y_10 <= 32'b0;
	else if(st[17]) y_10 <= relu_out;
	else y_10 <= y_10;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) y_11 <= 32'b0;
	else if(st[18]) y_11 <= relu_out;
	else y_11 <= y_11;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) y_12 <= 32'b0;
	else if(st[19]) y_12 <= relu_out;
	else y_12 <= y_12;
end
// output 
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'b0;
	else if(st[20]) out_valid <= 1'b1;
	else if(st[29]) out_valid <= 1'b0;
	else out_valid <= out_valid;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out <= 32'b0;
	else if(st[20]) out <= y_10;
	else if(st[21]) out <= y_11;
	else if(st[22]) out <= y_12;
	else if(st[23]) out <= relu_out;
	else if(st[24]) out <= relu_out;
	else if(st[25]) out <= relu_out;
	else if(st[26]) out <= relu_out;
	else if(st[27]) out <= relu_out;
	else if(st[28]) out <= relu_out;
	else out <= 32'b0;
end


// comdinational login

// relu
assign relu_out = (ma3_out[31] == 1'b1)? 32'b0 : ma3_out;
// ma1
DW_fp_mult #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma1_m(.a(ma1_a), .b(ma1_b), .rnd(round), .z(m1_out), .status(status_ma1_m));
DW_fp_add #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma1_a(.a(ma1_c), .b(m1_out), .rnd(round), .z(ma1_out), .status(status_ma1_a));

// ma2
DW_fp_mult #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma2_m(.a(ma2_a), .b(ma2_b), .rnd(round), .z(m2_out), .status(status_ma2_m));
DW_fp_add #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma2_a(.a(ma2_c), .b(m2_out), .rnd(round), .z(ma2_out), .status(status_ma2_a));

// ma3
DW_fp_mult #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma3_m(.a(ma3_a), .b(ma3_b), .rnd(round), .z(m3_out), .status(status_ma3_m));
DW_fp_add #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uma3_a(.a(ma3_c), .b(m3_out), .rnd(round), .z(ma3_out), .status(status_ma3_a));

// exp
DW_fp_exp #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_arch) Uexp(.a(exp_in), .z(exp_out), .status(status_exp));

//add
DW_fp_add #(inst_sig_width,inst_exp_width,inst_ieee_compliance) Uadd(.a(add_in), .b(add_in_1), .rnd(round), .z(add_out), .status(status_add));

//recip
DW_fp_recip #(inst_sig_width,inst_exp_width,inst_ieee_compliance,inst_faithful_round) Urecip(.a(recip_in), .rnd(round), .z(recip_out), .status(status_recip));

endmodule
