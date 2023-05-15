// synopsys translate_off 
`ifdef RTL
`include "GATED_OR.v"
`else
`include "Netlist/GATED_OR_SYN.v"
`endif
// synopsys translate_on
module SP(
	// Input signals
	clk,
	rst_n,
	cg_en,
	in_valid,
	in_data,
	in_mode,
	// Output signals
	out_valid,
	out_data
);

// INPUT AND OUTPUT DECLARATION  
input		clk;
input		rst_n;
input		in_valid;
input		cg_en;
input [8:0] in_data;
input [2:0] in_mode;

output reg 		  out_valid;
output reg signed[9:0] out_data;


/* FSM Declaration */
reg [3:0] c_state, n_state;
parameter ST_IDLE = 'd0,
		  ST_IN_MODE = 'd1,
		  ST_IN = 'd2,
		  ST_ADDSUB = 'd3,
		  ST_SMA = 'd4,
		  ST_MMM = 'd5,
		  ST_OUT = 'd6;

/* reg & wire */
reg [2:0] mode;
reg signed [9:0] data [8:0];
reg [1:0] out_cnt;
wire signed [8:0] bin_code;
reg signed [9:0] final_in_data;
wire signed [8:0] bin_code_two_comp;
wire signed [9:0] max_wire, med_wire, min_wire;
wire signed [9:0] max_min_sub,
			  	  max_min_add,
				  half_diff_temp,
				  midpoint_temp,
				  half_diff,
				  midpoint;
reg signed [9:0] addsub_max, addsub_min;
reg signed [9:0] add_sub [8:0];
wire signed [9:0] sma [8:0];
reg signed [9:0] out_max, out_med, out_min;
reg [3:0] in_cnt;
genvar i;

wire signed [9:0] hor_0 [2:0]; // 0 = maximum, 1 = median, 2 = minmum 
wire signed [9:0] hor_1 [2:0]; // 0 = maximum, 1 = median, 2 = minmum 
wire signed [9:0] hor_2 [2:0]; // 0 = maximum, 1 = median, 2 = minmum 
wire signed [9:0] ver_0 [2:0]; // 0 = maximum, 1 = median, 2 = minmum 
wire signed [9:0] ver_1 [2:0]; // 0 = maximum, 1 = median, 2 = minmum 
wire signed [9:0] ver_2 [2:0]; // 0 = maximum, 1 = median, 2 = minmum
wire signed [9:0] iter1_winner [6:0];
wire signed [9:0] iter1_loser [6:0];
wire signed [9:0] iter2_winner [6:0];
wire signed [9:0] iter2_loser [6:0];

wire data_gated, clk_data;
wire out_gated, clk_out;
wire in_max_min_gated, clk_in_max_min;
assign data_gated = (((c_state == ST_IDLE && !in_valid)
					|| (c_state == ST_OUT) || (c_state == ST_SMA)
					) && cg_en);
assign out_gated = (((c_state == ST_IDLE) || (c_state == ST_IN && in_cnt <= 8)
					) && cg_en);
assign in_max_min_gated = (((c_state == ST_OUT) || (c_state == ST_ADDSUB) || (c_state == ST_SMA)
					) && cg_en);
GATED_OR GATED_data(.CLOCK(clk), .SLEEP_CTRL(data_gated), .RST_N(rst_n), .CLOCK_GATED(clk_data));
GATED_OR GATED_out(.CLOCK(clk), .SLEEP_CTRL(out_gated), .RST_N(rst_n), .CLOCK_GATED(clk_out));
GATED_OR GATED_in_max_min(.CLOCK(clk), .SLEEP_CTRL(in_max_min_gated), .RST_N(rst_n), .CLOCK_GATED(clk_in_max_min));
/* FSM */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= ST_IDLE;
	else c_state <= n_state;
end
always @(*) begin
	case (c_state)
	ST_IDLE: begin
		if(in_valid) n_state = ST_IN_MODE;
		else n_state = ST_IDLE;
	end
	ST_IN_MODE: n_state = ST_IN;
	ST_IN: begin
		if(in_cnt <= 4'd8) n_state = ST_IN;
		else begin
			if(mode[1]) n_state = ST_ADDSUB;
			else if(mode[2]) n_state = ST_SMA;
			else n_state = ST_OUT;
		end
	end
	ST_ADDSUB: begin
		if(mode[2]) n_state = ST_SMA;
		else n_state = ST_OUT;
	end
	ST_SMA: n_state = ST_OUT;
	ST_OUT: begin
		if(out_cnt == 2'b11) n_state = ST_IDLE;
		else n_state = ST_OUT;
	end
	default: n_state = ST_IDLE;
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) in_cnt <= 4'b0;
	else begin
		case (n_state)
			ST_IN_MODE: in_cnt <= in_cnt + 1'b1;
			ST_IN: in_cnt <= in_cnt + 1'b1;
			default: in_cnt <= 1'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) mode <= 3'b0;
	else begin
		case (n_state)
		ST_IN_MODE: mode <= in_mode;
		default: mode <= mode;
		endcase
	end
end
always @(*) begin
	case (c_state)
	ST_IDLE: begin
		if(in_valid) begin
			if(in_mode[0]) final_in_data = {bin_code[8], bin_code};
			else final_in_data = {in_data[8], in_data};
		end
		else final_in_data = 10'd0;
	end
	ST_IN_MODE: begin
		if(mode[0]) final_in_data = {bin_code[8], bin_code};
		else final_in_data = {in_data[8], in_data};
	end
	ST_IN: begin
		if(in_valid) begin
			if(mode[0]) final_in_data = {bin_code[8], bin_code};
			else final_in_data = {in_data[8], in_data};
		end
		else final_in_data = 10'd0;
	end
	default: final_in_data = 10'd0;
	endcase
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) data[0] <= 10'b0;
	else begin
		case (n_state)
		ST_IN_MODE: data[0] <= final_in_data;
		ST_IN: data[0] <= data[0];
		ST_ADDSUB: begin
			if(data[0] > midpoint) data[0] <= data[0] - half_diff;
			else if(data[0] < midpoint) data[0] <= data[0] + half_diff;
			else data[0] <= data[0];
		end
		ST_SMA: data[0] <= sma[0];
		default: data[0] <= data[0];
		endcase
	end
end
generate
for(i = 1; i < 9; i = i + 1) begin
	always @(posedge clk_data or negedge rst_n) begin
		if(!rst_n) data[i] <= 10'b0;
		else begin
			case (n_state)
			ST_IN: begin
				if(in_cnt == i)	data[i] <= final_in_data;
				else data[i] <= data[i];
			end
			
			ST_ADDSUB: begin
				if(data[i] > midpoint) data[i] <= data[i] - half_diff;
				else if(data[i] < midpoint) data[i] <= data[i] + half_diff;
				else data[i] <= data[i];
			end
			ST_SMA: data[i] <= sma[i];
			default: data[i] <= ~data[i];
			endcase
		end
	end
end
endgenerate


always @(posedge clk_in_max_min or negedge rst_n) begin
	if(!rst_n) addsub_max <= 10'b0;
	else begin
		case (n_state)
		ST_IN_MODE: addsub_max <= final_in_data;
		ST_IN: begin
			if(final_in_data > addsub_max) addsub_max <= final_in_data;
			else addsub_max <= addsub_max;
		end
		ST_ADDSUB: addsub_max <= addsub_max;
		default: addsub_max <= ~addsub_max;
		endcase
	end
end
always @(posedge clk_in_max_min or negedge rst_n) begin
	if(!rst_n) addsub_min <= 10'b0;
	else begin
		case (n_state)
		ST_IN_MODE: addsub_min <= final_in_data;
		ST_IN: begin
			if(final_in_data < addsub_min) addsub_min <= final_in_data;
			else addsub_min <= addsub_min;
		end
		ST_ADDSUB: addsub_min <= addsub_min;
		default: addsub_min <= ~addsub_min;
		endcase
	end
end
always @(posedge clk_out or negedge rst_n) begin
	if(!rst_n) out_max <= 10'b0;
	else begin
		case (n_state)
		ST_OUT: begin
			if(c_state == ST_IN || c_state == ST_ADDSUB || c_state == ST_SMA) out_max <= max_wire;
			else out_max <= out_max;
		end
		default: out_max <= ~out_max;
		endcase
		
	end
end
always @(posedge clk_out or negedge rst_n) begin
	if(!rst_n) out_med <= 10'b0;
	else begin
		case (n_state)
		ST_OUT: begin
			if(c_state == ST_IN || c_state == ST_ADDSUB || c_state == ST_SMA) out_med <= med_wire;
			else out_med <= out_med;
		end
		default: out_med <= ~out_med;
		endcase
	end
end
always @(posedge clk_out or negedge rst_n) begin
	if(!rst_n) out_min <= 10'b0;
	else begin
		case (n_state)
		ST_OUT: begin
			if(c_state == ST_IN || c_state == ST_ADDSUB || c_state == ST_SMA) out_min <= min_wire;
			else out_min <= out_min;
		end
		default: out_min <= ~out_min;
		endcase
	end
end
GRAYCODE2BINARY U_g2b(.gray(in_data), .bin(bin_code));

assign bin_code_two_comp = (in_data[8])? {1'b1, (~bin_code[7:0]) + 1'b1} : bin_code;
assign max_min_sub = addsub_max - addsub_min;
assign max_min_add = addsub_max + addsub_min;
assign half_diff = max_min_sub / 2;
assign midpoint = max_min_add / 2;

assign sma[0] = (data[0] + data[1] + data[8]) / 3;
assign sma[8] = (data[7] + data[8] + data[0]) / 3;
generate
for(i = 1; i < 8; i = i + 1) begin
	assign sma[i] = (data[i-1] + data[i] + data[i+1]) / 3;
end	
endgenerate

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_cnt <= 2'b0;
	else begin
		case (n_state)
			ST_OUT: out_cnt <= out_cnt + 1'b1;
			default: out_cnt <= 2'b0;
		endcase
	end
end
/* output */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'b0;
	else begin
		case (n_state)
		ST_OUT : out_valid <= 1'b1;		
		default: out_valid <= 1'b0;
		endcase
	end
end

always @(*) begin
	case (c_state)
	ST_OUT: begin
		case (out_cnt)
		2'b01: out_data = out_max;
		2'b10: out_data = out_med;
		2'b11: out_data = out_min;
		default: out_data = 10'b0;
		endcase
		end
	default: out_data = 10'b0;
	endcase
end

/* compare */

assign iter1_winner[0] = (data[0] >= data[1])? data[0] : data[1];
assign iter1_loser[0] = (data[0] >= data[1])? data[1] : data[0];
assign iter2_winner[0] = (iter1_loser[0] >= data[2])? iter1_loser[0] : data[2];
assign iter2_loser[0] = (iter1_loser[0] >= data[2])? data[2] : iter1_loser[0];

assign iter1_winner[1] = (data[3] >= data[4])? data[3] : data[4];
assign iter1_loser[1] = (data[3] >= data[4])? data[4] : data[3];
assign iter2_winner[1] = (iter1_loser[1] >= data[5])? iter1_loser[1] : data[5];
assign iter2_loser[1] = (iter1_loser[1] >= data[5])? data[5] : iter1_loser[1];

assign iter1_winner[2] = (data[6] >= data[7])? data[6] : data[7];
assign iter1_loser[2] = (data[6] >= data[7])? data[7] : data[6];
assign iter2_winner[2] = (iter1_loser[2] >= data[8])? iter1_loser[2] : data[8];
assign iter2_loser[2] = (iter1_loser[2] >= data[8])? data[8] : iter1_loser[2];

assign hor_0[0] = (iter1_winner[0] >= iter2_winner[0])? iter1_winner[0] : iter2_winner[0];
assign hor_0[1] = (iter1_winner[0] >= iter2_winner[0])? iter2_winner[0] : iter1_winner[0];
assign hor_0[2] = iter2_loser[0];

assign hor_1[0] = (iter1_winner[1] >= iter2_winner[1])? iter1_winner[1] : iter2_winner[1];
assign hor_1[1] = (iter1_winner[1] >= iter2_winner[1])? iter2_winner[1] : iter1_winner[1];
assign hor_1[2] = iter2_loser[1];

assign hor_2[0] = (iter1_winner[2] >= iter2_winner[2])? iter1_winner[2] : iter2_winner[2];
assign hor_2[1] = (iter1_winner[2] >= iter2_winner[2])? iter2_winner[2] : iter1_winner[2];
assign hor_2[2] = iter2_loser[2];

assign iter1_winner[3] = (hor_0[0] >= hor_1[0])? hor_0[0] : hor_1[0];
assign iter1_loser[3] = (hor_0[0] >= hor_1[0])? hor_1[0] : hor_0[0];
assign iter2_winner[3] = (iter1_loser[3] >= hor_2[0])? iter1_loser[3] : hor_2[0];
assign iter2_loser[3] = (iter1_loser[3] >= hor_2[0])? hor_2[0] : iter1_loser[3];

assign iter1_winner[4] = (hor_0[1] >= hor_1[1])? hor_0[1] : hor_1[1];
assign iter1_loser[4] = (hor_0[1] >= hor_1[1])? hor_1[1] : hor_0[1];
assign iter2_winner[4] = (iter1_loser[4] >= hor_2[1])? iter1_loser[4] : hor_2[1];
assign iter2_loser[4] = (iter1_loser[4] >= hor_2[1])? hor_2[1] : iter1_loser[4];

assign iter1_winner[5] = (hor_0[2] >= hor_1[2])? hor_0[2] : hor_1[2];
assign iter1_loser[5] = (hor_0[2] >= hor_1[2])? hor_1[2] : hor_0[2];
assign iter2_winner[5] = (iter1_loser[5] >= hor_2[2])? iter1_loser[5] : hor_2[2];
assign iter2_loser[5] = (iter1_loser[5] >= hor_2[2])? hor_2[2] : iter1_loser[5];

assign ver_0[0] = (iter1_winner[3] >= iter2_winner[3])? iter1_winner[3] : iter2_winner[3];
assign ver_0[1] = (iter1_winner[3] >= iter2_winner[3])? iter2_winner[3] : iter1_winner[3];
assign ver_0[2] = iter2_loser[3];

assign ver_1[0] = (iter1_winner[4] >= iter2_winner[4])? iter1_winner[4] : iter2_winner[4];
assign ver_1[1] = (iter1_winner[4] >= iter2_winner[4])? iter2_winner[4] : iter1_winner[4];
assign ver_1[2] = iter2_loser[4];

assign ver_2[0] = (iter1_winner[5] >= iter2_winner[5])? iter1_winner[5] : iter2_winner[5];
assign ver_2[1] = (iter1_winner[5] >= iter2_winner[5])? iter2_winner[5] : iter1_winner[5];
assign ver_2[2] = iter2_loser[5];


assign iter1_winner[6] = (ver_0[2] >= ver_1[1])? ver_0[2] : ver_1[1];
assign iter1_loser[6] = (ver_0[2] >= ver_1[1])? ver_1[1] : ver_0[2];
assign iter2_winner[6] = (iter1_loser[6] >= ver_2[0])? iter1_loser[6] : ver_2[0];
assign iter2_loser[6] = (iter1_loser[6] >= ver_2[0])? ver_2[0] : iter1_loser[6];

assign max_wire = ver_0[0];
assign med_wire = (iter1_winner[6] >= iter2_winner[6])? iter2_winner[6] : iter1_winner[6];
assign min_wire = ver_2[2];

endmodule

module GRAYCODE2BINARY(
	gray, bin
);

input signed [8:0] gray;
output signed [8:0] bin;
wire [7:0] w;
wire [7:0] w_neg;
wire zeroFlag;
// assign w[8] = gray[8];
assign w[7] = gray[7];
assign w[6] = gray[6] ^ w[7];
assign w[5] = gray[5] ^ w[6];
assign w[4] = gray[4] ^ w[5];
assign w[3] = gray[3] ^ w[4];
assign w[2] = gray[2] ^ w[3];
assign w[1] = gray[1] ^ w[2];
assign w[0] = gray[0] ^ w[1];
assign zeroFlag = |w;
assign bin = (zeroFlag)? ((gray[8])? {1'b1, (~w[7:0]) + 1'b1} : w) : 9'b0;

endmodule
