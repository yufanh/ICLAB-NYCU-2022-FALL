`include "synchronizer.v"
`include "syn_XOR.v"
module CDC(
	//Input Port
	clk1,
    clk2,
    clk3,
	rst_n,
	in_valid1,
	in_valid2,
	user1,
	user2,

    //Output Port
    out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
); 
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input 		clk1, clk2, clk3, rst_n;
input 		in_valid1, in_valid2;
input [3:0]	user1, user2;

output wire	out_valid1, out_valid2;
output wire	equal, exceed, winner;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
//----clk1----
wire [3:0] clk1_out_card;
wire clk1_out_card_valid;
//----clk2----

//----clk3----
wire clk3_in_card_valid;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
//----clk1----

//----clk2----

//----clk3----

//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------

CLK1_IN U_clk1(
	/* input */
	.clk(clk1),
	.rst_n(rst_n),
	.in_valid1(in_valid1),
	.in_valid2(in_valid2),
	.user1(user1),
	.user2(user2),
	/* output */
	.card(clk1_out_card),
	.card_valid(clk1_out_card_valid)
);
CLK3_OUT U_clk3(
	/* input */
	.clk(clk3),
	.rst_n(rst_n),
	.clk1_in_valid(clk3_in_card_valid),
	.clk1_in(clk1_out_card),
	/* output */
	.out_valid1(out_valid1),
    .out_valid2(out_valid2),
	.equal(equal),
	.exceed(exceed),
	.winner(winner)
);
//---------------------------------------------------------------------
//   syn_XOR
//---------------------------------------------------------------------
syn_XOR u_syn_XOR(.IN(clk1_out_card_valid),.OUT(clk3_in_card_valid),.TX_CLK(clk1),.RX_CLK(clk3),.RST_N(rst_n));

endmodule



module CLK1_IN (
	/* input */
	clk, rst_n, in_valid1, in_valid2, user1, user2,
	/* output */
	card, card_valid,
);
input 		clk, rst_n;
input 		in_valid1, in_valid2;
input [3:0]	user1, user2;

output reg [3:0] card;
output wire card_valid;

reg [3:0] card_delay1;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) card <= 4'b0;
	else if(in_valid1) card <= user1;
	else if(in_valid2) card <= user2;
	else card <= 4'b0;
end

assign card_valid = (in_valid1 || in_valid2)? 1'b1 : 1'b0;

endmodule

module CLK3_OUT (
	/* input */
	clk,
	rst_n,
	clk1_in_valid,
	clk1_in,
	/* output */
	out_valid1,
    out_valid2,
	equal,
	exceed,
	winner
);
input clk, rst_n, clk1_in_valid;
input [3:0] clk1_in;
output reg	out_valid1, out_valid2;
output reg	equal, exceed, winner;

/* FSM reg & parameter*/
reg [4:0] c_state, n_state;
parameter ST_IDLE = 'd0,
		  ST_IN_US1 = 'd1,
		  ST_IN_US2 = 'd2,
		  ST_PRE_US1 = 'd3,
		  ST_PRE_US2 = 'd4,
		  ST_OUT = 'd5,
		  ST_WAIT = 'd6,
		  ST_READY_1 = 'd7,
		  ST_NO_WINNER = 'd8,
		  ST_WINNER_1 = 'd9,
		  ST_WINNER_2 = 'd10,
		  ST_READY_2 = 'd11;
/* reg & wire */
reg [3:0] counter;
reg [3:0] out_cnt;
reg [5:0] point_us1, point_us2;
wire[3:0] clk1_in_filter;
reg [5:0] sum_table_1;
reg [5:0] sum_table_2;
reg [5:0] sum_table_3;
reg [4:0] sum_table_4;
reg [4:0] sum_table_5;
reg [4:0] sum_table_6;
reg [4:0] sum_table_7;
reg [3:0] sum_table_8;
reg [3:0] sum_table_9;
reg [2:0] sum_table_10;
reg [5:0] rst_cnt;
// calculate
reg [4:0] eq_dividen_filter;
reg [5:0] eq_dividen_prob;
reg [12:0] eq_dividen;
reg [11:0] divider;
wire eq_div_op;

reg [4:0] ex_dividen_filter;
reg [5:0] ex_dividen_prob;
reg [12:0] ex_dividen;
wire ex_div_op;

reg [1:0] winner_check;
genvar i;

/* FSM */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= ST_IDLE;
	else c_state <= n_state;
end
always @(*) begin
	case (c_state)
		ST_IDLE: begin
			if(clk1_in_valid) n_state = ST_IN_US1;
			else n_state = ST_IDLE;
		end
		ST_IN_US1: begin
			if(counter == 4'd3 || counter == 4'd4) n_state = ST_PRE_US1;
			else n_state = ST_WAIT;
		end
		ST_IN_US2: begin
			if(counter == 4'd8 || counter == 4'd9) n_state = ST_PRE_US2;
			else if(counter == 4'd10)begin
				if(winner_check == 2'd0 )n_state = ST_NO_WINNER;
				else n_state = ST_WINNER_1;
			end
			else n_state = ST_WAIT;
		end
		ST_PRE_US1: begin
			n_state = ST_READY_1;
		end
		ST_PRE_US2: begin
			n_state = ST_READY_1;
		end
		ST_READY_1: n_state = ST_READY_2;
		ST_READY_2: n_state = ST_OUT;
		ST_OUT: begin
			if(out_cnt == 3'd7) n_state = ST_WAIT;
			else n_state = ST_OUT;
		end
		ST_WAIT: begin
			if(clk1_in_valid) begin
				if(counter >= 4'd5 && counter < 4'd10)  n_state = ST_IN_US2;
				else n_state = ST_IN_US1;
			end
			else n_state = ST_WAIT;
		end
		ST_NO_WINNER: n_state = ST_WAIT;
		ST_WINNER_1: n_state = ST_WINNER_2;
		ST_WINNER_2: n_state = ST_WAIT;
		default: n_state = ST_IDLE;
	endcase
end


/* design */
assign clk1_in_filter = (clk1_in > 10)? 4'd1 : clk1_in;

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) counter <= 4'd0;
	else if(clk1_in_valid) begin
		if(counter == 4'd10) counter <= 4'd1;
		else counter <= counter + 1'd1;
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_cnt <= 3'd0;
	else begin
		case (n_state)
			ST_OUT: out_cnt <= out_cnt + 1'd1; 
			default: out_cnt <= 1'd0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) point_us1 <= 6'd0;
	else begin
		case (n_state)
			ST_IDLE: point_us1 <= 6'b0;
			ST_IN_US1: begin
				if(counter == 4'd0 || counter == 4'd10) point_us1 <= clk1_in_filter;
				else point_us1 <= point_us1 + clk1_in_filter;
			end
			default: point_us1 <= point_us1;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) point_us2 <= 6'd0;
	else begin
		case (n_state)
			ST_IDLE: point_us2 <= 6'b0;
			ST_IN_US2: begin
				if(counter == 4'd5) point_us2 <= clk1_in_filter;
				else point_us2 <= point_us2 + clk1_in_filter;
			end
			default: point_us2 <= point_us2;
		endcase
	end
end


// winner

always @(*) begin
	if(point_us1 <= 6'd21 && point_us2 <= 6'd21) begin
		if(point_us1 > point_us2) winner_check = 2'b10;
		else if(point_us2 > point_us1) winner_check = 2'b11;
		else winner_check = 2'b00;
	end
	else if(point_us1 <= 6'd21 && point_us2 > 6'd21) begin
		winner_check = 2'b10;
	end
	else if(point_us1 > 6'd21 && point_us2 <= 6'd21) begin
		winner_check = 2'b11;
	end
	else winner_check = 2'b0;
end


/* output */

always @(*) begin
	case (c_state)
		ST_PRE_US1: begin
			if(point_us1 <= 5'd10 || point_us1 >= 5'd21) eq_dividen_filter = 5'b0;
			else eq_dividen_filter = 5'd21 - point_us1;
		end
		ST_PRE_US2: begin
			if(point_us2 <= 5'd10 || point_us2 >= 5'd21) eq_dividen_filter = 5'b0;
			else eq_dividen_filter = 5'd21 - point_us2;
		end
		default: eq_dividen_filter = 5'b0;
	endcase

end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) eq_dividen_prob <= 5'b0;
	else begin
		case (eq_dividen_filter)
			5'd1: eq_dividen_prob <= sum_table_1 - sum_table_2;
			5'd2: eq_dividen_prob <= sum_table_2 - sum_table_3;
			5'd3: eq_dividen_prob <= sum_table_3 - sum_table_4;
			5'd4: eq_dividen_prob <= sum_table_4 - sum_table_5;
			5'd5: eq_dividen_prob <= sum_table_5 - sum_table_6;
			5'd6: eq_dividen_prob <= sum_table_6 - sum_table_7;
			5'd7: eq_dividen_prob <= sum_table_7 - sum_table_8;
			5'd8: eq_dividen_prob <= sum_table_8 - sum_table_9;
			5'd9: eq_dividen_prob <= sum_table_9 - sum_table_10;
			5'd10: eq_dividen_prob <= sum_table_10;
			default: eq_dividen_prob <= 5'b0;
		endcase
	end
	
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) eq_dividen <= 13'b0;
	else begin
		case (n_state)
			// ST_PRE_US1: eq_dividen <= eq_dividen_prob * 7'd100;
			// ST_PRE_US2: eq_dividen <= eq_dividen_prob * 7'd100;
			ST_READY_2: eq_dividen <= eq_dividen_prob * 7'd100;
			ST_OUT: begin
				if(eq_dividen >= divider) eq_dividen <= eq_dividen - divider;
				else eq_dividen <= eq_dividen;
			end
			default: eq_dividen <= 13'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) divider <= 12'b0;
	else begin
		case (n_state)
			// ST_PRE_US1: divider <= {sum_table_1, 6'b0};
			// ST_PRE_US2: divider <= {sum_table_1, 6'b0};
			ST_READY_2: divider <= {sum_table_1, 6'b0};
			ST_OUT: divider <= divider >> 1;
			default: divider <= 12'b0;
		endcase
	end
end

assign eq_div_op = (eq_dividen >= divider)? 1'b1 : 1'b0;




// ex
always @(*) begin
	case (c_state)
		ST_PRE_US1: begin
			if(point_us1 <= 5'd11) ex_dividen_filter = 5'b0;
			else if( point_us1 >= 5'd21) ex_dividen_filter = 5'd10;
			else ex_dividen_filter = 5'd21 - point_us1;
		end
		ST_PRE_US2: begin
			if(point_us2 <= 5'd11) ex_dividen_filter = 5'b0;
			else if( point_us2 >= 5'd21) ex_dividen_filter = 5'd10;
			else ex_dividen_filter = 5'd21 - point_us2;
		end
		default: ex_dividen_filter = 5'b0;
	endcase
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ex_dividen_prob <= 5'b0;
	else begin
		case (ex_dividen_filter)
			5'd1: ex_dividen_prob <= sum_table_2;
			5'd2: ex_dividen_prob <= sum_table_3;
			5'd3: ex_dividen_prob <= sum_table_4;
			5'd4: ex_dividen_prob <= sum_table_5;
			5'd5: ex_dividen_prob <= sum_table_6;
			5'd6: ex_dividen_prob <= sum_table_7;
			5'd7: ex_dividen_prob <= sum_table_8;
			5'd8: ex_dividen_prob <= sum_table_9;
			5'd9: ex_dividen_prob <= sum_table_10;
			5'd10: ex_dividen_prob <= sum_table_1;
			default: ex_dividen_prob <= 5'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ex_dividen <= 13'b0;
	else begin
		case (n_state)
			ST_READY_2: ex_dividen <= ex_dividen_prob * 7'd100;
			ST_OUT: begin
				if(ex_dividen >= divider) ex_dividen <= ex_dividen - divider;
				else ex_dividen <= ex_dividen;
			end
			default: ex_dividen <= 13'b0;
		endcase
	end
end
assign ex_div_op = (ex_dividen >= divider)? 1'b1 : 1'b0;


always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid1 <= 1'b0;
	else begin
		case (n_state)
			ST_OUT: out_valid1 <= 1'b1;
			default: out_valid1 <= 1'b0;
		endcase
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) equal <= 1'b0;
	else begin
		case (n_state)
			ST_OUT: equal <= eq_div_op;
			default: equal <= 1'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) exceed <= 1'b0;
	else begin
		case (n_state)
			ST_OUT: exceed <= ex_div_op;
			default: exceed <= 1'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid2 <= 1'b0;
	else begin
		case (n_state)
			ST_NO_WINNER: out_valid2 <= 1'b1;
			ST_WINNER_1: out_valid2 <= 1'b1;
			ST_WINNER_2: out_valid2 <= 1'b1;
			default: out_valid2 <= 1'b0;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) winner <= 1'b0;
	else begin
		case (n_state)
			ST_WINNER_1: winner <= winner_check[1];
			ST_WINNER_2: winner <= winner_check[0];
			default: winner <= 1'b0;
		endcase
	end
end







// table
	always @(posedge clk or negedge rst_n) begin
	if(!rst_n) rst_cnt <= 6'd0;
	else begin
		if(clk1_in_valid) begin
			if(rst_cnt == 6'd50) rst_cnt <= 1'b1;
			else rst_cnt <= rst_cnt + 1'b1;
		end
		else rst_cnt <= rst_cnt;
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_1 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_1 <= 6'd52;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_1 <= 6'd52;
				else sum_table_1 <= sum_table_1;
			end
			ST_IN_US1: begin
				sum_table_1 <= sum_table_1 - 1'b1;
			end
			ST_IN_US2: begin
				sum_table_1 <= sum_table_1 - 1'b1;
			end
			default: sum_table_1 <= sum_table_1;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_2 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_2 <= 6'd36;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_2 <= 6'd36;
				else sum_table_2 <= sum_table_2;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd1) sum_table_2 <= sum_table_2 - 1'b1;
				else sum_table_2 <= sum_table_2;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd1) sum_table_2 <= sum_table_2 - 1'b1;
				else sum_table_2 <= sum_table_2;
			end
			default: sum_table_2 <= sum_table_2;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_3 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_3 <= 6'd32;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_3 <= 6'd32;
				else sum_table_3 <= sum_table_3;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd2) sum_table_3 <= sum_table_3 - 1'b1;
				else sum_table_3 <= sum_table_3;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd2) sum_table_3 <= sum_table_3 - 1'b1;
				else sum_table_3 <= sum_table_3;
			end
			default: sum_table_3 <= sum_table_3;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_4 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_4 <= 6'd28;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_4 <= 6'd28;
				else sum_table_4 <= sum_table_4;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd3) sum_table_4 <= sum_table_4 - 1'b1;
				else sum_table_4 <= sum_table_4;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd3) sum_table_4 <= sum_table_4 - 1'b1;
				else sum_table_4 <= sum_table_4;
			end
			default: sum_table_4 <= sum_table_4;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_5 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_5 <= 6'd24;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_5 <= 6'd24;
				else sum_table_5 <= sum_table_5;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd4) sum_table_5 <= sum_table_5 - 1'b1;
				else sum_table_5 <= sum_table_5;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd4) sum_table_5 <= sum_table_5 - 1'b1;
				else sum_table_5 <= sum_table_5;
			end
			default: sum_table_5 <= sum_table_5;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_6 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_6 <= 6'd20;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_6 <= 6'd20;
				else sum_table_6 <= sum_table_6;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd5) sum_table_6 <= sum_table_6 - 1'b1;
				else sum_table_6 <= sum_table_6;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd5) sum_table_6 <= sum_table_6 - 1'b1;
				else sum_table_6 <= sum_table_6;
			end
			default: sum_table_6 <= sum_table_6;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_7 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_7 <= 6'd16;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_7 <= 6'd16;
				else sum_table_7 <= sum_table_7;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd6) sum_table_7 <= sum_table_7 - 1'b1;
				else sum_table_7 <= sum_table_7;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd6) sum_table_7 <= sum_table_7 - 1'b1;
				else sum_table_7 <= sum_table_7;
			end
			default: sum_table_7 <= sum_table_7;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_8 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_8 <= 6'd12;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_8 <= 6'd12;
				else sum_table_8 <= sum_table_8;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd7) sum_table_8 <= sum_table_8 - 1'b1;
				else sum_table_8 <= sum_table_8;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd7) sum_table_8 <= sum_table_8 - 1'b1;
				else sum_table_8 <= sum_table_8;
			end
			default: sum_table_8 <= sum_table_8;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_9 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_9 <= 6'd8;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_9 <= 6'd8;
				else sum_table_9 <= sum_table_9;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd8) sum_table_9 <= sum_table_9 - 1'b1;
				else sum_table_9 <= sum_table_9;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd8) sum_table_9 <= sum_table_9 - 1'b1;
				else sum_table_9 <= sum_table_9;
			end
			default: sum_table_9 <= sum_table_9;
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) sum_table_10 <= 6'b0;
	else begin
		case (n_state)
			ST_IDLE: sum_table_10 <= 6'd4;
			ST_WAIT: begin
				if(rst_cnt == 6'd50 || rst_cnt == 6'd0) sum_table_10 <= 6'd4;
				else sum_table_10 <= sum_table_10;
			end
			ST_IN_US1: begin
				if(clk1_in_filter > 4'd9) sum_table_10 <= sum_table_10 - 1'b1;
				else sum_table_10 <= sum_table_10;
			end
			ST_IN_US2: begin
				if(clk1_in_filter > 4'd9) sum_table_10 <= sum_table_10 - 1'b1;
				else sum_table_10 <= sum_table_10;
			end
			default: sum_table_10 <= sum_table_10;
		endcase
	end
end

endmodule
