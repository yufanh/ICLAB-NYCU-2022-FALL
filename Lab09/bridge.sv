module bridge(input clk, INF.bridge_inf inf);

//================================================================
// logic 
//================================================================
logic [63:0] data;
//================================================================
// state 
//================================================================
typedef enum logic [2:0] {ST_IDLE   = 3'd0,
                          ST_R_ADDR= 3'd1,
                          ST_R_DATA  = 3'd2,
                          ST_R_FINISH = 3'd3,
                          ST_W_ADDR = 3'd4,
                          ST_W_DATA  = 3'd5,
                          ST_W_FINISH = 3'd6} state;
state c_state, n_state;
//================================================================
//   FSM
//================================================================
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end

always_comb begin
    case (c_state)
    ST_IDLE: begin
        if(inf.C_in_valid) begin
            if(inf.C_r_wb) n_state = ST_R_ADDR;
            else n_state = ST_W_ADDR;
        end
        else n_state = ST_IDLE;
    end
    ST_R_ADDR: begin
        if(inf.AR_READY) n_state = ST_R_DATA;
        else n_state = ST_R_ADDR;
    end
    ST_R_DATA: begin
        if(inf.R_VALID) n_state = ST_R_FINISH;
        else n_state = ST_R_DATA;
    end
    ST_R_FINISH: n_state = ST_IDLE;
    ST_W_ADDR: begin
        if(inf.AW_READY) n_state = ST_W_DATA;
        else n_state = ST_W_ADDR;
    end
    ST_W_DATA: begin
        if(inf.B_VALID) n_state = ST_W_FINISH;
        else n_state = ST_W_DATA;
    end
    ST_W_FINISH: n_state = ST_IDLE;
    default: n_state = ST_IDLE; 
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) data <= 64'b0;
    else begin
        case (n_state)
        ST_IDLE: data <= 64'b0;
        ST_W_ADDR: data <= inf.C_data_w;
        ST_R_FINISH: data <= inf.R_DATA;
        default: data <= data;
        endcase
    end
end
// AR_VALID
always_comb begin
    case (c_state)
    ST_R_ADDR: inf.AR_VALID = 1'b1;
    default: inf.AR_VALID = 1'b0;
    endcase
end

// AR_ADDR
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.AR_ADDR <= 17'b0;
    else begin
        case (n_state)
        ST_IDLE: inf.AR_ADDR <= 17'b0;
        ST_R_ADDR: inf.AR_ADDR <={6'b100000,inf.C_addr,3'b0};
        default: inf.AR_ADDR <= inf.AR_ADDR;
        endcase
    end
end

// R_READY
always_comb begin
    case (c_state)
    ST_R_DATA: inf.R_READY = 1'b1;
    default: inf.R_READY = 1'b0;
    endcase
end

// AW_VALID
always_comb begin
    case (c_state)
    ST_W_ADDR: inf.AW_VALID = 1'b1;
    default: inf.AW_VALID = 1'b0;
    endcase
end

// AW_ADDR
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.AW_ADDR <= 17'b0;
    else begin
        case (n_state)
        ST_IDLE: inf.AW_ADDR <= 17'b0;
        ST_W_ADDR: inf.AW_ADDR <={6'b100000,inf.C_addr,3'b0};
        default: inf.AW_ADDR <= inf.AW_ADDR;
        endcase
    end
end

// W_VALID
always_comb begin
    case (c_state)
    ST_W_DATA: inf.W_VALID = 1'b1;
    default: inf.W_VALID = 1'b0;
    endcase
end

// B_READY
always_comb begin
    case (c_state)
    ST_W_ADDR: inf.W_DATA = data;
    ST_W_DATA: inf.W_DATA = data;
    ST_W_FINISH: inf.W_DATA = data;
    default: inf.W_DATA = 64'b0;
    endcase
end

// W_DATA
always_comb begin
    case (c_state)
    ST_W_DATA: inf.B_READY = 1'b1;
    default: inf.B_READY = 1'b0;
    endcase
end


// C_out_valid
always_comb begin
    case (c_state)
    ST_R_FINISH: inf.C_out_valid = 1'b1;
    ST_W_FINISH: inf.C_out_valid = 1'b1;
    default: inf.C_out_valid = 1'b0;
    endcase
end

// C_data_r
always_comb begin
    case (c_state)
    ST_R_FINISH: inf.C_data_r = data;
    default: inf.C_data_r = 64'b0;
    endcase
end
endmodule
