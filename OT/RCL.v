module RCL(
    clk,
    rst_n,
    in_valid,
    coef_Q,
    coef_L,
    out_valid,
    out
);
input clk, rst_n, in_valid;
input signed [4:0] coef_Q, coef_L;
output reg out_valid;
output reg [1:0] out;
/* FSM */
reg [3:0] c_state, n_state;
parameter ST_IDLE = 'd0, ST_IN = 'd1, ST_RUN = 'd2, ST_OUT = 'd3;
/* reg and wire */
reg signed [4:0] a, b, c, m, n;
reg [4:0] k;
reg [1:0] in_counter;
reg [2:0] run_counter;
reg signed [4:0] mult_in_A, mult_in_B;
wire signed [9:0] mult_out;
reg signed [9:0] am, bn;
reg [9:0] aa, bb;
reg signed [11:0] ambnc;
reg [23:0] ambnc_sqr;
reg [23:0] kaabb;
reg [1:0] ans;
wire [11:0] ambnc_abs;
reg [10:0] aabb;
 
/*am + bn + c*/
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) ambnc_sqr <= 24'b0;
	else begin
		case(n_state)
		ST_IDLE: ambnc_sqr <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd3) ambnc_sqr <= ambnc * ambnc;
			else ambnc_sqr <= ambnc_sqr;
		end
		default: ambnc_sqr <= ambnc_sqr;	
		endcase	
	end
end

always @(posedge clk or negedge rst_n) begin
	if(!rst_n) kaabb <= 24'b0;
	else begin
		case(n_state)
		ST_IDLE: kaabb <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd3) kaabb <= k * (aa + bb);
			else kaabb <= kaabb;
		end
		default: kaabb <= kaabb;	
		endcase	
	end
end
always @(*) begin
	ambnc = am + bn + c;
end

always @(*) begin
	if(ambnc_sqr == kaabb) ans = 2'b01;
	else if(ambnc_sqr > kaabb) ans = 2'b00;
	else ans = 2'b10;
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) aa <= 10'b0;
	else begin
		case(n_state)
		ST_IDLE: aa <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd1) aa <= a * a;
			else aa <= aa;
		end
		default: aa <= aa;		
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) am <= 10'b0;
	else begin
		case(n_state)
		ST_IDLE: am <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd1) am <= a * m;
			else am <= am;
		end
		default: am <= am;	
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) bb <= 10'b0;
	else begin
		case(n_state)
		ST_IDLE: bb <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd2) bb <= b * b;
			else bb <= bb;
		end
		default: bb <= bb;	
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) bn <= 10'b0;
	else begin
		case(n_state)
		ST_IDLE: bn <= 10'b0;
		ST_RUN: begin
			if(run_counter == 3'd2) bn <= b * n;
			else bn <= bn;
		end
		default: bn <= bn;	
		endcase	
	end
end


always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c_state <= ST_IDLE;
	else c_state <= n_state;
end
always @(*) begin
	case(c_state)
	ST_IDLE: begin
		if(in_valid) n_state = ST_IN;
		else n_state = ST_IDLE;
	end
	ST_IN: begin
		if(in_counter == 2'b11) n_state = ST_RUN;
		else n_state = ST_IN;
	end
	ST_RUN: begin
		if(run_counter == 3'd4) n_state = ST_OUT;
		else n_state = ST_RUN;
	end
	ST_OUT: begin
		n_state = ST_IDLE;
	end
	default: begin
		n_state = ST_IDLE;
	end	
	endcase
end
/* IN Counter */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) in_counter <= 2'b0;
	else begin
		case(n_state)
		ST_IN: in_counter <= in_counter + 1'b1;
		default: in_counter <= 1'b0;		
		endcase	
	end
end
/* Run Counter */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) run_counter <= 3'b0;
	else begin
		case(n_state)
		ST_RUN: run_counter <= run_counter + 1'b1;
		default: run_counter <= 3'b0;		
		endcase	
	end
end
/* L */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) a <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: a <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b00) a <= coef_L;
			else a <= a;
		end
		default: a <= a;		
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) b <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: b <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b01) b <= coef_L;
			else b <= b;
		end
		default: b <= b;		
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) c <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: c <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b10) c <= coef_L;
			else c <= c;
		end
		default: c <= c;		
		endcase	
	end
end
/* Q */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) m <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: m <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b00) m <= coef_Q;
			else m <= m;
		end
		default: m <= m;
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) n <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: n <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b01) n <= coef_Q;
			else n <= n;
		end
		default: n <= n;		
		endcase	
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) k <= 5'b0;
	else begin
		case(n_state)
		ST_IDLE: k <= 5'b0;
		ST_IN: begin
			if(in_counter == 2'b10) k <= coef_Q;
			else k <= k;
		end
		default: k <= k;
		endcase	
	end
end


/* out reg */
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_valid <= 1'b0;
	else begin
		case(n_state)
		ST_OUT: begin
			out_valid <= 1'b1;	
		end
		default: begin
			out_valid <= 1'b0;
		end	
		endcase
	end
end
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out <= 2'b0;
	else begin
		case(n_state)
		ST_OUT: begin
			out <= ans; // output!!	
		end
		default: begin
			out <= 1'b0;
		end	
		endcase
	end
end

endmodule

