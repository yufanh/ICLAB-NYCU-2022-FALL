`include "../00_TESTBED/pseudo_DRAM.sv"
`include "Usertype_FD.sv"

program automatic PATTERN(input clk, INF.PATTERN inf);
import usertype::*;

parameter SEED = 666;
parameter DRAM_PATH = "../00_TESTBED/DRAM/dram.dat";
parameter DRAM_START_ADDR = 65536;
logic [7:0] GOLDEN_DRAM[((DRAM_START_ADDR + 256 * 8 ) -  1) : DRAM_START_ADDR + 0];
logic [7:0] d_man_id;
logic [7:0] res_id;

Action act;
// integer
integer pat_count;
Ctm_Info input_cmt;
food_ID_servings input_food;
logic order_needed_flag, take_needed_flag;
Food_id temp_food_food_id;
logic [3:0] temp_food_ser_food;
logic [7:0] temp_res_id, temp_ser_food;

// golden ans
logic golden_complete;
Error_Msg golden_err_msg;
res_info golden_res;
res_info golden_new_res;
D_man_Info golden_d_man;
Ctm_Info golden_ctm_1, golden_ctm_2;
Ctm_Info golden_new_ctm_1, golden_new_ctm_2;
integer total_ser_food;

res_info design_res;
Ctm_Info design_ctm_1, design_ctm_2;

integer total_latency, latency;
/************************************
* take: act -> id -> cus            *
* take(if need): act -> cus         *
* deliver act -> id                 *
* order: act -> res -> food         *
* order(if needed): act -> food     *
* cancel: act -> res -> food -> id  *
*************************************/


initial begin
    $readmemh(DRAM_PATH, GOLDEN_DRAM);
    reset_task;
    for (pat_count = 0; pat_count < 400; pat_count = pat_count + 1) begin
        input_task;
        wait_out_valid_task;
        compute_ans_task;
        check_ans_task;
    end
    
    @(negedge clk);
    $finish;

end
task input_task; begin
    @(negedge clk);
    @(negedge clk);
    if(pat_count <= 59) begin
        res_id = pat_count / 2;
        d_man_id = pat_count / 2;
        read_dream_res_task;
        read_dream_d_man_task;
        if(pat_count <= 19) begin
            if((pat_count % 2)  == 0) order_res_busy_task;
            else begin
                if(pat_count <= 4) begin
                    res_id = 0;
                    read_dream_res_task;
                end
                take_d_man_busy_no_food_task;
            end
        end
        else if(pat_count <= 39) begin
            if((pat_count % 2)  == 0) order_res_busy_task;
            else cancel_wrong_man_task;
        end
        else begin
            if((pat_count % 2)  == 0) order_res_busy_task;
            else deliever_no_cus_task;
        end
    end
    else if(pat_count <= 129) begin
        res_id = pat_count - 30;
        d_man_id = pat_count - 30;
        read_dream_res_task;
        read_dream_d_man_task;
        if(pat_count <= 79) begin
            if((pat_count % 2)  == 0) take_d_man_busy_no_food_task;
            else deliever_no_cus_task;
        end
        else if(pat_count <= 99)begin
            if((pat_count % 2)  == 0) cancel_wrong_man_task;
            else deliever_no_cus_task;
        end
        else if(pat_count <= 109)begin
            deliever_no_cus_task;
        end
        else begin
            cancel_wrong_res_task;
        end
    end
    else if(pat_count <= 139)begin
        
        d_man_id = pat_count - 30;
        read_dream_d_man_task;
        read_dream_res_task;
        if((pat_count % 2)  == 0) res_id = golden_ctm_1.res_ID;
        else  res_id = 0;
        cancel_wrong_food_task;
    end
    else if(pat_count <= 199) begin
        res_id = pat_count - 30;
        d_man_id = pat_count - 30;
        read_dream_res_task;
        read_dream_d_man_task;
        if(pat_count <= 159) begin
            if((pat_count % 2)  == 0) take_d_man_busy_no_food_task;
            else begin
                res_id = 255;
                read_dream_res_task;
                cancel_wrong_food_task;
            end
        end
        else take_d_man_busy_no_food_task;
    end
    else if(pat_count <= 282) begin
        res_id = pat_count - 30;
        d_man_id = pat_count - 30;
        read_dream_res_task;
        read_dream_d_man_task;
        deliever_no_cus_task;
    end
    else if(pat_count <= 393)begin
        res_id = 252;
        d_man_id = 252;
        read_dream_res_task;
        read_dream_d_man_task;
        order_task;
        order_needed_flag = 1;
    end
    else if(pat_count == 394) begin
        order_needed_flag = 0;
        d_man_id = 253;
        read_dream_d_man_task;
        res_id = golden_ctm_2.res_ID;
        read_dream_res_task;
        cancel_conner_case_2_task;
    end
    else if(pat_count == 395) begin
        d_man_id = 253;
        read_dream_d_man_task;
        res_id = golden_ctm_1.res_ID;
        read_dream_res_task;
        cancel_conner_case_task;
    end
    else if(pat_count == 396) begin
        res_id = 254;
        d_man_id = 254;
        read_dream_res_task;
        read_dream_d_man_task;
        take_conner_case_task;
    end
    else if(pat_count == 397) begin
        res_id = 255;
        d_man_id = 254;
        read_dream_res_task;
        read_dream_d_man_task;
        take_conner_case_if_needed_task;
    end
    else if(pat_count == 398) begin
        d_man_id = 254;
        read_dream_d_man_task;
        res_id = golden_ctm_1.res_ID;
        read_dream_res_task;
        cancel_conner_case_task;
    end
    else begin
        d_man_id = 255;
        read_dream_d_man_task;
        res_id = golden_ctm_1.res_ID;
        read_dream_res_task;
        cancel_conner_case_task;
    end
end
endtask

task order_res_busy_task; begin
    // order: act -> res -> food
    act = Order;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    case (($urandom % 2))
        2'd0: temp_food_food_id = FOOD1;
        2'd1: temp_food_food_id = FOOD2;
        2'd2: temp_food_food_id = FOOD3;
        default: temp_food_food_id = FOOD1;
    endcase
    input_food.d_food_ID = temp_food_food_id;
    temp_food_ser_food = ($urandom % 11) + 4;
    input_food.d_ser_food = temp_food_ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task order_task; begin
    // order: act -> res -> food
    act = Order;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    if(!order_needed_flag) begin
        inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
        inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    end
    // food_valid
    case (($urandom % 2))
        2'd0: temp_food_food_id = FOOD1;
        2'd1: temp_food_food_id = FOOD2;
        2'd2: temp_food_food_id = FOOD3;
        default: temp_food_food_id = FOOD1;
    endcase
    input_food.d_food_ID = temp_food_food_id;
    temp_food_ser_food = 1;
    input_food.d_ser_food = temp_food_ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task deliever_no_cus_task; begin
    // deliver act -> id
    act = Deliver;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // id valid
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task take_d_man_busy_no_food_task; begin
    // take: act -> id -> cus
    // take(if need): act -> cus 

    act = Take;
    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // id_valid
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // cus_vaild
    case ($urandom % 2)
        1'd0: input_cmt.ctm_status = Normal;
        1'd1: input_cmt.ctm_status = VIP;
        default: input_cmt.ctm_status = Normal;
    endcase
    input_cmt.res_ID = res_id;
    case (($urandom % 3))
        2'd0: input_cmt.food_ID = FOOD1;
        2'd1: input_cmt.food_ID = FOOD2;
        2'd2: input_cmt.food_ID = FOOD3;
        default: input_cmt.food_ID = FOOD1;
    endcase
    temp_ser_food = ($urandom % 14) + 1;
    input_cmt.ser_food = temp_ser_food;

    inf.cus_valid = 1'b1; inf.D = input_cmt; @(negedge clk);
    inf.cus_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task take_conner_case_task; begin
    // take: act -> id -> cus

    act = Take;
    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // id_valid
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // cus_vaild
    input_cmt.ctm_status = Normal;
    input_cmt.res_ID = res_id;
    case (($urandom % 3))
        2'd0: input_cmt.food_ID = FOOD1;
        2'd1: input_cmt.food_ID = FOOD2;
        2'd2: input_cmt.food_ID = FOOD3;
        default: input_cmt.food_ID = FOOD1;
    endcase
    temp_ser_food = ($urandom % 14) + 1;
    input_cmt.ser_food = temp_ser_food;

    inf.cus_valid = 1'b1; inf.D = input_cmt; @(negedge clk);
    inf.cus_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task take_conner_case_if_needed_task; begin
    // take: act -> id -> cus
    // take(if need): act -> cus 

    act = Take;
    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // cus_vaild
    input_cmt.ctm_status = VIP;
    input_cmt.res_ID = res_id;
    case (($urandom % 3))
        2'd0: input_cmt.food_ID = FOOD1;
        2'd1: input_cmt.food_ID = FOOD2;
        2'd2: input_cmt.food_ID = FOOD3;
        default: input_cmt.food_ID = FOOD1;
    endcase
    temp_ser_food = ($urandom % 14) + 1;
    input_cmt.ser_food = temp_ser_food;

    inf.cus_valid = 1'b1; inf.D = input_cmt; @(negedge clk);
    inf.cus_valid = 1'b0; inf.D = 'bx; @(negedge clk);
end
endtask
task cancel_conner_case_task; begin
    // cancel: act -> res -> food -> id
    act = Cancel;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    input_food.d_food_ID = golden_ctm_1.food_ID;
    input_food.d_ser_food = golden_ctm_1.ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // id
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
end
endtask
task cancel_conner_case_2_task; begin
    // cancel: act -> res -> food -> id
    act = Cancel;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    input_food.d_food_ID = golden_ctm_2.food_ID;
    input_food.d_ser_food = golden_ctm_2.ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // id
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
end
endtask
task cancel_wrong_man_task; begin
    // cancel: act -> res -> food -> id
    act = Cancel;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    case (($urandom % 2))
        2'd0: temp_food_food_id = FOOD1;
        2'd1: temp_food_food_id = FOOD2;
        2'd2: temp_food_food_id = FOOD3;
        default: temp_food_food_id = FOOD1;
    endcase
    input_food.d_food_ID = temp_food_food_id;
    temp_food_ser_food = ($urandom % 14) + 1;
    input_food.d_ser_food = temp_food_ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // id
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
end
endtask
task cancel_wrong_res_task; begin
    // cancel: act -> res -> food -> id
    act = Cancel;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    input_food.d_food_ID = FOOD3;
    temp_food_ser_food = ($urandom % 14) + 1;
    input_food.d_ser_food = temp_food_ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // id
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
end
endtask
task cancel_wrong_food_task; begin
    // cancel: act -> res -> food -> id
    act = Cancel;

    // action valid
    inf.act_valid = 1'b1; inf.D = act; @(negedge clk);
    inf.act_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // res_valid
    inf.res_valid = 1'b1; inf.D = res_id; @(negedge clk);
    inf.res_valid = 1'b0; inf.D = 'bx; @(negedge clk);

    // food_valid
    case (($urandom % 2))
        2'd0: temp_food_food_id = FOOD1;
        2'd1: temp_food_food_id = FOOD2;
        default: temp_food_food_id = FOOD1;
    endcase
    input_food.d_food_ID = temp_food_food_id;
    temp_food_ser_food = ($urandom % 14) + 1;
    input_food.d_ser_food = temp_food_ser_food;

    inf.food_valid = 1'b1; inf.D = input_food; @(negedge clk);
    inf.food_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
    // id
    inf.id_valid = 1'b1; inf.D = d_man_id; @(negedge clk);
    inf.id_valid = 1'b0; inf.D = 'bx; @(negedge clk);
    
end
endtask
task compute_take_ans_task; begin
    if(golden_ctm_1 !== 0 && golden_ctm_2 !== 0) begin
        golden_complete = 1'b0;
        golden_err_msg = D_man_busy;
        golden_new_res = golden_res;
        golden_new_ctm_1 = golden_ctm_1;
        golden_new_ctm_2 = golden_ctm_2;
    end
    else begin
        case (input_cmt.food_ID)
            FOOD1: begin
                if(golden_res.ser_FOOD1 < input_cmt.ser_food) begin
                    golden_complete = 1'b0;
                    golden_err_msg = No_Food;
                end
                else begin
                    golden_new_res.limit_num_orders = golden_res.limit_num_orders;
                    golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1 - input_cmt.ser_food;
                    golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2;
                    golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3;
                    golden_complete = 1'b1;
                    golden_err_msg = No_Err;
                    //write_dream_res_task;
                end
            end
            FOOD2: begin
                if(golden_res.ser_FOOD2 < input_cmt.ser_food) begin
                    golden_complete = 1'b0;
                    golden_err_msg = No_Food;
                end
                else begin
                    golden_new_res.limit_num_orders = golden_res.limit_num_orders;
                    golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1;
                    golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2 - input_cmt.ser_food;
                    golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3;
                    golden_complete = 1'b1;
                    golden_err_msg = No_Err;
                    //write_dream_res_task;
                end
            end
            FOOD3: begin
                if(golden_res.ser_FOOD3 < input_cmt.ser_food) begin
                    golden_complete = 1'b0;
                    golden_err_msg = No_Food;
                end
                else begin
                    golden_new_res.limit_num_orders = golden_res.limit_num_orders;
                    golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1;
                    golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2;
                    golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3 - input_cmt.ser_food;
                    golden_complete = 1'b1;
                    golden_err_msg = No_Err;
                    //write_dream_res_task;
                end
            end
            default: begin
                golden_complete = 1'b0;
                golden_err_msg = No_Err;
                golden_new_res = golden_res;
                golden_new_ctm_1 = golden_ctm_1;
                golden_new_ctm_2 = golden_ctm_2;
            end
        endcase
        if(golden_complete == 1) begin
            if(golden_ctm_1 !== 0) begin
                if(input_cmt.ctm_status !== VIP) begin
                    golden_new_ctm_1 = golden_ctm_1;
                    golden_new_ctm_2 = input_cmt;
                end
                else begin
                    if(golden_ctm_1.ctm_status !== VIP) begin
                        golden_new_ctm_1 = input_cmt;
                        golden_new_ctm_2 = golden_ctm_1;
                    end
                    else begin
                        golden_new_ctm_1 = golden_ctm_1;
                        golden_new_ctm_2 = input_cmt;
                    end
                end
            end
            else begin
                golden_new_ctm_1 = input_cmt;
                golden_new_ctm_2.ctm_status = None;
                golden_new_ctm_2.res_ID = 0;
                golden_new_ctm_2.food_ID = No_food;
                golden_new_ctm_2.ser_food = 0;
            end
            write_dream_d_man_task;
            write_dream_res_task;
        end
        else begin
            // golden_new_res = golden_res;
            // golden_new_ctm_1 = golden_ctm_1;
            // golden_new_ctm_2 = golden_ctm_2;
        end
    end
end
endtask
task compute_deliver_ans_task; begin
    if(golden_ctm_1 === 0 && golden_ctm_2 === 0) begin
        golden_complete = 1'b0;
        golden_err_msg = No_customers;
        golden_new_res = golden_res;
        golden_new_ctm_1 = golden_ctm_1;
        golden_new_ctm_2 = golden_ctm_2;
    end
    else begin

        golden_new_ctm_1 = golden_ctm_2;
        golden_new_ctm_2.ctm_status = None;
        golden_new_ctm_2.res_ID = 0;
        golden_new_ctm_2.food_ID = No_food;
        golden_new_ctm_2.ser_food = 0;

        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        write_dream_d_man_task;
    end
end
endtask
task compute_order_ans_task; begin
    total_ser_food = golden_res.ser_FOOD1 + golden_res.ser_FOOD2 + golden_res.ser_FOOD3 + input_food.d_ser_food;
    if(total_ser_food > golden_res.limit_num_orders) begin
        golden_complete = 1'b0;
        golden_err_msg = Res_busy;
        golden_new_res = golden_res;
        golden_new_ctm_1 = golden_ctm_1;
        golden_new_ctm_2 = golden_ctm_2;
    end
    else begin
        golden_new_res.limit_num_orders = golden_res.limit_num_orders;
        case (input_food.d_food_ID)
            FOOD1: begin
                golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1 + input_food.d_ser_food;
                golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2;
                golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3;
            end
            FOOD2: begin
                golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1;
                golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2 + input_food.d_ser_food;
                golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3;
            end
            FOOD3: begin
                golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1;
                golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2;
                golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3 + input_food.d_ser_food;
            end
            default: begin
                golden_new_res.ser_FOOD1 = golden_res.ser_FOOD1;
                golden_new_res.ser_FOOD2 = golden_res.ser_FOOD2;
                golden_new_res.ser_FOOD3 = golden_res.ser_FOOD3 + input_food.d_ser_food;
            end
        endcase
        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        write_dream_res_task;
    end
end
endtask
task compute_cancel_ans_task; begin
    if(golden_ctm_1 === 0 && golden_ctm_2 === 0) begin
        golden_complete = 1'b0;
        golden_err_msg = Wrong_cancel;
        golden_new_res = golden_res;
        golden_new_ctm_1 = golden_ctm_1;
        golden_new_ctm_2 = golden_ctm_2;
    end
    else if(((golden_ctm_1.res_ID === res_id) && (golden_ctm_1.food_ID === input_food.d_food_ID)) && 
            ((golden_ctm_2.res_ID === res_id) && (golden_ctm_2.food_ID === input_food.d_food_ID))) begin
        
        golden_new_ctm_1.ctm_status = None;
        golden_new_ctm_1.res_ID = 0;
        golden_new_ctm_1.food_ID = No_food;
        golden_new_ctm_1.ser_food = 0;

        golden_new_ctm_2.ctm_status = None;
        golden_new_ctm_2.res_ID = 0;
        golden_new_ctm_2.food_ID = No_food;
        golden_new_ctm_2.ser_food = 0;
        
        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        write_dream_d_man_task;
    end
    else if(((golden_ctm_1.res_ID === res_id) && (golden_ctm_1.food_ID === input_food.d_food_ID)) && 
            !((golden_ctm_2.res_ID === res_id) && (golden_ctm_2.food_ID === input_food.d_food_ID))) begin
        
        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        
        golden_new_ctm_1 = golden_ctm_2;
        golden_new_ctm_2.ctm_status = None;
        golden_new_ctm_2.res_ID = 0;
        golden_new_ctm_2.food_ID = No_food;
        golden_new_ctm_2.ser_food = 0;
        
        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        write_dream_d_man_task;
    end
    else if (!((golden_ctm_1.res_ID === res_id) && (golden_ctm_1.food_ID === input_food.d_food_ID)) && 
            ((golden_ctm_2.res_ID === res_id) && (golden_ctm_2.food_ID === input_food.d_food_ID))) begin
        
        golden_new_ctm_1 = golden_ctm_1;
        golden_new_ctm_2.ctm_status = None;
        golden_new_ctm_2.res_ID = 0;
        golden_new_ctm_2.food_ID = No_food;
        golden_new_ctm_2.ser_food = 0;
        
        golden_complete = 1'b1;
        golden_err_msg = No_Err;
        write_dream_d_man_task;
    end
    else begin
        if((golden_ctm_1.res_ID !== res_id) && (golden_ctm_2.res_ID !== res_id)) begin
            golden_complete = 1'b0;
            golden_err_msg = Wrong_res_ID;
            golden_new_res = golden_res;
            golden_new_ctm_1 = golden_ctm_1;
            golden_new_ctm_2 = golden_ctm_2;
        end
        else begin
            golden_complete = 1'b0;
            golden_err_msg = Wrong_food_ID;
            golden_new_res = golden_res;
            golden_new_ctm_1 = golden_ctm_1;
            golden_new_ctm_2 = golden_ctm_2;
        end
    end

end
endtask
task wait_out_valid_task; begin
    latency = 1;
    while(inf.out_valid !== 1) begin
        latency = latency + 1;
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end
endtask
task compute_ans_task; begin
    // read_dream_res_task;
    // read_dream_d_man_task;
    case (act)
        Take: compute_take_ans_task;
        Deliver: compute_deliver_ans_task;
        Order: compute_order_ans_task;
        Cancel: compute_cancel_ans_task;
        default: begin
            golden_complete = 1'b0;
            golden_err_msg = No_Err;
        end 
    endcase
end
endtask
task check_ans_task; begin
    read_design_d_man_task;
    read_design_res_task;
    if(inf.complete !== golden_complete) wrong_ans_task;

    else if(inf.complete === 1'b0 && inf.err_msg !== golden_err_msg) wrong_ans_task;
    else if(inf.complete === 1'b1) begin
        case (act)
            Take: begin
                if(design_res !== golden_new_res || design_ctm_1 !== golden_new_ctm_1 || design_ctm_2 !== golden_new_ctm_2) begin
                    wrong_ans_task;
                end
            end 
            Deliver: begin
                if(inf.out_info[31:0] !== 32'd0 || design_ctm_1 !== golden_new_ctm_1 || design_ctm_2 !== golden_new_ctm_2) begin
                    wrong_ans_task;
                end
            end
            Order: begin
                if(design_res !== golden_new_res || inf.out_info[63:32] !== 32'd0) begin
                    wrong_ans_task;
                end
            end
            Cancel: begin
                if(design_res !== 32'd0 || design_ctm_1 !== golden_new_ctm_1 || design_ctm_2 !== golden_new_ctm_2) begin
                    wrong_ans_task;
                end
            end
            default: begin
            end
        endcase
    end
end
endtask
task wrong_ans_task; begin
    $display("Wrong Answer");
    $finish;
end
endtask


task read_dream_d_man_task; begin
    // d_man_cmt1
    case (GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 4][7:6])
        2'b01: golden_ctm_1.ctm_status = Normal;
        2'b11: golden_ctm_1.ctm_status = VIP;
        default: golden_ctm_1.ctm_status = None;
    endcase
    golden_ctm_1.res_ID = {GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 4][5:0],
                                    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][7:6]};
    case (GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][5:4])
        2'b01: golden_ctm_1.food_ID = FOOD1;
        2'b10: golden_ctm_1.food_ID = FOOD2;
        2'b11: golden_ctm_1.food_ID = FOOD3;
        default: golden_ctm_1.food_ID = No_food;
    endcase
    golden_ctm_1.ser_food = GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][3:0];

    // d_man_cmt2
    case (GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 6][7:6])
        2'b01: golden_ctm_2.ctm_status = Normal;
        2'b11: golden_ctm_2.ctm_status = VIP;
        default: golden_ctm_2.ctm_status = None;
    endcase
    golden_ctm_2.res_ID = {GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 6][5:0],
                                    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][7:6]};
    case (GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][5:4])
        2'b01: golden_ctm_2.food_ID = FOOD1;
        2'b10: golden_ctm_2.food_ID = FOOD2;
        2'b11: golden_ctm_2.food_ID = FOOD3;
        default: golden_ctm_2.food_ID = No_food;
    endcase
    golden_ctm_2.ser_food = GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][3:0];
    // debug_d_man_task;
end
endtask
task read_design_d_man_task; begin
    // d_man_cmt1
    case (inf.out_info[63:62])
        2'b01: design_ctm_1.ctm_status = Normal;
        2'b11: design_ctm_1.ctm_status = VIP;
        default: design_ctm_1.ctm_status = None;
    endcase
    design_ctm_1.res_ID = inf.out_info[61:54];
    case (inf.out_info[53:52])
        2'b01: design_ctm_1.food_ID = FOOD1;
        2'b10: design_ctm_1.food_ID = FOOD2;
        2'b11: design_ctm_1.food_ID = FOOD3;
        default: design_ctm_1.food_ID = No_food;
    endcase
    design_ctm_1.ser_food = inf.out_info[51:48];

    // d_man_cmt2
    case (inf.out_info[47:46])
        2'b01: design_ctm_2.ctm_status = Normal;
        2'b11: design_ctm_2.ctm_status = VIP;
        default: design_ctm_2.ctm_status = None;
    endcase
    design_ctm_2.res_ID = inf.out_info[45:38];
    case (inf.out_info[37:36])
        2'b01: design_ctm_2.food_ID = FOOD1;
        2'b10: design_ctm_2.food_ID = FOOD2;
        2'b11: design_ctm_2.food_ID = FOOD3;
        default: design_ctm_2.food_ID = No_food;
    endcase
    design_ctm_2.ser_food = inf.out_info[35:32];
    // debug_golden_d_man_task;
end
endtask
task write_dream_d_man_task; begin
    // d_man_cmt1
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 4][7:6] = golden_new_ctm_1.ctm_status;
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 4][5:0] = golden_new_ctm_1.res_ID[7:2];
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][7:6] = golden_new_ctm_1.res_ID[1:0];
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][5:4] = golden_new_ctm_1.food_ID;
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 5][3:0] = golden_new_ctm_1.ser_food;
    // d_man_cmt2
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 6][7:6] = golden_new_ctm_2.ctm_status;
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 6][5:0] = golden_new_ctm_2.res_ID[7:2];
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][7:6] = golden_new_ctm_2.res_ID[1:0];
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][5:4] = golden_new_ctm_2.food_ID;
    GOLDEN_DRAM[DRAM_START_ADDR + (d_man_id * 8) + 7][3:0] = golden_new_ctm_2.ser_food;
end
endtask

task read_dream_res_task; begin
    golden_res.limit_num_orders = GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8)];
    golden_res.ser_FOOD1 = GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 1];
    golden_res.ser_FOOD2 = GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 2];
    golden_res.ser_FOOD3 = GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 3];
    // debug_res_task;
end
endtask
task read_design_res_task; begin
    design_res.limit_num_orders = inf.out_info[31:24];
    design_res.ser_FOOD1 = inf.out_info[23:16];
    design_res.ser_FOOD2 = inf.out_info[15:8];
    design_res.ser_FOOD3 = inf.out_info[7:0];
    // debug_golden_res_task;
end
endtask
task write_dream_res_task; begin
    GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8)] = golden_new_res.limit_num_orders;
    GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 1] = golden_new_res.ser_FOOD1;
    GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 2] = golden_new_res.ser_FOOD2;
    GOLDEN_DRAM[DRAM_START_ADDR + (res_id * 8) + 3] = golden_new_res.ser_FOOD3;
end
endtask

task reset_task; begin
    order_needed_flag = 1'b0;
    take_needed_flag = 1'b0;
    inf.rst_n = 1'b1;
    inf.act_valid = 1'b0;
    inf.id_valid = 1'b0;
    inf.res_valid = 1'b0;
    inf.food_valid = 1'b0;
    inf.cus_valid = 1'b0;
    inf.D = 'bx;
    force clk = 0;
    #10 ; inf.rst_n = 1'b0;
    #10 ; inf.rst_n = 1'b1;
    #10 ; release clk;
    @(negedge clk);
end
endtask
endprogram
