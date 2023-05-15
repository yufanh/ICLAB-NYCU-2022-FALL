module MH(
    /* input signal */
    clk,
    clk2,
    rst_n,
    in_valid,
    op_valid,
    pic_data,
    se_data,
    op,
    /* output signal */
    out_valid, out_data

);

//================================
// input output signal
//================================
parameter ADDR_WIDTH = 8, DATA_WIDTH = 32;
input wire clk, clk2, rst_n, in_valid, op_valid;
input wire [31:0] pic_data;
input wire [7:0] se_data;
input wire [2:0] op;
output reg out_valid;
output reg [31:0] out_data;



//================================
// reg & wire
//================================
reg [3:0] op_reg;
reg [9:0] counter;
reg [7:0] se_reg [15:0];
wire [127:0] ero_window_se, dil_window_se;

/*sram*/
wire [31:0]sram_q;
reg [7:0] sram_index;
reg [31:0] sram_d;
reg sram_wen;

/* Histogram Equalization */
reg [32:0] he_pic_reg;
wire [7:0] he_pixal [3:0];
wire [255:0] he_count [3:0];
wire [2:0] he_sum_wire [255:0];
reg [10:0] he_table [255:0];
reg he_table_valid;
wire [7:0] he_min_pixal;
reg [7:0] he_min_index;
reg [12:0] he_min;
reg [10:0] he_max_min;
wire [10:0] he_cdf [3:0];
reg [18:0] he_pixal_mult[3:0];
wire [7:0] he_pixal_div[3:0];
wire [7:0] he_pixal_div_pip[3:0];


/* Erosion */
reg [2:0]zero_cnt;
reg [31:0] ero_lb_3;
reg [31:0] ero_lb_2 [6:0];
reg [31:0] ero_lb_1 [6:0];
reg [31:0] ero_lb_0 [6:0];
reg [55:0] ero_window[3:0];
wire [127:0] ero_window_pic[3:0];
wire [7:0] ero_out [3:0];


/* Dilation */
reg [31:0] dil_lb_3;
reg [31:0] dil_lb_2 [6:0];
reg [31:0] dil_lb_1 [6:0];
reg [31:0] dil_lb_0 [6:0];

reg [55:0] dil_window[3:0];
wire [127:0] dil_window_pic[3:0];
wire [7:0] dil_out [3:0];

reg [31:0] temp_reg;
// reg [31:0] dil_lb_3;
genvar i, j;

//================================
// FSM
//================================
reg [3:0] n_state, c_state;
parameter ST_IDLE = 'd0,
          ST_IN_SE = 'd1,
          ST_E = 'd2,
          ST_D = 'd3,
          ST_HE = 'd4,
          ST_ED = 'd5,
          ST_DE = 'd6;

/* FSM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end
always @(*) begin
    case (c_state)
        ST_IDLE: begin
            if(in_valid) n_state = ST_IN_SE;
            else n_state = ST_IDLE;
        end
        ST_IN_SE: begin
            if(counter[4]) begin
                case (op_reg)
                    3'b000: n_state = ST_HE;
                    3'b010: n_state = ST_E;
                    3'b011: n_state = ST_D;
                    3'b110: n_state = ST_ED;
                    3'b111: n_state = ST_DE;
                    default: n_state = ST_IDLE;
                endcase
            end
            else n_state = ST_IN_SE;
        end
        ST_E: begin
            if(counter < 10'd512) n_state = ST_E;
            else n_state = ST_IDLE;
        end
        ST_D: begin
            if(counter < 10'd512) n_state = ST_D;
            else n_state = ST_IDLE;
        end
        ST_HE: begin
            if(counter < 10'd516) n_state = ST_HE;
            else n_state = ST_IDLE;
        end
        ST_ED: begin
            if(counter < 10'd512) n_state = ST_ED;
            else n_state = ST_IDLE;
        end
        ST_DE: begin
            if(counter < 10'd512) n_state = ST_DE;
            else n_state = ST_IDLE;
           
        end
        default: n_state = ST_IDLE;
    endcase
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) zero_cnt <= 3'b0;
    else begin
        case (n_state)
            ST_IDLE: zero_cnt <= 3'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) zero_cnt<= zero_cnt;
                else zero_cnt <= zero_cnt + 1'b1;
            end
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) zero_cnt<= zero_cnt;
                else zero_cnt <= zero_cnt + 1'b1;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) zero_cnt<= zero_cnt;
                else zero_cnt <= zero_cnt + 1'b1;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) zero_cnt<= zero_cnt;
                else zero_cnt <= zero_cnt + 1'b1;
            end
            default: zero_cnt <= zero_cnt + 1'b1;
        endcase
    end
end

/* Erosion */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_lb_3 <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: ero_lb_3 <= 32'b0;
            ST_E: begin
                if(in_valid) ero_lb_3 <= pic_data;
                else if(counter >= 10'd256 && counter <= 10'd485) ero_lb_3 <= ero_lb_3;
                else ero_lb_3 <= 32'b0;
            end
            ST_ED: begin
                if(in_valid) ero_lb_3 <= pic_data;
                else if(counter >= 10'd256 && counter <= 10'd459) ero_lb_3 <= ero_lb_3;
                else ero_lb_3 <= 32'b0;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_3 <= ero_lb_3;
                else if(counter >= 10'd26 && counter <= 10'd485) ero_lb_3 <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
                else ero_lb_3 <= 32'b0;
            end
            default: begin
                if(in_valid) ero_lb_3 <= pic_data;
                else ero_lb_3 <= 32'b0;
            end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_lb_2[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: ero_lb_2[6] <= 32'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_lb_2[6] <= ero_lb_2[6];
                else ero_lb_2[6] <= ero_window[3][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_2[6] <= ero_lb_2[6];
                else ero_lb_2[6] <= ero_window[3][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_2[6] <= ero_lb_2[6];
                else ero_lb_2[6] <= ero_window[3][31:0];
            end
            default: begin
                ero_lb_2[6] <= ero_window[3][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :ero_LB_2
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) ero_lb_2[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: ero_lb_2[i] <= 32'b0;
                    ST_E: begin
                        if(counter >= 10'd256 && counter <= 10'd485) ero_lb_2[i] <= ero_lb_2[i];
                        else ero_lb_2[i] <= ero_lb_2[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_2[i] <= ero_lb_2[i];
                        else ero_lb_2[i] <= ero_lb_2[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_2[i] <= ero_lb_2[i];
                        else ero_lb_2[i] <= ero_lb_2[i + 1];
                    end
                    default: begin
                        ero_lb_2[i] <= ero_lb_2[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_lb_1[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: ero_lb_1[6] <= 32'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_lb_1[6] <= ero_lb_1[6];
                else ero_lb_1[6] <= ero_window[2][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_1[6] <= ero_lb_1[6];
                else ero_lb_1[6] <= ero_window[2][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_1[6] <= ero_lb_1[6];
                else ero_lb_1[6] <= ero_window[2][31:0];
            end
            default: begin
                ero_lb_1[6] <= ero_window[2][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :ero_LB_1
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) ero_lb_1[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: ero_lb_1[i] <= 32'b0;
                    ST_E: begin
                        if(counter >= 10'd256 && counter <= 10'd485) ero_lb_1[i] <= ero_lb_1[i];
                        else ero_lb_1[i] <= ero_lb_1[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_1[i] <= ero_lb_1[i];
                        else ero_lb_1[i] <= ero_lb_1[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_1[i] <= ero_lb_1[i];
                        else ero_lb_1[i] <= ero_lb_1[i + 1];
                    end
                    default: begin
                        ero_lb_1[i] <= ero_lb_1[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_lb_0[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: ero_lb_0[6] <= 32'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_lb_0[6]<= ero_lb_0[6];
                else ero_lb_0[6] <= ero_window[1][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_0[6]<= ero_lb_0[6];
                else ero_lb_0[6] <= ero_window[1][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_lb_0[6]<= ero_lb_0[6];
                else ero_lb_0[6] <= ero_window[1][31:0];
            end
            default: begin
                ero_lb_0[6] <= ero_window[1][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :ero_LB_0
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) ero_lb_0[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: ero_lb_0[i] <= 32'b0;
                    ST_E: begin
                        if(counter >= 10'd256 && counter <= 10'd485) ero_lb_0[i] <=  ero_lb_0[i];
                        else ero_lb_0[i] <= ero_lb_0[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_0[i] <=  ero_lb_0[i];
                        else ero_lb_0[i] <= ero_lb_0[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459) ero_lb_0[i] <=  ero_lb_0[i];
                        else ero_lb_0[i] <= ero_lb_0[i + 1];
                    end
                    default: begin
                        ero_lb_0[i] <= ero_lb_0[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_window[3] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: ero_window[3] <= 55'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_window[3] <= ero_window[3];
                else if(zero_cnt == 3'd0) ero_window[3] <= {24'b0, ero_lb_3};
                else if(in_valid) ero_window[3] <= {pic_data[23:0], ero_lb_3};
                else ero_window[3] <= 55'b0;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[3] <= ero_window[3];
                else if(zero_cnt == 3'd0) ero_window[3] <= {24'b0, ero_lb_3};
                else if(in_valid) ero_window[3] <= {pic_data[23:0], ero_lb_3};
                else ero_window[3] <= 55'b0;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[3] <= ero_window[3];
                else if(zero_cnt == 3'd2) ero_window[3] <= {24'b0, ero_lb_3};
                else if(counter >= 10'd26 && counter <= 10'd485) ero_window[3] <= {dil_out[2], dil_out[1], dil_out[0], ero_lb_3};
                else ero_window[3] <= 55'b0;
            end
            default: begin
                if(zero_cnt == 3'd0) ero_window[3] <= {24'b0, ero_lb_3};
                else if(in_valid) ero_window[3] <= {pic_data[23:0], ero_lb_3};
                else ero_window[3] <= 55'b0;
            end 
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_window[2] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: ero_window[2] <= 55'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_window[2]<= ero_window[2];
                else if(zero_cnt == 3'd0) ero_window[2] <= {24'b0, ero_lb_2[0]};
                else ero_window[2] <= {ero_lb_2[1][23:0], ero_lb_2[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[2]<= ero_window[2];
                else if(zero_cnt == 3'd0) ero_window[2] <= {24'b0, ero_lb_2[0]};
                else ero_window[2] <= {ero_lb_2[1][23:0], ero_lb_2[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[2]<= ero_window[2];
                else if(zero_cnt == 3'd2) ero_window[2] <= {24'b0, ero_lb_2[0]};
                else ero_window[2] <= {ero_lb_2[1][23:0], ero_lb_2[0]};
            end
            default: begin
                if(zero_cnt == 3'd0) ero_window[2] <= {24'b0, ero_lb_2[0]};
                else ero_window[2] <= {ero_lb_2[1][23:0], ero_lb_2[0]};
            end
                
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_window[1] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: ero_window[1] <= 55'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_window[1] <= ero_window[1];
                else if(zero_cnt == 3'd0) ero_window[1] <= {24'b0, ero_lb_1[0]};
                else ero_window[1] <= {ero_lb_1[1][23:0], ero_lb_1[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[1] <= ero_window[1];
                else if(zero_cnt == 3'd0) ero_window[1] <= {24'b0, ero_lb_1[0]};
                else ero_window[1] <= {ero_lb_1[1][23:0], ero_lb_1[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[1] <= ero_window[1];
                else if(zero_cnt == 3'd2) ero_window[1] <= {24'b0, ero_lb_1[0]};
                else ero_window[1] <= {ero_lb_1[1][23:0], ero_lb_1[0]};
            end
            
            default: begin
                if(zero_cnt == 3'd0) ero_window[1] <= {24'b0, ero_lb_1[0]};
                else ero_window[1] <= {ero_lb_1[1][23:0], ero_lb_1[0]};
            end
                
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_window[0] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: ero_window[0] <= 55'b0;
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd485) ero_window[0] <= ero_window[0];
                else if(zero_cnt == 3'd0) ero_window[0] <= {24'b0, ero_lb_0[0]};
                else ero_window[0] <= {ero_lb_0[1][23:0], ero_lb_0[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[0] <= ero_window[0];
                else if(zero_cnt == 3'd0) ero_window[0] <= {24'b0, ero_lb_0[0]};
                else ero_window[0] <= {ero_lb_0[1][23:0], ero_lb_0[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) ero_window[0] <= ero_window[0];
                else if(zero_cnt == 3'd2) ero_window[0] <= {24'b0, ero_lb_0[0]};
                else ero_window[0] <= {ero_lb_0[1][23:0], ero_lb_0[0]};
            end
            default: begin
                if(zero_cnt == 3'd0) ero_window[0] <= {24'b0, ero_lb_0[0]};
                else ero_window[0] <= {ero_lb_0[1][23:0], ero_lb_0[0]};
            end
                
        endcase
    end
end
generate
    for(i = 0; i < 4; i = i + 1) begin
        assign ero_window_pic[i] = {ero_window[3][((8 * i) + 31): 8 * i ], ero_window[2][((8 * i) + 31): 8 * i], ero_window[1][((8 * i) + 31): 8 * i], ero_window[0][((8 * i) + 31): 8 * i]};
    end
endgenerate
generate
    for(i = 0; i < 4; i = i + 1) begin
        IP_ERO U_ero(.pic(ero_window_pic[i]), .se(ero_window_se), .out(ero_out[i]));
    end
endgenerate







/* Dilation */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_lb_3 <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: dil_lb_3 <= 32'b0;
            ST_D: begin
                if(in_valid) dil_lb_3 <= pic_data;
                else if(counter >= 10'd256 && counter <= 10'd485) dil_lb_3 <= dil_lb_3;
                else dil_lb_3 <= 32'b0;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_3 <= dil_lb_3;
                else if(counter >= 10'd26 && counter <= 10'd485) dil_lb_3 <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
                else dil_lb_3 <= 32'b0;
            end
            ST_DE: begin
                if(in_valid) dil_lb_3 <= pic_data;
                else if(counter >= 10'd256 && counter <= 10'd459) dil_lb_3 <= dil_lb_3;
                else dil_lb_3 <= 32'b0;
            end
            default: begin
                if(in_valid) dil_lb_3 <= pic_data;
                else begin
                    dil_lb_3 <= 32'b0;
                end
            end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_lb_2[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: dil_lb_2[6] <= 32'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_lb_2[6] <= dil_lb_2[6];
                else dil_lb_2[6] <= dil_window[3][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_2[6] <= dil_lb_2[6];
                else dil_lb_2[6] <= dil_window[3][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_2[6] <= dil_lb_2[6];
                else dil_lb_2[6] <= dil_window[3][31:0];
            end
            default: begin
                dil_lb_2[6] <= dil_window[3][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :DIL_LB_2
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) dil_lb_2[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: dil_lb_2[i] <= 32'b0;
                    ST_D: begin
                        if(counter >= 10'd256 && counter <= 10'd485) dil_lb_2[i] <= dil_lb_2[i];
                        else dil_lb_2[i] <= dil_lb_2[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459)dil_lb_2[i] <= dil_lb_2[i];
                        else dil_lb_2[i] <= dil_lb_2[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459)dil_lb_2[i] <= dil_lb_2[i];
                        else dil_lb_2[i] <= dil_lb_2[i + 1];
                    end
                    default: begin
                        dil_lb_2[i] <= dil_lb_2[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_lb_1[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: dil_lb_1[6] <= 32'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_lb_1[6] <= dil_lb_1[6];
                else dil_lb_1[6] <= dil_window[2][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_1[6] <= dil_lb_1[6];
                else dil_lb_1[6] <= dil_window[2][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_1[6] <= dil_lb_1[6];
                else dil_lb_1[6] <= dil_window[2][31:0];
            end
            default: begin
                dil_lb_1[6] <= dil_window[2][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :DIL_LB_1
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) dil_lb_1[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: dil_lb_1[i] <= 32'b0;
                    ST_D: begin
                        if(counter >= 10'd256 && counter <= 10'd485) dil_lb_1[i] <= dil_lb_1[i];
                        else dil_lb_1[i] <= dil_lb_1[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459) dil_lb_1[i] <= dil_lb_1[i];
                        else dil_lb_1[i] <= dil_lb_1[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459) dil_lb_1[i] <= dil_lb_1[i];
                        else dil_lb_1[i] <= dil_lb_1[i + 1];
                    end
                    default: begin
                        dil_lb_1[i] <= dil_lb_1[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_lb_0[6] <= 32'b0;
    else begin
        case (n_state)
            ST_IDLE: dil_lb_0[6] <= 32'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_lb_0[6] <= dil_lb_0[6];
                else dil_lb_0[6] <= dil_window[1][31:0];
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_0[6] <= dil_lb_0[6];
                else dil_lb_0[6] <= dil_window[1][31:0];
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_lb_0[6] <= dil_lb_0[6];
                else dil_lb_0[6] <= dil_window[1][31:0];
            end
            default: begin
                dil_lb_0[6] <= dil_window[1][31:0];
            end
        endcase
    end
end
generate
    for(i = 0; i < 6; i = i + 1) begin :DIL_LB_0
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) dil_lb_0[i] <= 32'b0;
            else begin
                case (n_state)
                    ST_IDLE: dil_lb_0[i] <= 32'b0;
                    ST_D: begin
                        if(counter >= 10'd256 && counter <= 10'd485) dil_lb_0[i]<= dil_lb_0[i];
                        else dil_lb_0[i] <= dil_lb_0[i + 1];
                    end
                    ST_ED: begin
                        if(counter >= 10'd256 && counter <= 10'd459) dil_lb_0[i]<= dil_lb_0[i];
                        else dil_lb_0[i] <= dil_lb_0[i + 1];
                    end
                    ST_DE: begin
                        if(counter >= 10'd256 && counter <= 10'd459) dil_lb_0[i]<= dil_lb_0[i];
                        else dil_lb_0[i] <= dil_lb_0[i + 1];
                    end
                    default: begin
                       dil_lb_0[i] <= dil_lb_0[i + 1];
                    end
                endcase
            end
        end
    end
endgenerate

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_window[3] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: dil_window[3] <= 55'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_window[3] <= dil_window[3];
                else if(zero_cnt == 3'b00) dil_window[3] <= {24'b0, dil_lb_3};
                else if(in_valid) dil_window[3] <= {pic_data[23:0], dil_lb_3};
                else dil_window[3] <= 55'b0;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[3] <= dil_window[3];
                else if(zero_cnt == 3'd2) dil_window[3] <= {24'b0, dil_lb_3};
                else if(counter >= 10'd26 && counter <= 10'd485) dil_window[3] <= {ero_out[2], ero_out[1], ero_out[0], dil_lb_3};
                else dil_window[3] <= 55'b0;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[3] <= dil_window[3];
                else if(zero_cnt == 3'b00) dil_window[3] <= {24'b0, dil_lb_3};
                else if(in_valid) dil_window[3] <= {pic_data[23:0], dil_lb_3};
                else dil_window[3] <= 55'b0;
            end
            default: begin
                if(zero_cnt == 3'b00) dil_window[3] <= {24'b0, dil_lb_3};
                else if(in_valid) dil_window[3] <= {pic_data[23:0], dil_lb_3};
                else dil_window[3] <= 55'b0;
            end
                
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_window[2] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: dil_window[2] <= 55'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_window[2] <= dil_window[2];
                else if(zero_cnt == 3'b00) dil_window[2] <= {24'b0, dil_lb_2[0]};
                else dil_window[2] <= {dil_lb_2[1][23:0], dil_lb_2[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[2] <= dil_window[2];
                else if(zero_cnt == 3'd2) dil_window[2] <= {24'b0, dil_lb_2[0]};
                else dil_window[2] <= {dil_lb_2[1][23:0], dil_lb_2[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[2] <= dil_window[2];
                else if(zero_cnt == 3'b00) dil_window[2] <= {24'b0, dil_lb_2[0]};
                else dil_window[2] <= {dil_lb_2[1][23:0], dil_lb_2[0]};
            end
            default: begin
                if(zero_cnt == 3'b00) dil_window[2] <= {24'b0, dil_lb_2[0]};
                else dil_window[2] <= {dil_lb_2[1][23:0], dil_lb_2[0]};
            end
                
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_window[1] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: dil_window[1] <= 55'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_window[1] <= dil_window[1];
                else if(zero_cnt == 3'b00) dil_window[1] <= {24'b0, dil_lb_1[0]};
                else dil_window[1] <= {dil_lb_1[1][23:0], dil_lb_1[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[1] <= dil_window[1];
                else if(zero_cnt == 3'd2) dil_window[1] <= {24'b0, dil_lb_1[0]};
                else dil_window[1] <= {dil_lb_1[1][23:0], dil_lb_1[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[1] <= dil_window[1];
                else if(zero_cnt == 3'b00) dil_window[1] <= {24'b0, dil_lb_1[0]};
                else dil_window[1] <= {dil_lb_1[1][23:0], dil_lb_1[0]};

            end
            default: begin
                if(zero_cnt == 3'b00) dil_window[1] <= {24'b0, dil_lb_1[0]};
                else dil_window[1] <= {dil_lb_1[1][23:0], dil_lb_1[0]};
            end
                
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dil_window[0] <= 55'b0;
    else begin
        case (n_state) 
            ST_IDLE: dil_window[0] <= 55'b0;
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd485) dil_window[0] <= dil_window[0];
                else if(zero_cnt == 3'b00) dil_window[0] <= {24'b0, dil_lb_0[0]};
                else dil_window[0] <= {dil_lb_0[1][23:0], dil_lb_0[0]};
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[0] <= dil_window[0];
                else if(zero_cnt == 3'd2) dil_window[0] <= {24'b0, dil_lb_0[0]};
                else dil_window[0] <= {dil_lb_0[1][23:0], dil_lb_0[0]};
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd459) dil_window[0] <= dil_window[0];
                else if(zero_cnt == 3'b00) dil_window[0] <= {24'b0, dil_lb_0[0]};
                else dil_window[0] <= {dil_lb_0[1][23:0], dil_lb_0[0]};
            end
            default: begin
                if(zero_cnt == 3'b00) dil_window[0] <= {24'b0, dil_lb_0[0]};
                else dil_window[0] <= {dil_lb_0[1][23:0], dil_lb_0[0]};
            end
                
        endcase
    end
end
generate
    for(i = 0; i < 4; i = i + 1) begin
        assign dil_window_pic[i] = {dil_window[3][((8 * i) + 31): 8 * i ], dil_window[2][((8 * i) + 31): 8 * i], dil_window[1][((8 * i) + 31): 8 * i], dil_window[0][((8 * i) + 31): 8 * i]};
    end
endgenerate
generate
    for(i = 0; i < 4; i = i + 1) begin
        IP_DIL U_dil(.pic(dil_window_pic[i]), .se(dil_window_se), .out(dil_out[i]));
    end
endgenerate


/* SE */
generate
    for(i = 0 ; i < 16; i = i + 1) begin : SE_REG
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) se_reg[i] <= 8'b0;
            else begin
                case (n_state)
                    ST_IN_SE: begin
                        if(counter == i) se_reg[i] <= se_data;
                        else se_reg[i] <= se_reg[i];
                    end
                    default: se_reg[i] <= se_reg[i];
                endcase
            end
        end
    end
endgenerate
assign ero_window_se = {se_reg[15], se_reg[14], se_reg[13], se_reg[12], se_reg[11], se_reg[10], se_reg[9], se_reg[8], 
                      se_reg[7], se_reg[6], se_reg[5], se_reg[4], se_reg[3], se_reg[2], se_reg[1], se_reg[0]};

assign dil_window_se = {se_reg[0], se_reg[1], se_reg[2], se_reg[3], se_reg[4], se_reg[5], se_reg[6], se_reg[7], 
                      se_reg[8], se_reg[9], se_reg[10], se_reg[11], se_reg[12], se_reg[13], se_reg[14], se_reg[15]};



/* Histogram Equalization */

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_table_valid <= 1'b0;
    else if(in_valid) he_table_valid <= 1'b1;
    else he_table_valid <= 1'b0;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_pic_reg <= 32'b0;
    else if(in_valid) he_pic_reg <= pic_data;
    else he_pic_reg <= 32'b0;
end
generate
    for(i = 0; i < 4; i = i + 1) begin
        assign he_pixal[i] = he_pic_reg[((8 * (i + 1)) - 1) : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 4; i = i + 1) begin
        for (j = 0; j < 256 ; j = j + 1) begin
            assign he_count[i][j] = (he_pixal[i] <= j)? 1'b1 : 1'b0;
        end
    end
endgenerate
generate
    for(i = 0; i < 256; i = i + 1) begin
        assign he_sum_wire[i] = he_count[0][i] + he_count[1][i] + he_count[2][i] + he_count[3][i];
    end
endgenerate
generate
    for(i = 0; i < 256; i = i + 1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) he_table[i] <= 11'b0;
            else begin
                case (n_state)
                    ST_IDLE: he_table[i] <= 11'b0;
                    ST_IN_SE: begin
                        if(he_table_valid) he_table[i] <= he_table[i] + he_sum_wire[i];
                        else he_table[i] <= he_table[i];
                    end
                    ST_HE: begin
                        if(he_table_valid) he_table[i] <= he_table[i] + he_sum_wire[i];
                        else he_table[i] <= he_table[i];
                    end 
                    default: he_table[i] <= he_table[i];
                endcase
            end
        end
    end
endgenerate
COMPARE_4_he_min_pixal U_comp_he_min_pixal(
    /* input */
    .in1(he_pixal[0]), .in2(he_pixal[1]), .in3(he_pixal[2]), .in4(he_pixal[3]),
    /* output */
    .out(he_min_pixal)
);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_min_index <= 8'b0;
    else begin
        case (n_state)
        ST_IDLE: he_min_index <= 8'd255;
        ST_IN_SE: begin
            if(he_min_pixal < he_min_index && he_table_valid) he_min_index <= he_min_pixal;
            else he_min_index <= he_min_index;
        end
        ST_HE: begin
            if(he_min_pixal < he_min_index && he_table_valid) he_min_index <= he_min_pixal;
            else he_min_index <= he_min_index;
        end
        default: he_min_index <= he_min_index;
        endcase
    end
end

always @(*) begin
    he_min = he_table[he_min_index];
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_max_min <= 11'd0;
    else begin
        he_max_min <= 11'd1024 - he_min;
    end
end
generate
for(i = 0; i < 4; i = i + 1) begin
    assign he_cdf[i] = he_table[sram_q[((8 * (i + 1)) - 1) : 8 * i]] - he_min;
end
endgenerate

generate
for(i = 0; i < 4; i = i + 1) begin
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) he_pixal_mult[i] <= 19'b0;
        else begin
            case (n_state)
            ST_HE: begin
                he_pixal_mult[i] <= he_cdf[i] * 8'd255;
            end 
            default: he_pixal_mult[i] <= 19'b0;
            endcase
        end
    end
end
endgenerate

// generate
//     for(i = 0; i < 4; i = i + 1) begin
//         assign he_pixal_div[i] = he_pixal_mult[i] / he_max_min;
//     end
// endgenerate

generate
    for(i = 0; i < 4; i = i + 1) begin  :DIV_PIP
        IP_PIP_DIV u_pip_div(.clk(clk), .rst_n(rst_n), .a(he_pixal_mult[i]), .b(he_max_min), .out(he_pixal_div_pip[i]));
    end
endgenerate

/* RA1SH SRAM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) temp_reg <= 32'b0;
    else begin
        case (n_state)
            ST_E: begin
                if(counter == 10'd255) temp_reg <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
                else temp_reg <= temp_reg;
            end
            ST_D: begin
                if(counter == 10'd255) temp_reg <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
                else temp_reg <= temp_reg;
            end
            ST_ED: begin
                if(counter == 10'd255) temp_reg <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
                else temp_reg <= temp_reg;
            end
            ST_DE: begin
                if(counter == 10'd255) temp_reg <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
                else temp_reg <= temp_reg;
            end
            default: temp_reg <= 32'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) sram_d <= 32'b0;
    else begin
        case (n_state)
            ST_IN_SE: sram_d <= pic_data;

            ST_E: begin
                if(counter >= 10'd255) sram_d <= sram_d;
                else sram_d <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
            end
            ST_D: begin
                if(counter >= 10'd255) sram_d <= sram_d;
                else sram_d <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
            end
            ST_HE: begin
                if(in_valid) sram_d <= pic_data;
                else sram_d <= 32'b0;
            end
            ST_ED: begin
                if(counter >= 10'd255) sram_d <= sram_d;
                else sram_d <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
            end
            ST_DE: begin
                if(counter >= 10'd255) sram_d <= sram_d;
                else sram_d <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
            end
            default: sram_d <= 32'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) sram_index <= 8'b0;
    else begin
        case (n_state)
            ST_IDLE: sram_index <= 8'b1111_1111;
            ST_IN_SE: sram_index <= sram_index + 1'b1;
            ST_E: begin
                if(counter == 10'd254) sram_index <= 1'b0;
                else if(counter >= 10'd27) sram_index <= sram_index + 1'b1;
                else sram_index <= 8'b0;
            end
            ST_D: begin
                if(counter == 10'd254) sram_index <= 1'b0;
                else if(counter >= 10'd27) sram_index <= sram_index + 1'b1;
                else sram_index <= 8'b0;
            end
            ST_HE: begin
                sram_index <= sram_index + 1'b1;
            end
            ST_ED: begin
                if(counter == 10'd254) sram_index <= 1'b0;
                else if(counter >= 10'd53) sram_index <= sram_index + 1'b1;
                else sram_index <= 8'b0;
            end
            ST_DE: begin
                if(counter == 10'd254) sram_index <= 1'b0;
                else if(counter >= 10'd53) sram_index <= sram_index + 1'b1;
                else sram_index <= 8'b0;
            end
            default: sram_index <= 8'b0;
        endcase
    end
end
always @(*) begin
    case (c_state)
        ST_IDLE: sram_wen = 1'b1;
        ST_IN_SE: sram_wen = 1'b0;
        ST_E:  begin
            if(counter >= 10'd27 && counter <= 10'd254) sram_wen = 1'b0;
            else sram_wen = 1'b1;
        end
        ST_D:  begin
            if(counter >= 10'd27 && counter <= 10'd254) sram_wen = 1'b0;
            else sram_wen = 1'b1;
        end
        ST_HE: begin
            if(counter >= 10'd1 && counter <= 10'd256) sram_wen = 1'b0;
            else sram_wen = 1'b1;
        end
        ST_DE: begin
            if(counter >= 10'd53 && counter <= 10'd254) sram_wen = 1'b0;
            else sram_wen = 1'b1;
        end
        ST_ED: begin
            if(counter >= 10'd53 && counter <= 10'd254) sram_wen = 1'b0;
            else sram_wen = 1'b1;
        end
        default: sram_wen = 1'b1;
    endcase
end
RA1SH Usram(.Q(sram_q), .CLK(clk), .CEN(1'b0), .WEN(sram_wen), .A(sram_index), .D(sram_d), .OEN(1'b0));



/* op_reg */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) op_reg <= 3'b0;
    else if(op_valid) op_reg <= op;
    else op_reg <= op_reg;
end

/* counter */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 10'b0;
    else begin
        case (n_state)
            ST_IDLE: counter <= 10'b0;
            default: counter <= counter + 1'b1;
        endcase
    end
end


/* output */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 1'b0;
    else begin
        case (n_state)
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd511) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd511) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            ST_HE: begin
                if(counter >= 10'd260 && counter <= 10'd515) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd511) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd511) out_valid <= 1'b1;
                else out_valid <= 1'b0;
            end
            default: out_valid <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_data <= 32'b0;
    else begin
        case (n_state)
            ST_E: begin
                if(counter >= 10'd256 && counter <= 10'd483) out_data <= sram_q;
                else if(counter == 10'd484) out_data <= sram_d;
                else if(counter == 10'd485) out_data <= temp_reg;
                else if(counter >= 10'd486 && counter <= 10'd511) out_data <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
                else out_data <= 32'b0;
            end
            ST_D: begin
                if(counter >= 10'd256 && counter <= 10'd483) out_data <= sram_q;
                else if(counter == 10'd484) out_data <= sram_d;
                else if(counter == 10'd485) out_data <= temp_reg;
                else if(counter >= 10'd486 && counter <= 10'd511) out_data <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
                else out_data <= 32'b0;
            end
            ST_HE: begin
                if(counter >= 10'd260 && counter <= 10'd515) out_data <= {he_pixal_div_pip[3], he_pixal_div_pip[2], he_pixal_div_pip[1], he_pixal_div_pip[0]};
                else out_data <= 32'b0;
            end
            ST_ED: begin
                if(counter >= 10'd256 && counter <= 10'd457) out_data <= sram_q;
                else if(counter == 10'd458) out_data <= sram_d;
                else if(counter == 10'd459) out_data <= temp_reg;
                else if(counter >= 10'd460 && counter <= 10'd511) out_data <= {dil_out[3], dil_out[2], dil_out[1], dil_out[0]};
                else out_data <= 32'b0;
            end
            ST_DE: begin
                if(counter >= 10'd256 && counter <= 10'd457) out_data <= sram_q;
                else if(counter == 10'd458) out_data <= sram_d;
                else if(counter == 10'd459) out_data <= temp_reg;
                else if(counter >= 10'd460 && counter <= 10'd511) out_data <= {ero_out[3], ero_out[2], ero_out[1], ero_out[0]};
                else out_data <= 32'b0;
            end
            default: out_data <= 32'b0;
        endcase
    end
end

endmodule

module COMPARE_ERO(
    /* input */
    a, b,
    /* output */
    out
);
input [7:0] a, b;
output reg [7:0] out;

always @(*) begin
    if(a <= b) out = a;
    else out = b;
end
endmodule

module COMPARE_DIL(
    /* input */
    a, b,
    /* output */
    out
);
input [7:0] a, b;
output reg [7:0] out;

always @(*) begin
    if(a <= b) out = b;
    else out = a;
end
endmodule
module COMPARE_4_he_min_pixal(
    /* input */
    in1, in2, in3, in4,
    /* output */
    out
);
input [7:0] in1, in2, in3, in4;
output wire [7:0] out;
wire [7:0] out1[1:0];

COMPARE_ERO U1_1(.a(in1), .b(in2), .out(out1[0]));
COMPARE_ERO U1_2(.a(in3), .b(in4), .out(out1[1]));

COMPARE_ERO U2_1(.a(out1[0]), .b(out1[1]), .out(out));

endmodule


module COMPARE_16_ERO(
    /* input */
    in1, in2, in3, in4,
    in5, in6, in7, in8,
    in9, in10, in11, in12,
    in13, in14, in15, in16,
    /* output */
    out
);
input [7:0] in1, in2, in3, in4,
            in5, in6, in7, in8,
            in9, in10, in11, in12,
            in13, in14, in15, in16;
output wire [7:0] out;
wire [7:0] out1[7:0];
wire [7:0] out2[3:0];
wire [7:0] out3[1:0];

COMPARE_ERO U1_1(.a(in1), .b(in2), .out(out1[0]));
COMPARE_ERO U1_2(.a(in3), .b(in4), .out(out1[1]));
COMPARE_ERO U1_3(.a(in5), .b(in6), .out(out1[2]));
COMPARE_ERO U1_4(.a(in7), .b(in8), .out(out1[3]));
COMPARE_ERO U1_5(.a(in9), .b(in10), .out(out1[4]));
COMPARE_ERO U1_6(.a(in11), .b(in12), .out(out1[5]));
COMPARE_ERO U1_7(.a(in13), .b(in14), .out(out1[6]));
COMPARE_ERO U1_8(.a(in15), .b(in16), .out(out1[7]));

COMPARE_ERO U2_1(.a(out1[0]), .b(out1[1]), .out(out2[0]));
COMPARE_ERO U2_2(.a(out1[2]), .b(out1[3]), .out(out2[1]));
COMPARE_ERO U2_3(.a(out1[4]), .b(out1[5]), .out(out2[2]));
COMPARE_ERO U2_4(.a(out1[6]), .b(out1[7]), .out(out2[3]));

COMPARE_ERO U3_1(.a(out2[0]), .b(out2[1]), .out(out3[0]));
COMPARE_ERO U3_2(.a(out2[2]), .b(out2[3]), .out(out3[1]));

COMPARE_ERO U4_1(.a(out3[0]), .b(out3[1]), .out(out));
endmodule

module COMPARE_16_DIL(
    /* input */
    in1, in2, in3, in4,
    in5, in6, in7, in8,
    in9, in10, in11, in12,
    in13, in14, in15, in16,
    /* output */
    out
);
input [7:0] in1, in2, in3, in4,
            in5, in6, in7, in8,
            in9, in10, in11, in12,
            in13, in14, in15, in16;
output wire [7:0] out;
wire [7:0] out1[7:0];
wire [7:0] out2[3:0];
wire [7:0] out3[1:0];

COMPARE_DIL U1_1(.a(in1), .b(in2), .out(out1[0]));
COMPARE_DIL U1_2(.a(in3), .b(in4), .out(out1[1]));
COMPARE_DIL U1_3(.a(in5), .b(in6), .out(out1[2]));
COMPARE_DIL U1_4(.a(in7), .b(in8), .out(out1[3]));
COMPARE_DIL U1_5(.a(in9), .b(in10), .out(out1[4]));
COMPARE_DIL U1_6(.a(in11), .b(in12), .out(out1[5]));
COMPARE_DIL U1_7(.a(in13), .b(in14), .out(out1[6]));
COMPARE_DIL U1_8(.a(in15), .b(in16), .out(out1[7]));

COMPARE_DIL U2_1(.a(out1[0]), .b(out1[1]), .out(out2[0]));
COMPARE_DIL U2_2(.a(out1[2]), .b(out1[3]), .out(out2[1]));
COMPARE_DIL U2_3(.a(out1[4]), .b(out1[5]), .out(out2[2]));
COMPARE_DIL U2_4(.a(out1[6]), .b(out1[7]), .out(out2[3]));

COMPARE_DIL U3_1(.a(out2[0]), .b(out2[1]), .out(out3[0]));
COMPARE_DIL U3_2(.a(out2[2]), .b(out2[3]), .out(out3[1]));

COMPARE_DIL U4_1(.a(out3[0]), .b(out3[1]), .out(out));
endmodule

module SUB (
    /* input */
    a, b,
    /* output */
    out,
);
input [7:0] a, b;
output wire [7:0] out;
assign out = (a > b)? (a - b) : 7'b0;
endmodule

module ADD (
    /* input */
    a, b,
    /* output */
    out,
);
input [7:0] a, b;
output wire [7:0] out;
wire [8:0] temp_out;
assign temp_out = a + b;
assign out = (temp_out[8])? 8'b1111_1111 : temp_out[7:0];
endmodule

module IP_ERO (
    /* input */
    pic, se,
    
    /* output */
    out
 );
input [127:0] pic;
input [127:0] se;
output [7:0] out;

wire [7:0] pic_pixal [15:0];
wire [7:0] se_pixal [15:0];
genvar i;

wire [7:0] add_out [15:0];
wire [7:0] sub_out [15:0];
wire [7:0] compare_in [15:0];
generate
    for(i = 0; i < 16; i  = i + 1) begin
        assign pic_pixal[i] = pic[(8 * (i + 1)) - 1 : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 16; i  = i + 1) begin
        assign se_pixal[i] = se[(8 * (i + 1)) - 1 : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 16; i  = i + 1) begin
        SUB U_sub(.a(pic_pixal[i]), .b(se_pixal[i]), .out(sub_out[i]));
    end
endgenerate
COMPARE_16_ERO U_comapre16(
    .in1(sub_out[0]), .in2(sub_out[1]), .in3(sub_out[2]), .in4(sub_out[3]),
    .in5(sub_out[4]), .in6(sub_out[5]), .in7(sub_out[6]), .in8(sub_out[7]),
    .in9(sub_out[8]), .in10(sub_out[9]), .in11(sub_out[10]), .in12(sub_out[11]),
    .in13(sub_out[12]), .in14(sub_out[13]), .in15(sub_out[14]), .in16(sub_out[15]),
    .out(out)
);
endmodule

module IP_DIL (
    /* input */
    pic, se,
    /* output */
    out
 );
input [127:0] pic;
input [127:0] se;
output [7:0] out;

wire [7:0] pic_pixal [15:0];
wire [7:0] se_pixal [15:0];
genvar i;

wire [7:0] add_out [15:0];
wire [7:0] sub_out [15:0];
wire [7:0] compare_in [15:0];
generate
    for(i = 0; i < 16; i  = i + 1) begin
        assign pic_pixal[i] = pic[(8 * (i + 1)) - 1 : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 16; i  = i + 1) begin
        assign se_pixal[i] = se[(8 * (i + 1)) - 1 : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 16; i  = i + 1) begin
        ADD U_add(.a(pic_pixal[i]), .b(se_pixal[i]), .out(add_out[i]));
    end
endgenerate
COMPARE_16_DIL U_comapre16(
    .in1(add_out[0]), .in2(add_out[1]), .in3(add_out[2]), .in4(add_out[3]),
    .in5(add_out[4]), .in6(add_out[5]), .in7(add_out[6]), .in8(add_out[7]),
    .in9(add_out[8]), .in10(add_out[9]), .in11(add_out[10]), .in12(add_out[11]),
    .in13(add_out[12]), .in14(add_out[13]), .in15(add_out[14]), .in16(add_out[15]),
    .out(out)
);


endmodule





module IP_PIP_DIV(
	clk, rst_n,
	a, b,
	out
);
input clk, rst_n;
input [18:0] a;
input [10:0] b;
output wire [7:0] out;

reg [18:0] a_pip;
reg [3:0] out_pip;
wire [16:0] b_7;
wire [15:0] b_6;
wire [14:0] b_5;
wire [13:0] b_4;
wire [12:0] b_3;
wire [12:0] b_2;
wire [11:0] b_1;
wire [18:0] temp_a[7:0];
wire [3:0] temp_out;

assign b_7 = b << 7;
assign b_6 = b << 6;
assign b_5 = b << 5;
assign b_4 = b << 4;
assign b_3 = b << 3;
assign b_2 = b << 2;
assign b_1 = b << 1;

assign temp_a[7] = (a >= b_7)? a - b_7 : a;
assign temp_a[6] = (temp_a[7] >= b_6)? temp_a[7] - b_6 : temp_a[7];
assign temp_a[5] = (temp_a[6] >= b_5)? temp_a[6] - b_5 : temp_a[6];
assign temp_a[4] = (temp_a[5] >= b_4)? temp_a[5] - b_4 : temp_a[5];
assign temp_a[3] = (a_pip >= b_3)? a_pip - b_3 : a_pip;
assign temp_a[2] = (temp_a[3] >= b_2)? temp_a[3] - b_2 : temp_a[3];
assign temp_a[1] = (temp_a[2] >= b_1)? temp_a[2] - b_1 : temp_a[2];
assign temp_a[0] = (temp_a[1] >= b)? temp_a[1] - b : temp_a[1];
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) a_pip <= 19'b0;
	else a_pip <= temp_a[4];
end

assign temp_out[3] = (a >= b_7)? 1'b1: 1'b0;
assign temp_out[2] = (temp_a[7] >= b_6)? 1'b1: 1'b0;
assign temp_out[1] = (temp_a[6] >= b_5)? 1'b1: 1'b0;
assign temp_out[0] = (temp_a[5] >= b_4)? 1'b1: 1'b0;
assign out[7] = out_pip[3];
assign out[6] = out_pip[2];
assign out[5] = out_pip[1];
assign out[4] = out_pip[0];
assign out[3] = (a_pip >= b_3)? 1'b1: 1'b0;
assign out[2] = (temp_a[3] >= b_2)? 1'b1: 1'b0;
assign out[1] = (temp_a[2] >= b_1)? 1'b1: 1'b0;
assign out[0] = (temp_a[1] >= b)? 1'b1: 1'b0;
always @(posedge clk or negedge rst_n) begin
	if(!rst_n) out_pip <= 4'b0;
	else out_pip <= temp_out;
end

endmodule
