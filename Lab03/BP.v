module BP(
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

input             clk, rst_n;
input             in_valid;
input       [2:0] guy;
input       [1:0] in0, in1, in2, in3, in4, in5, in6, in7;
output reg        out_valid;
output reg  [1:0] out;


/* wire */
wire is_space, is_low, is_high, not_space;

wire [2:0] move;
wire [1:0] action;
reg [2:0] pos_in;
reg [7:0] in;
reg [15:0] temp_ans;

/* reg */
reg [2:0] pos_guy;
reg [109:0] ans;
reg [5:0] counter;

/* FSM */
reg [3:0] c_state, n_state;
parameter ST_IDLE = 3'd0,ST_IN_GUY = 3'd1, ST_IN = 3'd2,
            ST_IN_SPACE = 3'd3, ST_OUT = 3'd4;
/* current state */
always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= ST_IDLE; /* initial state */
    else 
        c_state <= n_state;
end

/* next state */
always@(*) begin
    case(c_state)
        ST_IDLE: begin
            if(in_valid) n_state = ST_IN_GUY;
            else n_state = ST_IDLE;
        end
        ST_IN_GUY: begin
            if(is_space) n_state = ST_IN_SPACE;
            else n_state = ST_IN;
        end
        ST_IN_SPACE: begin
            if(!in_valid) n_state = ST_OUT;
            else if(not_space) n_state = ST_IN;
            else n_state = ST_IN_SPACE;
        end
        ST_IN: begin
            if(!in_valid) n_state = ST_OUT;
            else if(is_space) n_state = ST_IN_SPACE;
            else n_state = ST_IN;
        end
        ST_OUT: begin
            if(counter == 6'd62) n_state = ST_IDLE;
            else n_state = ST_OUT;
        end

        default: n_state = ST_IDLE;
    endcase
end
/* input block */
assign is_space = (in_valid)? (~(in0[0] | in0[1])) : 1'b0;
assign not_space = ~is_space;
assign is_low = (not_space)? (in0[0] & in1[0] & in2[0] & in3[0] & in4[0] & in5[0] & in6[0] & in7[0]) : 1'b0;
assign is_high = (not_space)? ~is_low : 1'b0;
assign move = (pos_in > pos_guy) ? (pos_in - pos_guy) : (pos_guy - pos_in);
assign action = (pos_in > pos_guy)? 2'b01: 2'b10;


/* calculate */
always @(*) begin
    if(is_high) in = {in7[0], in6[0], in5[0], in4[0], in3[0], in2[0], in1[0], in0[0]};
    else if(is_low) in = {in7[1], in6[1], in5[1], in4[1], in3[1], in2[1], in1[1], in0[1]};
    else in = 8'b0;
    
end
always @(*) begin
    if(in[0] == 1'b0) pos_in = 3'd0;
    else if(in[1] == 1'b0) pos_in = 3'd1;
    else if(in[2] == 1'b0) pos_in = 3'd2;
    else if(in[3] == 1'b0) pos_in = 3'd3;
    else if(in[4] == 1'b0) pos_in = 3'd4;
    else if(in[5] == 1'b0) pos_in = 3'd5;
    else if(in[6] == 1'b0) pos_in = 3'd6;
    else if(in[7] == 1'b0) pos_in = 3'd7;
    else pos_in = 3'd0;
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        temp_ans <= 16'd0;
    end
    else begin
        case(n_state)
            ST_IN: begin
                if(is_low) begin
                    case (move)
                        3'd0: temp_ans <= {temp_ans[13:0], {2'b11}};
                        3'd1: temp_ans <= {temp_ans[13:2],  action, {2'b11}};
                        3'd2: temp_ans <= {temp_ans[13:4], {2{action}}, {2'b11}};
                        3'd3: temp_ans <= {temp_ans[13:6], {3{action}}, {2'b11}};
                        3'd4: temp_ans <= {temp_ans[13:8], {4{action}}, {2'b11}};
                        3'd5: temp_ans <= {temp_ans[13:10], {5{action}}, {2'b11}};
                        3'd6: temp_ans <= {temp_ans[13:12], {6{action}}, {2'b11}};
                        3'd7: temp_ans <= {{7{action}}, {2'b11}};
                    endcase
                end
                else if(is_high)begin
                    case (move)
                        3'd0: temp_ans <= temp_ans << 2;
                        3'd1: temp_ans <= {temp_ans[13:0],  action};
                        3'd2: temp_ans <= {temp_ans[13:2], {2{action}}};
                        3'd3: temp_ans <= {temp_ans[13:4], {3{action}}};
                        3'd4: temp_ans <= {temp_ans[13:6], {4{action}}};
                        3'd5: temp_ans <= {temp_ans[13:8], {5{action}}};
                        3'd6: temp_ans <= {temp_ans[13:10], {6{action}}};
                        3'd7: temp_ans <= {temp_ans[13:12], {7{action}}};
                    endcase
                end
            end
            default: begin
                temp_ans <= temp_ans << 2;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ans <= 1'b0;
    end
    else begin
        case(n_state)
            default: begin
                ans <= {ans[107:0],temp_ans[15:14]};
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) pos_guy <= 3'b0;
    else begin
        
        case(n_state)
            ST_IDLE: begin
                pos_guy <= 3'b0;
            end
            ST_IN_GUY: begin
                pos_guy <= guy;
            end
            ST_IN: begin
                pos_guy <= pos_in;
            end
            default: begin
                pos_guy <= pos_guy;
            end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        counter <= 6'b0;
    end
    else begin
        case(n_state)
            ST_IDLE: begin
                counter <= 6'b0;
            end
            ST_IN_GUY: begin
                counter <= 6'b0;
            end
            default: begin
                counter <= counter + 1'b1;
            end
        endcase
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out_valid <= 1'b0;
    else begin
        case(n_state)
            ST_IDLE: begin
                out_valid <= 1'b0;
            end
            ST_OUT: begin
                out_valid <= 1'b1;
            end
            default: begin
                out_valid <= 1'b0;
            end
        endcase
    end
        
end
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) out <= 2'b0;
    else begin
        case(n_state)
            ST_IDLE: begin
                out <= 2'b0;
            end
            ST_OUT: begin
                out <= ans[109:108];
            end
            default: begin
                out <= 2'b0;
            end
        endcase
    end
    
end  
endmodule
