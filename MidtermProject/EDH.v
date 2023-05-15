module EDH(
    /* input signal */
    clk, rst_n, in_valid, op, pic_no, se_no,

    /* output signal */
    busy,

    /* DRAM axi4 write address channel input */
    awready_m_inf,

    /* DRAM axi4 write address channel output */
    awid_m_inf,
    awaddr_m_inf,
    awsize_m_inf,
    awburst_m_inf,
    awlen_m_inf,
    awvalid_m_inf,

    /* DRAM axi4 write data channel input */
    wready_m_inf,

    /* DRAM axi4 write data channel output */
    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    
    /* DRAM axi4 write response channel input */
    bid_m_inf,
    bresp_m_inf,
    bvalid_m_inf,
    
    /* DRAM axi4 write response channel output */
    bready_m_inf,

    /* DRAM axi4 read address channel input */
    arready_m_inf,
    /* DRAM axi4 read address channel output */
    arid_m_inf,
    araddr_m_inf,
    arlen_m_inf,
    arsize_m_inf,
    arburst_m_inf,
    arvalid_m_inf,

    /* DRAM axi4 read data channel input */
    rid_m_inf,
    rdata_m_inf,
    rresp_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    /* DRAM axi4 read data channel output */
    rready_m_inf
);

//================================
// input output signal
//================================
parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;
input wire clk, rst_n, in_valid;
input wire [1:0] op;
input wire [3:0] pic_no;
input wire [5:0] se_no;
output reg busy;

/* DRAM axi write address channel */
output wire [ID_WIDTH-1:0]     awid_m_inf;
output wire [ADDR_WIDTH-1:0] awaddr_m_inf;
output wire [2:0]            awsize_m_inf;
output wire [1:0]           awburst_m_inf;
output wire [7:0]             awlen_m_inf;
output wire                 awvalid_m_inf;
input wire                 awready_m_inf;

/* DRAM axi4 write data channel */
output wire [DATA_WIDTH-1:0]  wdata_m_inf;
output wire                   wlast_m_inf;
output wire                  wvalid_m_inf;
input wire                  wready_m_inf;

/* DRAM axi4 write response channel */
input wire [ID_WIDTH-1:0]      bid_m_inf;
input wire [1:0]             bresp_m_inf;
input wire                  bvalid_m_inf;
output wire                 bready_m_inf;

/* DRAM axi4 read address channel */
output wire    [ID_WIDTH-1:0]      arid_m_inf;
output wire    [ADDR_WIDTH-1:0]  araddr_m_inf;
output wire    [7:0]              arlen_m_inf;
output wire    [2:0]             arsize_m_inf;
output wire    [1:0]            arburst_m_inf;
output wire                     arvalid_m_inf;
input wire                     arready_m_inf;

/* DRAM axi4 read data channel */
input wire [ID_WIDTH-1:0]          rid_m_inf;
input wire [DATA_WIDTH-1:0]      rdata_m_inf;
input wire [1:0]                 rresp_m_inf;
input wire                       rlast_m_inf;
input wire                      rvalid_m_inf;
output wire                      rready_m_inf;

//================================
// reg and wire
//================================
reg [1:0] in_op;
reg [3:0] in_pic;
reg [5:0] in_se;
wire [ADDR_WIDTH-1:0] read_addr;
wire read_mode;
wire read_enable, write_enable, read_valid, write_valid;
wire [DATA_WIDTH-1:0] read_out;
reg [DATA_WIDTH-1:0] sram_out_data;
reg [9:0] sram_out_cnt;
reg [11:0] test_counter;
wire [11:0] read_cnt, write_cnt;
reg write_data_valid;
wire se_mode;
reg [127:0] dram_write_data;
reg[127:0] dram_write_data_wire;

wire [127:0] sram_in_q;
reg [7:0] sram_in_index;
reg [127:0] sram_in_d;
reg sram_in_wen;
// for Histogram Equalization
reg [127:0] dram_read_out;
wire [7:0] pixal [15:0];
wire [255:0] value_wire [15:0];
wire [4:0] sum_wire [255:0];
reg [12:0] sum_table [255:0];
reg [7:0] read_pic_cnt_delay1;
// reg [8:0] cdf_cnt;
reg [7:0] sum_table_cnt;
reg read_valid_delay1;
wire [11:0] k;
reg [12:0] min;
wire [12:0] he_cdf [15:0];
wire [20:0] he_pixal_shift [15:0];
reg [20:0] he_pixal_mult [15:0];
wire [7:0] he_pixal_div [15:0];
reg [11:0] max_min;
reg [127:0] sram_out_outdata;
reg [8:0]he_write_cnt;
reg he_write_cnt_eq2_flag;
wire [7:0] min_pixal;
reg [7:0] min_index;


// for Erosion
reg [8:0] ero_dil_cnt;

reg [151:0] window [3:0];
reg [127:0] line_buffer_0 [2:0];
reg [127:0] line_buffer_1 [2:0];
reg [127:0] line_buffer_2 [2:0];
reg [127:0] line_buffer_3;
reg [127:0] se;
wire [127:0] dil_se;
wire ero_dil_op;
wire [127:0] window_se;
wire [127:0] window_pic [15:0];
wire [7:0] ero_dil_out [15:0];

// wire [7:0] dil_pixal [15:0];
// wire [7:0] se_pixal [15:0];
wire [1:0] zero_cnt;
wire line_buffer_en;
wire ero_dil_sram_w_en;
wire [7:0] ero_dil_sram_w_index;
reg [8:0]ero_dil_write_cnt;
reg handshack;
genvar i, j;
//================================
// FSM
//================================
reg [3:0] n_state, c_state;
parameter ST_IDLE = 'd0,
          ST_INPUT = 'd1,
          // ST_READ = 'd6,
          ST_RUN_E = 'd2,
          ST_RUN_D = 'd3,
          ST_RUN_HE = 'd4,
          ST_WRITE = 'd5,
          ST_SE = 'd6,
          ST_WAIT_SE = 'd7,
          // ST_RUN_CDF_HE = 'd9,
          ST_WRTIE_HE = 'd8;
/* FSM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end
always @(*) begin
    case (c_state)
        ST_IDLE: begin
            if(in_valid) n_state = ST_INPUT;
            else n_state = ST_IDLE;
        end
        ST_INPUT: begin
            if(in_op == 2'b00) n_state = ST_SE;
            else if(in_op == 2'b01) n_state = ST_SE;
            else n_state = ST_RUN_HE;
        end
        ST_SE: begin
            if(read_valid) begin
                n_state = ST_WAIT_SE;
                // if(op == 2'b00) n_state = ST_RUN_E;
                // else n_state = ST_RUN_D;
            end
            else n_state = ST_SE;
        end
        ST_WAIT_SE: begin
            if(op == 2'b00) n_state = ST_RUN_E;
            else n_state = ST_RUN_D;
        end
        ST_RUN_E: begin
            if(ero_dil_cnt == 9'd270) n_state = ST_WRITE;
            else n_state = ST_RUN_E;
        end
        ST_RUN_D: begin
            if(ero_dil_cnt == 9'd270) n_state = ST_WRITE;
            else n_state = ST_RUN_D;
        end
        ST_RUN_HE: begin
            if(sum_table_cnt == 8'd255) n_state = ST_WRTIE_HE;
            else n_state = ST_RUN_HE;
        end
        // ST_RUN_CDF_HE: begin
        //     if(cdf_cnt == 8'd255) n_state = ST_WRTIE_HE;
        //     else n_state = ST_RUN_CDF_HE;
        // end
        ST_WRTIE_HE: begin
            if(he_write_cnt == 9'd258 && write_valid) n_state = ST_IDLE;
            else n_state = ST_WRTIE_HE;
        end
        ST_WRITE: begin
            if(write_cnt == 8'd255) n_state = ST_IDLE;
            else n_state = ST_WRITE;
        end
        // ST_WAIT: begin
        //     if(op == 2'b00) n_state = ST_RUN_E;
        //     else if(op == 2'b01) n_state = ST_RUN_D;
        //     else n_state = ST_RUN_HE;
        // end

        default: n_state = ST_IDLE;
    endcase
end

assign write_enable = (c_state == ST_WRITE || c_state == ST_WRTIE_HE)? 1'b1 : 1'b0;
assign read_enable = ((sum_table_cnt <= 8'd253 && c_state == ST_RUN_HE) ||(ero_dil_cnt <= 8'd255 && (c_state == ST_RUN_E || c_state == ST_RUN_D)) || (c_state == ST_SE))? 1'b1: 1'b0;
assign se_mode = (c_state == ST_SE)? 1'b1 : 1'b0;
// assign read_addr = 32'h00040000 + (in_pic * 9'd256);
// assign read_addr = {{16'h0004},in_pic,{12'h000}};

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_op <= 2'b0;
    else begin
        case (n_state)
            ST_IDLE: in_op <= 2'b0;
            ST_INPUT: in_op <= op;
            default: in_op <= in_op;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_pic <= 4'b0;
    else begin
        case (n_state)
            ST_IDLE: in_pic <= 4'b0;
            ST_INPUT: in_pic <= pic_no;
            default: in_pic <= in_pic;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) in_se <= 6'b0;
    else begin
        case (n_state)
            ST_IDLE: in_se <= 6'b0;
            ST_INPUT: in_se <= se_no;
            default: in_se <= in_se;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) busy <= 1'b0;
    else begin
        case (n_state)
            ST_IDLE: busy <= 1'b0;
            ST_INPUT: busy <= 1'b0;
            default: busy <= 1'b1;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) sram_out_cnt <= 10'b0;
    else begin
        case (n_state)
            ST_WRITE: begin
                if(write_valid) sram_out_cnt <= sram_out_cnt + 1;
                else sram_out_cnt <= sram_out_cnt;
            end
            default: sram_out_cnt <= 10'b0;
        endcase
    end
end

// assign sram_in_d = {read_out[127:96], read_out[95:64], read_out[63:32], read_out[0:31]};
// assign sram_in_d = {read_out[31:0], read_out[63:32], read_out[95:64], read_out[127:96]};



/* Histogram Equalization */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) read_pic_cnt_delay1 <= 8'b0;
    else begin
        case (n_state)
            ST_IDLE: read_pic_cnt_delay1 <= 8'b0;
            ST_RUN_HE: read_pic_cnt_delay1 <= read_cnt;
            default: read_pic_cnt_delay1 <= 8'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) sum_table_cnt <= 8'b0;
    else begin
        case (n_state)
            ST_IDLE: sum_table_cnt <= 8'b0;
            ST_RUN_HE: sum_table_cnt <= read_pic_cnt_delay1;
            default: sum_table_cnt <= 8'b0;
        endcase
    end
end
// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n) cdf_cnt <= 9'd0;
//     else begin
//         case (n_state)
//             ST_RUN_CDF_HE: cdf_cnt <= cdf_cnt + 1'b1;
//             default: cdf_cnt <= 9'b0;
//         endcase
//     end
// end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) read_valid_delay1 <= 1'b0;
    else begin
        case (n_state)
            ST_RUN_HE: read_valid_delay1 <= read_valid;
            default: read_valid_delay1 <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dram_read_out <= 128'b0;
    else dram_read_out <= read_out;
end
generate
    for(i = 0; i < 16; i = i + 1) begin
        assign pixal[i] = dram_read_out[((8 * (i + 1)) - 1) : 8 * i];
    end
endgenerate
generate
    for(i = 0; i < 16; i = i + 1) begin
        for (j = 0; j < 256 ; j = j + 1) begin
            assign value_wire[i][j] = (pixal[i] <= j)? 1'b1 : 1'b0;
        end
    end
endgenerate
generate
    for(i = 0; i < 256; i = i + 1) begin
        assign sum_wire[i] = value_wire[0][i] + value_wire[1][i] + value_wire[2][i] + value_wire[3][i]
                             + value_wire[4][i] + value_wire[5][i] + value_wire[6][i] + value_wire[7][i]
                             + value_wire[8][i] + value_wire[9][i] + value_wire[10][i] + value_wire[11][i]
                             + value_wire[12][i] + value_wire[13][i] + value_wire[14][i] + value_wire[15][i];
    end
endgenerate
generate
    for(i = 0; i < 256; i = i + 1) begin
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) sum_table[i] <= 12'b0;
            else begin
                case (n_state)
                    ST_RUN_HE: begin
                        if(read_valid_delay1) sum_table[i] <= sum_table[i] + sum_wire[i];
                        else sum_table[i] <= sum_table[i];
                        
                    end 
                    // ST_RUN_CDF_HE: sum_table[i] <= sum_table[i];
                    ST_WRTIE_HE: sum_table[i] <= sum_table[i];
                    default: sum_table[i] <= 12'b0;
                endcase
            end
        end
    end
endgenerate
// assign k = sum_table[cdf_cnt];


COMPARE_16 U_comp_min_pixal(
    /* input */
    .in1(pixal[0]), .in2(pixal[1]), .in3(pixal[2]), .in4(pixal[3]),
    .in5(pixal[4]), .in6(pixal[5]), .in7(pixal[6]), .in8(pixal[7]),
    .in9(pixal[8]), .in10(pixal[9]), .in11(pixal[10]), .in12(pixal[11]),
    .in13(pixal[12]), .in14(pixal[13]), .in15(pixal[14]), .in16(pixal[15]),
    .op(1'b0),
    /* output */
    .out(min_pixal)
);
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) min_index <= 8'b0;
    else begin
        case (n_state)
        ST_RUN_HE: begin
            if(min_pixal < min_index && read_valid_delay1) min_index <= min_pixal;
            else min_index <= min_index;
        end
        ST_WRTIE_HE: min_index <= min_index;
        default: min_index <= 8'd255;
        endcase
    end
end

// always @(posedge clk or negedge rst_n) begin
//     if(!rst_n) min <= 13'd0;
//     else min <= sum_table[min_index];
    
// end

always @(*) begin
    min = sum_table[min_index];
end

// assign max_min = 13'd4096 - min;


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) max_min <= 12'd0;
    else begin
        max_min <= 13'd4096 - min;
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_write_cnt_eq2_flag <= 1'b0;
    else begin
        case (n_state)
            ST_WRTIE_HE: begin
                if(he_write_cnt == 2'd3) he_write_cnt_eq2_flag <= 1'b1;
                else he_write_cnt_eq2_flag <= he_write_cnt_eq2_flag;
            end 
            default: he_write_cnt_eq2_flag <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) sram_out_data <= 128'b0;
    else begin
        case (n_state)
            ST_WRTIE_HE: begin
                if(write_valid) sram_out_data <= sram_in_q;
                else if(he_write_cnt <= 2'd3) begin
                    if(!he_write_cnt_eq2_flag) sram_out_data <= sram_in_q;
                    else sram_out_data <= sram_out_data;
                    // if(sram_out_data == dram_write_data) 
                    // else sram_out_data <= sram_out_data;
                end
                else sram_out_data <= sram_out_data;
            end
            default: sram_out_data <= sram_in_q;
        endcase
    end
end

generate
for(i = 0; i < 16; i = i + 1) begin
    assign he_cdf[i] = sum_table[sram_out_data[((8 * (i + 1)) - 1) : 8 * i]] - min;
end
endgenerate

generate
for(i = 0; i < 16; i = i + 1) begin
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) he_pixal_mult[i] <= 21'b0;
        else begin
            case (n_state)
            ST_WRTIE_HE: begin
                if(write_valid) he_pixal_mult[i] <= he_cdf[i] * 8'd255;
                else if (he_write_cnt <= 3'd3) begin
                    if(!he_write_cnt_eq2_flag) he_pixal_mult[i] <= he_cdf[i] * 8'd255;
                    else he_pixal_mult[i] <= he_pixal_mult[i];
                end
                else he_pixal_mult[i] <= he_pixal_mult[i];
            end 
            default: he_pixal_mult[i] <= 21'b0;
            endcase
        end
    end
end
endgenerate


// generate
//     for(i = 0; i < 16; i = i + 1) begin
//         assign he_pixal_shift[i] = he_cdf[i] * 8'd255;
//     end
// endgenerate

generate
    for(i = 0; i < 16; i = i + 1) begin
        assign he_pixal_div[i] = he_pixal_mult[i] / max_min;
    end
endgenerate

always @(*) begin
    if(!rst_n) sram_out_outdata = 128'b0;
    else begin
        sram_out_outdata = {he_pixal_div[15], he_pixal_div[14], he_pixal_div[13],
                                            he_pixal_div[12], he_pixal_div[11], he_pixal_div[10],
                                            he_pixal_div[9], he_pixal_div[8], he_pixal_div[7],
                                            he_pixal_div[6], he_pixal_div[5], he_pixal_div[4],
                                            he_pixal_div[3], he_pixal_div[2], he_pixal_div[1],
                                            he_pixal_div[0]};
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) dram_write_data <= 128'b0;
    else begin
        case (n_state)
            ST_WRITE: begin
                
                if(handshack) dram_write_data <= sram_in_q;
                else if(ero_dil_write_cnt < 1'b1) dram_write_data <= sram_in_q;
                else dram_write_data <= dram_write_data;
                //else dram_write_data <= sram_in_q;
            end
            ST_WRTIE_HE: begin
                if(write_valid) dram_write_data <= sram_out_outdata;
                else if(he_write_cnt < 3) dram_write_data <= sram_out_outdata;
                else dram_write_data <= dram_write_data;
            end 
            default: dram_write_data <= 128'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) handshack <= 1'b0;
    else handshack <= write_valid;
end
always @(*) begin
   
    case (c_state)
        ST_WRITE: begin
            if(handshack && ero_dil_write_cnt > 1'b1 ) dram_write_data_wire = sram_in_q;
            else dram_write_data_wire = dram_write_data;
        end
        ST_WRTIE_HE: begin
            dram_write_data_wire = dram_write_data;
        end 
        default: dram_write_data_wire = 12'b0;
    endcase

end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) he_write_cnt <= 9'b0;
    else begin
        case (n_state)
            ST_WRTIE_HE: begin
                if(write_valid) he_write_cnt <= he_write_cnt + 1'b1;
                else if(he_write_cnt < 2'd3) he_write_cnt <= he_write_cnt + 1'b1;
                else he_write_cnt <= he_write_cnt;
            end
            default: he_write_cnt <= 9'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_dil_write_cnt <= 9'b0;
    else begin
        case (n_state)
            ST_WRITE: begin
                if(c_state != ST_RUN_E && c_state != ST_RUN_D) begin
                    if(write_valid) ero_dil_write_cnt <= ero_dil_write_cnt + 1'b1;
                    else if(ero_dil_write_cnt < 1'd1) ero_dil_write_cnt <= ero_dil_write_cnt + 1'b1;
                    else ero_dil_write_cnt <= ero_dil_write_cnt;
                end
                else ero_dil_write_cnt <= 9'b0;
            end
            default: ero_dil_write_cnt <= 9'b0;
        endcase
    end
end
RA1SH Usram_in(.Q(sram_in_q), .CLK(clk), .CEN(1'b0), .WEN(sram_in_wen), .A(sram_in_index), .D(sram_in_d), .OEN(1'b0));

always @(*) begin
    case (c_state)
        ST_SE: sram_in_index = read_cnt[7:0];
        ST_WRTIE_HE: begin
            if(he_write_cnt <= 8'd255) sram_in_index = he_write_cnt[7:0];
            else sram_in_index = 8'd255;
        end
        ST_RUN_E: sram_in_index = ero_dil_sram_w_index;
        ST_RUN_D: sram_in_index = ero_dil_sram_w_index;
        ST_WRITE: begin
            if(ero_dil_write_cnt <= 8'd255) sram_in_index = ero_dil_write_cnt[7:0];
            else sram_in_index = 8'd255;
        end
        default: sram_in_index = read_cnt[7:0];
    endcase
end
always @(*) begin
    case (c_state)
        ST_RUN_D: sram_in_wen = ero_dil_sram_w_en;
        ST_RUN_E: sram_in_wen = ero_dil_sram_w_en;
        ST_RUN_HE: begin 
            if(sum_table_cnt <= 253) sram_in_wen = 1'b0;
            else sram_in_wen = 1'b1;
        end
        default: sram_in_wen = 1'b1;
    endcase
end
always @(*) begin
    case (c_state)
        ST_RUN_D: sram_in_d = {ero_dil_out[15], ero_dil_out[14], ero_dil_out[13], ero_dil_out[12],
                              ero_dil_out[11], ero_dil_out[10], ero_dil_out[9], ero_dil_out[8],
                              ero_dil_out[7], ero_dil_out[6], ero_dil_out[5], ero_dil_out[4],
                              ero_dil_out[3], ero_dil_out[2], ero_dil_out[1], ero_dil_out[0]};
        ST_RUN_E: sram_in_d = {ero_dil_out[15], ero_dil_out[14], ero_dil_out[13], ero_dil_out[12],
                              ero_dil_out[11], ero_dil_out[10], ero_dil_out[9], ero_dil_out[8],
                              ero_dil_out[7], ero_dil_out[6], ero_dil_out[5], ero_dil_out[4],
                              ero_dil_out[3], ero_dil_out[2], ero_dil_out[1], ero_dil_out[0]};
        ST_RUN_HE: begin 
            sram_in_d = read_out;
        end
        default: sram_in_d = 8'b0;
    endcase
end

always @(*) begin
    case (c_state)
        ST_WRTIE_HE: begin
            if (he_write_cnt >= 2'd3 && write_cnt <= 8'd255) begin
                if(write_valid) write_data_valid = 1'b0;
                else write_data_valid = 1'b1;
            end
            else write_data_valid = 1'b0;
        end
        ST_WRITE: begin
            if(ero_dil_write_cnt >= 1'b1 && write_cnt <= 8'd255) begin
                write_data_valid = 1'b1;
            end
            else write_data_valid = 1'b0;
        end
        default: write_data_valid = 1'b0;
    endcase
end



/* Erosion and Dilation */
/* Read SE for Erosion and Dilation */


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) se <= 128'b0;
    else begin
        case (n_state)
            ST_RUN_E: begin
                se <= se;
                // if(c_state == ST_SE) se <= read_out;
                // else se <= se;
            end 
            ST_RUN_D: begin
                se <= se;
                // if(c_state == ST_SE) se <= read_out;
                // else se <= se;
            end
            ST_WAIT_SE: se <= read_out;       
            default: se <= 128'b0;
        endcase
    end
end

assign dil_se = {se[7:0], se[15:8], se[23:16], se[31:24], se[39:32], se[47:40], se[55:48], se[63:56], 
                se[71:64], se[79:72], se[87:80], se[95:88], se[103:96], se[111:104], se[119:112], se[127:120]};

assign window_se = (in_op == 2'b00)? se : dil_se;

// generate
//     for(i = 0; i < 16; i = i + 1) begin
//         assign dil_pixal[i] = se[(8 * (i + 1)) - 1 : 8 * i];
//     end
// endgenerate
// generate
//     for(i = 0; i < 16; i = i + 1) begin
//         assign se_pixal[i] = (in_op == 2'b01)? se_pixal[i] : se_pixal[16 - i];
//     end
// endgenerate
assign zero_cnt = ero_dil_cnt[1:0];

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) ero_dil_cnt <= 9'b0;
    else begin
        case (n_state)
            ST_RUN_E: begin
                if(ero_dil_cnt <= 8'd255) begin
                    if(read_valid) ero_dil_cnt <= ero_dil_cnt + 1'b1;
                    else ero_dil_cnt <= ero_dil_cnt;
                end
                else ero_dil_cnt <= ero_dil_cnt + 1'b1;
            end 
            ST_RUN_D: begin
                if(ero_dil_cnt <= 8'd255) begin
                    if(read_valid) ero_dil_cnt <= ero_dil_cnt + 1'b1;
                    else ero_dil_cnt <= ero_dil_cnt;
                end
                else ero_dil_cnt <= ero_dil_cnt + 1'b1;
            end
            default: ero_dil_cnt <= 9'b0;
        endcase
    end
end

// line buffer and windows
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) window[0] <= 151'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 8'd255) begin
                if(read_valid) begin
                    if(zero_cnt == 2'b00) window[0] <= {24'b0 ,line_buffer_0[0]};
                    else window[0] <= {line_buffer_0[1][23:0] ,line_buffer_0[0]};
                end
                else window[0] <= window[0];
            end
            else begin
                if(zero_cnt == 2'b00) window[0] <= {24'b0 ,line_buffer_0[0]};
                else window[0] <= {line_buffer_0[1][23:0] ,line_buffer_0[0]};
            end
        end
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) window[1] <= 151'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 8'd255) begin
                if(read_valid) begin
                    if(zero_cnt == 2'b00) window[1] <= {24'b0 ,line_buffer_1[0]};
                    else window[1] <= {line_buffer_1[1][23:0] ,line_buffer_1[0]};
                end
                else window[1] <= window[1];
            end
            else begin
                if(zero_cnt == 2'b00) window[1] <= {24'b0 ,line_buffer_1[0]};
                else window[1] <= {line_buffer_1[1][23:0] ,line_buffer_1[0]};
            end
        end
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) window[2] <= 151'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 8'd255) begin
                if(read_valid) begin
                    if(zero_cnt == 2'b00) window[2] <= {24'b0 ,line_buffer_2[0]};
                    else window[2] <= {line_buffer_2[1][23:0] ,line_buffer_2[0]};
                end
                else window[2] <= window[2];
            end
            else begin
                if(zero_cnt == 2'b00) window[2] <= {24'b0 ,line_buffer_2[0]};
                else window[2] <= {line_buffer_2[1][23:0] ,line_buffer_2[0]};
            end
        end
        endcase
    end 
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) window[3] <= 151'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 8'd255) begin
                if(read_valid) begin
                    if(zero_cnt == 2'b00) window[3] <= {24'b0 ,line_buffer_3};
                    else window[3] <= {read_out[23:0] ,line_buffer_3};
                end
                else window[3] <= window[3];
            end
            else begin
                if(zero_cnt == 2'b00) window[3] <= {24'b0 ,line_buffer_3};
                else window[3] <= {read_out[23:0] ,line_buffer_3};
            end
        end
        endcase
    end
end


// line buffer 00
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_0[0] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_0[0] <= line_buffer_0[1];
                else line_buffer_0[0] <= line_buffer_0[0];
            end
            else line_buffer_0[0] <= line_buffer_0[1];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_0[1] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_0[1] <= line_buffer_0[2];
                else line_buffer_0[1] <= line_buffer_0[1];
            end
            else line_buffer_0[1] <= line_buffer_0[2];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_0[2] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_0[2] <= window[1][127:0];
                else line_buffer_0[2] <= line_buffer_0[2];
            end
            else line_buffer_0[2] <= window[1][127:0];
        end
        endcase
    end
end
// line buffer 01
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_1[0] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_1[0] <= line_buffer_1[1];
                else line_buffer_1[0] <= line_buffer_1[0];
            end
            else line_buffer_1[0] <= line_buffer_1[1];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_1[1] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_1[1] <= line_buffer_1[2];
                else line_buffer_1[1] <= line_buffer_1[1];
            end
            else line_buffer_1[1] <= line_buffer_1[2];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_1[2] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_1[2] <= window[2][127:0];
                else line_buffer_1[2] <= line_buffer_1[2];
            end
            else line_buffer_1[2] <= window[2][127:0];
        end
        endcase
    end
end
// line buffer 02
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_2[0] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_2[0] <= line_buffer_2[1];
                else line_buffer_2[0] <= line_buffer_2[0];
            end
            else line_buffer_2[0] <= line_buffer_2[1];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_2[1] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_2[1] <= line_buffer_2[2];
                else line_buffer_2[1] <= line_buffer_2[1];
            end
            else line_buffer_2[1] <= line_buffer_2[2];
        end
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_2[2] <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_2[2] <= window[3][127:0];
                else line_buffer_2[2] <= line_buffer_2[2];
            end
            else line_buffer_2[2] <= window[3][127:0];
        end
        endcase
    end
end
// line buffer 03
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) line_buffer_3 <= 128'b0;
    else begin
        case (n_state)
        default: begin
            if(ero_dil_cnt <= 'd255) begin
                if(read_valid) line_buffer_3 <= read_out;
                else line_buffer_3 <= line_buffer_3;
            end
            else line_buffer_3 <= 1'b0;
        end
        endcase
    end
end


generate
    for(i = 0; i < 16; i = i + 1) begin
        assign window_pic[i] = {window[3][((8 * i) + 31): 8 * i ], window[2][((8 * i) + 31): 8 * i], window[1][((8 * i) + 31): 8 * i], window[0][((8 * i) + 31): 8 * i]};
    end
endgenerate

generate
    for(i = 0; i < 16; i = i + 1) begin
        ERO_DIL U_erodli(.pic(window_pic[i]), .se(window_se), .op(ero_dil_op), .out(ero_dil_out[i]));
    end
endgenerate
assign ero_dil_op = (in_op == 1'b0)? 1'b0: 1'b1;
assign ero_dil_sram_w_en = (ero_dil_cnt >= 4'd14 && ero_dil_cnt <= 9'd269)? 1'b0 : 1'b1;
assign ero_dil_sram_w_index = (ero_dil_cnt >= 4'd14 && ero_dil_cnt <= 9'd269) ? ero_dil_cnt - 4'd14 : 8'b0;







AXI4_READ_CHANNEL Uaxi4_read(
    /* input */
    .clk(clk), .rst_n(rst_n), .en(read_enable), .pic(in_pic), .se(in_se), .mode(se_mode),

    /* output */
    .read_out(read_out), .read_valid(read_valid), .counter(read_cnt),

    /* DRAM axi4 read address channel input */
    .arready_m_inf(arready_m_inf),

    /* DRAM axi4 read address channel output */
    .arid_m_inf(arid_m_inf),
    .araddr_m_inf(araddr_m_inf),
    .arlen_m_inf(arlen_m_inf),
    .arsize_m_inf(arsize_m_inf),
    .arburst_m_inf(arburst_m_inf),
    .arvalid_m_inf(arvalid_m_inf),

    /* DRAM axi4 read data channel input */
    .rid_m_inf(rid_m_inf),
    .rdata_m_inf(rdata_m_inf),
    .rresp_m_inf(rresp_m_inf),
    .rlast_m_inf(rlast_m_inf),
    .rvalid_m_inf(rvalid_m_inf),
    /* DRAM axi4 read data channel output */
    .rready_m_inf(rready_m_inf)
);

AXI4_WRITE_CHANNEL Uaxi4_write(
    /* input */
    .clk(clk), .rst_n(rst_n), .en(write_enable), .pic(in_pic), .write_data(dram_write_data_wire),
    .write_data_valid(write_data_valid),
    /* output */
    .write_valid(write_valid), .counter(write_cnt),

    /* DRAM axi4 write address channel input */
    .awready_m_inf(awready_m_inf),

    /* DRAM axi4 write address channel output */
    .awid_m_inf(awid_m_inf),
    .awaddr_m_inf(awaddr_m_inf),
    .awsize_m_inf(awsize_m_inf),
    .awburst_m_inf(awburst_m_inf),
    .awlen_m_inf(awlen_m_inf),
    .awvalid_m_inf(awvalid_m_inf),

    /* DRAM axi4 write data channel input */
    .wready_m_inf(wready_m_inf),

    /* DRAM axi4 write data channel output */
    .wdata_m_inf(wdata_m_inf),
    .wlast_m_inf(wlast_m_inf),
    .wvalid_m_inf(wvalid_m_inf),
    
    /* DRAM axi4 write response channel input */
    .bid_m_inf(bid_m_inf),
    .bresp_m_inf(bresp_m_inf),
    .bvalid_m_inf(bvalid_m_inf),
    
    /* DRAM axi4 write response channel output */
    .bready_m_inf(bready_m_inf)
);

endmodule



module AXI4_READ_CHANNEL(
    /* input */
    clk, rst_n, en, pic, se, mode,
    /* output */
    read_out, read_valid, counter,
    /* DRAM axi4 read address channel input */
    arready_m_inf,
    /* DRAM axi4 read address channel output */
    arid_m_inf,
    araddr_m_inf,
    arlen_m_inf,
    arsize_m_inf,
    arburst_m_inf,
    arvalid_m_inf,

    /* DRAM axi4 read data channel input */
    rid_m_inf,
    rdata_m_inf,
    rresp_m_inf,
    rlast_m_inf,
    rvalid_m_inf,
    /* DRAM axi4 read data channel output */
    rready_m_inf
);
parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;

/* DRAM axi4 read address channel */
output wire    [ID_WIDTH-1:0]      arid_m_inf; // 4'b0
output wire    [ADDR_WIDTH-1:0]   araddr_m_inf;
output wire    [7:0]              arlen_m_inf; // (mode?) 8'd63 : 8'd255;
output wire    [2:0]             arsize_m_inf; // 128bits = 16bytes
output wire    [1:0]            arburst_m_inf; // INCR mode 2'b01
output reg                      arvalid_m_inf;
input wire                      arready_m_inf;

/* DRAM axi4 read data channel */
input wire [ID_WIDTH-1:0]           rid_m_inf;
input wire [DATA_WIDTH-1:0]       rdata_m_inf;
input wire [1:0]                  rresp_m_inf;
input wire                        rlast_m_inf;
input wire                       rvalid_m_inf;
output reg                       rready_m_inf;

input wire clk, rst_n, en;
input wire mode; // 1 -> se, 0 -> pic
input wire [3:0] pic;
input [5:0] se;
output reg [DATA_WIDTH-1:0] read_out;
output reg read_valid;
output reg [11:0] counter;

/* FSN Declare */
reg [3:0] c_state, n_state;

/* reg & wire */

parameter ST_IDLE = 'd0, ST_ADDR = 'd1, ST_DATA ='d2, ST_LAST = 'd3, ST_WAIT = 'd4;
/* FSM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end
always @(*) begin
    case (c_state)
        ST_IDLE: begin
            if(en) n_state = ST_ADDR;
            else n_state = ST_IDLE;
        end
        ST_ADDR: begin
            if(arready_m_inf) begin
                n_state = ST_DATA;
                // if(rvalid_m_inf) n_state = ST_DATA;
                // else n_state = ST_WAIT;
            end
            else n_state = ST_ADDR;
        end
        ST_DATA: begin
            if(rlast_m_inf) n_state = ST_LAST;
            else n_state = ST_DATA;
            // else if(rvalid_m_inf) n_state = ST_DATA;
            // else n_state = ST_WAIT;
        end
        // ST_WAIT: begin
        //     if(rvalid_m_inf) n_state = ST_DATA;
        //     else n_state = ST_WAIT;
        // end
        default: begin
            n_state = ST_IDLE;
        end 
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 12'b0;
    else begin
        case (n_state)
            ST_DATA: begin
                if(rvalid_m_inf) counter <= counter + 1'b1; 
                else counter <= counter;
            end
            default: counter <= 12'b0; 
        endcase
    end
end
assign arid_m_inf = 4'b0;
assign arlen_m_inf = (mode)? 8'd0 : 8'd255;
assign arsize_m_inf = 3'b100;
assign arburst_m_inf = 2'b01;

assign araddr_m_inf = (mode)? {20'h00030, 2'b0, se, 4'b0} : {{16'h0004},pic,{12'h000}};

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) arvalid_m_inf <= 1'b0;
    else begin
        case (n_state)
            ST_ADDR: arvalid_m_inf <= 1'b1;
            default: arvalid_m_inf <= 1'b0;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) rready_m_inf <= 1'b0;
    else begin
        case (n_state)
            ST_DATA: rready_m_inf <= 1'b1;
            // ST_WAIT: rready_m_inf <= 1'b1;
            default: rready_m_inf <= 1'b0;
        endcase
    end
end
always @(*) begin
    if(c_state == ST_DATA && rvalid_m_inf) read_out = rdata_m_inf;
    else read_out = 128'b0;
end
always @(*) begin
    if(c_state == ST_DATA && rvalid_m_inf) read_valid = 1'b1;
    else read_valid = 1'b0;
end


endmodule


module AXI4_WRITE_CHANNEL(
    /* input */
    clk, rst_n, en, pic, write_data, write_data_valid,
    /* output */
    write_valid, counter,

    /* DRAM axi4 write address channel input */
    awready_m_inf,

    /* DRAM axi4 write address channel output */
    awid_m_inf,
    awaddr_m_inf,
    awsize_m_inf,
    awburst_m_inf,
    awlen_m_inf,
    awvalid_m_inf,

    /* DRAM axi4 write data channel input */
    wready_m_inf,

    /* DRAM axi4 write data channel output */
    wdata_m_inf,
    wlast_m_inf,
    wvalid_m_inf,
    
    /* DRAM axi4 write response channel input */
    bid_m_inf,
    bresp_m_inf,
    bvalid_m_inf,
    
    /* DRAM axi4 write response channel output */
    bready_m_inf
);

parameter ID_WIDTH = 4 , ADDR_WIDTH = 32, DATA_WIDTH = 128;
input wire clk, rst_n, en, write_data_valid;
input wire [3:0] pic;
input wire [DATA_WIDTH-1:0] write_data;
output reg write_valid;
output reg [11:0] counter;
/* DRAM axi write address channel */
output wire [ID_WIDTH-1:0]     awid_m_inf;  // 4'b0
output wire [ADDR_WIDTH-1:0] awaddr_m_inf;
output wire [2:0]            awsize_m_inf; // 128bits = 16bytes
output wire [1:0]           awburst_m_inf; // INCR mode 2'b01
output wire [7:0]             awlen_m_inf; // 8'd255;
output reg                 awvalid_m_inf;
input wire                 awready_m_inf;

/* DRAM axi4 write data channel */
output reg [DATA_WIDTH-1:0]  wdata_m_inf;
output reg                   wlast_m_inf;
output reg                  wvalid_m_inf;
input wire                  wready_m_inf;

/* DRAM axi4 write response channel */
input wire [ID_WIDTH-1:0]      bid_m_inf;
input wire [1:0]             bresp_m_inf;
input wire                  bvalid_m_inf;
output wire                 bready_m_inf;

/* FSN Declare */
reg [3:0] c_state, n_state;
/* reg & wire */

parameter ST_IDLE = 'd0, ST_ADDR = 'd1, ST_DATA ='d2, ST_WAIT = 'd3;

assign awid_m_inf = 4'b0;
assign awsize_m_inf = 3'b100; // 128bits = 16bytes
assign awburst_m_inf = 2'b01; // INCR mode 2'b01
assign awlen_m_inf = 8'd255;
assign bready_m_inf = 1'b1;
assign awaddr_m_inf = {{16'h0004},pic,{12'h000}};
/* FSM */
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end
always @(*) begin
    case (c_state)
        ST_IDLE: begin
            if(en) n_state = ST_ADDR;
            else n_state = ST_IDLE;
        end
        ST_ADDR: begin
            if(awready_m_inf) n_state = ST_DATA;
            else n_state = ST_ADDR;
        end
        ST_DATA: begin
            if(counter == 8'd255 && wready_m_inf && wvalid_m_inf) n_state = ST_IDLE;
            else n_state = ST_DATA;
        end
        default: begin
            n_state = ST_IDLE;
        end 
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) wvalid_m_inf <= 1'b0;
    else begin
        case (n_state)
            ST_DATA: begin
                // wvalid_m_inf <= 1'b1;
                if(write_data_valid) wvalid_m_inf <= 1'b1;
                else wvalid_m_inf <= 1'b0;
            end
            default: wvalid_m_inf <= 1'b0;
        endcase
    end
end

always @(*) begin
    case (c_state)
        ST_DATA: begin
            if(counter == 8'd255) wlast_m_inf = 1'b1;
            else wlast_m_inf = 1'b0;
        end
        default: wlast_m_inf = 1'b0;
    endcase
end

always @(*) begin
    wdata_m_inf = write_data;
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) awvalid_m_inf <= 1'b0;
    else begin
        case (n_state)
            ST_ADDR: awvalid_m_inf <= 1'b1;
            default: awvalid_m_inf <= 1'b0;
        endcase
    end
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) counter <= 12'b0;
    else begin
        case (n_state)
            ST_DATA: begin
                if(wready_m_inf && wvalid_m_inf) counter <= counter + 1'b1; 
                else counter <= counter;
            end
            default: counter <= 12'b0; 
        endcase
    end
end

always @(*) begin
    if(c_state == ST_DATA && wready_m_inf && wvalid_m_inf) write_valid = 1'b1;
    else write_valid = 1'b0;
end

endmodule

module COMPARE(
    /* input */
    a, b, op,
    /* output */
    out
);
input [7:0] a, b;
input op;   // 1 -> larger, 0 -> smaller
output reg [7:0] out;

always @(*) begin
    case (op)
        1'b0: begin
            if(a <= b) out = a;
            else out = b;
        end
        1'b1: begin
            if(a <= b) out = b;
            else out = a;
        end  
    endcase
end
endmodule

module COMPARE_16(
    /* input */
    in1, in2, in3, in4,
    in5, in6, in7, in8,
    in9, in10, in11, in12,
    in13, in14, in15, in16,
    op,
    /* output */
    out
);
input [7:0] in1, in2, in3, in4,
            in5, in6, in7, in8,
            in9, in10, in11, in12,
            in13, in14, in15, in16;
input op;   // 1 -> larger, 0 -> smaller
output wire [7:0] out;
wire [7:0] out1[7:0];
wire [7:0] out2[3:0];
wire [7:0] out3[1:0];

COMPARE U1_1(.a(in1), .b(in2), .op(op), .out(out1[0]));
COMPARE U1_2(.a(in3), .b(in4), .op(op), .out(out1[1]));
COMPARE U1_3(.a(in5), .b(in6), .op(op), .out(out1[2]));
COMPARE U1_4(.a(in7), .b(in8), .op(op), .out(out1[3]));
COMPARE U1_5(.a(in9), .b(in10), .op(op), .out(out1[4]));
COMPARE U1_6(.a(in11), .b(in12), .op(op), .out(out1[5]));
COMPARE U1_7(.a(in13), .b(in14), .op(op), .out(out1[6]));
COMPARE U1_8(.a(in15), .b(in16), .op(op), .out(out1[7]));

COMPARE U2_1(.a(out1[0]), .b(out1[1]), .op(op), .out(out2[0]));
COMPARE U2_2(.a(out1[2]), .b(out1[3]), .op(op), .out(out2[1]));
COMPARE U2_3(.a(out1[4]), .b(out1[5]), .op(op), .out(out2[2]));
COMPARE U2_4(.a(out1[6]), .b(out1[7]), .op(op), .out(out2[3]));

COMPARE U3_1(.a(out2[0]), .b(out2[1]), .op(op), .out(out3[0]));
COMPARE U3_2(.a(out2[2]), .b(out2[3]), .op(op), .out(out3[1]));

COMPARE U4_1(.a(out3[0]), .b(out3[1]), .op(op), .out(out));
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


 module ERO_DIL (
    /* input */
    pic, se, op,
    
    /* output */
    out
 );
input [127:0] pic;
input [127:0] se;
input op;
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
generate
    for(i = 0; i < 16; i  = i + 1) begin
        SUB U_sub(.a(pic_pixal[i]), .b(se_pixal[i]), .out(sub_out[i]));
    end
endgenerate
generate
    for(i = 0; i < 16; i  = i + 1) begin
        assign compare_in[i] = (op == 1'b0)? sub_out[i] : add_out[i];
    end
endgenerate

COMPARE_16 U_comapre16(
    .in1(compare_in[0]), .in2(compare_in[1]), .in3(compare_in[2]), .in4(compare_in[3]),
    .in5(compare_in[4]), .in6(compare_in[5]), .in7(compare_in[6]), .in8(compare_in[7]),
    .in9(compare_in[8]), .in10(compare_in[9]), .in11(compare_in[10]), .in12(compare_in[11]),
    .in13(compare_in[12]), .in14(compare_in[13]), .in15(compare_in[14]), .in16(compare_in[15]),
    .op(op),
    .out(out)
);


endmodule
