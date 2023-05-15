//synopsys translate_off
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW02_mult.v"
`include "/RAID2/cad/synopsys/synthesis/cur/dw/sim_ver/DW01_add.v"
//synopsys translate_on

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
input        clk, rst_n, in_valid, in_valid2;
input [15:0] matrix;
input [1:0]  matrix_size;
input [3:0]  i_mat_idx, w_mat_idx;

output reg       	     out_valid;
output reg signed [39:0] out_value;

//---------------------------------------------------------------------
//   PARAMETER
//---------------------------------------------------------------------
parameter ST_IDLE = 'd0,
          ST_IN_SIZE = 'd1,
          ST_IN = 'd2,
          ST_WAIT = 'd3,
          ST_IN_AIM = 'd4,
          ST_CALCULATE = 'd5,
          //ST_OUT = 'd6,
          ST_RED_SRAM = 'd6;

parameter SIZE_2 = 'd0,
          SIZE_4 = 'd1,
          SIZE_8 = 'd2,
          SIZE_16 = 'd3;

/* FSM reg */
reg [4:0] c_state, n_state;
//---------------------------------------------------------------------
//   WIRE AND REG DECLARATION
//---------------------------------------------------------------------
reg [11:0] x_index, w_index;
wire signed [15:0] x_input, w_input;
wire signed [15:0] x_out, w_out;
reg x_write, w_write;
reg [1:0] size;
reg [13:0] counter;
reg [4:0] matrix_length;
reg [3:0] x_colum_count;
reg [3:0] x_matrix_count, x_row_count, w_matrix_count;
reg signed [15:0]m_w [15:0], m_x[15:0];
reg [3:0] mult_w_count;
wire signed [31:0] m_out[15:0];

reg signed [39:0] adderA_in[15:0], adderB_in[15:0];
reg signed [39:0] adderA_y_in, adderB_y_in;
reg signed [39:0] adderA_4_in[1:0], adderB_4_in[1:0];
wire signed [39:0] addA_1_out[7:0], addB_1_out[7:0];
wire signed [39:0] addA_2_out[3:0], addB_2_out[3:0];
wire signed [39:0] addA_3_out[1:0], addB_3_out[1:0];
wire signed [39:0] addA_4_out, addB_4_out;
wire signed [39:0] addA_5_out, addB_5_out;
wire addA_1_cout[7:0], addB_1_cout[7:0];
wire addA_2_cout[3:0], addB_2_cout[3:0];
wire addA_3_cout[1:0], addB_3_cout[1:0];
wire addA_4_cout, addB_4_cout;
wire addA_5_cout, addB_5_cout;
reg signed [39:0] y[30:0];
reg[3:0] adder_count;
reg [3:0] adder_pip_count;
reg[3:0] store_count;
reg[4:0] out_count;
reg out_flag;
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
            if(in_valid) n_state = ST_IN_SIZE;
            else n_state = ST_IDLE;
        end
        ST_IN_SIZE: n_state = ST_IN;
        ST_IN: begin
            //n_state = ST_IN;
            case (size)
                SIZE_2: begin
                    if(counter == 128) n_state = ST_WAIT;
                    else n_state = ST_IN;
                end
                SIZE_4: begin
                    if(counter == 512) n_state = ST_WAIT;
                    else n_state = ST_IN;
                end
                SIZE_8: begin
                    if(counter == 2048) n_state = ST_WAIT;
                    else n_state = ST_IN;
                end
                SIZE_16: begin
                    if(counter == 8192) n_state = ST_WAIT;
                    else n_state = ST_IN;
                end 
                default: begin
                    n_state = ST_IDLE;
                end 
            endcase
        end
        ST_WAIT: begin
            if(in_valid2) n_state = ST_IN_AIM;
            else if(in_valid) n_state = ST_IN_SIZE;
            else n_state = ST_WAIT;
        end
        ST_IN_AIM: n_state = ST_RED_SRAM;
        ST_CALCULATE: begin
            case (size)
                SIZE_2: begin
                    if(out_count == 3) n_state = ST_WAIT;
                    else n_state = ST_CALCULATE;
                end
                SIZE_4: begin
                    if(out_count == 7) n_state = ST_WAIT;
                    else n_state = ST_CALCULATE;
                end
                SIZE_8: begin
                    if(out_count == 15) n_state = ST_WAIT;
                    else n_state = ST_CALCULATE;
                end
                SIZE_16: begin
                    if(out_count == 31) n_state = ST_WAIT;
                    else n_state = ST_CALCULATE;
                end
            endcase
        end
        ST_RED_SRAM: n_state = ST_CALCULATE;
        default: n_state = ST_IDLE;
    endcase
end


RA1SH UsramX(.Q(x_out), .CLK(clk), .CEN(1'b0), .WEN(x_write), .A(x_index), .D(x_input), .OEN(1'b0));

RA1SH UsramW(.Q(w_out), .CLK(clk), .CEN(1'b0), .WEN(w_write), .A(w_index), .D(w_input), .OEN(1'b0));


assign x_input = matrix;
assign w_input = matrix;
always @(*) begin
    // x_index = x_colum_count + (x_row_count * matrix_length);
    case (n_state)
        ST_IN_SIZE: x_index = 0;
        ST_IN: begin
            case (size)
            SIZE_2: begin
                x_index = x_colum_count[0] + (x_matrix_count * matrix_length*matrix_length) + (x_row_count[0] * matrix_length);
            end
            SIZE_4: begin
                x_index = x_colum_count[1:0] + (x_matrix_count * matrix_length*matrix_length) + (x_row_count[1:0] * matrix_length);
            end
            SIZE_8: begin
                x_index = x_colum_count[2:0] + (x_matrix_count * matrix_length*matrix_length) + (x_row_count[2:0] * matrix_length);
            end
            SIZE_16: begin
                x_index = x_colum_count[3:0] + (x_matrix_count * matrix_length*matrix_length) + (x_row_count[3:0] * matrix_length);
            end 
            default: begin
                x_index = 1'b0;
            end 
            endcase
        end
        //ST_IN_AIM: x_index = i_mat_idx * matrix_length * matrix_length;
        ST_RED_SRAM: x_index = counter + (x_matrix_count * matrix_length * matrix_length);
        ST_CALCULATE: x_index = counter + (x_matrix_count * matrix_length * matrix_length);
        default: x_index = 1'b0;
    endcase
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) x_colum_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: x_colum_count <= 4'b0;
            ST_IN_SIZE:  x_colum_count <= 4'b0;
            ST_IN: begin
                case (size)
                    SIZE_2: begin
                        if(x_row_count[0] == 1'd1) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    SIZE_4: begin
                        if(x_row_count[1:0] == 4'd3) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    SIZE_8: begin
                        if(x_row_count[2:0] == 4'd7) x_colum_count <= x_colum_count + 1'b1;
                        else x_colum_count <= x_colum_count;
                    end
                    SIZE_16: begin
                        if(x_row_count[3:0] == 4'd15) x_colum_count <= x_colum_count + 1'b1;
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
    if(!rst_n) x_row_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: x_row_count <= 4'b0;
            ST_IN_SIZE:  x_row_count <= 4'd1;
            ST_IN: begin
                x_row_count <= x_row_count + 1'b1;
            end
            default: x_row_count <= 4'b0;
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
                        if(counter[1:0] == 2'd3) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    SIZE_4: begin
                        if(counter[3:0] == 4'd15) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    SIZE_8: begin
                        if(counter[5:0] == 6'd63) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end
                    SIZE_16: begin
                        if(counter[7:0] == 8'd255) x_matrix_count <= x_matrix_count + 1'b1;
                        else x_matrix_count <= x_matrix_count;
                    end 
                    //default:; 
                endcase
            end
            ST_IN_AIM: x_matrix_count <= i_mat_idx;
            ST_WAIT: x_matrix_count <= 4'd0;
            default: x_matrix_count <= x_matrix_count;
        endcase
    end
end

always @(*) begin
    case (n_state)
        ST_IN_SIZE: w_index = 1'b0;
        ST_IN: begin
             case (size)
                SIZE_2: begin
                    w_index = {6'b0 ,counter[5:0]};
                end
                SIZE_4: begin
                    w_index = {4'b0 ,counter[7:0]};
                end
                SIZE_8: begin
                    w_index = {2'b0 ,counter[9:0]};
                end
                SIZE_16: begin
                    w_index = {counter[11:0]};
                end
             endcase
        end 
        //ST_IN_AIM: w_index = w_mat_idx * matrix_length * matrix_length;
        ST_RED_SRAM: w_index = counter + (w_matrix_count * matrix_length * matrix_length);
        ST_CALCULATE: w_index = counter + (w_matrix_count * matrix_length * matrix_length);
        default: w_index = 1'b0;
    endcase
   
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) w_matrix_count <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: w_matrix_count <= 4'b0;
            ST_IN_AIM: w_matrix_count <= w_mat_idx;
            default: w_matrix_count <= w_matrix_count;
        endcase
    end
end
always @(*) begin
    case (size)
        SIZE_2: begin
            if(counter[6] == 1'b1) x_write = 1'b1;
            else x_write = ~in_valid;
        end
        SIZE_4: begin
            if(counter[8] == 1'b1) x_write = 1'b1;
            else x_write = ~in_valid;
        end
        SIZE_8: begin
            if(counter[10] == 1'b1) x_write = 1'b1;
            else x_write = ~in_valid;
        end
        SIZE_16: begin
            if(counter[12] == 1'b1) x_write = 1'b1;
            else x_write = ~in_valid;
        end 
        default: begin
            x_write = 1'b1;
        end 
    endcase
    
end
always @(*) begin
    case (size)
        SIZE_2: begin
            if(counter[6] == 1'b0) w_write = 1'b1;
            else w_write = ~in_valid;
        end
        SIZE_4: begin
            if(counter[8] == 1'b0) w_write = 1'b1;
            else w_write = ~in_valid;
        end
        SIZE_8: begin
            if(counter[10] == 1'b0) w_write = 1'b1;
            else w_write = ~in_valid;
        end
        SIZE_16: begin
            if(counter[12] == 1'b0) w_write = 1'b1;
            else w_write = ~in_valid;
        end 
        default: begin
            w_write = 1'b1;
        end 
    endcase
    
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
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) matrix_length <= 1'b0;
    else begin
        case (n_state)
            ST_IN_SIZE: begin
                if(matrix_size == 2'b0) matrix_length <= 5'd2;
                else if(matrix_size == 2'b01) matrix_length <= 5'd4;
                else if(matrix_size == 2'b10) matrix_length <= 5'd8;
                else matrix_length <= 5'd16;
            end

            default: matrix_length <= matrix_length;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 12'd0;
    else begin
        case (n_state)
            ST_IDLE: counter <= 12'd0;
            ST_IN_SIZE: counter <= counter + 1'b1;
            ST_IN: begin
                counter <= counter + 1'b1;
            end
            ST_WAIT: counter <= 12'd0;
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
    if(!rst_n) out_count <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE:begin
                if(out_flag == 1) out_count <= out_count + 1'b1;
                else out_count <= 1'b0;
            end
            default: out_count <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE:begin
                if(out_flag) out_valid <= 1'b1;
            end
                
            //ST_OUT: out_valid <= 1'b0;
            default: out_valid <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_flag <= 1'b0;
    else begin
        case (n_state)
            ST_CALCULATE:begin
                case (size)
                    SIZE_2: begin
                        if(counter == 5) out_flag <= 1'b1;
                    end
                    SIZE_4: begin
                        if(counter == 15) out_flag <= 1'b1;
                    end
                    SIZE_8: begin
                        if(counter == 59) out_flag <= 1'b1;
                    end
                    SIZE_16: begin
                        if(counter == 243) out_flag <= 1'b1;
                    end 
                endcase
                
            end
            default: out_flag <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_value <= 1'b0;
    else begin
        case (n_state)
        ST_CALCULATE: begin
            case (size)
                SIZE_2: begin
                    if(out_flag == 1) begin
                        if(out_count <= 1) out_value <= addA_5_out;
                        else out_value <= addB_5_out;
                    end
                    else out_value <= 1'b0;
                end

                SIZE_4: begin
                    if(out_flag == 1) begin
                        if(out_count <= 3) out_value <= addA_5_out;
                        else out_value <= addB_5_out;
                    end
                    else out_value <= 1'b0;
                end

                SIZE_8: begin
                    if(out_flag == 1) begin
                        if(out_count <= 7) out_value <= addA_5_out;
                        else out_value <= addB_5_out;
                    end
                    else out_value <= 1'b0;
                end

                SIZE_16: begin
                    if(out_flag == 1) begin
                        if(out_count <= 15) out_value <= addA_5_out;
                        else out_value <= addB_5_out;
                    end
                    else out_value <= 1'b0;
                end

            endcase
        end
            // ST_OUT: begin
            //     out_value <= 1'b0;
            // end
            default: out_value <= 1'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) m_x[0] <= 16'd0;
    else begin
        case (n_state)
            ST_CALCULATE:  m_x[0] <= x_out;
            default:  m_x[0] <= 1'b0;
        endcase
    end
end


generate
    for(i = 1 ; i < 16; i = i + 1) begin: M_X
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
    //mult_w_count = counter[3:0] - 1;
    if(!rst_n) mult_w_count <= 1'b0;
    else begin
        case(size)
            SIZE_2: mult_w_count <= {{3'b000},counter[0]};
            SIZE_4: mult_w_count <= {{2'b00}, counter[1:0]};
            SIZE_8: mult_w_count <= {{1'b0}, counter[2:0]};
            SIZE_16: mult_w_count <= counter[3:0];
        endcase
    end
    
    
end

generate
    for(i = 0; i < 16; i = i + 1) begin: M_W
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) m_w[i] <= 16'd0;
            else begin
                case (n_state)
                    ST_CALCULATE: begin
                        if(mult_w_count == i)  m_w[i] <= w_out;
                        else  m_w[i] <=  m_w[i];
                    end
                    default:  m_w[i] <= 1'b0;
                endcase
            end
        end
    end
endgenerate

generate
    for(i = 0 ; i < 16; i = i + 1) begin: MULT
        DW02_mult #(16, 16) Umult(.A(m_x[i]), .B(m_w[i]), .TC(1'b1), .PRODUCT(m_out[i]));
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adder_count <= 1'b0;
    else begin
        case(size)
            SIZE_2: adder_count <= {{3'b000},mult_w_count[0]};
            SIZE_4: adder_count <= {{2'b00}, mult_w_count[1:0]};
            SIZE_8: adder_count <= {{1'b0}, mult_w_count[2:0]};
            SIZE_16: adder_count <= mult_w_count[3:0];
        endcase
    end
    
    
end
generate
    for (i = 0; i < 16; i = i + 1) begin: ADDER_A
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) adderA_in[i] <= 32'd0;
            else begin
                case (n_state)
                    ST_CALCULATE: begin
                        if(adder_count >= i) adderA_in[i] <= {{8{m_out[i][31]}},m_out[i]};
                        else adderA_in[i] <= 1'b0;
                    end
                    default:  adderA_in[i] <= 1'b0;
                endcase
            end
        end
    end
endgenerate
generate
    for (i = 0; i < 16; i = i + 1) begin: ADDER_B
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) adderB_in[i] <= 39'd0;
            else begin
                case (n_state)
                    ST_CALCULATE: begin
                        if(adder_count < i) adderB_in[i] <= {{8{m_out[i][31]}},m_out[i]};
                        else adderB_in[i] <= 1'b0;
                    end
                    default:  adderB_in[i] <= 1'b0;
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) store_count <= 1'b0;
    else begin
        store_count <= adder_pip_count;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adder_pip_count <= 1'b0;
    else begin
        adder_pip_count <= adder_count;
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[0] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(store_count == 0) y[0] <= addA_5_out;
                else y[0] <= y[0];
            end
            default: y[0] <= 1'b0;
        endcase
    end
    
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[1] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(store_count == 1) y[1] <= addA_5_out;
                else y[1] <= y[1];
            end
            default: y[1] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[2] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_2: begin
                        if(store_count == 0) y[2] <= addB_5_out;
                        else y[2] <= y[2];
                    end
                    default: begin
                        if(store_count == 2) y[2] <= addA_5_out;
                        else y[2] <= y[2];
                    end
                endcase  
            end    
            default: y[2] <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[3] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(store_count == 3) y[3] <= addA_5_out;
                else y[3] <= y[3];
            end
            default: y[3] <= 1'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[4] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 0) y[4] <= addB_5_out;
                        else y[4] <= y[4];
                    end
                    default: begin
                        if(store_count == 4) y[4] <= addA_5_out;
                        else y[4] <= y[4];
                    end
                endcase 
            end
            default: y[4] <= 1'b0;
        endcase
    end 
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[5] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 1) y[5] <= addB_5_out;
                        else y[5] <= y[5];
                    end
                    default: begin
                        if(store_count == 5) y[5] <= addA_5_out;
                        else y[5] <= y[5];
                    end
                endcase 
            end
            default: y[5] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[6] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_4: begin
                        if(store_count == 2) y[6] <= addB_5_out;
                        else y[6] <= y[6];
                    end
                    default: begin
                        if(store_count == 6) y[6] <= addA_5_out;
                        else y[6] <= y[6];
                    end
                endcase 
            end
            default: y[6] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[7] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(store_count == 7) y[7] <= addA_5_out;
                else y[7] <= y[7];
            end
            default: y[7] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[8] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 0) y[8] <= addB_5_out;
                        else y[8] <= y[8];
                    end
                    default: begin
                        if(store_count == 8) y[8] <= addA_5_out;
                        else y[8] <= y[8];
                    end
                endcase 
            end
            default: y[8] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[9] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 1) y[9] <= addB_5_out;
                        else y[9] <= y[9];
                    end
                    default: begin
                        if(store_count == 9) y[9] <= addA_5_out;
                        else y[9] <= y[9];
                    end
                endcase 
            end
            default: y[9] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[10] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 2) y[10] <= addB_5_out;
                        else y[10] <= y[10];
                    end
                    default: begin
                        if(store_count == 10) y[10] <= addA_5_out;
                        else y[10] <= y[10];
                    end
                endcase 
            end
            default: y[10] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[11] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 3) y[11] <= addB_5_out;
                        else y[11] <= y[11];
                    end
                    default: begin
                        if(store_count == 11) y[11] <= addA_5_out;
                        else y[11] <= y[11];
                    end
                endcase 
            end
            default: y[11] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[12] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 4) y[12] <= addB_5_out;
                        else y[12] <= y[12];
                    end
                    default: begin
                        if(store_count == 12) y[12] <= addA_5_out;
                        else y[12] <= y[12];
                    end
                endcase 
            end
            default: y[12] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[13] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 5) y[13] <= addB_5_out;
                        else y[13] <= y[13];
                    end
                    default: begin
                        if(store_count == 13) y[13] <= addA_5_out;
                        else y[13] <= y[13];
                    end
                endcase 
            end
            default: y[13] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[14] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_8: begin
                        if(store_count == 6) y[14] <= addB_5_out;
                        else y[14] <= y[14];
                    end
                    default: begin
                        if(store_count == 14) y[14] <= addA_5_out;
                        else y[14] <= y[14];
                    end
                endcase 
            end
            default: y[14] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[15] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                if(store_count == 15) y[15] <= addA_5_out;
                else y[15] <= y[15]; 
            end
            default: y[15] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[16] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 0) y[16] <= addB_5_out;
                        else y[16] <= y[16]; 
                    end 
                    default: y[16] <= 1'b0; 
                endcase
            end
            default: y[16] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[17] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 1) y[17] <= addB_5_out;
                        else y[17] <= y[17]; 
                    end 
                    default: y[17] <= 1'b0; 
                endcase
            end
            default: y[17] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[18] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 2) y[18] <= addB_5_out;
                        else y[18] <= y[18]; 
                    end 
                    default: y[18] <= 1'b0; 
                endcase
            end
            default: y[18] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[19] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 3) y[19] <= addB_5_out;
                        else y[19] <= y[19]; 
                    end 
                    default: y[19] <= 1'b0; 
                endcase
            end
            default: y[19] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[20] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 4) y[20] <= addB_5_out;
                        else y[20] <= y[20]; 
                    end 
                    default: y[20] <= 1'b0; 
                endcase
            end
            default: y[20] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[21] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 5) y[21] <= addB_5_out;
                        else y[21] <= y[21]; 
                    end 
                    default: y[21] <= 1'b0; 
                endcase
            end
            default: y[21] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[22] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 6) y[22] <= addB_5_out;
                        else y[22] <= y[22]; 
                    end 
                    default: y[22] <= 1'b0; 
                endcase
            end
            default: y[22] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[23] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 7) y[23] <= addB_5_out;
                        else y[23] <= y[23]; 
                    end 
                    default: y[23] <= 1'b0; 
                endcase
            end
            default: y[23] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[24] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 8) y[24] <= addB_5_out;
                        else y[24] <= y[24]; 
                    end 
                    default: y[24] <= 1'b0; 
                endcase
            end
            default: y[24] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[25] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 9) y[25] <= addB_5_out;
                        else y[25] <= y[25]; 
                    end 
                    default: y[25] <= 1'b0; 
                endcase
            end
            default: y[25] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[26] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 10) y[26] <= addB_5_out;
                        else y[26] <= y[26]; 
                    end 
                    default: y[26] <= 1'b0; 
                endcase
            end
            default: y[26] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[27] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 11) y[27] <= addB_5_out;
                        else y[27] <= y[27]; 
                    end 
                    default: y[27] <= 1'b0; 
                endcase
            end
            default: y[27] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[28] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 12) y[28] <= addB_5_out;
                        else y[28] <= y[28]; 
                    end 
                    default: y[28] <= 1'b0; 
                endcase
            end
            default: y[28] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[29] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 13) y[29] <= addB_5_out;
                        else y[29] <= y[29]; 
                    end 
                    default: y[29] <= 1'b0; 
                endcase
            end
            default: y[29] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) y[30] <= 40'b0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (size)
                    SIZE_16: begin
                        if(store_count == 14) y[30] <= addB_5_out;
                        else y[30] <= y[30]; 
                    end 
                    default: y[30] <= 1'b0; 
                endcase
            end
            default: y[30] <= 1'b0;
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderA_y_in <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
                case (adder_pip_count[3:0])
                    4'd0: adderA_y_in <= y[0];
                    4'd1: adderA_y_in <= y[1];
                    4'd2: adderA_y_in <= y[2];
                    4'd3: adderA_y_in <= y[3];
                    4'd4: adderA_y_in <= y[4];
                    4'd5: adderA_y_in <= y[5];
                    4'd6: adderA_y_in <= y[6];
                    4'd7: adderA_y_in <= y[7];
                    4'd8: adderA_y_in <= y[8];
                    4'd9: adderA_y_in <= y[9];
                    4'd10: adderA_y_in <= y[10];
                    4'd11: adderA_y_in <= y[11];
                    4'd12: adderA_y_in <= y[12];
                    4'd13: adderA_y_in <= y[13];
                    4'd14: adderA_y_in <= y[14];
                    4'd15: adderA_y_in <= y[15];
                endcase

            end
            default:  adderA_y_in <= 1'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderA_4_in[0] <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
               adderA_4_in[0] <= addA_3_out[0];
            end
            default:  adderA_4_in[0] <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderA_4_in[1] <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
               adderA_4_in[1] <= addA_3_out[1];
            end
            default:  adderA_4_in[1] <= 1'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderB_4_in[0] <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
               adderB_4_in[0] <= addB_3_out[0];
            end
            default:  adderB_4_in[0] <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) adderB_4_in[1] <= 39'd0;
    else begin
        case (n_state)
            ST_CALCULATE: begin
               adderB_4_in[1] <= addB_3_out[1];
            end
            default:  adderB_4_in[1] <= 1'b0;
        endcase
    end
end
DW01_add #(40) UaddA_1_1(.A(adderA_in[0]), .B(adderA_in[1]), .CI(1'b0), .CO(addA_1_cout[0]), .SUM(addA_1_out[0]));
DW01_add #(40) UaddA_1_2(.A(adderA_in[2]), .B(adderA_in[3]), .CI(1'b0), .CO(addA_1_cout[1]), .SUM(addA_1_out[1]));
DW01_add #(40) UaddA_1_3(.A(adderA_in[4]), .B(adderA_in[5]), .CI(1'b0), .CO(addA_1_cout[2]), .SUM(addA_1_out[2]));
DW01_add #(40) UaddA_1_4(.A(adderA_in[6]), .B(adderA_in[7]), .CI(1'b0), .CO(addA_1_cout[3]), .SUM(addA_1_out[3]));
DW01_add #(40) UaddA_1_5(.A(adderA_in[8]), .B(adderA_in[9]), .CI(1'b0), .CO(addA_1_cout[4]), .SUM(addA_1_out[4]));
DW01_add #(40) UaddA_1_6(.A(adderA_in[10]), .B(adderA_in[11]), .CI(1'b0), .CO(addA_1_cout[5]), .SUM(addA_1_out[5]));
DW01_add #(40) UaddA_1_7(.A(adderA_in[12]), .B(adderA_in[13]), .CI(1'b0), .CO(addA_1_cout[6]), .SUM(addA_1_out[6]));
DW01_add #(40) UaddA_1_8(.A(adderA_in[14]), .B(adderA_in[15]), .CI(1'b0), .CO(addA_1_cout[7]), .SUM(addA_1_out[7]));

DW01_add #(40) UaddA_2_1(.A(addA_1_out[0]), .B(addA_1_out[1]), .CI(1'b0), .CO(addA_2_cout[0]), .SUM(addA_2_out[0]));
DW01_add #(40) UaddA_2_2(.A(addA_1_out[2]), .B(addA_1_out[3]), .CI(1'b0), .CO(addA_2_cout[1]), .SUM(addA_2_out[1]));
DW01_add #(40) UaddA_2_3(.A(addA_1_out[4]), .B(addA_1_out[5]), .CI(1'b0), .CO(addA_2_cout[2]), .SUM(addA_2_out[2]));
DW01_add #(40) UaddA_2_4(.A(addA_1_out[6]), .B(addA_1_out[7]), .CI(1'b0), .CO(addA_2_cout[3]), .SUM(addA_2_out[3]));

DW01_add #(40) UaddA_3_1(.A(addA_2_out[0]), .B(addA_2_out[1]), .CI(1'b0), .CO(addA_3_cout[0]), .SUM(addA_3_out[0]));
DW01_add #(40) UaddA_3_2(.A(addA_2_out[2]), .B(addA_2_out[3]), .CI(1'b0), .CO(addA_3_cout[1]), .SUM(addA_3_out[1]));

DW01_add #(40) UaddA_4(.A(adderA_4_in[0]), .B(adderA_4_in[1]), .CI(1'b0), .CO(addA_4_cout), .SUM(addA_4_out));

DW01_add #(40) UaddA_5(.A(addA_4_out), .B(adderA_y_in), .CI(1'b0), .CO(addA_5_cout), .SUM(addA_5_out));


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
                            3'd7: adderB_y_in <= y[15];
                        endcase
                    end

                    SIZE_16: begin
                        case (adder_pip_count[3:0])
                        4'd0: adderB_y_in <= y[16];
                        4'd1: adderB_y_in <= y[17];
                        4'd2: adderB_y_in <= y[18];
                        4'd3: adderB_y_in <= y[19];
                        4'd4: adderB_y_in <= y[20];
                        4'd5: adderB_y_in <= y[21];
                        4'd6: adderB_y_in <= y[22];
                        4'd7: adderB_y_in <= y[23];
                        4'd8: adderB_y_in <= y[24];
                        4'd9: adderB_y_in <= y[25];
                        4'd10: adderB_y_in <= y[26];
                        4'd11: adderB_y_in <= y[27];
                        4'd12: adderB_y_in <= y[28];
                        4'd13: adderB_y_in <= y[29];
                        4'd14: adderB_y_in <= y[30];
                        4'd15: adderB_y_in <= 1'b0;
                        endcase
                    end
                endcase
            end
            default:  adderB_y_in <= 1'b0;
        endcase
    end
end
DW01_add #(40) UaddB_1_1(.A(adderB_in[0]), .B(adderB_in[1]), .CI(1'b0), .CO(addB_1_cout[0]), .SUM(addB_1_out[0]));
DW01_add #(40) UaddB_1_2(.A(adderB_in[2]), .B(adderB_in[3]), .CI(1'b0), .CO(addB_1_cout[1]), .SUM(addB_1_out[1]));
DW01_add #(40) UaddB_1_3(.A(adderB_in[4]), .B(adderB_in[5]), .CI(1'b0), .CO(addB_1_cout[2]), .SUM(addB_1_out[2]));
DW01_add #(40) UaddB_1_4(.A(adderB_in[6]), .B(adderB_in[7]), .CI(1'b0), .CO(addB_1_cout[3]), .SUM(addB_1_out[3]));
DW01_add #(40) UaddB_1_5(.A(adderB_in[8]), .B(adderB_in[9]), .CI(1'b0), .CO(addB_1_cout[4]), .SUM(addB_1_out[4]));
DW01_add #(40) UaddB_1_6(.A(adderB_in[10]), .B(adderB_in[11]), .CI(1'b0), .CO(addB_1_cout[5]), .SUM(addB_1_out[5]));
DW01_add #(40) UaddB_1_7(.A(adderB_in[12]), .B(adderB_in[13]), .CI(1'b0), .CO(addB_1_cout[6]), .SUM(addB_1_out[6]));
DW01_add #(40) UaddB_1_8(.A(adderB_in[14]), .B(adderB_in[15]), .CI(1'b0), .CO(addB_1_cout[7]), .SUM(addB_1_out[7]));

DW01_add #(40) UaddB_2_1(.A(addB_1_out[0]), .B(addB_1_out[1]), .CI(1'b0), .CO(addB_2_cout[0]), .SUM(addB_2_out[0]));
DW01_add #(40) UaddB_2_2(.A(addB_1_out[2]), .B(addB_1_out[3]), .CI(1'b0), .CO(addB_2_cout[1]), .SUM(addB_2_out[1]));
DW01_add #(40) UaddB_2_3(.A(addB_1_out[4]), .B(addB_1_out[5]), .CI(1'b0), .CO(addB_2_cout[2]), .SUM(addB_2_out[2]));
DW01_add #(40) UaddB_2_4(.A(addB_1_out[6]), .B(addB_1_out[7]), .CI(1'b0), .CO(addB_2_cout[3]), .SUM(addB_2_out[3]));

DW01_add #(40) UaddB_3_1(.A(addB_2_out[0]), .B(addB_2_out[1]), .CI(1'b0), .CO(addB_3_cout[0]), .SUM(addB_3_out[0]));
DW01_add #(40) UaddB_3_2(.A(addB_2_out[2]), .B(addB_2_out[3]), .CI(1'b0), .CO(addB_3_cout[1]), .SUM(addB_3_out[1]));

DW01_add #(40) UaddB_4(.A(adderB_4_in[0]), .B(adderB_4_in[1]), .CI(1'b0), .CO(addB_4_cout), .SUM(addB_4_out));

DW01_add #(40) UaddB_5(.A(addB_4_out), .B(adderB_y_in), .CI(1'b0), .CO(addB_5_cout), .SUM(addB_5_out));


endmodule
