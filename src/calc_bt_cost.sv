//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`include "../include/sgbm_defines.v"

module calc_cost_bt (
    input wire                     clk,
    input wire                     rst,
    input wire [`WIDTH_BITS-1:0]   i_width,
    input wire             [7:0]   i_pixel_left_row0,
    input wire             [7:0]   i_pixel_left_row1,
    input wire             [7:0]   i_pixel_left_row2,
    input wire             [7:0]   i_pixel_right_row0,
    input wire             [7:0]   i_pixel_right_row1,
    input wire             [7:0]   i_pixel_right_row2,
    input wire                     i_rst_calc_cost,
    input wire                     i_reverse,
    input wire [`DISPD_BITS-1:0]   i_min_disp,
    input wire [`DISPD_BITS-1:0]   i_max_disp,

    output reg    [`DISPD*8-1:0]   o_data,
    output reg                     o_valid,
    output reg                     o_calc_cost_one_row_done
);


reg        [7:0]     pixel_left_row0_d1;
reg        [7:0]     pixel_left_row1_d1;
reg        [7:0]     pixel_left_row2_d1;
reg        [7:0]     pixel_left_row0_d2;
reg        [7:0]     pixel_left_row1_d2;
reg        [7:0]     pixel_left_row2_d2;
reg        [7:0]     pixel_left_row1_d3;
reg        [7:0]     pixel_left_row1_d4;
reg        [7:0]     pixel_left_row1_d5;
reg        [7:0]     pixel_left_row1_d6;


reg        [7:0]     pixel_right_row0_d1;
reg        [7:0]     pixel_right_row1_d1;
reg        [7:0]     pixel_right_row2_d1;
reg        [7:0]     pixel_right_row0_d2;
reg        [7:0]     pixel_right_row1_d2;
reg        [7:0]     pixel_right_row2_d2;
reg        [7:0]     pixel_right_row1_d3;
reg        [7:0]     pixel_right_row1_d4;
reg        [7:0]     pixel_right_row1_d5;
reg        [7:0]     pixel_right_row1_d6;


wire signed [ 9:0]    sobel_left_tmp0;
wire signed [ 9:0]    sobel_left_tmp1;
wire signed [ 9:0]    sobel_left_tmp2;
reg  signed [11:0]    sobel_left_tmp;

wire signed [ 9:0]    sobel_right_tmp0;
wire signed [ 9:0]    sobel_right_tmp1;
wire signed [ 9:0]    sobel_right_tmp2;
reg  signed [11:0]    sobel_right_tmp;

reg          [6:0]    sobel_left0;
reg          [6:0]    sobel_left1;
reg          [6:0]    sobel_left2;
reg          [6:0]    sobel_right0;
reg          [6:0]    sobel_right1;
reg          [6:0]    sobel_right2;


reg   [`WIDTH_BITS-1:0] x;
reg   [`WIDTH_BITS-1:0] y;
reg                     keep_first_cost_2cycles;
reg               [2:0] delay_cycles;
reg                     go;

//u左图，v右图
wire  [7:0]             u;
wire  [7:0]             ul;
wire  [7:0]             ur;
wire  [7:0]             u0;
wire  [7:0]             u1;

wire  [6:0]             u_grad;
wire  [6:0]             ul_grad;
wire  [6:0]             ur_grad;
wire  [6:0]             u0_grad;
wire  [6:0]             u1_grad;

reg   [7:0]             u_r;
reg   [7:0]             u0_r;
reg   [7:0]             u1_r;

reg   [6:0]             u_grad_r;
reg   [6:0]             u0_grad_r;
reg   [6:0]             u1_grad_r;

typedef struct packed {
    logic   [6:0] v1_grad;
    logic   [7:0] v1;
    logic   [6:0] v0_grad;
    logic   [7:0] v0;
    logic   [6:0] v_grad;
    logic   [7:0] v;
} vbuf;

vbuf  [0:`DISPD-1] right_buffer;

wire  [7:0]             v;
wire  [7:0]             vl;
wire  [7:0]             vr;
wire  [7:0]             v0;
wire  [7:0]             v1;

wire  [6:0]             v_grad;
wire  [6:0]             vl_grad;
wire  [6:0]             vr_grad;
wire  [6:0]             v0_grad;
wire  [6:0]             v1_grad;

reg   [7:0]             v_r;
reg   [7:0]             v0_r;
reg   [7:0]             v1_r;

reg   [6:0]             v_grad_r;
reg   [6:0]             v0_grad_r;
reg   [6:0]             v1_grad_r;

reg   [1:0]             state;
reg                     valid;

localparam
Idle = 0,
Running = 1,
WaitHsum = 2;

//width=512,min_disparity=12,max_disparity=92,x到92时才输出有效数据，
//左图x=92和右图0~80比较，right_buffer[48:127]有效，
//右图从line_buffer_9row出数据要比左图延迟12周期，这样左图x=92时，右图最新的数据x=80移入right_buffer[127]
//右图x=80，pixel,grad在right_buffer[127],x=0,在right_buffer[48]
//x=92,D=12的代价u-right_buffer[127],D=92的代价u-right_buffer[48]
//输出o_data是反过来的，看下面pixel_diff，[0:79]有效
//最右边，左图x=511和右图x=511-92~511-12比较


//反向，左图一直延迟到x=511-12，移入right_buffer[0]为止,x=511-91,对应right_buffer[79]，
//x=511,D=12的代价u-right_buffer[0],D=91的代价u-right_buffer[79], [0:79]有效

//    左 x=92,                           右 x=80               x=1
//                                       right_buffer[0]      right_buffer[79]
//D=                                      12                    91
//pixel(u_r=pixel_left_row1_d5)= 0x50     0x56                  0x41
//u0(u0_r)                  =    0x50
//u1(u1_r)                  =    0x50
//v0                        =             0x53                  0x3f
//v1                        =             0x59                  0x41


//grad(u_grade_r=sobel_left2) =  0x40     0x45                  0x6b
//u0(u0_grad_r)             =    0x40
//u1(u1_grad_r)             =    0x49
//v0                        =             0x64                  0x42
//v1                        =             0x6b                  0x55

always @(posedge clk)
if (rst) begin
    state                         <= Idle;
    x                             <= 0;
    y                             <= 0;
    o_valid                       <= 0;
    go                            <= 0;
    keep_first_cost_2cycles       <= 0;
    delay_cycles                  <= 0;
    o_calc_cost_one_row_done      <= 1;
end else begin
    if (state==Idle && i_rst_calc_cost) begin

        state                     <= Running;
        x                         <= 0;
        o_valid                   <= 0;
        go                        <= 1;
        o_calc_cost_one_row_done  <= 0;
        keep_first_cost_2cycles   <= 0;
        delay_cycles              <= 0;
    end

    if (state==Running) begin
        x                                 <= x+1;
        //VS cost.txt输出看cost，直接找pixel_diff对应起来的x值
        //y=0 x=92 cost[12]=34
        //y=0 x=92 cost[13]=21
        //y=0 x=92 cost[14]=7
        if (i_reverse) begin
            if (x==`DISPD+i_min_disp+5) begin
                o_valid                   <= 1;
                keep_first_cost_2cycles   <= 1;
                go                        <= 0;
                delay_cycles              <= 1;
            end
            else if (delay_cycles>0&&delay_cycles < 4) begin
                delay_cycles              <= delay_cycles+1;
            end

            if (delay_cycles==2) begin
                keep_first_cost_2cycles   <= 0;
                go                        <= 1;
            end

             //最后3列，需要保持bt_cost_data为最后一列不变，重复加这一列
            if (x == i_width+`DISPD+i_min_disp-i_max_disp+6) begin //delay DISPD+i_min_disp+width-i_max_disp+pipeline adjust
                state                     <= Idle;
                go                        <= 0;
                y                         <= y+1;
                o_calc_cost_one_row_done  <= 1;
            end

        end
        else begin
            if (x==i_max_disp+6) begin
                o_valid                   <= 1;
                keep_first_cost_2cycles   <= 1;
                go                        <= 0;
                delay_cycles              <= 1;
            end
            else if (delay_cycles>0&&delay_cycles < 4) begin
                delay_cycles              <= delay_cycles+1;
            end

            if (delay_cycles==2) begin
                keep_first_cost_2cycles   <= 0;
                go                        <= 1;
            end

            //同样找cost.txt x=511的pixel_diff
            if (x == i_width+7) begin
                state                     <= Idle;
                go                        <= 0;
                y                         <= y+1;
                o_calc_cost_one_row_done  <= 1;
            end

        end

    end

end


//sobel算子
//[-1,0,1]    tmp0
//[-2,0,2]    tmp1
//[-1,0,1]    tmp2
//sobel结果 tmp0+2*tmp1+tmp2

assign sobel_left_tmp0    = i_reverse?pixel_left_row0_d2-i_pixel_left_row0:
                                      i_pixel_left_row0 - pixel_left_row0_d2;
assign sobel_left_tmp1    = i_reverse?pixel_left_row1_d2-i_pixel_left_row1:
                                      i_pixel_left_row1 - pixel_left_row1_d2;
assign sobel_left_tmp2    = i_reverse?pixel_left_row2_d2-i_pixel_left_row2:
                                      i_pixel_left_row2 - pixel_left_row2_d2;

assign sobel_right_tmp0   = i_reverse?pixel_right_row0_d2-i_pixel_right_row0:
                                      i_pixel_right_row0 - pixel_right_row0_d2;
assign sobel_right_tmp1   = i_reverse?pixel_right_row1_d2-i_pixel_right_row1:
                                      i_pixel_right_row1 - pixel_right_row1_d2;
assign sobel_right_tmp2   = i_reverse?pixel_right_row2_d2-i_pixel_right_row2:
                                      i_pixel_right_row2 - pixel_right_row2_d2;


always @(posedge clk)  begin
    if (go) begin
        pixel_left_row0_d1        <= i_pixel_left_row0;
        pixel_left_row1_d1        <= i_pixel_left_row1;
        pixel_left_row2_d1        <= i_pixel_left_row2;
        pixel_left_row0_d2        <= pixel_left_row0_d1;
        pixel_left_row1_d2        <= pixel_left_row1_d1;
        pixel_left_row2_d2        <= pixel_left_row2_d1;

        //最左和最右值都是0x3f
        //prow1[width*c] = prow1[width*c + width-1] =
        //prow2[width*c] = prow2[width*c + width-1] = tab[0];

        if (i_reverse) begin
            if (x <= i_min_disp+`DISPD+2)
                pixel_left_row1_d3    <= 8'h3f;
            else
                pixel_left_row1_d3    <= pixel_left_row1_d2;
            end
        else begin
            if (x <= 3 || x >= i_width+4) //左图x=0点用不到,x<=3可去掉
                pixel_left_row1_d3    <= 8'h3f;
            else
                pixel_left_row1_d3    <= pixel_left_row1_d2;
        end

        pixel_left_row1_d4            <= pixel_left_row1_d3;
        pixel_left_row1_d5            <= pixel_left_row1_d4;

        sobel_left_tmp                <= sobel_left_tmp0 + 2*sobel_left_tmp1 + sobel_left_tmp2;

        if (i_reverse) begin
            if (x <= i_min_disp+`DISPD+2)
                sobel_left0           <= 7'h3f;
            else
                sobel_left0           <= sobel_left_tmp < -63 ? 0 : (
                                          sobel_left_tmp >= 64 ? 126 : sobel_left_tmp + 63);
        end
        else begin
            if (x <= 3 || x >= i_width +4)
                sobel_left0           <= 7'h3f;
            else
                sobel_left0           <= sobel_left_tmp < -63 ? 0 : (
                                          sobel_left_tmp >= 64 ? 126 : sobel_left_tmp + 63);
        end

        sobel_left1                   <= sobel_left0;
        sobel_left2                   <= sobel_left1;

        pixel_right_row0_d1           <= i_pixel_right_row0;
        pixel_right_row1_d1           <= i_pixel_right_row1;
        pixel_right_row2_d1           <= i_pixel_right_row2;
        pixel_right_row0_d2           <= pixel_right_row0_d1;
        pixel_right_row1_d2           <= pixel_right_row1_d1;
        pixel_right_row2_d2           <= pixel_right_row2_d1;

        if (i_reverse) begin
            if (x <= 3|| x >= i_width+4)
                pixel_right_row1_d3   <= 8'h3f;
            else
                pixel_right_row1_d3   <= pixel_right_row1_d2;
        end
        else begin
            if (x <= i_min_disp+3|| x >= i_width+i_min_disp+4) //右图x=i_width-1点用不到，x >= i_width+i_min_disp+2可去掉
                pixel_right_row1_d3   <= 8'h3f;
            else
                pixel_right_row1_d3   <= pixel_right_row1_d2;
        end

        pixel_right_row1_d4       <= pixel_right_row1_d3;
        pixel_right_row1_d5       <= pixel_right_row1_d4;

        sobel_right_tmp           <= sobel_right_tmp0 + 2*sobel_right_tmp1 + sobel_right_tmp2;

        if (i_reverse) begin
            if (x <= 3 || x >= i_width+4)
                sobel_right0      <= 8'h3f;
            else
                sobel_right0      <= sobel_right_tmp < -63 ? 0 : (
                                      sobel_right_tmp >= 64 ? 126 : sobel_right_tmp + 63);
        end
        else begin
            if (x <= i_min_disp+3 || x >= i_width+i_min_disp+4)
                sobel_right0      <= 8'h3f;
            else
                sobel_right0      <= sobel_right_tmp < -63 ? 0 : (
                                      sobel_right_tmp >= 64 ? 126 : sobel_right_tmp + 63);
        end

        sobel_right1              <= sobel_right0;
        sobel_right2              <= sobel_right1;
    end
end


// int v0 = std::min(vl, vr); v0 = std::min(v0, v); 右图左半，右半，本像素三者最小
// int v1 = std::max(vl, vr); v1 = std::max(v1, v); 右图左半，右半，本像素三者最大

assign v  = pixel_right_row1_d4;
assign vl = (pixel_right_row1_d3 + pixel_right_row1_d4)/2;
assign vr = (pixel_right_row1_d4 + pixel_right_row1_d5)/2;

minmax3_0cycle #(8) minmax3_0cycle_inst0(
    .i_d0(vl),
    .i_d1(vr),
    .i_d2(v),
    .o_min(v0),
    .o_max(v1)
);

assign v_grad  = sobel_right1;
assign vl_grad = (sobel_right0+sobel_right1)/2;
assign vr_grad = (sobel_right1+sobel_right2)/2;

minmax3_0cycle #(7) minmax3_0cycle_inst1(
    .i_d0(vl_grad),
    .i_d1(vr_grad),
    .i_d2(v_grad),
    .o_min(v0_grad),
    .o_max(v1_grad)
);



// int u0 = std::min(ul, ur); u0 = std::min(u0, u); 左图左半，右半，本像素三者最小
// int u1 = std::max(ul, ur); u1 = std::max(u1, u); 左图左半，右半，本像素三者最大

assign u  = pixel_left_row1_d4;
assign ul = (pixel_left_row1_d3 + pixel_left_row1_d4)/2;
assign ur = (pixel_left_row1_d4 + pixel_left_row1_d5)/2;

minmax3_0cycle #(8) minmax3_0cycle_inst2(
    .i_d0(ul),
    .i_d1(ur),
    .i_d2(u),
    .o_min(u0),
    .o_max(u1)
);

assign u_grad  = sobel_left1;
assign ul_grad = (sobel_left0+sobel_left1)/2;
assign ur_grad = (sobel_left1+sobel_left2)/2;

minmax3_0cycle #(7) minmax3_0cycle_inst3(
    .i_d0(u_grad),
    .i_d1(ul_grad),
    .i_d2(ur_grad),
    .o_min(u0_grad),
    .o_max(u1_grad)
);


always @(*) begin
    right_buffer[`DISPD-1] = {v1_grad_r,v1_r,v0_grad_r,v0_r,v_grad_r,v_r};
end

always @(posedge clk) begin
    if (go)                              //44:38   37:30 29:23    22:15 14:8    7:0
        right_buffer[0:`DISPD-2] <= {right_buffer[1:`DISPD-2],v1_grad_r,v1_r,v0_grad_r,v0_r,v_grad_r,v_r};
end

always @(posedge clk) begin
    if (go) begin                              //44:38   37:30 29:23    22:15 14:8    7:0
        u_r                     <= u;
        u0_r                    <= u0;
        u1_r                    <= u1;

        u_grad_r                <= u_grad;
        u0_grad_r               <= u0_grad;
        u1_grad_r               <= u1_grad;

        v_r                     <= v;
        v0_r                    <= v0;
        v1_r                    <= v1;

        v_grad_r                <= v_grad;
        v0_grad_r               <= v0_grad;
        v1_grad_r               <= v1_grad;

    end

end


genvar gi;
integer ii;
(* mark_debug="true" *)
reg signed [8:0] u_minus_v1[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [8:0] v0_minus_u[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [8:0] v_minus_u1[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [8:0] u0_minus_v[0:`DISPD-1];
(* mark_debug="true" *)
reg        [5:0] c0[0:`DISPD-1];
(* mark_debug="true" *)
reg        [5:0] c1[0:`DISPD-1];
(* mark_debug="true" *)
reg        [5:0] min_c0c1[0:`DISPD-1];

// int c0 = std::max(0, u - v1); c0 = std::max(c0, v0 - u);
// int c1 = std::max(0, v - u1); c1 = std::max(c1, u0 - v);

always @(*) begin
    //if (state == Running)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            u_minus_v1[ii]        = u_r-right_buffer[ii][37:30];
            v0_minus_u[ii]        = right_buffer[ii][22:15]-u_r;
            v_minus_u1[ii]        = right_buffer[ii][7:0]-u1_r;
            u0_minus_v[ii]        = u0_r-right_buffer[ii][7:0];
        end
end


always @(posedge clk) begin
    if (go)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            if (u_minus_v1[ii][8] && v0_minus_u[ii][8])
                c0[ii] <= 0;
            else if (u_minus_v1[ii] > v0_minus_u[ii])
                c0[ii] <= u_minus_v1[ii][7:2];
            else
                c0[ii] <= v0_minus_u[ii][7:2];

            if (v_minus_u1[ii][8] && u0_minus_v[ii][8])
                c1[ii] <= 0;
            else if (v_minus_u1[ii] > u0_minus_v[ii])
                c1[ii] <= v_minus_u1[ii][7:2];
            else
                c1[ii] <= u0_minus_v[ii][7:2];
        end
end


always @(*) begin
    //if (state == Running)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            if (c0[ii] > c1[ii])
                min_c0c1[ii] = c1[ii];
            else
                min_c0c1[ii] = c0[ii];
        end
end


(* mark_debug="true" *)
reg signed [7:0] u_minus_v1_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [7:0] v0_minus_u_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [7:0] v_minus_u1_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg signed [7:0] u0_minus_v_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg        [6:0] c0_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg        [6:0] c1_grad[0:`DISPD-1];
(* mark_debug="true" *)
reg        [6:0] min_c0c1_grad[0:`DISPD-1];

// int c0 = std::max(0, u - v1); c0 = std::max(c0, v0 - u);
// int c1 = std::max(0, v - u1); c1 = std::max(c1, u0 - v);

always @(*) begin
    //if (state == Running)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            u_minus_v1_grad[ii]        = u_grad_r-right_buffer[ii][44:38];
            v0_minus_u_grad[ii]        = right_buffer[ii][29:23]-u_grad_r;
            v_minus_u1_grad[ii]        = right_buffer[ii][14:8]-u1_grad_r;
            u0_minus_v_grad[ii]        = u0_grad_r-right_buffer[ii][14:8];
        end
end

always @(posedge clk) begin
    if (go)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            if (u_minus_v1_grad[ii][7] && v0_minus_u_grad[ii][7])
                c0_grad[ii] <= 0;
            else if (u_minus_v1_grad[ii] > v0_minus_u_grad[ii])
                c0_grad[ii] <= u_minus_v1_grad[ii][6:0];
            else
                c0_grad[ii] <= v0_minus_u_grad[ii][6:0];

            if (v_minus_u1_grad[ii][7] && u0_minus_v_grad[ii][7])
                c1_grad[ii] <= 0;
            else if (v_minus_u1_grad[ii] > u0_minus_v_grad[ii])
                c1_grad[ii] <= v_minus_u1_grad[ii][6:0];
            else
                c1_grad[ii] <= u0_minus_v_grad[ii][6:0];
        end
end


always @(*) begin
    //if (state == Running)
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            if (c0_grad[ii] > c1_grad[ii])
                min_c0c1_grad[ii] = c1_grad[ii];
            else
                min_c0c1_grad[ii] = c0_grad[ii];
        end
end




reg [0:`DISPD-1][7:0] pixel_diff;

always @(*) begin
    //if (state == Running&&~keep_first_cost_2cycles) begin
        if (i_reverse) begin
            for (ii = 0; ii < `DISPD; ii = ii+1) begin
                pixel_diff[ii] = min_c0c1_grad[ii] + min_c0c1[ii]; //与正向区别
            end
        end
        else begin
            for (ii = 0; ii < `DISPD; ii = ii+1) begin
                pixel_diff[`DISPD-1-ii] = min_c0c1_grad[ii] + min_c0c1[ii];
            end
        end
    //end
end

always @(*) begin
    o_data = pixel_diff;
end




`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_data                             = {random_val,random_val};
    o_valid                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_calc_cost_one_row_done           = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    pixel_left_row0_d1                 = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    pixel_left_row1_d1                 = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    pixel_left_row2_d1                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    pixel_left_row0_d2                 = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    pixel_left_row1_d2                 = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    pixel_left_row2_d2                 = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    pixel_left_row1_d3                 = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    pixel_left_row1_d4                 = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    pixel_left_row1_d5                 = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    pixel_left_row1_d6                 = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    pixel_right_row0_d1                = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    pixel_right_row1_d1                = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    pixel_right_row2_d1                = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    pixel_right_row0_d2                = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    pixel_right_row1_d2                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    pixel_right_row2_d2                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    pixel_right_row1_d3                = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    pixel_right_row1_d4                = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    pixel_right_row1_d5                = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    pixel_right_row1_d6                = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    sobel_left_tmp                     = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    sobel_right_tmp                    = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    sobel_left0                        = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    sobel_left1                        = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    sobel_left2                        = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    sobel_right0                       = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    sobel_right1                       = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    sobel_right2                       = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    x                                  = {random_val[31:0],random_val[31:0]};
    y                                  = {random_val,random_val};
    u_r                                = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    u0_r                               = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    u1_r                               = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    u_grad_r                           = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    u0_grad_r                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    u1_grad_r                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    right_buffer                       = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    v_r                                = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    v0_r                               = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    v1_r                               = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    v_grad_r                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    v0_grad_r                          = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    v1_grad_r                          = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    state                              = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    valid                              = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    pixel_diff                         = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
end
`endif


endmodule
