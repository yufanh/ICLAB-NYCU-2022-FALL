//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : UT_TOP.v
//   Module Name : UT_TOP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

//synopsys translate_off
`include "B2BCD_IP.v"
//synopsys translate_on

module UT_TOP (
    // Input signals
    clk, rst_n, in_valid, in_time,
    // Output signals
    out_valid, out_display, out_day
);

// ===============================================================
// Input & Output Declaration
// ===============================================================
input clk, rst_n, in_valid;
input [30:0] in_time;
output reg out_valid;
output reg [3:0] out_display;
output reg [2:0] out_day;
// ===============================================================
// Parameter & Integer Declaration
// ===============================================================

/* FSM */
reg [3:0] c_state, n_state;
parameter ST_IDLE = 'd0,
	  	  ST_INPUT = 'd1,
	  	  ST_RUN = 'd2,
	  	  //ST_RUN_Y2 = 'd2,
	  	  ST_OUT = 'd3;

//================================================================
// Wire & Reg Declaration
//================================================================
reg [3:0] out_counter;
reg [2:0] run_counter;
reg [30:0] in_binary_time;

wire [24:0] sub1_in_b;

reg [27:0] sub4_in_a;
wire [27:0] sub64_out;
wire [30:0] sub64_in_a, sub32_in_a;
wire [29:0] sub32_out;
wire [28:0] sub16_out;
wire [27:0] sub8_out;
wire [26:0] sub4_out;
wire [25:0] sub2_out;
wire [24:0] sub1_out;
wire [6:0] sub_y_op;

wire larger64y;
reg [6:0] op_y;

wire [2:0] week_day_y[6:0];
wire [5:0] week_day_y_sum0;
wire [4:0] week_day_y_sum1;
wire [3:0] week_day_y_sum2;
wire [2:0] week_day_y_sum3;

wire [11:0] sub_w_op;

wire [30:0] sub_w_out11;
wire [29:0] sub_w_out10;
wire [28:0] sub_w_out9;
wire [27:0] sub_w_out8;
wire [26:0] sub_w_out7;
reg [26:0] sub_w_pip1;

wire [25:0] sub_w_out6;
wire [24:0] sub_w_out5;
wire [23:0] sub_w_out4;
wire [22:0] sub_w_out3;
wire [21:0] sub_w_out2;
reg [21:0] sub_w_pip2;

wire [20:0] sub_w_out1;
wire [19:0] sub_w_out0;
wire [18:0] sub_wd_out2;
wire [17:0] sub_wd_out1;
wire [16:0] sub_wd_out0;
wire [2:0] sub_wd_op;

reg[24:0] month_in;
wire[24:0] month_in2;
wire [24:0] subm_out[10:0];
reg [21:0] feb;
wire largerJUL;
reg [24:0] MAR_out, JUL_out;
reg MAR_op_en, JUL_op_en;
wire [10:0] sub_m_op;


reg [21:0] day_in;
wire [20:0] sub_d_out[4:0];
wire [4:0] sub_d_op;

reg [16:0] hour_in;
wire [16:0] sub_h_out[4:0];
wire [4:0] sub_h_op;

reg [11:0] minute_in;
wire [11:0] sub_min_out[5:0];
wire [5:0] sub_min_op;

wire [2:0] display_week;
reg [5:0] display_second;
reg [3:0] display_month;
reg [10:0] display_year;
reg [4:0] display_day;
reg [4:0] display_hour;
reg [5:0] display_minute;

wire [15:0] bcd_year;
wire [7:0] bcd_month;
wire [7:0] bcd_day;
wire [7:0] bcd_hour;
wire [7:0] bcd_minute;
wire [7:0] bcd_second;

//================================================================
// DESIGN
//================================================================

/* DESIGN_FSM */

always @(posedge clk or negedge rst_n)begin
	if(!rst_n) c_state <= ST_IDLE;
	else c_state <= n_state;
end

always @(*) begin
	case(c_state)
	ST_IDLE: begin
		if(in_valid) n_state = ST_INPUT;
		else n_state = ST_IDLE;
	end
	ST_INPUT: begin
		n_state = ST_RUN;
	end
	ST_RUN: begin
		if(run_counter == 3'd2) n_state = ST_OUT;
		else n_state = ST_RUN;
	end
	ST_OUT: begin
		if(out_counter == 4'd14) n_state = ST_IDLE;
		else n_state = ST_OUT;
		// n_state = ST_OUT;
	end
	default: n_state = ST_IDLE;
	
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_counter <= 4'b0;
	else begin
		case(n_state)
		//ST_IDLE: out_counter <= 4'b0;
		ST_OUT: out_counter <= out_counter + 1'b1;
		default: out_counter <= 4'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) run_counter <= 3'b0;
	else begin
		case(n_state)
		//ST_IDLE: run_counter <= 3'b0;
		ST_RUN: run_counter <= run_counter + 1'b1;
		default: run_counter <= 3'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) in_binary_time <= 31'b0;
	else begin
		case(n_state)
		ST_IDLE: in_binary_time <= 31'b0;
		ST_INPUT: in_binary_time <= in_time;
		default: in_binary_time <= in_binary_time;
		endcase
	end
end

assign larger64y = (in_binary_time >= 31'h7861_F800) ? 1'b1 : 1'b0; //input >= 64y(2034)?

assign sub64_in_a = (larger64y)? in_binary_time : 31'b0;
assign sub32_in_a = (larger64y)? 31'b0 : in_binary_time;
SUB_IP #(31, 31, 28) Usub64(.in_a(sub64_in_a), .in_b(31'h7861_F800), .out(sub64_out), .op(sub_y_op[6]));
SUB_IP #(31, 30, 30) Usub32(.in_a(sub32_in_a), .in_b(30'h3C30_FC00), .out(sub32_out), .op(sub_y_op[5]));
SUB_IP #(30, 29, 29) Usub16(.in_a(sub32_out), .in_b(29'h1E18_7E00), .out(sub16_out), .op(sub_y_op[4]));
SUB_IP #(29, 28, 28) Usub8(.in_a(sub16_out), .in_b(28'hF0C_3F00), .out(sub8_out), .op(sub_y_op[3]));

SUB_IP #(28, 27, 27) Usub4(.in_a(sub4_in_a), .in_b(27'h786_1F80), .out(sub4_out), .op(sub_y_op[2]));
SUB_IP #(27, 26, 26) Usub2(.in_a(sub4_out), .in_b(26'h3C2_6700), .out(sub2_out), .op(sub_y_op[1]));
assign sub1_in_b = (sub_y_op[1])? ((sub2_out >=  25'h1E2_8500)? 25'h1E1_3380 : 25'h1E2_8500) : 25'h1E1_3380;
SUB_IP #(26, 25, 25) Usub1(.in_a(sub2_out), .in_b(sub1_in_b), .out(sub1_out), .op(sub_y_op[0]));


SUB_IP #(31, 31, 31) Usub_w2048(.in_a(in_binary_time), .in_b(31'h49D4_0000), .out(sub_w_out11), .op(sub_w_op[11])); // 2048week
SUB_IP #(31, 30, 30) Usub_w1024(.in_a(sub_w_out11), .in_b(30'h24EA_0000), .out(sub_w_out10), .op(sub_w_op[10])); // 1024week
SUB_IP #(30, 29, 29) Usub_w512(.in_a(sub_w_out10), .in_b(29'h1275_0000), .out(sub_w_out9), .op(sub_w_op[9])); // 512week
SUB_IP #(29, 28, 28) Usub_w256(.in_a(sub_w_out9), .in_b(28'h93A_8000), .out(sub_w_out8), .op(sub_w_op[8])); // 256week
SUB_IP #(28, 27, 27) Usub_w128(.in_a(sub_w_out8), .in_b(27'h49D_4000), .out(sub_w_out7), .op(sub_w_op[7])); // 128week
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sub_w_pip1 <= 27'b0;
	else begin
		case(n_state)
		ST_IDLE: sub_w_pip1 <= 27'b0;
		ST_RUN: begin
			sub_w_pip1 <= sub_w_out7;
		end
		ST_OUT: sub_w_pip1 <= sub_w_out7;
		default: sub_w_pip1 <= sub_w_pip1;
		endcase
	end
end
SUB_IP #(27, 26, 26) Usub_w64(.in_a(sub_w_pip1), .in_b(26'h24E_A000), .out(sub_w_out6), .op(sub_w_op[6])); // 64week
SUB_IP #(26, 25, 25) Usub_w32(.in_a(sub_w_out6), .in_b(25'h127_5000), .out(sub_w_out5), .op(sub_w_op[5])); // 32week
SUB_IP #(25, 24, 24) Usub_w16(.in_a(sub_w_out5), .in_b(24'h93_A800), .out(sub_w_out4), .op(sub_w_op[4])); // 16week
SUB_IP #(24, 23, 23) Usub_w8(.in_a(sub_w_out4), .in_b(23'h49_D400), .out(sub_w_out3), .op(sub_w_op[3])); // 8week
SUB_IP #(23, 22, 22) Usub_w4(.in_a(sub_w_out3), .in_b(22'h24_EA00), .out(sub_w_out2), .op(sub_w_op[2])); // 4week
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sub_w_pip2 <= 22'b0;
	else begin
		case(n_state)
		ST_IDLE: sub_w_pip2 <= 22'b0;
		ST_RUN: begin
			sub_w_pip2 <= sub_w_out2;
		end
		ST_OUT: sub_w_pip2 <= sub_w_out2;
		default: sub_w_pip2 <= sub_w_pip2;
		endcase
	end
end
SUB_IP #(22, 21, 21) Usub_w2(.in_a(sub_w_pip2), .in_b(21'h12_7500), .out(sub_w_out1), .op(sub_w_op[1])); // 2week
SUB_IP #(21, 20, 20) Usub_w1(.in_a(sub_w_out1), .in_b(20'h9_3A80), .out(sub_w_out0), .op(sub_w_op[0])); // 1week
SUB_IP #(20, 19, 19) Usub_wd4(.in_a(sub_w_out0), .in_b(19'h5_4600), .out(sub_wd_out2), .op(sub_wd_op[2])); // 4
SUB_IP #(19, 18, 18) Usub_wd2(.in_a(sub_wd_out2), .in_b(18'h2_A300), .out(sub_wd_out1), .op(sub_wd_op[1])); // 2
SUB_IP #(18, 17, 17) Usub_wd1(.in_a(sub_wd_out1), .in_b(17'h1_5180), .out(sub_wd_out0), .op(sub_wd_op[0])); // 1
assign display_week = (sub_wd_op >= 2'd3)? (sub_wd_op - 2'd3): (sub_wd_op + 3'd4);
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sub4_in_a <= 28'b0;
	else begin
		case(n_state)
		ST_IDLE: sub4_in_a <= 1'b0;
		ST_RUN: begin
			if(larger64y) sub4_in_a <= sub64_out;
			else sub4_in_a <= sub8_out;
		end
		ST_OUT: begin
			if(larger64y) sub4_in_a <= sub64_out;
			else sub4_in_a <= sub8_out;
		end
		default: sub4_in_a <= sub4_in_a;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) op_y <= 7'b0;
	else begin
		case(n_state)
		ST_IDLE: op_y <= 1'b1;
		ST_RUN: op_y <= sub_y_op[6:0];
		ST_OUT: op_y <= sub_y_op[6:0];
		default: op_y <= op_y;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) month_in <= 25'b0;
	else begin
		case(n_state)
		ST_IDLE: month_in <= 1'b0;
		ST_RUN: begin
			month_in <= sub1_out;
		end
		ST_OUT: month_in <= sub1_out;
		default: month_in <= month_in;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_year <= 11'b0;
	else begin
		case(n_state)
		ST_IDLE: display_year <= 1'b0;
		ST_RUN: begin
			display_year <= 11'd1970 + sub_y_op;
		end
		ST_OUT: display_year <= 11'd1970 + sub_y_op;
		default: display_year <= display_year;
		endcase
	end
end
always @(*) begin
	if(op_y[0] == 1'b0 && op_y[1] == 1'b1) feb = 22'h26_3B80;
	else feb = 22'h24_EA00;
end
assign month_in2 = (op_y[1] && op_y[0])? (month_in - 20'h1_5180) : month_in;


SUB_IP #(25, 22, 25) Usubm1(.in_a(month_in2), .in_b(22'h28_DE80), .out(subm_out[0]), .op(sub_m_op[0])); // JQN
SUB_LOCK_IP #(25, 22, 25) Usubm2(.in_a(subm_out[0]), .in_b(feb), .en(sub_m_op[0]),.out(subm_out[1]), .op(sub_m_op[1])); // FEB
SUB_LOCK_IP #(25, 22, 25) Usubm3(.in_a(subm_out[1]), .in_b(22'h28_DE80), .en(sub_m_op[1]), .out(subm_out[2]), .op(sub_m_op[2])); // MAR

SUB_LOCK_IP #(25, 22, 25) Usubm4(.in_a(MAR_out), .in_b(22'h27_8D00), .en(MAR_op_en), .out(subm_out[3]), .op(sub_m_op[3])); // APR 
SUB_LOCK_IP #(25, 22, 25) Usubm5(.in_a(subm_out[3]), .in_b(22'h28_DE80), .en(sub_m_op[3]), .out(subm_out[4]), .op(sub_m_op[4])); // MAY
SUB_LOCK_IP #(25, 22, 25) Usubm6(.in_a(subm_out[4]), .in_b(22'h27_8D00), .en(sub_m_op[4]), .out(subm_out[5]), .op(sub_m_op[5])); // JUN
SUB_LOCK_IP #(25, 22, 25) Usubm7(.in_a(subm_out[5]), .in_b(22'h28_DE80), .en(sub_m_op[5]), .out(subm_out[6]), .op(sub_m_op[6])); // JUL

SUB_LOCK_IP #(25, 22, 25) Usubm8(.in_a(JUL_out), .in_b(22'h28_DE80), .en(JUL_op_en), .out(subm_out[7]), .op(sub_m_op[7])); // AUG
SUB_LOCK_IP #(25, 22, 25) Usubm9(.in_a(subm_out[7]), .in_b(22'h27_8D00), .en(sub_m_op[7]), .out(subm_out[8]), .op(sub_m_op[8])); // SEP
SUB_LOCK_IP #(25, 22, 25) Usubm10(.in_a(subm_out[8]), .in_b(22'h28_DE80), .en(sub_m_op[8]), .out(subm_out[9]), .op(sub_m_op[9])); // OCT
SUB_LOCK_IP #(25, 22, 25) Usubm11(.in_a(subm_out[9]), .in_b(22'h27_8D00), .en(sub_m_op[9]), .out(subm_out[10]), .op(sub_m_op[10])); // NOV

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) MAR_out <= 25'b0;
	else begin
		case(n_state)
		ST_IDLE: MAR_out <= 1'b0;
		ST_RUN: begin
			MAR_out <= subm_out[2];
		end
		ST_OUT: MAR_out <= subm_out[2];
		default: MAR_out <= MAR_out;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) MAR_op_en <= 1'b0;
	else begin
		case(n_state)
		ST_IDLE: MAR_op_en <= 1'b0;
		ST_RUN: begin
			MAR_op_en <= sub_m_op[2];
		end
		ST_OUT: MAR_op_en <= sub_m_op[2];
		default: MAR_op_en <= MAR_op_en;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) JUL_out <= 25'b0;
	else begin
		case(n_state)
		ST_IDLE: JUL_out <= 1'b0;
		ST_RUN: begin
			JUL_out <= subm_out[6];
		end
		ST_OUT: JUL_out <= subm_out[6];
		default: JUL_out <= JUL_out;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) JUL_op_en <= 1'b0;
	else begin
		case(n_state)
		ST_IDLE: JUL_op_en <= 1'b0;
		ST_RUN: begin
			JUL_op_en <= sub_m_op[6];
		end
		ST_OUT: JUL_op_en <= sub_m_op[6];
		default: JUL_op_en <= JUL_op_en;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_month <= 4'b0;
	else begin
		case(n_state)
		ST_IDLE: display_month <= 4'b0;
		ST_RUN: begin
			display_month <= sub_m_op[0] + sub_m_op[1] + sub_m_op[2]
			 + sub_m_op[3] + sub_m_op[4] + sub_m_op[5] +sub_m_op[6] 
			 + sub_m_op[7] + sub_m_op[8] + sub_m_op[9] + sub_m_op[10] + 1'b1;
		end
		ST_OUT: begin
			display_month <= sub_m_op[0] + sub_m_op[1] + sub_m_op[2]
			 + sub_m_op[3] + sub_m_op[4] + sub_m_op[5] +sub_m_op[6] 
			 + sub_m_op[7] + sub_m_op[8] + sub_m_op[9] + sub_m_op[10] + 1'b1;
		end
		default: display_month <= display_month;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) day_in <= 22'b0;
	else begin
		case(n_state)
		ST_IDLE: day_in <= 22'b0;
		ST_RUN: begin
			day_in <= subm_out[10][21:0];
		end
		ST_OUT: begin
			day_in <= subm_out[10][21:0];
		end
		default: day_in <= day_in;
		endcase
	end
end
SUB_IP #(22, 21, 21) Usub_d16(.in_a(day_in), .in_b(21'h15_1800), .out(sub_d_out[4]), .op(sub_d_op[4])); // 16
SUB_IP #(21, 20, 21) Usub_d8(.in_a(sub_d_out[4]), .in_b(20'hA_8C00), .out(sub_d_out[3]), .op(sub_d_op[3])); // 8
SUB_IP #(21, 20, 21) Usub_d4(.in_a(sub_d_out[3]), .in_b(20'h5_4600), .out(sub_d_out[2]), .op(sub_d_op[2])); // 4
SUB_IP #(21, 20, 21) Usub_d2(.in_a(sub_d_out[2]), .in_b(20'h2_A300), .out(sub_d_out[1]), .op(sub_d_op[1])); // 2
SUB_IP #(21, 20, 21) Usub_d1(.in_a(sub_d_out[1]), .in_b(20'h1_5180), .out(sub_d_out[0]), .op(sub_d_op[0])); // 1
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_day <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: display_day <= 5'b0;
		ST_RUN: begin
			display_day <= sub_d_op + 1'b1;
		end
		ST_OUT: display_day <= sub_d_op + 1'b1;
		default: display_day <= display_day;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) hour_in <= 17'b0;
	else begin
		case(n_state)
		ST_IDLE: hour_in <= 17'b0;
		ST_RUN: begin
			hour_in <= sub_d_out[0][16:0];
		end
		ST_OUT: hour_in <= sub_d_out[0][16:0];
		default: hour_in <= hour_in;
		endcase
	end
end

SUB_IP #(17, 16, 17) Usub_h12(.in_a(hour_in), .in_b(16'hE100), .out(sub_h_out[4]), .op(sub_h_op[4])); // 16
SUB_IP #(17, 16, 17) Usub_h8(.in_a(sub_h_out[4]), .in_b(16'h7080), .out(sub_h_out[3]), .op(sub_h_op[3])); // 8
SUB_IP #(17, 16, 17) Usub_h4(.in_a(sub_h_out[3]), .in_b(16'h3840), .out(sub_h_out[2]), .op(sub_h_op[2])); // 4
SUB_IP #(17, 16, 17) Usub_h2(.in_a(sub_h_out[2]), .in_b(16'h1C20), .out(sub_h_out[1]), .op(sub_h_op[1])); // 2
SUB_IP #(17, 12, 17) Usub_h1(.in_a(sub_h_out[1]), .in_b(12'hE10), .out(sub_h_out[0]), .op(sub_h_op[0])); // 1
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_hour <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: display_hour <= 5'b0;
		ST_RUN: begin
			display_hour <= sub_h_op;
		end
		ST_OUT: display_hour <= sub_h_op;
		default: display_hour <= display_hour;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) minute_in <= 12'b0;
	else begin
		case(n_state)
		ST_IDLE: minute_in <= 12'b0;
		ST_RUN: begin
			minute_in <= sub_h_out[0][11:0];
		end
		ST_OUT: minute_in <= sub_h_out[0][11:0];
		default: minute_in <= minute_in;
		endcase
	end
end

SUB_IP #(12, 12, 12) Usub_min32(.in_a(minute_in), .in_b(12'h780), .out(sub_min_out[5]), .op(sub_min_op[5])); // 32
SUB_IP #(12, 12, 12) Usub_min16(.in_a(sub_min_out[5]), .in_b(12'h3C0), .out(sub_min_out[4]), .op(sub_min_op[4])); // 16
SUB_IP #(12, 12, 12) Usub_mib8(.in_a(sub_min_out[4]), .in_b(12'h1E0), .out(sub_min_out[3]), .op(sub_min_op[3])); // 8
SUB_IP #(12, 8, 12) Usub_min4(.in_a(sub_min_out[3]), .in_b(8'hF0), .out(sub_min_out[2]), .op(sub_min_op[2])); // 4
SUB_IP #(12, 8, 12) Usub_min2(.in_a(sub_min_out[2]), .in_b(8'h78), .out(sub_min_out[1]), .op(sub_min_op[1])); // 2
SUB_IP #(12, 8, 12) Usub_min1(.in_a(sub_min_out[1]), .in_b(8'h3C), .out(sub_min_out[0]), .op(sub_min_op[0])); // 1
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_minute <= 6'b0;
	else begin
		case(n_state)
		ST_IDLE: display_minute <= 6'b0;
		ST_RUN: begin
			display_minute <= sub_min_op;
		end
		ST_OUT: display_minute <= sub_min_op;
		default: display_minute <= display_minute;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) display_second <= 6'b0;
	else begin
		case(n_state)
		ST_IDLE: display_second <= 6'b0;
		ST_RUN: begin
			display_second <= sub_min_out[0][5:0];
		end
		ST_OUT: display_second <= sub_min_out[0][5:0];
		default: display_second <= display_second;
		endcase
	end
end


B2BCD_IP #(11, 4) Ubcd_year(.Binary_code(display_year),.BCD_code(bcd_year));
B2BCD_IP #(4, 2) Ubcd_month(.Binary_code(display_month),.BCD_code(bcd_month));
B2BCD_IP #(5, 2) Ubcd_day(.Binary_code(display_day),.BCD_code(bcd_day));
B2BCD_IP #(5, 2) Ubcd_hour(.Binary_code(display_hour),.BCD_code(bcd_hour));
B2BCD_IP #(6, 2) Ubcd_minute(.Binary_code(display_minute),.BCD_code(bcd_minute));
B2BCD_IP #(6, 2) Ubcd_second(.Binary_code(display_second),.BCD_code(bcd_second));

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'b0;
	else begin
		case(n_state)
		ST_OUT: out_valid <= 1'b1;
		default: out_valid <= 1'b0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_display <= 4'b0;
	else begin
		case(n_state)
		ST_OUT: begin
			case (out_counter)
				4'd0: out_display <= bcd_year[15:12];
				4'd1: out_display <= bcd_year[11:8];
				4'd2: out_display <= bcd_year[7:4];
				4'd3: out_display <= bcd_year[3:0];
				4'd4: out_display <= bcd_month[7:4];
				4'd5: out_display <= bcd_month[3:0];
				4'd6: out_display <= bcd_day[7:4];
				4'd7: out_display <= bcd_day[3:0];
				4'd8: out_display <= bcd_hour[7:4];
				4'd9: out_display <= bcd_hour[3:0];
				4'd10: out_display <= bcd_minute[7:4];
				4'd11: out_display <= bcd_minute[3:0];
				4'd12: out_display <= bcd_second[7:4];
				4'd13: out_display <= bcd_second[3:0];
				default: out_display <= 1'b0;
			endcase
		end
		default: out_display <= 4'b0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_day <= 3'b0;
	else begin
		case(n_state)
		ST_OUT: out_day <= display_week;
		default: out_day <= 3'b0;
		endcase
	end
end

endmodule

module SUB_IP #(parameter WIDTH_IN_A = 4, parameter WIDTH_IN_B = 4, parameter WIDTH_OUT = 4) (
    // Input signals
    in_a,
	in_b,
    // Output signals
    out,
	op
);
	input [WIDTH_IN_A-1:0] in_a;
	input [WIDTH_IN_B-1:0] in_b;
	output reg [WIDTH_OUT-1:0] out;
	output reg op;

	generate
		always @(*) begin: SUB
			if(in_a >= in_b) out = in_a - in_b;
			else out = in_a;
		end
		always @(*) begin: OP
			if(in_a >= in_b) op = 1'b1;
			else op = 1'b0;
		end
	endgenerate

endmodule
module SUB_LOCK_IP #(parameter WIDTH_IN_A = 4, parameter WIDTH_IN_B = 4, parameter WIDTH_OUT = 4) (
    // Input signals
    in_a,
	in_b,
	en,
    // Output signals
    out,
	op
);
	input [WIDTH_IN_A-1:0] in_a;
	input [WIDTH_IN_B-1:0] in_b;
	input en;
	output reg [WIDTH_OUT-1:0] out;
	output reg op;

	generate
		always @(*) begin: SUB_L
			if((in_a >= in_b) && en) out = in_a - in_b;
			else out = in_a;
		end
		always @(*) begin: OP_L
			if((in_a >= in_b) && en) op = 1'b1;
			else op = 1'b0;
		end
	endgenerate

endmodule
