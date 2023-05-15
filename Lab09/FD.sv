module FD(input clk, INF.FD_inf inf);
import usertype::*;

//===========================================================================
// parameter 
//===========================================================================

//===========================================================================
// FSM
//===========================================================================
typedef enum logic [4:0] {ST_IDLE   = 'd0,
                          ST_IN = 'd1,
                          ST_READ_D_MAN = 'd2,
                          ST_READ_RES = 'd3,
                          ST_RUN = 'd4,
                          ST_WRITE_D_MAN = 'd5,
                          ST_WRITE_RES = 'd6,
                          ST_OUT = 'd7,
                          ST_OUT_ER = 'd8,
                          ST_STORE_D_MAN = 'd9,
                          ST_STORE_RES = 'd10,
                          ST_SET_OUT_INFO = 'd11,
                          ST_CHECK_D_MAN = 'd12,
                          ST_CHECK_RES = 'd13
                          } state;
state c_state, n_state;

//===========================================================================
// logic 
//===========================================================================

Action in_act; // 
Delivery_man_id in_dman_id; // 8 bits
Restaurant_id in_res_id; // 8 bits
Ctm_Info in_ctm;
food_ID_servings in_food;
res_info decode_res_info_wire;
D_man_Info decode_d_man_info_wire;
res_info res_reg, res_reserve_reg;

res_info dram_write_res_wire;
D_man_Info dram_write_d_man_wire;


D_man_Info d_man_wire, d_man_reserve_wire;
Ctm_Info ctm1_reg, ctm2_reg, ctm1_reserve_reg, ctm2_reserve_reg;

logic [63:0] encode_dram_write_data_d_man;
logic [63:0] encode_dram_write_data_res;
logic [63:0] encode_dram_write_data_d_man_res;

logic take_if_needed, order_if_needed, write_flag;
logic correct_ctm1_rst_id, correct_ctm1_food;
logic correct_ctm2_rst_id, correct_ctm2_food;
logic ctm_empty, ctm1_empty, ctm2_empty;
logic d_man_busy, no_food;
logic [9:0] food_count;
logic id_equal_flag;
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) id_equal_flag <= 1'b0;
    else if(in_ctm.res_ID == in_dman_id) id_equal_flag <= 1'b1;
    else id_equal_flag <= 1'b0;
end
//===========================================================================
// calculate
//===========================================================================
assign d_man_wire.ctm_info1 = ctm1_reg;
assign d_man_wire.ctm_info2 = ctm2_reg;
assign d_man_reserve_wire.ctm_info1 = ctm1_reserve_reg;
assign d_man_reserve_wire.ctm_info2 = ctm2_reserve_reg;
DECODER U_decoder(
    /* input */
    .r_dram_data(inf.C_data_r),
    /* output */
    .r_rst_info(decode_res_info_wire),
    .r_div_man_info(decode_d_man_info_wire));

ENCODER U_encoder_1(
    /* input */
    .w_rst_info(res_reserve_reg),
    .w_div_man_info(d_man_wire),
    /* output */
    .w_dram_data(encode_dram_write_data_d_man));
ENCODER U_encoder_2(
    /* input */
    .w_rst_info(res_reg),
    .w_div_man_info(d_man_reserve_wire),
    /* output */
    .w_dram_data(encode_dram_write_data_res));
ENCODER U_encoder_3(
    /* input */
    .w_rst_info(res_reg),
    .w_div_man_info(d_man_wire),
    /* output */
    .w_dram_data(encode_dram_write_data_d_man_res));

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) res_reg <= 32'b0;
    else if(c_state == ST_READ_RES && inf.C_out_valid) res_reg <= decode_res_info_wire;
    else if (n_state == ST_RUN)begin
        // case (n_state)
        // ST_RUN: begin
        case (in_act)
        Take: begin
            case (in_ctm.food_ID)
            FOOD1: begin
                res_reg.ser_FOOD1 <= res_reg.ser_FOOD1 - in_ctm.ser_food;
            end
            FOOD2: res_reg.ser_FOOD2 <= res_reg.ser_FOOD2 - in_ctm.ser_food;
            FOOD3: res_reg.ser_FOOD3 <= res_reg.ser_FOOD3 - in_ctm.ser_food;
            default: res_reg <= res_reg;
            endcase
        end
        Order: begin
            case (in_food.d_food_ID)
            FOOD1: begin
                res_reg.ser_FOOD1 <= res_reg.ser_FOOD1 + in_food.d_ser_food;
            end
            FOOD2: res_reg.ser_FOOD2 <= res_reg.ser_FOOD2 + in_food.d_ser_food;
            FOOD3: res_reg.ser_FOOD3 <= res_reg.ser_FOOD3 + in_food.d_ser_food;
            default: res_reg <= res_reg;
            endcase
        end
        default: res_reg <= res_reg;
        endcase
    end
    else res_reg <= res_reg;
end 

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) res_reserve_reg <= 32'b0;
    else if(c_state == ST_READ_D_MAN && inf.C_out_valid) res_reserve_reg <= decode_res_info_wire;
    else if(n_state == ST_SET_OUT_INFO) begin
        case (in_act)
            Take: res_reserve_reg <= res_reg;
            Deliver: res_reserve_reg <= 32'b0;
            Order: res_reserve_reg <= res_reg;
            Cancel: res_reserve_reg <= 32'b0;
            default: res_reserve_reg <= res_reserve_reg;
        endcase
    end
    else res_reserve_reg <= res_reserve_reg;
end
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        ctm1_reg.ctm_status <= None;
        ctm1_reg.res_ID <= 8'b0;
        ctm1_reg.food_ID <= No_food;
        ctm1_reg.ser_food <= 4'b0;
    end
    else if(c_state == ST_READ_D_MAN && inf.C_out_valid) ctm1_reg <= decode_d_man_info_wire.ctm_info1;
    else if (n_state == ST_RUN)begin
        case (in_act)
            Take: begin
                if(ctm1_reg == 16'b0) ctm1_reg <= in_ctm;
                else if(in_ctm.ctm_status > ctm1_reg.ctm_status) ctm1_reg <= in_ctm;
                else ctm1_reg <= ctm1_reg;
            end 
            Deliver: ctm1_reg <= ctm2_reg;
            Cancel: begin
                if((correct_ctm1_rst_id && correct_ctm1_food) && (correct_ctm2_rst_id && correct_ctm2_food)) begin
                    ctm1_reg.ctm_status <= None;
                    ctm1_reg.res_ID <= 8'b0;
                    ctm1_reg.food_ID <= No_food;
                    ctm1_reg.ser_food <= 4'b0;
                end
                else if ((correct_ctm1_rst_id && correct_ctm1_food) && (!(correct_ctm2_rst_id && correct_ctm2_food))) begin
                    ctm1_reg <= ctm2_reg;
                end
                else ctm1_reg <= ctm1_reg;
            end
            default: ctm1_reg <= ctm1_reg;
        endcase
    end
    else ctm1_reg <= ctm1_reg;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        ctm2_reg.ctm_status <= None;
        ctm2_reg.res_ID <= 8'b0;
        ctm2_reg.food_ID <= No_food;
        ctm2_reg.ser_food <= 4'b0;
    end
    else if(c_state == ST_READ_D_MAN && inf.C_out_valid) ctm2_reg <= decode_d_man_info_wire.ctm_info2;
    else if (n_state == ST_RUN)begin
    case (in_act)
        Take: begin
            if(ctm1_reg == 16'b0) ctm2_reg <= 16'b0;
            else if(in_ctm.ctm_status > ctm1_reg.ctm_status) ctm2_reg <= ctm1_reg;
            else ctm2_reg <= in_ctm;
        end
        Deliver: begin
            ctm2_reg.ctm_status <= None;
            ctm2_reg.res_ID <= 8'b0;
            ctm2_reg.food_ID <= No_food;
            ctm2_reg.ser_food <= 4'b0;
        end
        Cancel: begin
            if((correct_ctm1_rst_id && correct_ctm1_food) || (correct_ctm2_rst_id && correct_ctm2_food)) begin
                ctm2_reg.ctm_status <= None;
                ctm2_reg.res_ID <= 8'b0;
                ctm2_reg.food_ID <= No_food;
                ctm2_reg.ser_food <= 4'b0;
            end
            else ctm2_reg <= ctm2_reg;
        end
        default: ctm2_reg <= ctm2_reg;
    endcase
    end
    else ctm2_reg <= ctm2_reg;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        ctm1_reserve_reg.ctm_status <= None;
        ctm1_reserve_reg.res_ID <= 8'b0;
        ctm1_reserve_reg.food_ID <= No_food;
        ctm1_reserve_reg.ser_food <= 4'b0;
    end
    else if(c_state == ST_READ_RES && inf.C_out_valid) ctm1_reserve_reg <= decode_d_man_info_wire.ctm_info1;
    else if(n_state == ST_SET_OUT_INFO) begin
        case (in_act)
            Take: ctm1_reserve_reg <= ctm1_reg;
            Deliver: ctm1_reserve_reg <= ctm1_reg;
            Order: begin
                ctm1_reserve_reg.ctm_status <= None;
                ctm1_reserve_reg.res_ID <= 8'b0;
                ctm1_reserve_reg.food_ID <= No_food;
                ctm1_reserve_reg.ser_food <= 4'b0;
            end
            Cancel: ctm1_reserve_reg <= ctm1_reg;
            default: ctm1_reserve_reg <= ctm1_reserve_reg;
        endcase
    end
    else ctm1_reserve_reg <= ctm1_reserve_reg;
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        ctm2_reserve_reg.ctm_status <= None;
        ctm2_reserve_reg.res_ID <= 8'b0;
        ctm2_reserve_reg.food_ID <= No_food;
        ctm2_reserve_reg.ser_food <= 4'b0;
    end
    else if(c_state == ST_READ_RES && inf.C_out_valid) ctm2_reserve_reg <= decode_d_man_info_wire.ctm_info2;
    else if(n_state == ST_SET_OUT_INFO) begin
        case (in_act)
            Take: ctm2_reserve_reg <= ctm2_reg;
            Deliver: ctm2_reserve_reg <= ctm2_reg;
            Order: begin
                ctm2_reserve_reg.ctm_status <= None;
                ctm2_reserve_reg.res_ID <= 8'b0;
                ctm2_reserve_reg.food_ID <= No_food;
                ctm2_reserve_reg.ser_food <= 4'b0;
            end
            Cancel: ctm2_reserve_reg <= ctm2_reg;
            default: ctm2_reserve_reg <= ctm2_reserve_reg;
        endcase
    end
    else ctm2_reserve_reg <= ctm2_reserve_reg;
end
assign correct_ctm1_rst_id = ((ctm1_reg.res_ID == in_res_id) && (!ctm1_empty))? 1'b1 : 1'b0;
assign correct_ctm1_food = (ctm1_reg.food_ID == in_food.d_food_ID)? 1'b1 : 1'b0;
assign correct_ctm2_rst_id = ((ctm2_reg.res_ID == in_res_id) && (!ctm2_empty))? 1'b1 : 1'b0;
assign correct_ctm2_food = (ctm2_reg.food_ID == in_food.d_food_ID)? 1'b1 : 1'b0;

assign ctm1_empty = (ctm1_reg == 16'b0)? 1'b1 : 1'b0;
assign ctm2_empty = (ctm2_reg == 16'b0)? 1'b1 : 1'b0;
assign ctm_empty = (ctm1_empty && ctm2_empty)? 1'b1 : 1'b0;

assign d_man_busy = (ctm1_reg != 16'b0 && ctm2_reg != 16'b0)? 1'b1 : 1'b0;
assign food_count = in_food.d_ser_food + res_reg.ser_FOOD1 + res_reg.ser_FOOD2 + res_reg.ser_FOOD3;
always_comb begin
    case (in_ctm.food_ID)
        FOOD1: begin
            if(res_reg.ser_FOOD1 < in_ctm.ser_food) no_food = 1'b1;
            else no_food = 1'b0;
        end
        FOOD2: begin
            if(res_reg.ser_FOOD2 < in_ctm.ser_food) no_food = 1'b1;
            else no_food = 1'b0;
        end
        FOOD3: begin
            if(res_reg.ser_FOOD3 < in_ctm.ser_food) no_food = 1'b1;
            else no_food = 1'b0;
        end
        default: no_food = 1'b0;
    endcase
end

always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) write_flag <= 1'b0;
    else begin
        case (in_act)
            Take: begin
                if(d_man_busy) write_flag <= 1'b0;
                else write_flag <= 1'b1;
            end
            Deliver: begin
                if(ctm_empty) write_flag <= 1'b0;
                else write_flag <= 1'b1;
            end
            Order: begin
                if(food_count > res_reg.limit_num_orders) write_flag <= 1'b0;
                else write_flag <= 1'b1;
            end
            Cancel: begin
                if(((correct_ctm1_rst_id && correct_ctm1_food) || (correct_ctm2_rst_id && correct_ctm2_food)) && (!ctm_empty)) begin
                    write_flag <= 1'b1;
                end
                else write_flag <= 1'b0;
            end
            default: write_flag <= 1'b0;
        endcase
    end
end
/* FSM */
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) c_state <= ST_IDLE;
    else c_state <= n_state;
end
always_comb begin
    case (c_state)
    ST_IDLE: begin
        if(inf.act_valid) n_state = ST_IN;
        else n_state = ST_IDLE;
    end
    ST_IN: begin
        case (in_act)
        Take: begin
            if(inf.cus_valid) begin
                if(take_if_needed) n_state = ST_READ_RES;
                else n_state = ST_READ_D_MAN;
            end
            else n_state = ST_IN;
        end
        Deliver: begin
            if(inf.id_valid) n_state = ST_READ_D_MAN;
            else n_state = ST_IN;
        end
        Order: begin
            if(inf.food_valid) begin
                if(order_if_needed) n_state = ST_RUN;
                else n_state = ST_READ_RES;
            end
            else n_state = ST_IN;
        end
        Cancel: begin
            if(inf.id_valid) n_state = ST_READ_D_MAN;
            else n_state = ST_IN;
        end
        default: n_state = ST_IDLE;
        endcase
    end
    ST_READ_D_MAN: begin
        if(inf.C_out_valid) n_state = ST_STORE_D_MAN;
        else n_state = ST_READ_D_MAN;
    end
    ST_STORE_D_MAN: begin
        if(in_act == Take) begin
            if(d_man_busy) n_state = ST_OUT_ER;
            else n_state = ST_READ_RES;
        end
        else begin
            n_state = ST_CHECK_D_MAN;
        end
    end
    ST_CHECK_D_MAN: begin
        if(!write_flag) n_state = ST_OUT_ER;
        else n_state = ST_RUN;
    end
    ST_READ_RES: begin
        if(inf.C_out_valid) n_state = ST_STORE_RES;
        else n_state = ST_READ_RES;
    end
    ST_STORE_RES: begin
        if(in_act == Take && no_food) n_state = ST_OUT_ER;
        else n_state = ST_CHECK_RES;
    end
    ST_CHECK_RES: begin
        if(!write_flag) n_state = ST_OUT_ER;
        else n_state = ST_RUN;
    end
    ST_RUN: begin
        case (in_act)
        Order: n_state = ST_WRITE_RES;
        default: n_state = ST_WRITE_D_MAN;
        endcase
    end

    ST_WRITE_D_MAN: begin
        if(inf.C_out_valid) begin
            if((in_act == Take) && (!id_equal_flag)) n_state = ST_WRITE_RES;
            else n_state = ST_SET_OUT_INFO;
        end
        else n_state = ST_WRITE_D_MAN;
    end
    ST_WRITE_RES: begin
        if(inf.C_out_valid) n_state = ST_SET_OUT_INFO;
        else n_state = ST_WRITE_RES;
    end
    ST_OUT: n_state = ST_IDLE;
    ST_OUT_ER:n_state = ST_IDLE;
    ST_SET_OUT_INFO: n_state = ST_OUT;
    default: n_state = ST_IDLE;
    endcase
end

/*********************************
* take: act -> id -> cus         *
* take(if needed): act -> cus    *
* deliver act -> id              *
* order: act -> res -> food      *
* order(if needed): act -> food  *
* cancel: act -> food -> id      *
**********************************/

//*****************************
// input data regeister
//*****************************
// in_act
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_act <= No_action;
    else if(c_state == ST_OUT) in_act <= No_action;
    else if(inf.act_valid) in_act <= inf.D.d_act[0];
    else in_act <= in_act;
end

// in_dman_id
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_dman_id <= 8'b0;
    // else if(c_state == ST_OUT) in_dman_id <= 8'b0;
    else if(inf.id_valid) in_dman_id <= inf.D.d_id[0];
    else in_dman_id <= in_dman_id;
end

// in_res_id
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) in_res_id <= 8'b0;
    // else if(c_state == ST_OUT) in_res_id <= 8'b0;
    else if(inf.res_valid) in_res_id <= inf.D.d_res_id[0];
    else if(in_act == Take && inf.cus_valid)  in_res_id <= inf.D.d_ctm_info[0].res_ID;
    else in_res_id <= in_res_id;
end

//in_ctm
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        in_ctm.ctm_status <= None;
        in_ctm.res_ID <= 8'b0;
        in_ctm.food_ID <= No_food;
        in_ctm.ser_food <= 4'd0;
    end
    else if(c_state == ST_OUT) begin
        in_ctm.ctm_status <= None;
        in_ctm.res_ID <= 8'b0;
        in_ctm.food_ID <= No_food;
        in_ctm.ser_food <= 4'd0;
    end
    else if(inf.cus_valid) in_ctm <= inf.D.d_ctm_info[0];
    else in_ctm <= in_ctm;
end

// in_food
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) begin
        in_food.d_food_ID <= No_food;
        in_food.d_ser_food <= 4'b0;
    end
    else if(c_state == ST_OUT) begin
        in_food.d_food_ID <= No_food;
        in_food.d_ser_food <= 4'b0;
    end
    else if(inf.food_valid) in_food <= inf.D.d_food_ID_ser[0];
    else in_food <= in_food;
end



/* output */
//     output out_valid, err_msg,  complete, out_info, 
// 		   C_addr, C_data_w, C_in_valid, C_r_wb
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.out_valid <= 1'b0;
    else begin
        case (n_state)
        ST_OUT: inf.out_valid <= 1'b1;
        ST_OUT_ER: inf.out_valid <= 1'b1;
        default: inf.out_valid <= 1'b0;
        endcase
    end
end
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.err_msg <= No_Err;
    else begin
        case (n_state)
        ST_OUT_ER: begin
            case (in_act)
            Take: begin
                if(d_man_busy) inf.err_msg <= D_man_busy;
                else inf.err_msg <= No_Food;
            end
            Deliver: begin
                inf.err_msg <= No_customers;
            end
            Order: begin
                inf.err_msg <= Res_busy;
            end
            Cancel: begin
                if(ctm_empty) inf.err_msg <= Wrong_cancel;
                else if((!correct_ctm1_rst_id) && (!correct_ctm2_rst_id)) inf.err_msg <= Wrong_res_ID;
                else inf.err_msg <= Wrong_food_ID;
            end
            default: inf.err_msg <= No_Err;
            endcase
        end
        default: inf.err_msg <= No_Err;
        endcase
        
    end
end
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.complete <= 1'b0;
    else begin
        case (n_state)
        ST_OUT: inf.complete <= 1'b1;
        default: inf.complete <= 1'b0;
        endcase
    end
end

always_comb begin
    case (c_state)
    ST_OUT: inf.out_info = {d_man_reserve_wire, res_reserve_reg};
    default: inf.out_info = 64'b0;
    endcase
end

always_comb begin
    case (c_state)
    ST_READ_D_MAN: inf.C_addr = in_dman_id;
    ST_WRITE_D_MAN: inf.C_addr = in_dman_id;
    ST_READ_RES: inf.C_addr = in_res_id;
    ST_WRITE_RES: inf.C_addr = in_res_id;
    default: inf.C_addr = 8'b0;
    endcase
end

always_comb begin
    begin
        case (c_state)
        ST_IDLE: inf.C_data_w = 64'b0;
        ST_WRITE_D_MAN: begin
            if((in_act == Take) && id_equal_flag) inf.C_data_w = encode_dram_write_data_d_man_res;
            else inf.C_data_w = encode_dram_write_data_d_man;
        end
        ST_WRITE_RES: begin
            inf.C_data_w = encode_dram_write_data_res;
            // if((in_act == Take) && id_equal_flag) inf.C_data_w = encode_dram_write_data_d_man_res;
            // else inf.C_data_w = encode_dram_write_data_res;
        end
        default: inf.C_data_w = 64'b0;
        endcase
    end
end
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.C_in_valid <= 1'b0;
    else begin
        case (n_state)
        ST_READ_D_MAN: begin
            if(c_state != ST_READ_D_MAN) inf.C_in_valid <= 1'b1;
            else inf.C_in_valid <= 1'b0;
        end
        ST_WRITE_D_MAN: begin
            if(c_state != ST_WRITE_D_MAN) inf.C_in_valid <= 1'b1;
            else inf.C_in_valid <= 1'b0;
        end
        ST_READ_RES: begin
            if(c_state != ST_READ_RES) inf.C_in_valid <= 1'b1;
            else inf.C_in_valid <= 1'b0;
        end
        ST_WRITE_RES: begin
            if(c_state != ST_WRITE_RES) inf.C_in_valid <= 1'b1;
            else inf.C_in_valid <= 1'b0;
        end
        default: inf.C_in_valid <= 1'b0;
        endcase
    end
end
always_ff @(posedge clk or negedge inf.rst_n) begin
    if(!inf.rst_n) inf.C_r_wb <= 1'b0;
    else begin
        case (n_state)
        ST_READ_D_MAN: inf.C_r_wb <= 1'b1;
        ST_WRITE_D_MAN: inf.C_r_wb <= 1'b0;
        ST_READ_RES: inf.C_r_wb <= 1'b1;
        ST_WRITE_RES: inf.C_r_wb <= 1'b0;
        default: inf.C_r_wb <= 1'b0;
        endcase
    end
end
endmodule

module DECODER(
    /* input */
    r_dram_data,
    /* output */
    r_rst_info, r_div_man_info
);
import usertype::*;
input logic [63:0] r_dram_data;
output res_info r_rst_info;
output D_man_Info r_div_man_info;
Ctm_Info r_ctm1, r_ctm2;
logic [15:0] r_pre_c1, r_pre_c2;
// limit_of_orders limit_orders;
// servings_of_FOOD ser_food_1, ser_food_2, ser_food_3;

assign r_rst_info.limit_num_orders = r_dram_data[7:0];
assign r_rst_info.ser_FOOD1 = r_dram_data[15:8];
assign r_rst_info.ser_FOOD2 = r_dram_data[23:16];
assign r_rst_info.ser_FOOD3 = r_dram_data[31:24];
assign r_pre_c1 = {r_dram_data[39:32], r_dram_data[47:40]};
assign r_pre_c2 = {r_dram_data[55:48], r_dram_data[63:56]};

always_comb begin
    case (r_pre_c1[15:14])
    2'b00: r_ctm1.ctm_status = None;
    2'b01: r_ctm1.ctm_status = Normal;
    2'b11: r_ctm1.ctm_status = VIP;
    default: r_ctm1.ctm_status = None;
    endcase
end
// assign r_ctm1.ctm_status = r_pre_c1[15:14];
assign r_ctm1.res_ID = r_pre_c1[13:6];
always_comb begin
    case (r_pre_c1[5:4])
    2'b00: r_ctm1.food_ID = No_food;
    2'b01: r_ctm1.food_ID = FOOD1;
    2'b10: r_ctm1.food_ID = FOOD2;
    2'b11: r_ctm1.food_ID = FOOD3;
    default: r_ctm1.food_ID = No_food;
    endcase
end
// assign r_ctm1.food_ID = r_pre_c1[5:4];
assign r_ctm1.ser_food = r_pre_c1[3:0];

always_comb begin
    case (r_pre_c2[15:14])
    2'b00: r_ctm2.ctm_status = None;
    2'b01: r_ctm2.ctm_status = Normal;
    2'b11: r_ctm2.ctm_status = VIP;
    default: r_ctm2.ctm_status = None;
    endcase
end
// assign r_ctm2.ctm_status = r_pre_c2[15:14];
assign r_ctm2.res_ID = r_pre_c2[13:6];
always_comb begin
    case (r_pre_c2[5:4])
    2'b00: r_ctm2.food_ID = No_food;
    2'b01: r_ctm2.food_ID = FOOD1;
    2'b10: r_ctm2.food_ID = FOOD2;
    2'b11: r_ctm2.food_ID = FOOD3;
    default: r_ctm2.food_ID = No_food;
    endcase
end
// assign r_ctm2.food_ID = r_pre_c2[5:4];
assign r_ctm2.ser_food = r_pre_c2[3:0];


assign r_div_man_info.ctm_info1 = r_ctm1;
assign r_div_man_info.ctm_info2 = r_ctm2;


endmodule

module ENCODER(
    /* input */
    w_rst_info, w_div_man_info,
    /* output */
    w_dram_data
);
import usertype::*;
input res_info w_rst_info;
input D_man_Info w_div_man_info;
output logic [63:0] w_dram_data;
Ctm_Info w_ctm1, w_ctm2;
logic [15:0] w_pre_c1, w_pre_c2;

assign w_ctm1 = w_div_man_info.ctm_info1;
assign w_ctm2 = w_div_man_info.ctm_info2;

assign w_pre_c1 = {w_ctm1.ctm_status, w_ctm1.res_ID, w_ctm1.food_ID, w_ctm1.ser_food};
assign w_pre_c2 = {w_ctm2.ctm_status, w_ctm2.res_ID, w_ctm2.food_ID, w_ctm2.ser_food};

assign w_dram_data = {w_pre_c2[7:0], w_pre_c2[15:8], w_pre_c1[7:0], w_pre_c1[15:8], w_rst_info.ser_FOOD3,
                      w_rst_info.ser_FOOD2, w_rst_info.ser_FOOD1, w_rst_info.limit_num_orders};

endmodule
