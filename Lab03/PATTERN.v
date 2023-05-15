`define PATTERN_NUMBER 300
`ifdef RTL
    `define CYCLE_TIME 10.0
`endif
`ifdef GATE
    `define CYCLE_TIME 10.0
`endif

module PATTERN(
    clk,
    rst_n,
    in_valid,
    guy,
    in0,
    in1,
    in2,
    in3,
    in4,
    in5,
    in6,
    in7,
  
    out_valid,
    out
);
/* design input */
output reg       clk, rst_n;
output reg       in_valid;
output reg [2:0] guy;
output reg [1:0] in0, in1, in2, in3, in4, in5, in6, in7;

/* design outpout */
input            out_valid;
input      [1:0] out;

/* set clock cycle */
real CYCLE = `CYCLE_TIME;
always #(CYCLE/2.0) clk = ~clk;

/* parameter and integer*/
integer  patnum = `PATTERN_NUMBER;
// integer seed = `SEED;
integer pat_count, i, j, a, t;
integer start_point;
integer latency;
integer total_latency;
integer left_bound, right_bound;
/* reg declaration */
reg [1:0] map[63:0][7:0];
// reg obstacle_flag;
integer input_count, space_count, type, range;
reg space_flag, take, left_right;
reg [2:0] position, new_position, temp;


initial begin
    reset_task;
    total_latency = 0;
    for(pat_count = 0; pat_count < patnum ; pat_count = pat_count + 1)begin
        input_task;
        //compute_ans_task;
        wait_out_valid_task;
        check_ans_task;
        check_out_not_valid_task;
        //check_out_valid_task;
        $display("\033[0;36mPASS PATTERN NO.%4d,\033[m execution cycle : %3d",pat_count ,latency);
    
    end
    pass_task;
end

task input_task; 
begin
    input_count = 0;
    space_flag = 1'b0;
    space_count = 0;
    take = 0;
    left_bound = 0;
    right_bound = 0;
    t = ($urandom % 3) + 2;
    start_point = $urandom % 8;
    for(i = 0; i < 64 ; i = i + 1) begin
        for(j = 0; j < 8; j = j + 1) begin
            map[i][j] = 0;
        end
    end
	repeat(t) @(negedge clk);

    in_valid = 1'b1;
    while (input_count != 64) begin
        out_valid_not_low_task;
        out_not_rst_task;
        if(input_count == 0) begin
            guy = start_point;
            in0 = 0; in1 = 0;
            in2 = 0; in3 = 0;
            in4 = 0; in5 = 0;
            in6 = 0; in7 = 0;
            space_flag =$urandom % 2;
            space_count = 1;
            position = start_point;
        end
        else begin

            if(space_flag) begin
                in0 = 0; in1 = 0;
                in2 = 0; in3 = 0;
                in4 = 0; in5 = 0;
                in6 = 0; in7 = 0;
                space_count = space_count + 1;
                space_flag =$urandom % 2;
            end
            else begin
                    type = ($urandom % 2) + 1;

                    if(type == 1) begin// low
                        if((space_count - 1) > position) left_bound = 0;
                        else left_bound = position - (space_count - 1);

                        if((space_count - 1) > (7 - position) ) right_bound = 7;
                        else right_bound = position + (space_count - 1);
                    end
                    else begin
                        if(space_count > position) left_bound = 0;
                        else left_bound = position - space_count;

                        if(space_count > (7 - position) ) right_bound = 7;
                        else right_bound = position + space_count;
                    end
                    new_position = $urandom_range(left_bound, right_bound);

                    case (new_position)
                        3'd0: begin
                            in0 = type; in1 = 3;
                            in2 = 3; in3 = 3;
                            in4 = 3; in5 = 3;
                            in6 = 3; in7 = 3;
                        end
                        3'd1: begin
                            in0 = 3; in1 = type;
                            in2 = 3; in3 = 3;
                            in4 = 3; in5 = 3;
                            in6 = 3; in7 = 3;
                        end

                        3'd2: begin
                            in0 = 3; in1 = 3;
                            in2 = type; in3 = 3;
                            in4 = 3; in5 = 3;
                            in6 = 3; in7 = 3;
                        end
                        3'd3: begin
                            in0 = 3; in1 = 3;
                            in2 = 3; in3 = type;
                            in4 = 3; in5 = 3;
                            in6 = 3; in7 = 3;
                        end

                        3'd4: begin
                            in0 = 3; in1 = 3;
                            in2 = 3; in3 = 3;
                            in4 = type; in5 = 3;
                            in6 = 3; in7 = 3;
                        end
                        3'd5: begin
                            in0 = 3; in1 = 3;
                            in2 = 3; in3 = 3;
                            in4 = 3; in5 = type;
                            in6 = 3; in7 = 3;
                        end
                        3'd6: begin
                            in0 = 3; in1 = 3;
                            in2 = 3; in3 = 3;
                            in4 = 3; in5 = 3;
                            in6 = type; in7 = 3;
                        end
                        3'd7: begin
                            in0 = 3; in1 = 3;
                            in2 = 3; in3 = 3;
                            in4 = 3; in5 = 3;
                            in6 = 3; in7 = type;
                        end

                    endcase
                    space_flag = 1;
                    space_count = 0;
                    position = new_position;  
            end
            guy = 'bx;
        end
        
        map[input_count][0] = in0; map[input_count][1] = in1;
        map[input_count][2] = in2; map[input_count][3] = in3;
        map[input_count][4] = in4; map[input_count][5] = in5;
        map[input_count][6] = in6; map[input_count][7] = in7;
        input_count = input_count + 1;
        take = $urandom % 2;
        @(negedge clk);
    end
    
    in_valid = 1'b0;
    guy = 'bx;
    in0 = 'bx; in1 = 'bx;
    in2 = 'bx; in3 = 'bx;
    in4 = 'bx; in5 = 'bx;
    in6 = 'bx; in7 = 'bx;
    // $display("+++latency: %d", latency);
end endtask


task wait_out_valid_task; begin
    latency = 0;
    while(!out_valid) begin
        // $display("---out_valid: %d", out_valid);
        latency = latency + 1;
        // $display("---latency: %d", latency);
        out_not_rst_task;
        if(latency == 3000) begin
            $display("----------------------------------------------------------------------");   
            $display("                          SPEC 6 IS FAIL!                             ");   
            $display("          The execution latency are over 3000 cycles at %8t           ",$time);
            $display("----------------------------------------------------------------------");
            repeat(2) @(negedge clk);
            $finish;
        end
        @(negedge clk);
    end
    total_latency = total_latency + latency;
end endtask
task reset_task; begin 
    rst_n = 'b1;
    in_valid = 'b0;
    guy = 'bx;
    in0 = 'bx; in1 = 'bx;
    in2 = 'bx; in3 = 'bx;
    in4 = 'bx; in5 = 'bx;
    in6 = 'bx; in7 = 'bx;
    
    force clk = 0;

    #CYCLE; rst_n = 0; 
    #CYCLE; rst_n = 1;

    // SPEC 3 IS FAIL!
    if(out_valid !== 1'b0 || out !=='b0) begin //out!==0
        $display("----------------------------------------------------------------------");   
        $display("                          SPEC 3 IS FAIL!                             ");   
        $display("        Output signal should be 0 after initial RESET  at %8t         ",$time);
        $display("----------------------------------------------------------------------");
        repeat(2) #CYCLE;
        $finish;
    end
	#CYCLE; release clk;
end endtask

task check_ans_task; 
    integer out_counter, guy_pos;
    reg [1:0] hight;
    reg [2:0] state; // ground = 0; low to high = 1; high to low 1st cycle = 2, (high to low 2nd cycle) = 3; or (low to low)= 4
    
    begin
    out_counter = 0;
    state = 0;
    while(out_counter != 63) begin
        out_counter = out_counter + 1;
        check_out_valid_task;
        // $display("+++cycle: %d", out_counter);   
        if(out_counter == 1) begin
            guy_pos = start_point;
            hight = 0;
        end
            case (state) // ground = 0; low to high = 1; high to low 1st cycle = 2, (high to low 2nd cycle) or (low to low)= 3
                3'd0: begin // ground = 0
                    case (out)
                        2'd0: begin // stop
                            if(map[out_counter][guy_pos] == 1 || map[out_counter][guy_pos] == 3) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(0)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                            end
                        
                        end
                        2'd1: begin // right
                            if(guy_pos == 7) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("              The wrong output : Out of Right Range                   ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            //else begin
                            else if(map[out_counter][guy_pos + 1] == 1 || map[out_counter][guy_pos + 1] == 3)begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(1)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                                guy_pos = guy_pos + 1;
                            end
                            //end
                        end
                        2'd2: begin // left
                            if(guy_pos == 0) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("               The wrong output : Out of left Range                   ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            //else begin
                            else if(map[out_counter][guy_pos - 1] == 1 || map[out_counter][guy_pos - 1] == 3)begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(2)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                                // $display("guy_pos = %d", guy_pos);
                                guy_pos = guy_pos - 1;
                            end
                            //end
                        end
                        2'd3: begin // jump
                            
                            if(map[out_counter][guy_pos] == 2 || map[out_counter][guy_pos] == 3)begin
                                // $display("map[out_counter][guy_pos] = %d", map[out_counter][guy_pos]);
                                // $display("guy_pos = %d", guy_pos);
                                
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(3)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 1;
                                if(map[out_counter][guy_pos] == 1) state = 1;
                                else state = 4;
                            end
                        end
                    endcase

                end
                3'd1: begin // low to high = 1
                    case (out)
                        2'd0: begin // stop
                                hight = 0;
                                state = 0;
                        end
                        2'd1: begin // right
                            if(guy_pos == 7) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("              The wrong output : Out of Right Range                   ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else if(map[out_counter][guy_pos + 1] == 1 || map[out_counter][guy_pos + 1] == 3)begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(8)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                                guy_pos = guy_pos + 1;
                            end
                            //end
                        end
                        2'd2: begin // left
                            if(guy_pos == 0) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("              The wrong output : Out of left Range                   ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else if(map[out_counter][guy_pos - 1] == 1 || map[out_counter][guy_pos - 1] == 3)begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(9)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                                guy_pos = guy_pos - 1;
                            end
                            //end
                        end
                        2'd3: begin // jump
                            if(map[out_counter][guy_pos] == 2 || map[out_counter][guy_pos] == 3)begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(4)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 2;
                                state = 2;
                            end
                        end
                    endcase
                end
                3'd2: begin // high to low 1st cycle = 2
                    case (out)
                        2'd0: begin // stop
                            if(map[out_counter][guy_pos] == 2 || map[out_counter][guy_pos] == 3) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                     guy hit hte obstacle(5)                          ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else if(map[out_counter][guy_pos] == 1) begin
                                hight = 1;
                                state = 1;
                            end
                            else begin
                                hight = 0;
                                state = 3;
                            end
                            
                        end
                        default: begin
                            if(map[out_counter][guy_pos] != 0) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-3 IS FAIL!                            ");   
                                $display("   If the guy jumps to the same height, out must be 2'00 for 1 cycle  ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                $display("-------------------------------------------------------------------------");   
                                $display("                         SPEC 8-2 IS FAIL!                               ");   
                                $display(" If the guy jumps from high to low place, out must be 2'b00 for 2 cycles ");
                                $display("-------------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            
                        end
                    endcase
                end
                3'd3: begin // high to low 2nd cycle = 3
                    case (out)
                        2'd0: begin // stop
                            if(map[out_counter][guy_pos] == 1 || map[out_counter][guy_pos] == 3) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                         The wrong output 6                           ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                            end
                        end
                        default: begin
                            $display("-------------------------------------------------------------------------");   
                            $display("                         SPEC 8-2 IS FAIL!                               ");   
                            $display(" If the guy jumps from high to low place, out must be 2'b00 for 2 cycles ");
                            $display("-------------------------------------------------------------------------");
                            repeat(2) @(negedge clk);
                            $finish;
                        end
                    endcase
                end
                3'd4: begin
                    case (out) //  (low to low)= 3
                        2'd0: begin // stop
                            if(map[out_counter][guy_pos] == 1 || map[out_counter][guy_pos] == 3) begin
                                $display("----------------------------------------------------------------------");   
                                $display("                         SPEC 8-1 IS FAIL!                            ");   
                                $display("                         The wrong output 7                           ");
                                $display("----------------------------------------------------------------------");
                                repeat(2) @(negedge clk);
                                $finish;
                            end
                            else begin
                                hight = 0;
                                state = 0;
                            end
                        end
                        default: begin
                            $display("----------------------------------------------------------------------");   
                            $display("                         SPEC 8-3 IS FAIL!                            ");   
                            $display("   If the guy jumps to the same height, out must be 2'00 for 1 cycle  ");
                            $display("----------------------------------------------------------------------");
                            repeat(2) @(negedge clk);
                            $finish;
                        end
                    endcase
                end
            endcase
        //end
        @(negedge clk);
    end

end endtask

task out_valid_not_low_task; begin
    if(out_valid) begin
        $display("----------------------------------------------------------------------");   
        $display("                          SPEC 5 IS FAIL!                             ");   
        $display("        The out_valid should not be high when in_valid is high        ");
        $display("----------------------------------------------------------------------");
        repeat(2) @(negedge clk);
        $finish;
    end
end endtask


task out_not_rst_task; begin
    if(out !== 2'b0) begin
        $display("----------------------------------------------------------------------");   
        $display("                         SPEC 4 IS FAIL!                              ");   
        $display("          The out should be reset when your out_valid is low          ");
        $display("----------------------------------------------------------------------");
        repeat(2) @(negedge clk);
        $finish;
    end
end endtask


task pass_task; begin
    $display ("**********************************************************************");
    $display ("                        \033[0;32m Congratulations!  \033[m                         ");
    $display ("                 \033[0;32m You have passed all patterns! \033[m                    ");
    $display("                                      ");
    $display("                               |\__||  ");
    $display("                              / O.O  | ");
    $display("                            /_____   | ");
    $display("                           /^ ^ ^ \\  |");
    $display("                          |^ ^ ^ ^ |w| ");
    $display("                           \\m___m__|_|");
    $display("                                       ");
    $display("                       Total Latency: %d                            ", total_latency);
    $display("**********************************************************************");      
        repeat(2) @(negedge clk);
    $finish;
end endtask

task check_out_valid_task; begin
    if(out_valid === 'b0) begin
        $display ("----------------------------------------------------------------------");
        $display ("                          SPEC 7 IS FAIL!                             ");
        $display ("   The out_valid and out must be asserted successively in 63 cycles   ");
        $display ("----------------------------------------------------------------------");
        repeat(2) @(negedge clk);
        $finish;
    end
end endtask
task check_out_not_valid_task; begin
    if(out_valid === 'b1) begin
        $display ("----------------------------------------------------------------------");
        $display ("                          SPEC 7 IS FAIL!                             ");
        $display ("   The out_valid and out must be asserted successively in 63 cycles   ");
        $display ("----------------------------------------------------------------------");
        repeat(2) @(negedge clk);
        $finish;
    end
end endtask
endmodule

