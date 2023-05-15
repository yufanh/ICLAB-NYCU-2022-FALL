module Checker(input clk, INF.CHECKER inf);
import usertype::*;

//declare other cover group

covergroup CG_SPEC_1 @(posedge clk iff inf.id_valid);
	coverpoint inf.D.d_id[0] {
		option.auto_bin_max = 256;
	}
endgroup

covergroup CG_SPEC_2 @(posedge clk iff inf.act_valid);
	coverpoint inf.D.d_act[0] {
		    option.at_least = 10;
            bins take2take = (Take => Take);
            bins take2deliver = (Take => Deliver);
            bins takke2order = (Take => Order);
            bins take2cancel = (Take => Cancel);

            bins deliver2tate = (Deliver => Take);
            bins deliver2deliver = (Deliver => Deliver);
            bins deliver2order = (Deliver => Order);
            bins deliver2cancel = (Deliver => Cancel);
            
            bins order2tate = (Order => Take);
            bins order2deliver = (Order => Deliver);
            bins order2order = (Order => Order);
            bins order2cancel = (Order => Cancel);
            
            bins cancel2tate = (Cancel => Take);
            bins cancel2deliver = (Cancel => Deliver);
            bins cancel2order = (Cancel => Order);
            bins cancel2cancel = (Cancel => Cancel);
	}
endgroup

covergroup CG_SPEC_3 @(posedge clk iff inf.out_valid);
	coverpoint inf.complete {
		    option.at_least = 200;
            bins complete_zero = {1'b0};
            bins complete_not_zero = {1'b1};
	}
endgroup

covergroup CG_SPEC_4 @(posedge clk iff inf.out_valid);
	coverpoint inf.err_msg {
		    option.at_least = 20;
            bins no_food = {No_Food};
            bins d_man_busy = {D_man_busy};
            bins no_cmt = {No_customers};
            bins res_busy = {Res_busy};
            bins wrong_cancel = {Wrong_cancel};
            bins wrong_res_id = {Wrong_res_ID};
            bins wrong_food_id = {Wrong_food_ID};
	}
endgroup

CG_SPEC_1 cg_spec1 = new();
CG_SPEC_2 cg_spec2 = new();
CG_SPEC_3 cg_spec3 = new();
CG_SPEC_4 cg_spec4 = new();


//************************************ below assertion is to check your pattern ***************************************** 
//                                          Please finish and hand in it
// This is an example assertion given by TA, please write the required assertions below
//  assert_interval : assert property ( @(posedge clk)  inf.out_valid |=> inf.id_valid == 0 [*2])
//  else
//  begin
//  	$display("Assertion X is violated");
//  	$fatal; 
//  end
wire #(0.5) rst_reg = inf.rst_n;
//write other assertions
//========================================================================================================================================================
// Assertion 1 ( All outputs signals (including FD.sv and bridge.sv) should be zero after reset.)
//========================================================================================================================================================
// ASSERTION1_FD : assert property (@(negedge rst_reg) inf.out_valid == 0 && inf.err_msg == 0
//                             && inf.complete == 0 && inf.out_info == 0 && inf.C_addr == 0 && inf.C_data_w == 0 
//                             && inf.C_in_valid == 0 && inf.C_r_wb == 0 )
// else begin
//     $display("Assertion 1 is violated");
//     $fatal;
// end
// ASSERTION1_bridge : assert property (@(negedge rst_reg) inf.C_out_valid == 0 && inf.C_data_r == 0
//                             && inf.AR_VALID == 0 && inf.AR_ADDR == 0 && inf.R_READY == 0 && inf.AW_VALID == 0
//                             && inf.AW_ADDR == 0 && inf.W_VALID == 0 && inf.W_DATA == 0 && inf.B_READY == 0)
// else begin
//     $display("Assertion 1 is violated");
//     $fatal;
// end
Action act;
always@(posedge clk or negedge inf.rst_n)begin
    if(!inf.rst_n) begin
        act <= No_action;
    end
    else if (inf.out_valid) begin
        act <= No_action;
    end
    else if(inf.act_valid) begin
        act <= inf.D.d_act[0];
    end
end
ASSERTION_1 : assert property (@(negedge rst_reg) inf.out_valid == 0 && inf.err_msg == 0
                            && inf.complete == 0 && inf.out_info == 0 && inf.C_addr == 0 && inf.C_data_w == 0 
                            && inf.C_in_valid == 0 && inf.C_r_wb == 0 && inf.C_out_valid == 0 && inf.C_data_r == 0
                            && inf.AR_VALID == 0 && inf.AR_ADDR == 0 && inf.R_READY == 0 && inf.AW_VALID == 0
                            && inf.AW_ADDR == 0 && inf.W_VALID == 0 && inf.W_DATA == 0 && inf.B_READY == 0)
else begin
    $display("Assertion 1 is violated");
    $fatal;
end
ASSERTION_2 : assert property (@(negedge clk) (inf.out_valid && inf.complete) |-> inf.err_msg == No_Err)
else begin
    $display("Assertion 2 is violated");
    $fatal;
end
ASSERTION_3 : assert property (@(negedge clk) (inf.out_valid && !inf.complete) |-> inf.out_info == 64'b0)
else begin
    $display("Assertion 3 is violated");
    $fatal;
end
// ASSERTION_4_0 : assert property (@(posedge clk) inf.act_valid |=> ##[1:5] (inf.id_valid || inf.res_valid || inf.food_valid || inf.cus_valid))
// else begin
//     $display("Assertion 4 is violated");
//     $fatal;
// end
ASSERTION_4_0 : assert property (@(posedge clk) (inf.act_valid || inf.id_valid || inf.res_valid || inf.food_valid || inf.cus_valid) |=> !(inf.act_valid || inf.id_valid || inf.res_valid || inf.food_valid || inf.cus_valid))
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_1_0 : assert property (@(posedge clk) (inf.act_valid && inf.D.d_act[0] == Take) |=> ##[1:5] (inf.id_valid || inf.cus_valid))
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_1_1 : assert property (@(posedge clk) (inf.act_valid && inf.D.d_act[0] == Deliver) |=> ##[1:5] inf.id_valid )
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_1_2 : assert property (@(posedge clk) (inf.act_valid && inf.D.d_act[0] == Order)|=> ##[1:5] (inf.res_valid || inf.food_valid))
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_1_3 : assert property (@(posedge clk) (inf.act_valid && inf.D.d_act[0] == Cancel)|=> ##[1:5] inf.res_valid)
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_2 : assert property (@(posedge clk) (inf.id_valid && act == Take) |=> ##[1:5] inf.cus_valid)
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_3 : assert property (@(posedge clk) (inf.res_valid && act == Order) |=> ##[1:5] inf.food_valid)
else begin
    $display("Assertion 4 is violated");
    $fatal;
end
ASSERTION_4_4 : assert property (@(posedge clk) (inf.food_valid && act == Cancel) |=> ##[1:5] inf.id_valid)
else begin
    $display("Assertion 4 is violated");
    $fatal;
end

ASSERTION_5_1 : assert property (@(posedge clk) inf.act_valid |-> !(inf.id_valid || inf.res_valid || inf.food_valid || inf.cus_valid))
else begin
    $display("Assertion 5 is violated");
    $fatal;
end
ASSERTION_5_2 : assert property (@(posedge clk) inf.id_valid |-> !(inf.act_valid || inf.res_valid || inf.food_valid || inf.cus_valid))
else begin
    $display("Assertion 5 is violated");
    $fatal;
end
ASSERTION_5_3 : assert property (@(posedge clk) inf.res_valid |-> !(inf.id_valid || inf.act_valid || inf.food_valid || inf.cus_valid))
else begin
    $display("Assertion 5 is violated");
    $fatal;
end
ASSERTION_5_4 : assert property (@(posedge clk) inf.food_valid |-> !(inf.id_valid || inf.res_valid || inf.act_valid || inf.cus_valid))
else begin
    $display("Assertion 5 is violated");
    $fatal;
end
ASSERTION_5_5 : assert property (@(posedge clk) inf.cus_valid |-> !(inf.id_valid || inf.res_valid || inf.food_valid || inf.act_valid))
else begin
    $display("Assertion 5 is violated");
    $fatal;
end
ASSERTION_6 : assert property (@(negedge clk) inf.out_valid |=> !inf.out_valid)
else begin
    $display("Assertion 6 is violated");
    $fatal;
end 

ASSERTION_7_0 : assert property (@(posedge clk) inf.out_valid |=> (!inf.act_valid && !inf.id_valid && !inf.res_valid && !inf.food_valid && !inf.cus_valid))
else begin
    $display("Assertion 7 is violated");
    $fatal;
end
ASSERTION_7_1 : assert property (@(posedge clk) inf.out_valid |=> ##[1:9] inf.act_valid)
else begin
    $display("Assertion 7 is violated");
    $fatal;
end

ASSERTION_8_1 : assert property (@(posedge clk) (inf.cus_valid && act == Take)|=> ##[0:1199] inf.out_valid)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end
ASSERTION_8_2 : assert property (@(posedge clk) (inf.id_valid && act == Deliver)|=> ##[0:1199] inf.out_valid)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end
ASSERTION_8_3 : assert property (@(posedge clk) (inf.food_valid && act == Order)|=> ##[0:1199] inf.out_valid)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end
ASSERTION_8_4 : assert property (@(posedge clk) (inf.id_valid && act == Cancel)|=> ##[0:1199] inf.out_valid)
else begin
    $display("Assertion 8 is violated");
    $fatal;
end


endmodule
