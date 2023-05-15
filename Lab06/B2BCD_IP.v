//############################################################################
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//   File Name   : B2BCD_IP.v
//   Module Name : B2BCD_IP
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################

module B2BCD_IP #(parameter WIDTH = 4, parameter DIGIT = 2) (
    // Input signals
    Binary_code,
    // Output signals
    BCD_code
);

// ===============================================================
// Declaration
// ===============================================================
input  [WIDTH-1:0]   Binary_code;
output [DIGIT*4-1:0] BCD_code;
wire [DIGIT*4+WIDTH-1 : 0] bcd[WIDTH:0];
genvar i, j;
// ===============================================================
// Soft IP DESIGN
// ===============================================================
generate
	assign bcd[0][WIDTH-1:0] = Binary_code;
	assign bcd[0][DIGIT*4+WIDTH-1:WIDTH] = 1'b0;

	for(i = 1; i < WIDTH ; i = i + 1) begin
		assign bcd[i][WIDTH-1:0] = {bcd[i-1][WIDTH-1:0], 1'b0};
		for(j = 1; j <= DIGIT;j = j + 1)begin
			assign bcd[i][(WIDTH-1+(j*4)) -: 4] = (bcd[i-1][(WIDTH-1+(j*4)-1) -: 4] > 4) ?  bcd[i-1][(WIDTH-1+(j*4)-1) -: 4] + 2'b11 :  bcd[i-1][(WIDTH-1+(j*4)- 1) -: 4] ;  
		
		end
	end
	assign bcd[WIDTH] = {bcd[WIDTH-1][DIGIT*4+WIDTH-2: 0], 1'b0};
	assign BCD_code = bcd[WIDTH][DIGIT*4+WIDTH-1 : WIDTH];
endgenerate



endmodule
