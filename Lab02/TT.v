module TT(
    //Input Port
    clk,
    rst_n,
	in_valid,
    source,
    destination,

    //Output Port
    out_valid,
    cost
    );

input               clk, rst_n, in_valid;
input       [3:0]   source;
input       [3:0]   destination;

output reg          out_valid;
output reg  [3:0]   cost;

//==============================================//
//             Parameter and Integer            //
//==============================================//
integer i, j;
//==============================================//
//            FSM State Declaration             //
//==============================================//
reg [2:0] c_state, n_state;
parameter ST_IDLE = 3'd2, ST_INPUT = 3'd1, ST_CALCULATE = 3'd4, ST_OUT = 3'd0 , ST_IN_AIM = 3'd3;
//==============================================//
//                 reg declaration              //
//==============================================//
reg adj[15:0][15:0]; // adjacent
reg path[15:0]; // path
reg [3:0] stage;
reg [3:0] s_aim, d_aim;
reg early_find, no_path;
//==============================================//
//             Current State Block              //
//==============================================//

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        c_state <= ST_IDLE; /* initial state */
    else 
        c_state <= n_state;
end

//==============================================//
//              Next State Block                //
//==============================================//

always@(*) begin
    case(c_state)
        ST_IDLE: begin
            if(in_valid) n_state = ST_IN_AIM;
            else n_state = ST_IDLE;
        end
        ST_IN_AIM: begin
            if(!in_valid) n_state = ST_OUT;
            else n_state = ST_INPUT;
        end
        ST_INPUT: begin
            if(!in_valid) begin
                if(early_find == 1'b1) n_state = ST_OUT;
                else n_state = ST_CALCULATE;
            end
            else n_state = ST_INPUT;
        end
        ST_CALCULATE: begin
            if(early_find || (stage == 4'b1111) || no_path) n_state = ST_OUT;
            else n_state = ST_CALCULATE;
        end
        default: n_state = ST_IDLE;
    endcase
end
//==============================================//
//                  Input Block                 //
//==============================================//

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) s_aim <= 4'b0;
    else begin
        case(n_state)
            ST_IDLE: begin
                s_aim <= 4'b0;
            end
            ST_IN_AIM: begin
                s_aim <= source;
            end
            ST_INPUT: begin
                s_aim <= s_aim;
            end
            default: begin
                s_aim <= s_aim;
            end
    endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) d_aim <= 4'b0;
    else begin
        case(n_state)
            ST_IDLE: begin
                d_aim <= 4'b0;
            end
            ST_IN_AIM: begin
                d_aim <= destination;
            end
            ST_INPUT: begin
                d_aim <= d_aim;
            end
            default: begin
                d_aim <= d_aim;
            end
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 16; i = i + 1)begin
            for(j = 0; j < 16; j = j + 1)begin
                adj[i][j] <= 1'b0;
            end
        end
    end
    
    else begin
        case (n_state)
            ST_IDLE: begin
                for(i = 0; i < 16; i = i + 1)begin
                    for(j = 0; j < 16; j = j + 1)begin
                        adj[i][j] <= 1'b0;
                end
                end
            end
            ST_INPUT: begin
                    adj[source][destination] <= 1'b1;
                    adj[destination][source] <= 1'b1;
            end
            ST_CALCULATE: begin
			
                for(i = 0; i < 16; i = i + 1)begin
                    for(j = 0; j < 16; j = j + 1)begin
                        if(path[j] == 1'b1) adj[j][i] <= 1'b0;
                    end
                end
				
            end
        endcase
    end
end
always@(*) begin
    early_find = path[d_aim];
end
//==============================================//
//              Calculation Block               //
//==============================================//
always@(*) begin
    no_path = ~(path[0] | path[1] | path[2] | path[3] | path[4] | path[5] | path[6] | path[7] | path[8] | path[9] | path[10]
                | path[11] | path[12] | path[13] | path[14] | path[15]);
end
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) stage <= 4'b0;
    else begin
        case(n_state)
            ST_IDLE: begin
                stage <= 4'b0001;
            end
            ST_CALCULATE:
                stage <= stage + 1'b1;
            default: begin
                stage <= stage;
            end
    endcase
    end
end


always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        for(i = 0; i < 16; i = i + 1)begin
                path[i] <= 1'b0;
            end
    end
    else begin
        case (n_state)
        ST_IDLE: begin
            for(i = 0; i < 16; i = i + 1)begin
                path[i] <= 1'b0;
            end
        end
        ST_IN_AIM: begin
            for(i = 0; i < 16; i = i + 1)begin
                path[i] <= 1'b0;
            end
        end
        ST_INPUT: begin
            for(i = 0; i < 16; i = i + 1)begin
                if(((source == s_aim) && (destination == i)) || ((source == i) && (destination == s_aim))) begin
                    path[i] <= 1'b1;
                end
            end
        end
        ST_CALCULATE: begin
            for(i = 0; i < 16; i = i + 1)begin
                path[i] <= ((adj[i][0] & path[0]) | (adj[i][1] & path[1]) | (adj[i][2] & path[2]) | (adj[i][3] & path[3]) | (adj[i][4] & path[4]) 
                | (adj[i][5] & path[5]) | (adj[i][6] & path[6]) | (adj[i][7] & path[7]) | (adj[i][8] & path[8]) | (adj[i][9] & path[9]) | (adj[i][10] & path[10]) 
                | (adj[i][11] & path[11]) | (adj[i][12] & path[12]) | (adj[i][13] & path[13]) | (adj[i][14] & path[14]) | (adj[i][15] & path[15])  ) ;
            end
        end
        default: begin
            for(i = 0; i < 16; i = i + 1)begin
                path[i] <= path[i];
            end
        end
        endcase
    end
end 

//==============================================//
//                Output Block                  //
//==============================================//

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        out_valid <= 1'b0; /* remember to reset */
    else begin
        case (n_state)
            ST_OUT: out_valid <= 1'b1;
            default: out_valid <= 1'b0;
        endcase
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cost <= 4'b0; /* remember to reset */
    else begin
        case (n_state)
        ST_OUT: begin
            if(early_find) cost <= stage;
            else cost <= 4'b0;
        end
        default: cost <= 4'b0;
        endcase
    end
end 

endmodule
