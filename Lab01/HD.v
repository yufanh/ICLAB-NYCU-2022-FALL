module HD(
	code_word1,
	code_word2,
	out_n
);
input  [6:0]code_word1, code_word2;
output reg signed[5:0] out_n;

wire [4:0] r_out1, r_out2;
wire [1:0] opt;
wire [3:0] w1, w2;
wire [5:0] a, b;
wire [5:0] adder_out;
wire op;
recover URecover1(.out(r_out1), .p1(code_word1[6]), .p2(code_word1[5]), .p3(code_word1[4]), .x1(code_word1[3]), .x2(code_word1[2]), .x3(code_word1[1]), .x4(code_word1[0]));
recover URecover2(.out(r_out2), .p1(code_word2[6]), .p2(code_word2[5]), .p3(code_word2[4]), .x1(code_word2[3]), .x2(code_word2[2]), .x3(code_word2[1]), .x4(code_word2[0]));
adder Uadder(.out(adder_out) , .a(a), .b(b), .op(op));

assign w1 = r_out1[3:0];
assign w2 = r_out2[3:0];
assign opt = {r_out1[4], r_out2[4]};

assign a = (opt[1])? {{2{w1[3]}}, w1} : {w1[3], w1, 1'b0};
assign b = (opt[1])? {{w2[3]}, w2, 1'b0} : {{2{w2[3]}}, w2};
assign op = (opt[1] ^ opt[0])? 1'b1 : 1'b0 ;

always @(*) begin
	out_n = adder_out;
end

endmodule

module recover(out, p1, p2, p3, x1, x2, x3, x4);
	input p1, p2, p3, x1, x2, x3, x4;
	output reg [4:0] out;
	wire c1, c2, c3, g1, g2, g3;
	wire c1_c2, c1_c3, c2_c3 , x_wrong;
	
	wire x1_, x2_, x3_, x4_;

	wire [2:0] wrong_type;
	
	assign c1 = p1 ^ x1 ^ x2 ^ x3;
	assign c2 = p2 ^ x1 ^ x2 ^ x4;
	assign c3 = p3 ^ x1 ^ x3 ^ x4;
	
	assign x1_ = ~x1;
	assign x2_ = ~x2;
	assign x3_ = ~x3;
	assign x4_ = ~x4;

	assign wrong_type = {c3, c2, c1};
	
	always @(*) begin
		case (wrong_type)
			3'b001: out = {p1 , x1, x2, x3, x4};
			3'b010: out = {p2 , x1, x2, x3, x4};
			3'b011: out = {x2 , x1, x2_, x3, x4};
			3'b100: out = {p3 , x1, x2, x3, x4};
			3'b101: out = {x3 , x1, x2, x3_, x4};
			3'b110: out = {x4 , x1, x2, x3, x4_};
			3'b111: out = {x1 , x1_, x2, x3, x4};
			default: out = {1'b0 , x1, x2, x3, x4};
		endcase
	
	end
	
endmodule


module HA(sum, c_out, a, b);
	input wire a, b;
	output wire sum, c_out;
	xor (sum, a, b);
	and (c_out, a, b);
endmodule

module FA(sum, c_out, a, b, c_in);
	input a, b, c_in;
	output sum, c_out;
	wire s1, c_out1, c_out2;
	HA U1(.sum(s1), .c_out(c_out1), .a(a), .b(b));
	HA U2(.sum(sum), .c_out(c_out2), .a(s1), .b(c_in));
	or (c_out, c_out1, c_out2);
endmodule

module adder(out , a, b, op);
	input [5:0] a, b;
	input op;
	output signed [5:0] out;
	wire [5:0] b_new;
	assign b_new = b ^ {6{op}};
	wire c_out1, c_out2, c_out3, c_out4, c_out5, c_out6;
	FA U1(.sum(out[0]), .c_out(c_out1), .a(a[0]), .b(b_new[0]), .c_in(op));
	FA U2(.sum(out[1]), .c_out(c_out2), .a(a[1]), .b(b_new[1]), .c_in(c_out1));
	FA U3(.sum(out[2]), .c_out(c_out3), .a(a[2]), .b(b_new[2]), .c_in(c_out2));
	FA U4(.sum(out[3]), .c_out(c_out4), .a(a[3]), .b(b_new[3]), .c_in(c_out3));
	FA U5(.sum(out[4]), .c_out(c_out5), .a(a[4]), .b(b_new[4]), .c_in(c_out4));
	FA U6(.sum(out[5]), .c_out(c_out6), .a(a[5]), .b(b_new[5]), .c_in(c_out5));
endmodule
