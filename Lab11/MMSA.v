module MMSA(
// input signals
    clk,
    rst_n,
    in_valid,
	in_valid2,
    matrix,
	matrix_size,
    i_mat_idx,
    w_mat_idx,
	
// output signals
    out_valid,
    out_value
);
//---------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//---------------------------------------------------------------------
input clk, rst_n, in_valid, in_valid2;
input matrix;
input [1:0]  matrix_size;
input i_mat_idx, w_mat_idx;

output reg out_valid;
output reg out_value;
//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
parameter ST_IDLE = 'd0,
          ST_IN_SIZE = 'd1,
          ST_IN = 'd2,
          // ST_WAIT = 'd3,
          ST_IN_AIM = 'd3,
          ST_CALCULATE = 'd4,
          //ST_OUT = 'd6,
          ST_RED_SRAM = 'd5;

parameter SIZE_2 = 'd0,
          SIZE_4 = 'd1,
          SIZE_8 = 'd2;

parameter MODE_BIT = 1'd0,
          MODE_VALUE = 1'd1;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------

/* FSM reg */
reg [4:0] c_state, n_state;
reg c_mode, n_mode;

wire signed [15:0] sram_x_data, sram_w_data;
wire signed [15:0] sram_x_out, sram_w_out;
reg [3:0] x_matrix_count, x_row_count, x_colum_count;
reg [9:0] x_matrix_count_shift, w_matrix_count_shift;
reg [7:0] x_row_count_shift;
reg [3:0] w_matrix_count;
reg [9:0] sram_x_index, sram_w_index;
reg sram_x_wen, sram_w_wen;
reg [1:0] size;
reg [15:0] counter;
reg [4:0] matrix_length;
reg [15:0] in_matrax;
reg [1:0] aim_count;

reg signed [15:0] m_w [7:0], m_x[7:0];

reg [2:0] mult_w_count;
reg [2:0] adder_count;
reg [2:0] adder_pip_count;
reg [2:0] store_count;
reg [2:0] bit_calculate_count;
wire signed [31:0] m_out[7:0];

reg signed [31:0] adderA_in[7:0], adderB_in[7:0];
reg signed [39:0] adderA_y_in, adderB_y_in;
reg signed [33:0] addA_3_in[1:0], addB_3_in[1:0];

wire signed [32:0] addA_1_out[3:0], addB_1_out[3:0];
wire signed [33:0] addA_2_out[1:0], addB_2_out[1:0];

wire signed [39:0] addA_3_out, addB_3_out;
wire signed [39:0] addA_4_out, addB_4_out;
reg signed [39:0] y[14:0];

wire [5:0] bit_count;
reg [5:0] bit_count_reg;
wire [39:0] out_y;
reg [39:0] out_y_reg;
reg out_flag;

reg [2:0] out_bit_count;
reg [5:0] out_value_count;
reg [3:0] out_y_count;
reg out_mode;
reg [39:0] prienc_in;
genvar i;
//---------------------------------------------------------------------
//   DESIGN
//---------------------------------------------------------------------
/* FSM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end

always @(*) begin
    case (c_state)
        ST_IDLE: begin
            if(in_valid2) n_state = ST_IN_AIM;
            else if(in_valid) n_state = ST_IN_SIZE;
            else n_state = ST_IDLE;
        end
        ST_IN_SIZE: n_state = ST_IN;
        ST_IN: begin
            //n_state = ST_IN;
            case (size)
                SIZE_2: begin
                    if(counter[11] == 1'b1) n_state = ST_IDLE;
                    else n_state = ST_IN;
                end
                SIZE_4: begin
                    if(counter[13] == 1'b1) n_state = ST_IDLE;
                    else n_state = ST_IN;
                end
                SIZE_8: begin
                    if(counter[15] == 1'b1) n_state = ST_IDLE;
                    else n_state = ST_IN;
                end
                default: begin
                    n_state = ST_IDLE;
                end 
            endcase
        end
        ST_IN_AIM: begin
            if(aim_count == 2'b00) n_state = ST_RED_SRAM;
            else n_state = ST_IN_AIM;
        end
        
        ST_CALCULATE: begin
            case (size)
                SIZE_2: begin
                    if(out_y_count == 4'd3) n_state = ST_IDLE;
                    else n_state = ST_CALCULATE;
                end
                SIZE_4: begin
                    if(out_y_count == 4'd7) n_state = ST_IDLE;
                    else n_state = ST_CALCULATE;
                end
                SIZE_8: begin
                    if(out_y_count == 4'd15) n_state = ST_IDLE;
                    else n_state = ST_CALCULATE;
                end
                default: begin
                    n_state = ST_IDLE;
                end 
            endcase
        end
        ST_RED_SRAM: n_state = ST_CALCULATE;
        default: n_state = ST_IDLE;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) aim_count <= 2'b0;
    else begin
        case (n_state)
            ST_IN_AIM: aim_count <= aim_count + 1'b1;
            default: aim_count <= 2'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 16'd0;
    else begin
        case (n_state)
            ST_IDLE: counter <= 16'd0;
            ST_IN_SIZE: counter <= counter + 1'b1;
            ST_IN: counter <= counter + 1'b1;
            ST_IN_AIM: counter <= counter + 1'b0;
            ST_RED_SRAM: counter <= counter + 1'b1;
            ST_CALCULATE: begin
                counter <= counter + 1'b1;
            end
            default: counter <= counter;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_matrax <= 16'b0;
    else begin
        case (n_state)
            ST_IN_SIZE: in_matrax <= {15'b0, matrix};
            ST_IN: begin
                if(counter[3:0] == 4'b1111) in_matrax <= {15'b0, matrix};
                else in_matrax <= {in_matrax[14:0], matrix};
            end
            default: in_matrax <= 16'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) size <= 1'b0;
    else begin
        case (n_state)
            ST_IN_SIZE: size <= matrix_size;
            default: size <= size;
        endcase
    end
end

assign sram_x_data = {in_matrax[14:0], matrix};
assign sram_w_data = {in_matrax[14:0], matrix};


RA1SH UsramX(.Q(sram_x_out), .CLK(clk), .CEN(1'b0), .WEN(sram_x_wen), .A(sram_x_index), .D(sram_x_data), .OEN(1'b0));
RA1SH UsramW(.Q(sram_w_out), .CLK(clk), .CEN(1'b0), .WEN(sram_w_wen), .A(sram_w_index), .D(sram_w_data), .OEN(1'b0));
always @(*) begin
    case (c_state)
        ST_IN: begin
            case (size)
                SIZE_2: begin
                    if(counter[11:10] != 1'b0) sram_x_wen = 1'b1;
                    else sram_x_wen = 1'b0;
                end
                SIZE_4: begin
                    if(counter[13:12] != 1'b0) sram_x_wen = 1'b1;
                    else sram_x_wen = 1'b0;
                end
                SIZE_8: begin
                    if(counter[15:14] != 1'b0) sram_x_wen = 1'b1;
                    else sram_x_wen = 1'b0;
                end
                default: sram_x_wen = 1'b1;
            endcase
        end 
        default: sram_x_wen = 1'b1;
    endcase
end
always @(*) begin
    case (c_state)
        ST_IN: begin
        case (size)
            SIZE_2: begin
                if(counter[10] == 1'b0) sram_w_wen = 1'b1;
                else sram_w_wen = 1'b0;
            end
            SIZE_4: begin
                if(counter[12] == 1'b0) sram_w_wen = 1'b1;
                else sram_w_wen = 1'b0;
            end
            SIZE_8: begin
                if(counter[14] == 1'b0) sram_w_wen = 1'b1;
                else sram_w_wen = 1'b0;
            end
            default: begin
                sram_w_wen = 1'b1;
            end 
        endcase
    end 
        default: sram_w_wen = 1'b1;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) x_row_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: x_row_count <= 4'b0;
            ST_IN_SIZE:  x_row_count <= 4'b0;
            ST_IN: begin
                if(counter[3:0] == 4'b1111) x_row_count <= x_row_count + 1'b1;
                else x_row_count <= x_row_count;
            end
            default: x_row_count <= 4'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) x_colum_count <= 4'b0;
    else begin
        case (n_state)
            ST_IN: begin
                case (size)
                    SIZE_2: begin
                        if(x_row_count[0] == 1'd1 && counter[3:0] == 4'b1111) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    SIZE_4: begin
                        if(x_row_count[1:0] == 4'd3 && counter[3:0] == 4'b1111) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    SIZE_8: begin
                        if(x_row_count[2:0] == 4'd7 && counter[3:0] == 4'b1111) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    default:; 
                endcase
            end
            default: x_colum_count <= 4'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) matrix_length <= 1'b0;
    else begin
        case (n_state)
            ST_IN_SIZE: begin
                if(matrix_size == 2'b0) matrix_length <= 5'd2;
                else if(matrix_size == 2'b01) matrix_length <= 5'd4;
                else matrix_length <= 5'd8;
            end
            default: matrix_length <= matrix_length;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) x_matrix_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: x_matrix_count <= 4'b0;
            ST_IN_SIZE:  x_matrix_count <= 4'd0;
            ST_IN: begin
                case(size)
                    SIZE_2: begin
                        if(counter[5:0] == 6'd63) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    SIZE_4: begin
                        if(counter[7:0] == 8'd255) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    SIZE_8: begin
                        if(counter[9:0] == 10'd1023) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    default: x_matrix_count <= x_matrix_count; 
                endcase
            end
            ST_IN_AIM: x_matrix_count <= {x_matrix_count[2:0], i_mat_idx};
            default: x_matrix_count <= x_matrix_count;
        endcase
    end
end
always @(*) begin
    case (size)
        SIZE_2: x_matrix_count_shift = {4'b0, x_matrix_count, 2'b0};
        SIZE_4: x_matrix_count_shift = {2'b0, x_matrix_count, 4'b0};
        SIZE_8: x_matrix_count_shift = {x_matrix_count, 6'b0};
        default: x_matrix_count_shift = 10'b0;
    endcase
end
always @(*) begin
    case (size)
        SIZE_2: x_row_count_shift = {4'b0, x_row_count[0], 1'b0};
        SIZE_4: x_row_count_shift = {2'b0, x_row_count[1:0], 2'b0};
        SIZE_8: x_row_count_shift = {x_row_count[2:0], 3'b0};
        default: x_row_count_shift = 6'b0;
    endcase
end
always @(*) begin
    // sram_x_index = x_colum_count + (x_row_count * matrix_length);
    case (n_state)
        ST_IN: begin
            case (size)
            SIZE_2: begin
                sram_x_index = x_colum_count[0] + x_matrix_count_shift + x_row_count_shift;
            end
            SIZE_4: begin
                sram_x_index = x_colum_count[1:0] + x_matrix_count_shift + x_row_count_shift;
            end
            SIZE_8: begin
                sram_x_index = x_colum_count[2:0] + x_matrix_count_shift + x_row_count_shift;
            end
            default: begin
                sram_x_index = 1'b0;
            end 
            endcase
        end
        //ST_IN_AIM: sram_x_index = i_mat_idx * matrix_length * matrix_length;
        ST_RED_SRAM: begin
            case (size)
                SIZE_2: sram_x_index = counter[1:0] + x_matrix_count_shift;
                SIZE_4: sram_x_index = counter[3:0] + x_matrix_count_shift;
                SIZE_8: sram_x_index = counter[5:0] + x_matrix_count_shift;
                default: sram_x_index = 1'b0;
            endcase    
        end
        // sram_x_index = counter + x_matrix_count_shift;
        ST_CALCULATE: begin
            case (size)
                SIZE_2: sram_x_index = counter[1:0] + x_matrix_count_shift;
                SIZE_4: sram_x_index = counter[3:0] + x_matrix_count_shift;
                SIZE_8: sram_x_index = counter[5:0] + x_matrix_count_shift;
                default: sram_x_index = 1'b0;
            endcase    
        end
        default: sram_x_index = 1'b0;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) w_matrix_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: w_matrix_count <= 4'b0;
            ST_IN_AIM: w_matrix_count <= {w_matrix_count[2:0], w_mat_idx};
            default: w_matrix_count <= w_matrix_count;
        endcase
    end
end
always @(*) begin
    case (size)
        SIZE_2: w_matrix_count_shift = {4'b0, w_matrix_count, 2'b0};
        SIZE_4: w_matrix_count_shift = {2'b0, w_matrix_count, 4'b0};
        SIZE_8: w_matrix_count_shift = {w_matrix_count, 6'b0};
        default: w_matrix_count_shift = 10'b0;
    endcase
end
always @(*) begin
    case (n_state)
        ST_IN_SIZE: sram_w_index = 1'b0;
        ST_IN: begin
             case (size)
                SIZE_2: begin
                    sram_w_index = {4'b0 ,counter[9:4]};
                end
                SIZE_4: begin
                    sram_w_index = {2'b0 ,counter[11:4]};
                end
                SIZE_8: begin
                    sram_w_index = {counter[13:4]};
                end
                default: sram_w_index = 1'b0;
             endcase
        end 
        //ST_IN_AIM: sram_w_index = w_mat_idx * matrix_length * matrix_length;
        ST_RED_SRAM:  begin
            case (size)
                SIZE_2: sram_w_index = counter[1:0] + w_matrix_count_shift;
                SIZE_4: sram_w_index = counter[3:0] + w_matrix_count_shift;
                SIZE_8: sram_w_index = counter[5:0] + w_matrix_count_shift;
                default: sram_w_index = 1'b0;
            endcase    
        end
        ST_CALCULATE: begin
            case (size)
                SIZE_2: sram_w_index = counter[1:0] + w_matrix_count_shift;
                SIZE_4: sram_w_index = counter[3:0] + w_matrix_count_shift;
                SIZE_8: sram_w_index = counter[5:0] + w_matrix_count_shift;
                default: sram_w_index = 1'b0;
            endcase    
        end
        default: sram_w_index = 1'b0;
    endcase
   
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_flag <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(out_flag) out_flag <= out_flag;
                else begin
                    case (size)
                    SIZE_2: begin
                        if(counter[2:0] == 3'b110) out_flag <= 1'b1;
                        else out_flag <= 1'b0;
                    end
                    SIZE_4: begin
                        if(counter[4] == 1'b1) out_flag <= 1'b1;
                        else out_flag <= 1'b0;
                    end
                    SIZE_8: begin
                        if(counter == 6'd60) out_flag <= 1'b1;
                        else out_flag <= 1'b0;
                    end
                    default: out_flag <= 1'b0;
                endcase
                end
            // out_flag <= 1'b0;
            end
            default: out_flag <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) m_x[0] <= 16'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_2: begin
                        if(counter >= 3'd5) m_x[0] <= 16'b0;
                        else m_x[0] <= sram_x_out;
                    end
                    SIZE_4: begin
                        if(counter >= 5'd17) m_x[0] <= 16'b0;
                        else m_x[0] <= sram_x_out;
                    end
                    SIZE_8: begin
                        if(counter >= 10'd65) m_x[0] <= 16'b0;
                        else m_x[0] <= sram_x_out;
                    end
                    default: m_x[0] <= 16'b0;
                endcase
                
            end  
            default:  m_x[0] <= 1'b0;
        endcase
    end
end


generate
    for(i = 1 ; i < 8; i = i + 1) begin: M_X
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) m_x[i] <= 16'd0;
            else begin
                case (n_state)
                    ST_CALCULATE:  m_x[i] <= m_x[i - 1];
                    default:  m_x[i] <= 1'b0;
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) mult_w_count <= 3'b0;
    else begin
        case(size)
            SIZE_2: mult_w_count <= {{2'b00},counter[0]};
            SIZE_4: mult_w_count <= {{1'b0}, counter[1:0]};
            SIZE_8: mult_w_count <= counter[2:0];
            default: mult_w_count <= 3'b0;
        endcase
    end
end
generate
    for(i = 0; i < 8; i = i + 1) begin: M_W
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) m_w[i] <= 16'd0;
            else begin
                case (n_state)
                    ST_CALCULATE: begin
                        if(mult_w_count[2:0] == i)  m_w[i] <= sram_w_out;
                        else  m_w[i] <=  m_w[i];
                    end
                    default:  m_w[i] <= 1'b0;
                endcase
            end
        end
    end
endgenerate

generate
    for(i = 0 ; i < 8; i = i + 1) begin: MULT
        assign m_out[i] = m_x[i] * m_w[i];
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adder_count <= 1'b0;
    else begin
        case(size)
            SIZE_2: adder_count <= {{2'b00},mult_w_count[0]};
            SIZE_4: adder_count <= {1'b0, mult_w_count[1:0]};
            SIZE_8: adder_count <= mult_w_count[2:0];
        endcase
    end
end
generate
for (i = 0; i < 8; i = i + 1) begin: ADDER_A
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) adderA_in[i] <= 32'd0;
        else begin
            case (n_state)
                ST_CALCULATE: begin
                    if(adder_count >= i) adderA_in[i] <= m_out[i];
                    else adderA_in[i] <= 1'b0;
                end
                default:  adderA_in[i] <= 1'b0;
            endcase
        end
    end
end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderA_y_in <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (adder_pip_count[2:0])
                    4'd0: adderA_y_in <= y[0];
                    4'd1: adderA_y_in <= y[1];
                    4'd2: adderA_y_in <= y[2];
                    4'd3: adderA_y_in <= y[3];
                    4'd4: adderA_y_in <= y[4];
                    4'd5: adderA_y_in <= y[5];
                    4'd6: adderA_y_in <= y[6];
                    4'd7: adderA_y_in <= y[7];
                endcase

            end
            default:  adderA_y_in <= 1'b0;
        endcase
    end
end
assign addA_1_out[0] = adderA_in[0] + adderA_in[1];
assign addA_1_out[1] = adderA_in[2] + adderA_in[3];
assign addA_1_out[2] = adderA_in[4] + adderA_in[5];
assign addA_1_out[3] = adderA_in[6] + adderA_in[7];

assign addA_2_out[0] = addA_1_out[0] + addA_1_out[1];
assign addA_2_out[1] = addA_1_out[2] + addA_1_out[3];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) addA_3_in[0] <= 34'b0;
    else addA_3_in[0] <= addA_2_out[0];
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) addA_3_in[1] <= 34'b0;
    else addA_3_in[1] <= addA_2_out[1];
end

assign addA_3_out = addA_3_in[0] + addA_3_in[1];
assign addA_4_out = addA_3_out + adderA_y_in;


generate
for (i = 0; i < 8; i = i + 1) begin: ADDER_B
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) adderB_in[i] <= 32'd0;
        else begin
            case (n_state)
                ST_CALCULATE: begin
                    if(adder_count < i) adderB_in[i] <= m_out[i];
                    else adderB_in[i] <= 1'b0;
                end
                default:  adderB_in[i] <= 1'b0;
            endcase
        end
    end
end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderB_y_in <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_2: begin
                        if(adder_pip_count[0] == 0) adderB_y_in <= y[2];
                        else adderB_y_in <= y[3];
                    end
                    SIZE_4: begin
                        case (adder_pip_count[1:0])
                            2'd0: adderB_y_in <= y[4];
                            2'd1: adderB_y_in <= y[5];
                            2'd2: adderB_y_in <= y[6];
                            2'd3: adderB_y_in <= y[7];
                        endcase
                    end
                    SIZE_8: begin
                        case (adder_pip_count[2:0])
                            3'd0: adderB_y_in <= y[8];
                            3'd1: adderB_y_in <= y[9];
                            3'd2: adderB_y_in <= y[10];
                            3'd3: adderB_y_in <= y[11];
                            3'd4: adderB_y_in <= y[12];
                            3'd5: adderB_y_in <= y[13];
                            3'd6: adderB_y_in <= y[14];
                            3'd7: adderB_y_in <= 1'b0;
                        endcase
                    end
                    default: adderB_y_in <= 1'b0;
                endcase
            end
            default:  adderB_y_in <= 1'b0;
        endcase
    end
end
assign addB_1_out[0] = adderB_in[0] + adderB_in[1];
assign addB_1_out[1] = adderB_in[2] + adderB_in[3];
assign addB_1_out[2] = adderB_in[4] + adderB_in[5];
assign addB_1_out[3] = adderB_in[6] + adderB_in[7];

assign addB_2_out[0] = addB_1_out[0] + addB_1_out[1];
assign addB_2_out[1] = addB_1_out[2] + addB_1_out[3];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) addB_3_in[0] <= 34'b0;
    else addB_3_in[0] <= addB_2_out[0];
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) addB_3_in[1] <= 34'b0;
    else addB_3_in[1] <= addB_2_out[1];
end

assign addB_3_out = addB_3_in[0] + addB_3_in[1];
assign addB_4_out = addB_3_out + adderB_y_in;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adder_pip_count <= 1'b0;
    else begin
        if(size == 2'b00) adder_pip_count <= {2'b0, adder_count[0]};
        else if (size == 2'b01) adder_pip_count <= {1'b0, adder_count[1:0]};
        else adder_pip_count <= adder_count[2:0];
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) store_count <= 1'b0;
    else begin
        if(size == 2'b00) store_count <= {2'b0, adder_pip_count[0]};
        else if (size == 2'b01) store_count <= {1'b0, adder_pip_count[1:0]};
        else store_count <= adder_pip_count[2:0];
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[0] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[0] <= 1'b0;
            ST_CALCULATE: begin
                if(store_count == 3'd0) y[0] <= addA_4_out;
                else y[0] <= y[0];
            end
            default: y[0] <= y[0];
        endcase
    end
    
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[1] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[1] <= 1'b0;
            ST_CALCULATE: begin
                if(store_count == 3'd1) y[1] <= addA_4_out;
                else y[1] <= y[1];
            end
            default: y[1] <= y[1];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[2] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[2] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_2: begin
                        if(store_count == 3'd0) y[2] <= addB_4_out;
                        else y[2] <= y[2];
                    end
                    default: begin
                        if(store_count == 3'd2) y[2] <= addA_4_out;
                        else y[2] <= y[2];
                    end
                endcase  
            end    
            default: y[2] <= y[2];
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[3] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[3] <= 1'b0;
            ST_CALCULATE: begin
                if(store_count == 3'd3) y[3] <= addA_4_out;
                else y[3] <= y[3];
            end
            default: y[3] <= y[3];
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[4] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[4] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 3'd0) y[4] <= addB_4_out;
                        else y[4] <= y[4];
                    end
                    default: begin
                        if(store_count == 3'd4) y[4] <= addA_4_out;
                        else y[4] <= y[4];
                    end
                endcase 
            end
            default: y[4] <= y[4];
        endcase
    end 
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[5] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[5] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 3'd1) y[5] <= addB_4_out;
                        else y[5] <= y[5];
                    end
                    default: begin
                        if(store_count == 3'd5) y[5] <= addA_4_out;
                        else y[5] <= y[5];
                    end
                endcase 
            end
            default: y[5] <= y[5];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[6] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[6] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 3'd2) y[6] <= addB_4_out;
                        else y[6] <= y[6];
                    end
                    default: begin
                        if(store_count == 3'd6) y[6] <= addA_4_out;
                        else y[6] <= y[6];
                    end
                endcase 
            end
            default: y[6] <= y[6];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[7] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[7] <= 1'b0;
            ST_CALCULATE: begin
                if(store_count == 3'd7) y[7] <= addA_4_out;
                else y[7] <= y[7];
            end
            default: y[7] <= y[7];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[8] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[8] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd0) y[8] <= addB_4_out;
                        else y[8] <= y[8];
                    end
                    default: y[8] <= y[8];
                endcase 
            end
            default: y[8] <= y[8];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[9] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[9] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd1) y[9] <= addB_4_out;
                        else y[9] <= y[9];
                    end
                    default: y[9] <= y[9];
                endcase 
            end
            default: y[9] <= y[9];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[10] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[10] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd2) y[10] <= addB_4_out;
                        else y[10] <= y[10];
                    end
                    default: y[10] <= y[10];
                endcase 
            end
            default: y[10] <= y[10];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[11] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[11] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd3) y[11] <= addB_4_out;
                        else y[11] <= y[11];
                    end
                    default: y[11] <= y[11];
                endcase 
            end
            default: y[11] <= y[11];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[12] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[12] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd4) y[12] <= addB_4_out;
                        else y[12] <= y[12];
                    end
                    default: y[12] <= y[12];
                endcase 
            end
            default: y[12] <= y[12];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[13] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[13] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd5) y[13] <= addB_4_out;
                        else y[13] <= y[13];
                    end
                    default: y[13] <= y[13];
                endcase 
            end
            default: y[13] <= y[13];
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[14] <= 40'b0;
    else begin
        case (n_state)
            ST_IDLE: y[14] <= 1'b0;
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3'd6) y[14] <= addB_4_out;
                        else y[14] <= y[14];
                    end
                    default: y[14] <= y[14];
                endcase 
            end
            default: y[14] <= y[14];
        endcase
    end 
end


always @(*) begin
    case (out_y_count)
        4'd0: prienc_in = y[0];
        4'd1: prienc_in = y[1];
        4'd2: prienc_in = y[2];
        4'd3: prienc_in = y[3];
        4'd4: prienc_in = y[4];
        4'd5: prienc_in = y[5];
        4'd6: prienc_in = y[6];
        4'd7: prienc_in = y[7];
        4'd8: prienc_in = y[8];
        4'd9: prienc_in = y[9];
        4'd10: prienc_in = y[10];
        4'd11: prienc_in = y[11];
        4'd12: prienc_in = y[12];
        4'd13: prienc_in = y[13];
        4'd14: prienc_in = y[14];
        4'd15: prienc_in = y[14];
    endcase
end
IP_PRIENC U_prienc(.clk(clk), .rst_n(rst_n), .in_array(prienc_in), .out_array(out_y), .out_bit(bit_count));
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_y_reg <= 40'b0;
    else begin
        if(out_mode) out_y_reg <= out_y_reg << 1;
        else out_y_reg <= out_y;
    end
end
/*mode FSM*/
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_mode <= 1'b0;
    else begin
        c_mode <= n_mode;
    end
end
always @(*) begin
    if(out_flag) begin
        case(c_mode) 
            MODE_BIT: begin
                if(out_bit_count == 3'd5) n_mode = MODE_VALUE;
                else n_mode = MODE_BIT;
            end
            MODE_VALUE: begin
                if(out_value_count + 1'b1 == bit_count) n_mode = MODE_BIT;
                else n_mode = MODE_VALUE;
            end
        endcase
    end
    else n_mode = MODE_BIT;
end
always @(*) begin
   out_mode = c_mode;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_bit_count <= 3'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(out_flag && !out_mode) begin
                    if(out_bit_count == 3'd6)  out_bit_count <= 1'b0;
                    else out_bit_count <= out_bit_count + 1'b1;
                end
                else out_bit_count <= 3'b0;
            end
            default: out_bit_count <= 3'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_value_count <= 6'b0;
    else begin
        case (c_state)
            ST_CALCULATE: begin
                if(out_flag && out_mode) begin
                    if(out_value_count == bit_count_reg)  out_value_count <= 6'b0;
                    else out_value_count <= out_value_count + 1'b1;
                end
                else out_value_count <= 6'b0;
            end
            default: out_value_count <= 6'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) bit_count_reg <= 6'b0;
    else bit_count_reg <= bit_count;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_y_count <= 4'b0;
    else begin
        case (c_state)
            ST_CALCULATE: begin
                if((out_value_count + 1'b1 == bit_count_reg) && out_mode) out_y_count <= out_y_count + 1'b1;
                else out_y_count <= out_y_count;
            end
            default: out_y_count <= 4'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE:begin
                if(out_flag) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            default: out_valid <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_value <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE:begin
                if(out_flag) begin
                    if(!out_mode) begin
                        case (out_bit_count)
                            3'd0: out_value <= bit_count[5];
                            3'd1: out_value <= bit_count[4];
                            3'd2: out_value <= bit_count[3];
                            3'd3: out_value <= bit_count[2];
                            3'd4: out_value <= bit_count[1];
                            3'd5: out_value <= bit_count[0];
                            default: out_value <= 1'b0;
                        endcase
                    end
                    else  out_value <= out_y_reg[39];
                end
                else out_value <= 1'b0;
            end
            default: out_value <= 1'b0;
        endcase
    end
end
endmodule

module IP_PRIENC (
    clk, rst_n, in_array, out_array, out_bit
);
    input clk, rst_n;
    input [39:0] in_array;
    output [39:0] out_array;
    output [5:0] out_bit;
    wire [39:0] temp_array [4:0];
    wire [39:0] temp_out_array[5:0];
    wire [5:0] temp_out_bit;
    reg [5:0] temp_out_bit_reg;
    reg [39:0] temp_out_array_3_pip;
    reg [39:0] temp_array_3_pip;

    assign temp_array[0] = (in_array[39:31] == 1'b0)? in_array: {32'b0, in_array[39:32]}; // 32
    assign temp_array[1] = (temp_array[0][30:15] == 1'b0)? temp_array[0] : {16'b0,temp_array[0][39:16]}; // 16
    assign temp_array[2] = (temp_array[1][14:7] == 1'b0)? temp_array[1] : {8'b0, temp_array[1][39:8]}; // 8
    assign temp_array[3] = (temp_array[2][6:3] == 1'b0)? temp_array[2] : {4'b0, temp_array[2][39:4]}; // 4
    assign temp_array[4] = (temp_array[3][2:1] == 1'b0)? temp_array[3] : {2'b0, temp_array[3][39:2]}; // 2
    
    // assign temp_array[5] = (temp_array[4][0] == 1'b0)? temp_array[4] : {1'b0, temp_array[4][39:1]}; // 1
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) temp_array_3_pip <= 40'b0;
        else temp_array_3_pip <= temp_array[3];
    end

    assign temp_out_bit[5] = (in_array[39:31] == 1'b0)? 1'b0 : 1'b1;
    assign temp_out_bit[4] = (temp_array[0][30:15] == 1'b0)? 1'b0 : 1'b1;
    assign temp_out_bit[3] = (temp_array[1][14:7] == 1'b0)? 1'b0 : 1'b1;
    assign temp_out_bit[2] = (temp_array[2][6:3] == 1'b0)? 1'b0 : 1'b1;
    assign temp_out_bit[1] = (temp_array[3][2:1] == 1'b0)? 1'b0 : 1'b1;
    assign temp_out_bit[0] = (temp_array[4][0] == 1'b0)? 1'b0 : 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) temp_out_bit_reg <= 6'b0;
        else temp_out_bit_reg <= temp_out_bit;
    end

    assign temp_out_array[0] = (!temp_out_bit_reg[5])? 40'b0: {in_array[31:0], 8'b0};
    assign temp_out_array[1] = (!temp_out_bit_reg[4])? temp_out_array[0] : {temp_array[0][15:0], temp_out_array[0][39:16]};
    assign temp_out_array[2] = (!temp_out_bit_reg[3])? temp_out_array[1] : {temp_array[1][7:0], temp_out_array[1][39:8]};
    assign temp_out_array[3] = (!temp_out_bit_reg[2])? temp_out_array[2] : {temp_array[2][3:0], temp_out_array[2][39:4]};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) temp_out_array_3_pip <= 40'b0;
        else temp_out_array_3_pip <= temp_out_array[3];
    end
    assign temp_out_array[4] = (!temp_out_bit_reg[1])? temp_out_array_3_pip : {temp_array_3_pip[1:0], temp_out_array_3_pip[39:2]};
    assign temp_out_array[5] = (!temp_out_bit_reg[0])? temp_out_array[4] : {temp_array[4][0],  temp_out_array[4][39:1]};

    assign out_array = (in_array == 0)? 40'b0 : temp_out_array[5];
    assign out_bit = (in_array == 0)? 1'b1: temp_out_bit;


endmodule
