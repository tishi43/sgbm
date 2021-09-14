//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`include "../include/sgbm_defines.v"

module sgbm
(
 input  wire                              clk,
 input  wire                              rst,
 input  wire [`WIDTH_BITS-1:0]            i_width,
 input  wire [`WIDTH_BITS-1:0]            i_height,
 input  wire [`STRIDE_BITS-1:0]            i_stride,
 input  wire            [31:0]            i_left_image_addr,
 input  wire            [31:0]            i_right_image_addr,
 input  wire            [31:0]            i_disp_addr,
 input  wire [`OUT_STRIDE_BITS-1:0]       i_disp_stride,
 input  wire  [`COST_BITS-1:0]            i_P1,
 input  wire  [`COST_BITS-1:0]            i_P2,
 input  wire [`DISPD_BITS-1:0]            i_min_disp,
 input  wire [`DISPD_BITS-1:0]            i_max_disp,
 input  wire             [7:0]            i_unique_ratio, //0~100
 input  wire [`DISPD_BITS-1:0]            i_disp12_max_diff,

 input  wire [31:0]                       fp_cost,
 input  wire [31:0]                       fp_intermediate,
 input  wire [31:0]                       fp_window,
 input  wire [31:0]                       fp_window_reverse,
 input  wire [31:0]                       fp_hsum,
 input  wire [31:0]                       fp_aggr_left_right,
 input  wire [31:0]                       fp_aggr_right_left,
 input  wire [31:0]                       fp_aggr_down_left,
 input  wire [31:0]                       fp_aggr_down,
 input  wire [31:0]                       fp_aggr_down_right,
 input  wire [31:0]                       fp_aggr,
 input  wire [31:0]                       fp_unique,
 input  wire [31:0]                       fp_lr_check,
 input  wire [31:0]                       fp_lr_check2,

 //axi bus read if
 input  wire                              m_axi_arready,
 output wire                              m_axi_arvalid,
 output wire [ 3:0]                       m_axi_arlen,
 output wire [31:0]                       m_axi_araddr,
 output wire [ 5:0]                       m_axi_arid,
 output wire [ 2:0]                       m_axi_arsize,
 output wire [ 1:0]                       m_axi_arburst,
 output wire [ 2:0]                       m_axi_arprot,
 output wire [ 3:0]                       m_axi_arcache,
 output wire [ 1:0]                       m_axi_arlock,
 output wire [ 3:0]                       m_axi_arqos,

 output wire                              m_axi_rready,
 input  wire [63:0]                       m_axi_rdata,
 input  wire                              m_axi_rvalid,
 input  wire                              m_axi_rlast,

 //axi bus write if
 input  wire                              m_axi_awready, // Indicates slave is ready to accept a
 output wire [ 5:0]                       m_axi_awid,    // Write ID
 output wire [31:0]                       m_axi_awaddr,  // Write address
 output wire [ 3:0]                       m_axi_awlen,   // Write Burst Length
 output wire [ 2:0]                       m_axi_awsize,  // Write Burst size
 output wire [ 1:0]                       m_axi_awburst, // Write Burst type
 output wire [ 1:0]                       m_axi_awlock,  // Write lock type
 output wire [ 3:0]                       m_axi_awcache, // Write Cache type
 output wire [ 2:0]                       m_axi_awprot,  // Write Protection type
 output reg                               m_axi_awvalid, // Write address valid

 input  wire                              m_axi_wready,  // Write data ready
 output wire [ 5:0]                       m_axi_wid,     // Write ID tag
 output wire [63:0]                       m_axi_wdata,    // Write data
 output reg  [ 7:0]                       m_axi_wstrb,    // Write strobes
 output reg                               m_axi_wlast,    // Last write transaction
 output reg                               m_axi_wvalid,   // Write valid

 input  wire [ 5:0]                       m_axi_bid,     // Response ID
 input  wire [ 1:0]                       m_axi_bresp,   // Write response
 input  wire                              m_axi_bvalid,  // Write reponse valid
 output wire                              m_axi_bready,  // Response ready
 output wire [ 5:0]                       m_axi_rrid,
 input  wire [ 1:0]                       m_axi_rresp,
 output wire [ 2:0]                       o_calcing_state
);



assign m_axi_awid = 0;
assign m_axi_awsize = 3;
assign m_axi_awburst = 1;
assign m_axi_awlock = 0;
assign m_axi_awcache = 0;
assign m_axi_awprot = 0;

assign m_axi_wid = 0;

assign m_axi_bready = 1;

assign m_axi_arid = 0;
assign m_axi_arsize = 3;
assign m_axi_arburst = 1;//0=fixed adress burst 1=incrementing 2=wrap 
assign m_axi_arprot = 0;
assign m_axi_arcache = 0;
assign m_axi_arlock = 0;
assign m_axi_arqos = 0;


//bt_cost_valid时x=92+9=101

//左右和上面三个方向的聚合是从左到右的，先得到最左边数据，
//右左方向是从右到左，先得到最右边数据，所以左右聚合的时候，右左聚合必须已经完成，5个方向相加得到结果
//否则如果左右，右左聚合要并行，就必须缓存2行结果

(*mark_debug="true"*)
reg    [`WIDTH_BITS-1:0]     x;
(*mark_debug="true"*)
reg    [`WIDTH_BITS-1:0]     x_reverse;
(*mark_debug="true"*)
wire   [`HEIGHT_BITS-1:0]    y;

(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_left_row0;
(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_left_row1;
(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_left_row2;
(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_right_row0;
(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_right_row1;
(*mark_debug="true"*)
wire        [4:0][7:0]   pixel_right_row2;

(*mark_debug="true"*)
wire                     rst_calc_cost;
wire                     clr_disp_ram;
(*mark_debug="true"*)
wire                     reverse;

wire             [4:0]   calc_cost_one_row_done;

reg                      window_cost_done;
reg                      window_cost_reverse_done;
reg                      clr_disp2_done;
reg                      lr_check_done;
reg                      output_done;

wire                     aggr_down_done;
wire                     aggr_down_left_done;
wire                     aggr_right_left_done;

line_buffer_8row line_buffer_8row_inst
(
    .clk                                (clk),
    .rst                                (rst),
    .i_width                            (i_width),
    .i_height                           (i_height),
    .i_stride                           (i_stride),
    .i_left_image_addr                  (i_left_image_addr),
    .i_right_image_addr                 (i_right_image_addr),
    .i_min_disp                         (i_min_disp),
    .i_max_disp                         (i_max_disp),
    .i_reverse_done                     (calc_cost_one_row_done[0]&&
                                         window_cost_reverse_done&&
                                         aggr_right_left_done),
    .i_all_done                         (calc_cost_one_row_done[0]&&           //在源头等待其他所有完成进行，然后发起起跑
                                         window_cost_done&&
                                         clr_disp2_done&&
                                         lr_check_done&&
                                         output_done&&
                                         aggr_down_done&&
                                         aggr_down_left_done&&
                                         aggr_right_left_done),
    .o_rst_calc_cost                    (rst_calc_cost),
    .o_calcing_state                    (o_calcing_state),
    .o_clr_disp_ram                     (clr_disp_ram),
    .o_reverse                          (reverse),
    .y                                  (y),

    .m_axi_arready                      (m_axi_arready),
    .m_axi_arvalid                      (m_axi_arvalid),
    .m_axi_arlen                        (m_axi_arlen),
    .m_axi_araddr                       (m_axi_araddr),

    .m_axi_rready                       (m_axi_rready),
    .m_axi_rdata                        (m_axi_rdata),
    .m_axi_rvalid                       (m_axi_rvalid),
    .m_axi_rlast                        (m_axi_rlast),


    .o_data0                            ({pixel_left_row0[0],pixel_right_row0[0],
                                          pixel_left_row1[0],pixel_right_row1[0],
                                          pixel_left_row2[0],pixel_right_row2[0]}),
    .o_data1                            ({pixel_left_row0[1],pixel_right_row0[1],
                                          pixel_left_row1[1],pixel_right_row1[1],
                                          pixel_left_row2[1],pixel_right_row2[1]}),
    .o_data2                            ({pixel_left_row0[2],pixel_right_row0[2],
                                          pixel_left_row1[2],pixel_right_row1[2],
                                          pixel_left_row2[2],pixel_right_row2[2]}),
    .o_data3                            ({pixel_left_row0[3],pixel_right_row0[3],
                                          pixel_left_row1[3],pixel_right_row1[3],
                                          pixel_left_row2[3],pixel_right_row2[3]}),
    .o_data4                            ({pixel_left_row0[4],pixel_right_row0[4],
                                          pixel_left_row1[4],pixel_right_row1[4],
                                          pixel_left_row2[4],pixel_right_row2[4]})

);



(*mark_debug="true"*)
wire [4:0][8*`DISPD-1:0]     bt_cost_data;

reg [4:0][4:0][8*`DISPD-1:0]     bt_cost_ram;

(*mark_debug="true"*)
wire [4:0]                   bt_cost_valid;
wire                         first_bt_cost_valid;

(*mark_debug="true"*)
reg                          window_cost_valid;
(*mark_debug="true"*)
reg                          window_cost_pre_valid;
reg                          window_cost_reverse_valid;
reg                          window_cost_reverse_pre_valid;


wire [4:0][0:`DISPD-1][7:0]  bt_cost_add = bt_cost_data;
wire [4:0][0:`DISPD-1][7:0]  bt_cost_sub;

always @ (posedge clk) begin
    bt_cost_ram  <= {bt_cost_data,bt_cost_ram[4:1]};
end

reg               [ 1:0]   state;
parameter BufferDelay = 7;

//disp1ptr[x + minX1] = (DispType)(d + minD*DISP_SCALE);
//从windowed cost valid到存入disp1ptr的数据有效
parameter WindowCost2Disp1ptrDelay = 27;



reg           bt_cost_valid_d1;
reg           bt_cost_valid_d2;
reg           bt_cost_valid_d3;
reg           bt_cost_valid_d4;
reg           bt_cost_valid_d5;

always @ (posedge clk) begin
    bt_cost_valid_d1          <= bt_cost_valid[0];
    bt_cost_valid_d2          <= bt_cost_valid_d1;
    bt_cost_valid_d3          <= bt_cost_valid_d2;
    bt_cost_valid_d4          <= bt_cost_valid_d3;
    bt_cost_valid_d5          <= bt_cost_valid_d4;
end

assign first_bt_cost_valid = bt_cost_valid[0]==1&&bt_cost_valid_d1==0;

reg   [4:0]       delay_cycles1;
reg   [4:0]       delay_cycles2;
reg               read_right_left_aggr_ram;
reg               read_down_right_aggr_ram;

reg               disp2_update_valid;
reg               lr_check_ram_valid; //第一行window cost,填disp1ptr,disp2ptr完成，可以lr_check了


reg    [`WIDTH_BITS-1:0]     x_log;

always @(posedge clk)
if (rst) begin
    x                                 <= 0;
    delay_cycles2                     <= 0;
    window_cost_done                  <= 1;
    window_cost_valid                 <= 0;
    window_cost_pre_valid             <= 0;
    disp2_update_valid                <= 0;
    lr_check_ram_valid                <= 0;
    x_log                             <= 0;
end
else if (rst_calc_cost&&~reverse) begin
    x                                 <= 0;
    delay_cycles2                     <= 0;
    window_cost_done                  <= 0;
    window_cost_valid                 <= 0;
    window_cost_pre_valid             <= 0;
    disp2_update_valid                <= 0;
    read_right_left_aggr_ram          <= 0;
    read_down_right_aggr_ram          <= 0;
    x_log                             <= 0;
end
else if (~reverse)begin

    if (bt_cost_valid[0]) begin //bt_cost_valid[0]变1一直持续到下一个reset的,x增长到一定程度会停止增长，x_log一直增长
        x_log                         <= x_log+1;
    end

    if (bt_cost_valid[0] && delay_cycles2<9)
        delay_cycles2                 <= delay_cycles2+1;

    if (delay_cycles2==5) begin
        window_cost_pre_valid         <= 1;
        read_right_left_aggr_ram      <= 1; //须提前一点
        read_down_right_aggr_ram      <= 1;
    end

    if (delay_cycles2==6) begin
        x                             <= i_max_disp;
        window_cost_pre_valid         <= 0;
        window_cost_valid             <= 1;
    end
    else if (x>=i_max_disp&&
             x<i_width-1+WindowCost2Disp1ptrDelay+1) begin
        x                             <= x+1;

        if (x==i_max_disp+4)
            disp2_update_valid        <= 1;

        if (x==i_width+4) begin
            disp2_update_valid        <= 0;
            lr_check_ram_valid        <= 1;
        end

        if (x==i_width-1) begin
            window_cost_valid         <= 0;
            read_right_left_aggr_ram  <= 0;
            read_down_right_aggr_ram  <= 0;
        end

        if (x==i_width-1+WindowCost2Disp1ptrDelay)
            window_cost_done          <= 1;
    end

end

always @(posedge clk)
if (rst) begin
    x_reverse                         <= 0;
    delay_cycles1                     <= 0;
    window_cost_reverse_done          <= 1;
    window_cost_reverse_valid         <= 0;
    window_cost_reverse_pre_valid     <= 0;
end
else if (rst_calc_cost&&reverse) begin
    x_reverse                         <= 0;
    delay_cycles1                     <= 0;
    window_cost_reverse_done          <= 0;
    window_cost_reverse_valid         <= 0;
    window_cost_reverse_pre_valid     <= 0;
end
else if (reverse)begin
    if (bt_cost_valid[0] && delay_cycles1<9)
        delay_cycles1  <= delay_cycles1+1;

    if (delay_cycles1==5)
        window_cost_reverse_pre_valid <= 1;

    if (delay_cycles1==6) begin
        x_reverse                      <= i_width-1;
        window_cost_reverse_pre_valid  <= 0;
        window_cost_reverse_valid      <= 1;
    end
    else if (x_reverse>=i_max_disp)begin
        x_reverse <= x_reverse-1;
        if (x_reverse==i_max_disp) begin
            window_cost_reverse_valid      <= 0;
            window_cost_reverse_done       <= 1;
        end
    end
end



integer      ii;
genvar       i,j;


reg         [4:0][0:`DISPD-1][10:0]   hsum_add; //5个8bit相加

reg    [0:`DISPD-1][`COST_BITS-1:0]   first_windowed_cost; //第一行最左边的windowed cost，opencv第二行开始并没有算最左边的滑动窗口，而是沿用第一行的

reg    [0:`DISPD-1][`COST_BITS-1:0]   windowed_cost_tmp0;
reg    [0:`DISPD-1][`COST_BITS-1:0]   windowed_cost_tmp1;
(*mark_debug="true"*)
reg    [0:`DISPD-1][`COST_BITS-1:0]   windowed_cost;

parameter Y_Delay1 =4;
parameter Y_Delay2 =4;
parameter X_Delay1 =7;


//y=            0    1    2    3    4    5    6    7    8    9    10   11         17(y=22)
//reverse D=0  1029,1038,1047,1059,1068,1068,1068,1071,1071
//        D=0  1359,
//x=93         1515,1463,1389,1359,1402,1510,1656,1867,2047,2157,2198,2191,       1161

//left, cost_valid时数据对应101列
//right 89列

generate
    for (i=0;i<`DISPD;i=i+1)
    begin: window_cost_label
        always @(posedge clk) begin

            windowed_cost_tmp1[i]              <= hsum_add[3][i]+hsum_add[4][i]+i_P2;
            windowed_cost_tmp0[i]              <= hsum_add[0][i]+hsum_add[1][i]+hsum_add[2][i];

            windowed_cost[i]                   <= (reverse&&x_reverse==i_max_disp+1&&y!=0+Y_Delay1)||
                                                  (~reverse&&delay_cycles2==6)?first_windowed_cost[i]:
                                                   windowed_cost_tmp0[i]+windowed_cost_tmp1[i];

            if (reverse&&x_reverse==i_max_disp&&y==0+Y_Delay1)
                first_windowed_cost[i]         <= windowed_cost[i];

        end
    end
endgenerate

always @ (posedge clk) begin
    if (~reverse) begin
        for (ii=0;ii<`DISPD;ii=ii+1) begin
            if (`log_window&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&window_cost_valid&&ii<i_max_disp-i_min_disp)
                $fdisplay(fp_window, "y=%0d x=%0d D=%0d window %0d",
                 y-Y_Delay2, x,ii, windowed_cost[ii]);
        end
    end
    else begin
        for (ii=0;ii<`DISPD;ii=ii+1) begin
            if (`log_window&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&
                window_cost_reverse_valid&&ii<i_max_disp-i_min_disp)
                $fdisplay(fp_window_reverse, "y=%0d x=%0d D=%0d window %0d",
                 y-Y_Delay2, x_reverse,ii, windowed_cost[ii]);
        end
    end

end

assign  bt_cost_sub = bt_cost_valid_d5==0?'d0:bt_cost_ram[0];
generate
    for (i=0;i<5;i=i+1)
    begin: outer_hsum_label
        for (j=0;j<`DISPD;j=j+1)
        begin : inner_hsum_label
            //hsum_add, 水平方向上5个点相加和，窗口大小5x5,窗口向前推进1格，加上最新的值，减去最老的值
            always @ (posedge clk)
                if (first_bt_cost_valid)
                    hsum_add[i][j] <= bt_cost_add[i][j];
                else
                    hsum_add[i][j] <= hsum_add[i][j] + bt_cost_add[i][j] - bt_cost_sub[i][j];
        end
    end
endgenerate


generate
    for (i=0;i<5;i=i+1)
    begin: calc_cost_bt_label

        calc_cost_bt calc_cost_bt_inst(
            .clk                        (clk),
            .rst                        (rst),

            .i_width                    (i_width),
            .i_pixel_left_row0          (pixel_left_row0[i]),
            .i_pixel_left_row1          (pixel_left_row1[i]),
            .i_pixel_left_row2          (pixel_left_row2[i]),
            .i_pixel_right_row0         (pixel_right_row0[i]),
            .i_pixel_right_row1         (pixel_right_row1[i]),
            .i_pixel_right_row2         (pixel_right_row2[i]),
            .i_rst_calc_cost            (rst_calc_cost),
            .i_reverse                  (reverse),
            .i_min_disp                 (i_min_disp),
            .i_max_disp                 (i_max_disp),

            .o_data                     (bt_cost_data[i]),
            .o_valid                    (bt_cost_valid[i]),
            .o_calc_cost_one_row_done   (calc_cost_one_row_done[i])
        
        );
    end
endgenerate



//aggr 
(*mark_debug="true"*)
wire  [0:`DISPD-1][`COST_BITS-1:0] cost_down_right;
(*mark_debug="true"*)
wire  [0:`DISPD-1][`COST_BITS-1:0] cost_down;
(*mark_debug="true"*)
wire  [0:`DISPD-1][`COST_BITS-1:0] cost_down_left;
(*mark_debug="true"*)
wire  [0:`DISPD-1][`COST_BITS-1:0] cost_left_right;
(*mark_debug="true"*)
wire  [0:`DISPD-1][`COST_BITS-1:0] cost_right_left;

(*mark_debug="true"*)
reg        [0:`DISPD-1][`FINAL_COST_BITS-1:0] Spd;
reg signed [0:`DISPD-1][`FINAL_COST_BITS-1:0] Spd_d1;

wire                              aggr_down_right_valid;
wire                              aggr_down_valid;
wire                              aggr_down_left_valid;
wire                              aggr_left_right_valid;
wire                              aggr_right_left_valid;

reg                               clr_up_three_aggr_ram;


always @ (posedge clk) begin
    if (rst) begin
        clr_up_three_aggr_ram    <= 1;
    end
    else if (y==Y_Delay1) //足够时间清0了
        clr_up_three_aggr_ram    <= 0;
end



sgbm_aggr_down sgbm_aggr_down_inst (
    .clk(clk),
    .rst(rst),

    .i_cost(windowed_cost),
    .i_cost_valid(window_cost_valid),
    .i_cost_pre_valid(window_cost_pre_valid),
    .i_rst_aggr(rst_calc_cost&&~reverse),
    .i_clr_ram(clr_up_three_aggr_ram),
    .i_min_disp(i_min_disp),
    .i_max_disp(i_max_disp),
    .i_width(i_width),
    .i_P1(i_P1),
    .i_P2(i_P2),

    .o_cost(cost_down),
    .o_valid(aggr_down_valid),
    .o_aggr_done(aggr_down_done)
);

sgbm_aggr_down_left sgbm_aggr_down_left_inst (
    .clk(clk),
    .rst(rst),

    .i_cost(windowed_cost),
    .i_cost_valid(reverse?window_cost_reverse_valid:
                  window_cost_valid),
    .i_cost_pre_valid(reverse?window_cost_reverse_pre_valid:
                      window_cost_pre_valid),
    .i_rst_aggr(rst_calc_cost),
    .i_reverse(reverse),
    .i_rd_req(read_down_right_aggr_ram),
    .i_min_disp(i_min_disp),
    .i_max_disp(i_max_disp),
    .i_clr_ram(clr_up_three_aggr_ram),
    .i_width(i_width),
    .i_P1(i_P1),
    .i_P2(i_P2),

    .o_cost_down_left(cost_down_left),
    .o_cost_down_right(cost_down_right),
    .o_valid(aggr_down_left_valid),
    .o_aggr_done(aggr_down_left_done)
);

sgbm_aggr_right_left  sgbm_aggr_right_left_inst (
    .clk(clk),
    .rst(rst),

    .i_cost(windowed_cost),
    .i_cost_valid(reverse?window_cost_reverse_valid:
                  window_cost_valid),
    .i_rst_aggr(rst_calc_cost),
    .i_rd_req(read_right_left_aggr_ram),
    .i_reverse(reverse),
    .i_min_disp(i_min_disp),
    .i_max_disp(i_max_disp),
    .i_width(i_width),
    .i_P1(i_P1),
    .i_P2(i_P2),

    .o_cost(cost_left_right),
    .o_cost_ram(cost_right_left),
    .o_valid(aggr_right_left_valid),
    .o_aggr_done(aggr_right_left_done)
);

reg        [0:`DISPD-1][`FINAL_COST_BITS-1:0] Spd_w;

//实际坐标x=170，x=170 windowed cost有效，cost_down,...有效
//x=171出Spd,
//x=172出minS,bestDisp,
//x=173出unique_operand0,unique_operand1
//x=174出ununique
//x=175出uniqueness
//x=197出d_scale,也就是disp1ptr
//x=174出x2_d1(disp2cost_ram_rd_addr)
//x=175出disp2cost_ram_dout,disp2ptr_ram_addra,disp2cost_ram_wr_addr准备好,写入


always @(*)
for (ii = 0; ii < `DISPD; ii = ii+1)
    Spd_w[ii]=cost_down_right[ii]+cost_down[ii]+cost_down_left[ii]+cost_left_right[ii]+cost_right_left[ii];

//pipeline 0
always @(posedge clk)
for (ii = 0; ii < `DISPD; ii = ii+1) begin
    Spd[ii]     <= cost_down_right[ii]+cost_down[ii]+cost_down_left[ii]+cost_left_right[ii]+cost_right_left[ii];
    Spd_d1[ii]  <= Spd[ii];

        if (`log_aggr&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr, "y=%0d x=%0d d=%0d Spd %0d=%0d+%0d+%0d+%0d+%0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii, Spd_w[ii],
             cost_down_right[ii],
             cost_down[ii],
             cost_down_left[ii],
             cost_left_right[ii],
             cost_right_left[ii]);

        if (`log_aggr_left_right&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr_left_right, "y=%0d x=%0d d=%0d L0 %0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii,
             cost_left_right[ii]);

        if (`log_aggr_right_left&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr_right_left, "y=%0d x=%0d d=%0d L0 %0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii,
             cost_right_left[ii]);

        if (`log_aggr_down_right&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr_down_right, "y=%0d x=%0d d=%0d L1 %0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii,
             cost_down_right[ii]);

        if (`log_aggr_down&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr_down, "y=%0d x=%0d d=%0d L2 %0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii,
             cost_down[ii]);

        if (`log_aggr_down_left&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
            x_log>=X_Delay1&&x_log<X_Delay1+i_width-i_max_disp)
            $fdisplay(fp_aggr_down_left, "y=%0d x=%0d d=%0d L3 %0d",
             y-Y_Delay2, x_log+i_max_disp-X_Delay1,ii,
             cost_down_left[ii]);

end



localparam
DispDHeapHeight = $clog2(`DISPD-1)+1,
DispDHeapWidth = 2**(DispDHeapHeight-1),
DispDHeapSize = 2**DispDHeapHeight-1;

reg [1:DispDHeapSize][`FINAL_COST_BITS-1:0]  minS_heap;
reg [1:DispDHeapSize][`DISPD_BITS-1:0]       bestDisp_heap;

reg                    [`FINAL_COST_BITS-1:0]  minS;
reg                    [`FINAL_COST_BITS-1:0]  minS_d1;
reg                    [`FINAL_COST_BITS-1:0]  minS_d2;
reg                    [`FINAL_COST_BITS-1:0]  minS_d3;
(*mark_debug="true"*)
reg                    [`DISPD_BITS-1:0]       bestDisp;


reg                                      disp_ram_sel;
reg       [1:0]                          disp2_ram_sel;
reg       [1:0][`WIDTH_BITS-1:0]         disp1_ptr_ram_addr;
reg       [1:0]                          disp1_ptr_ram_wr_ena;
reg            [`DISP_TYPE_BITS-1:0]     disp1_ptr_ram_din;
wire      [1:0][`DISP_TYPE_BITS-1:0]     disp1_ptr_ram_dout;

reg       [2:0][`WIDTH_BITS-1:0]         disp2_ptr_ram_addra;
reg       [2:0][`WIDTH_BITS-1:0]         disp2_ptr_ram_addrb;
reg       [2:0]                          disp2_ptr_ram_wr_ena;
reg       [2:0][`DISPD_BITS-1:0]         disp2_ptr_ram_dia;
wire      [2:0][`DISPD_BITS-1:0]         disp2_ptr_ram_doa;
wire      [2:0][`DISPD_BITS-1:0]         disp2_ptr_ram_dob;

reg       [1:0][`WIDTH_BITS-1:0]         disp2_cost_ram_rd_addr;
reg       [1:0][`WIDTH_BITS-1:0]         disp2_cost_ram_wr_addr;
reg       [1:0]                          disp2_cost_ram_wr_ena;
reg       [1:0][`FINAL_COST_BITS-1:0]    disp2_cost_ram_din;
wire      [1:0][`FINAL_COST_BITS-1:0]    disp2_cost_ram_dout;


reg   [`FINAL_COST_BITS-1:0]    denom2;
reg   [`FINAL_COST_BITS-1:0]    denom2_d1;
reg   [`FINAL_COST_BITS-1:0]    old_disp2_cost_in_ram;
reg   [`FINAL_COST_BITS-1:0]    minS_disp2_update;
reg                             need_update_disp2; //wire


reg   [`FINAL_COST_BITS-1:0]    Spd_left;   //Sp[d-1]
reg   [`FINAL_COST_BITS-1:0]    Spd_right;   //Sp[d+1]
reg   [`FINAL_COST_BITS-1:0]    Spd_left_d1;
reg   [`FINAL_COST_BITS-1:0]    Spd_right_d1;
reg                             do_interpolate;
reg                   [22:0]    do_interpolate_d;



reg  [23:0][`DISPD_BITS-1:0]    d_d;
reg        [`WIDTH_BITS-1:0]    x2;
reg        [`WIDTH_BITS-1:0]    x2_d1;
reg        [`WIDTH_BITS-1:0]    x2_d2;
reg        [`WIDTH_BITS-1:0]    x2_d3;

wire signed [`FINAL_COST_BITS:0]   denom2_tmp;
reg                       [19:0]   d_scale_tmp_ge0;
reg                       [19:0]   d_scale_tmp_lt0;
reg                                d_scale_tmp_sign;
reg                       [20:0]   d_scale_tmp_sign_d;
wire                      [19:0]   div_result_ge0;
wire                      [19:0]   div_result_lt0;
reg       [`FINAL_COST_BITS-1:0]   d_scale;
reg        [`DISP_TYPE_BITS-1:0]   minD_minus1;
reg        [`DISP_TYPE_BITS-1:0]   invalid_disp_scale;

(*mark_debug="true"*)
reg            [`WIDTH_BITS-1:0]    x_output;
reg           [`HEIGHT_BITS-1:0]    y_output;
reg            [`WIDTH_BITS-1:0]    x_lr_check;
reg            [`WIDTH_BITS-1:0]    x_lr_check_d1;
reg            [`WIDTH_BITS-1:0]    x_lr_check_d2;
reg            [`WIDTH_BITS-1:0]    x_lr_check_d3;
reg            [`WIDTH_BITS-1:0]    x_lr_check_d4;
reg            [`WIDTH_BITS-1:0]    x_lr_check_d5;

reg            [`WIDTH_BITS-1:0]    x_clr;
reg           [`PIC_SIZE_BITS:0]    disp_output_offset;
reg           [`PIC_SIZE_BITS:0]    disp_output_line_offset;
(*mark_debug="true"*)
reg                        [2:0]    output_stage;

wire signed       [7:0]  hundred_minus_unique;
reg        [0:`DISPD-1]  ununique;
reg                      uniqueness;
reg              [21:0]  unique_d;


assign hundred_minus_unique = 100-i_unique_ratio;

(* use_dsp = "yes" *) 
reg  signed     [0:`DISPD-1][`FINAL_COST_BITS+7:0]  unique_result; //Sp[d]*(100 - uniquenessRatio)


wire  signed                 [`FINAL_COST_BITS+7:0]  unique_operand1; //minS*100
assign unique_operand1 = minS*100;

//pipeline 2
always @ (posedge clk) begin
    for (ii = 0; ii < `DISPD; ii = ii + 1) begin
        unique_result[ii] <= Spd_d1[ii]*hundred_minus_unique-unique_operand1;
    end
end
always @ (posedge clk) begin
    if (unique_result[0][`FINAL_COST_BITS+7]&&d_d[0]>1) begin //fix,ii-d_d[0]>1||d_d[0]-ii>1,不能出现减法
        ununique[0]  <= 1;

        if (`log_unique&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&
            x_log>=X_Delay1+3&&x_log<X_Delay1+3+i_width-i_max_disp)
            $fdisplay(fp_unique, "y=%0d x=%0d d=%0d operand1 %0d unique 0",
             y-Y_Delay2, x_log-(X_Delay1+3)+i_max_disp,0,unique_operand1);

    end
    else begin
        ununique[0]  <= 0;
        if (`log_unique&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&
            x_log>=X_Delay1+3&&x_log<X_Delay1+3+i_width-i_max_disp)
            $fdisplay(fp_unique, "y=%0d x=%0d d=%0d operand1 %0d unique 1",
             y-Y_Delay2, x_log-(X_Delay1+3)+i_max_disp,0,unique_operand1);

    end
end


always @ (posedge clk) begin
    for (ii = 1; ii < `DISPD; ii = ii + 1) begin
        if (ii>=i_max_disp-i_min_disp) begin
            ununique[ii]  <= 0;
        end
        else if (unique_result[ii][`FINAL_COST_BITS+7]&&(ii-1>d_d[0]||d_d[0]>ii+1)) begin //fix,ii-d_d[0]>1||d_d[0]-ii>1,不能出现减法
            ununique[ii]  <= 1;

            if (`log_unique&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
                x_log>=X_Delay1+3&&x_log<X_Delay1+3+i_width-i_max_disp)
                $fdisplay(fp_unique, "y=%0d x=%0d d=%0d operand1 %0d unique 0",
                 y-Y_Delay2, x_log-(X_Delay1+3)+i_max_disp,ii,unique_operand1);

        end
        else begin
            ununique[ii]  <= 0;
            if (`log_unique&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&ii<i_max_disp-i_min_disp&&
                x_log>=X_Delay1+3&&x_log<X_Delay1+3+i_width-i_max_disp)
                $fdisplay(fp_unique, "y=%0d x=%0d d=%0d operand1 %0d unique 1",
                 y-Y_Delay2, x_log-(X_Delay1+3)+i_max_disp,ii,unique_operand1);

        end
    end
end


//pipeline 4
always @ (posedge clk) begin
    if (ununique==0) begin
        uniqueness   <= 1;
    end else begin
        uniqueness   <= 0;
    end
end

always @ (posedge clk) begin
    unique_d[0]     <= uniqueness;
    for (ii = 1; ii < 22; ii = ii + 1) begin
        unique_d[ii] <= unique_d[ii-1];
    end
end

//lr check,
//int _d = d1 >> DISP_SHIFT;
//int d_ = (d1 + DISP_SCALE-1) >> DISP_SHIFT;
//int _x = x - _d, x_ = x - d_;

reg            [`WIDTH_BITS-1:0]    x_1; //_x
reg            [`WIDTH_BITS-1:0]    x_2; //x_

generate
    for (i=0;i<2;i=i+1)
    begin: disp1_ptr_ram_label
        ram #(`WIDTH_BITS, `DISP_TYPE_BITS) disp1_ptr_ram_inst(
            .clk(clk),
            .en(1'b1),
            .we(disp1_ptr_ram_wr_ena[i]),
            .addr(disp1_ptr_ram_addr[i]),
            .data_in(disp1_ptr_ram_din),
            .data_out(disp1_ptr_ram_dout[i])
        );
    end
endgenerate

generate
    for (i=0;i<3;i=i+1)
    begin: disp2_ptr_ram_label
        ram_d #(`WIDTH_BITS, `DISPD_BITS) disp2_ptr_ram_inst(
            .clk        (clk),
            .en         (1'b1),
            .we         (disp2_ptr_ram_wr_ena[i]),
            .addra      (disp2_ptr_ram_addra[i]),
            .addrb      (disp2_ptr_ram_addrb[i]),
            .dia        (disp2_ptr_ram_dia[i]),
            .doa        (disp2_ptr_ram_doa[i]),
            .dob        (disp2_ptr_ram_dob[i])

        );
    end
endgenerate

generate
    for (i=0;i<2;i=i+1)
    begin: disp2_cost_ram_label
        dp_ram #(`FINAL_COST_BITS, `WIDTH_BITS) disp2_cost_ram_inst(
            .data(disp2_cost_ram_din[i]),
            .wraddress(disp2_cost_ram_wr_addr[i]),
            .rdaddress(disp2_cost_ram_rd_addr[i]),
            .wren(disp2_cost_ram_wr_ena[i]),
            .rdclock(clk),
            .wrclock(clk),
            .q(disp2_cost_ram_dout[i]),
            .aclr(1'b0)

        );
    end
endgenerate



always @ (posedge clk) begin
    d_d[0]     <= bestDisp;
    for (ii = 1; ii <= 23; ii = ii + 1) begin
        d_d[ii] <= d_d[ii-1];
    end
end

always @ (posedge clk) begin
    if (rst) begin
        disp_ram_sel   <= 0;
        disp2_ram_sel  <= 0;
    end
    else if (rst_calc_cost&&reverse) begin //rst_calc_cost_reverse时disp_ram_sel=0保持不变，并且开始清这个ram[0]
        disp_ram_sel   <= ~disp_ram_sel;
        disp2_ram_sel  <= disp2_ram_sel==0?1:(disp2_ram_sel==1?2:0);
    end
end

//int _x2 = x + minX1 - d - minD;
//这里x是从minX1(i_max_disp)开始，不用加i_max_disp
//pipeline 2
always @ (posedge clk) begin
    x2       <= x>=i_max_disp+2?x-i_min_disp-bestDisp-2:0; //
    x2_d1    <= x2;
    x2_d2    <= x2_d1;
    x2_d3    <= x2_d2;
end

always @ (*) begin
    if (x2_d3 == x2_d2) begin //假如前后两点_x2一样，前面一点的更新值没写进去，读出来就不对
        old_disp2_cost_in_ram        = minS_disp2_update;
        if (x2_d3!=0&&uniqueness)
            $display("%t same address in a row occur x2=%d x=%d",$time,x2_d3,x-i_max_disp-5);
    end
    else begin
        if (disp_ram_sel)
            old_disp2_cost_in_ram    = disp2_cost_ram_dout[1];
        else
            old_disp2_cost_in_ram    = disp2_cost_ram_dout[0];
    end
end

//opencv x从大到小遍历，两个x minS相同选前面的x，这里x从小到大遍历，x选后面的，所以是>=
always @ (*) begin
    need_update_disp2   = uniqueness&&disp2_update_valid&&(old_disp2_cost_in_ram>=minS_d3)?1:0;
end

always @ (posedge clk) begin
    if (need_update_disp2) begin
        minS_disp2_update   <= minS_d3;

        if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&
            x_log>=X_Delay1+5&&x_log<X_Delay1+5+i_width-i_max_disp)
            $fdisplay(fp_lr_check, "y=%0d x=%0d disp2cost[%0d] %0d update to %0d disp2ptr[%0d] %0d",
             y-Y_Delay2, x_log-(X_Delay1+5)+i_max_disp,x2_d3,old_disp2_cost_in_ram,minS_d3,x2_d3,d_d[2]+i_min_disp);


    end
    else begin
        minS_disp2_update   <= old_disp2_cost_in_ram;

        if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
            y<Y_Delay2+i_height&&
            x_log>=X_Delay1+5&&x_log<X_Delay1+5+i_width-i_max_disp)
            $fdisplay(fp_lr_check, "y=%0d x=%0d disp2cost[%0d] %0d keep same",
             y-Y_Delay2, x_log-(X_Delay1+5)+i_max_disp,x2_d3,old_disp2_cost_in_ram);



    end
end


always @ (*) begin
    if (unique_d[21])
        disp1_ptr_ram_din           = d_scale;
    else
        disp1_ptr_ram_din           = invalid_disp_scale;

    if (disp_ram_sel) begin
        disp1_ptr_ram_addr[0]       = x_lr_check_d1; //延迟1周期，等disp_ram_sel翻转
        disp1_ptr_ram_addr[1]       = x-WindowCost2Disp1ptrDelay;
        disp1_ptr_ram_wr_ena[0]     = 0;
        disp1_ptr_ram_wr_ena[1]     = 1; //1用来写入，0读出，左右一致检测，输出ddr
    end
    else begin
        disp1_ptr_ram_addr[0]       = x-WindowCost2Disp1ptrDelay;
        disp1_ptr_ram_addr[1]       = x_lr_check_d1;
        disp1_ptr_ram_wr_ena[0]     = 1;
        disp1_ptr_ram_wr_ena[1]     = 0;
    end
end


always @ (*) begin

    if (disp2_ram_sel==0) begin
        disp2_ptr_ram_wr_ena[0]     = 1;                 //clr
        disp2_ptr_ram_wr_ena[1]     = need_update_disp2; //写入
        disp2_ptr_ram_wr_ena[2]     = 0;                 //lr check
        disp2_ptr_ram_addra[0]      = x_clr;
        disp2_ptr_ram_addra[1]      = x2_d2;
        disp2_ptr_ram_addra[2]      = x_1;
        disp2_ptr_ram_addrb[0]      = 0;
        disp2_ptr_ram_addrb[1]      = 0;                //无需读
        disp2_ptr_ram_addrb[2]      = x_2;
        disp2_ptr_ram_dia[0]        = invalid_disp_scale;
        disp2_ptr_ram_dia[1]        = d_d[2]+i_min_disp;
        disp2_ptr_ram_dia[2]        = 0;
    end
    else if (disp2_ram_sel==1) begin
        disp2_ptr_ram_wr_ena[0]     = need_update_disp2; //写入
        disp2_ptr_ram_wr_ena[1]     = 0;                 //lr check
        disp2_ptr_ram_wr_ena[2]     = 1;                 //clr
        disp2_ptr_ram_addra[0]      = x2_d2;
        disp2_ptr_ram_addra[1]      = x_1;
        disp2_ptr_ram_addra[2]      = x_clr;
        disp2_ptr_ram_addrb[0]      = 0;
        disp2_ptr_ram_addrb[1]      = x_2;
        disp2_ptr_ram_addrb[2]      = 0;
        disp2_ptr_ram_dia[0]        = d_d[2]+i_min_disp;
        disp2_ptr_ram_dia[1]        = 0;
        disp2_ptr_ram_dia[2]        = invalid_disp_scale;
    end
    else begin
        disp2_ptr_ram_wr_ena[0]     = 0;                 //lr check
        disp2_ptr_ram_wr_ena[1]     = 1;                 //clr
        disp2_ptr_ram_wr_ena[2]     = need_update_disp2; //写入
        disp2_ptr_ram_addra[0]      = x_1;
        disp2_ptr_ram_addra[1]      = x_clr;
        disp2_ptr_ram_addra[2]      = x2_d2;
        disp2_ptr_ram_addrb[0]      = x_2;
        disp2_ptr_ram_addrb[1]      = 0;
        disp2_ptr_ram_addrb[2]      = 0;
        disp2_ptr_ram_dia[0]        = 0;
        disp2_ptr_ram_dia[1]        = invalid_disp_scale;
        disp2_ptr_ram_dia[2]        = d_d[2]+i_min_disp;
    end
end



always @ (*) begin

    if (disp_ram_sel) begin
        disp2_cost_ram_wr_ena[0]    = 1;
        disp2_cost_ram_wr_ena[1]    = need_update_disp2;
        disp2_cost_ram_rd_addr[0]   = 0;
        disp2_cost_ram_rd_addr[1]   = x2_d1; //延迟一些，和uniqueness对齐
        disp2_cost_ram_wr_addr[0]   = x_clr;
        disp2_cost_ram_wr_addr[1]   = x2_d2; //后写，延迟1周期
        disp2_cost_ram_din[0]       = `MAX_FINAL_COST;
        disp2_cost_ram_din[1]       = minS_d3;
    end
    else begin
        disp2_cost_ram_wr_ena[0]    = need_update_disp2;
        disp2_cost_ram_wr_ena[1]    = 1;
        disp2_cost_ram_rd_addr[0]   = x2_d1;
        disp2_cost_ram_rd_addr[1]   = 0;
        disp2_cost_ram_wr_addr[0]   = x2_d2;
        disp2_cost_ram_wr_addr[1]   = x_clr;
        disp2_cost_ram_din[0]       = minS_d3;
        disp2_cost_ram_din[1]       = `MAX_FINAL_COST;
    end
end



always @(*) begin
    for (ii = 0; ii < DispDHeapWidth; ii = ii + 1) begin
        if (ii < i_max_disp-i_min_disp) begin
            minS_heap[DispDHeapWidth+ii] = Spd[ii];
        end
        else begin
            minS_heap[DispDHeapWidth+ii] = 32767;
        end
        bestDisp_heap[DispDHeapWidth+ii] = ii;
    end
end

always @(*) begin
    for (ii = DispDHeapWidth-1; ii >0; ii = ii - 1) begin
        if (minS_heap[ii*2] <= minS_heap[ii*2+1]) begin
            minS_heap[ii]     = minS_heap[ii*2];
            bestDisp_heap[ii] = bestDisp_heap[ii*2];
        end
        else begin
            minS_heap[ii]     = minS_heap[ii*2+1];
            bestDisp_heap[ii] = bestDisp_heap[ii*2+1];
        end
    end
end

//pipeline 1
always @ (posedge clk) begin
    minS        <= minS_heap[1];
    bestDisp    <= bestDisp_heap[1];
    minS_d1     <= minS;
    minS_d2     <= minS_d1;
    minS_d3     <= minS_d2;
end


//pipeline 2
always @ (posedge clk) begin
    Spd_left     <= Spd_d1[bestDisp-1];
    Spd_right    <= Spd_d1[bestDisp+1];

    if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
        y<Y_Delay2+i_height&&
        x_log>=X_Delay1+2&&x_log<X_Delay1+2+i_width-i_max_disp)
        $fdisplay(fp_lr_check, "y=%0d x=%0d bestDisp %0d minS %0d Spd_left %0d Spd_right %0d",
         y-Y_Delay2, x_log-(X_Delay1+2)+i_max_disp,bestDisp,minS,Spd_d1[bestDisp-1],Spd_d1[bestDisp+1]);

    Spd_left_d1  <= Spd_left;
    Spd_right_d1 <= Spd_right;
end

//pipeline 2
always @ (posedge clk) begin
    if (bestDisp==0||bestDisp==i_max_disp-i_min_disp-1)
        do_interpolate        <= 0;
    else
        do_interpolate        <= 1;

    do_interpolate_d[0]       <= do_interpolate;
    for (ii = 1; ii <=22; ii = ii + 1) begin
        do_interpolate_d[ii]  <= do_interpolate_d[ii-1];
    end
end



div_by_shift_sum #(
    .WidthD0(20),
    .WidthD1(16)
) div_by_shift_sum_inst_ge0(
    .clk(clk),
    .a(d_scale_tmp_ge0),
    .b(denom2_d1),
    .result(div_result_ge0)
);

div_by_shift_sum #(
    .WidthD0(20),
    .WidthD1(16)
) div_by_shift_sum_inst_lt0(
    .clk(clk),
    .a(d_scale_tmp_lt0),
    .b(denom2_d1),
    .result(div_result_lt0)
);

assign denom2_tmp = Spd_left+Spd_right-2*minS_d1;

//pipeline 3
always @ (posedge clk) begin
    if (denom2_tmp>1)
        denom2 <= denom2_tmp;
    else
        denom2 <= 1;
    denom2_d1  <= denom2;
end

//d = d*DISP_SCALE + ((Sp[d-1] - Sp[d+1])*DISP_SCALE + denom2)/(denom2*2);
//DISP_SCALE=4

//pipeline 4
always @ (posedge clk) begin
    if ({Spd_left_d1,4'd0}+denom2>={Spd_right_d1,4'd0}) begin
        d_scale_tmp_sign  <= 0;
    end
    else begin
        d_scale_tmp_sign  <= 1;
    end

    d_scale_tmp_ge0       <= {Spd_left_d1,4'd0}+denom2-{Spd_right_d1,4'd0};
    d_scale_tmp_lt0       <= {Spd_right_d1,4'd0}-{Spd_left_d1,4'd0}-denom2;
end

always @ (posedge clk) begin
    d_scale_tmp_sign_d[0]       <= d_scale_tmp_sign;
    for (ii = 1; ii <=20; ii = ii + 1) begin
        d_scale_tmp_sign_d[ii]  <= d_scale_tmp_sign_d[ii-1];
    end
end

always @ (posedge clk) begin
    if (do_interpolate_d[22]) begin
        if (d_scale_tmp_sign_d[20]) begin
            d_scale    <= (d_d[23]<<4)-(div_result_lt0>>1)+(i_min_disp<<4);

            if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&
                x_log>=X_Delay1+26&&x_log<X_Delay1+26+i_width-i_max_disp)
                $fdisplay(fp_lr_check, "y=%0d x=%0d interpolate -%0d disp1ptr=%0d",
                 y-Y_Delay2, x_log-(X_Delay1+26)+i_max_disp,div_result_lt0,
                 (d_d[23]<<4)-(div_result_lt0>>1)+(i_min_disp<<4));


        end
        else begin
            d_scale    <= (d_d[23]<<4)+(div_result_ge0>>1)+(i_min_disp<<4);

            if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&
                x_log>=X_Delay1+26&&x_log<X_Delay1+26+i_width-i_max_disp)
                $fdisplay(fp_lr_check, "y=%0d x=%0d interpolate %0d disp1ptr=%0d",
                 y-Y_Delay2, x_log-(X_Delay1+26)+i_max_disp,div_result_ge0,
                 (d_d[23]<<4)+(div_result_ge0>>1)+(i_min_disp<<4));


        end



    end
    else begin
        d_scale        <= (d_d[23]<<4)+(i_min_disp<<4);

            if (`log_lr_check&&y>=Y_Delay2+`log_start_row&&y<Y_Delay2+`log_end_row &&
                y<Y_Delay2+i_height&&
                x_log>=X_Delay1+26&&x_log<X_Delay1+26+i_width-i_max_disp)
                $fdisplay(fp_lr_check, "y=%0d x=%0d disp1ptr=%0d",
                 y-Y_Delay2, x_log-(X_Delay1+26)+i_max_disp,
                 (d_d[23]<<4)+(i_min_disp<<4));


    end
end

always @ (posedge clk) begin
    minD_minus1        <= i_min_disp-1;
    invalid_disp_scale <= minD_minus1<<4;
end


reg        disp1_out_ram_valid; //第一行lr_check完成，结果填到disp1_out_ram，可以输出到ddr了



always @ (posedge clk) begin
    if (rst) begin
        x_lr_check                <= 0;
        lr_check_done             <= 1;
        disp1_out_ram_valid       <= 0;
    end
    else if ((rst_calc_cost&&reverse)&&lr_check_ram_valid) begin
        x_lr_check                <= i_max_disp;
        lr_check_done             <= 0;
    end
    else if (~lr_check_done) begin
        x_lr_check                <= x_lr_check+1; //最后到i_width保持不变，i_width修改了也没关系
        if (x_lr_check==i_width-1+7) begin
            lr_check_done         <= 1;
            disp1_out_ram_valid   <= 1;
        end
    end
end

always @ (posedge clk) begin
    x_lr_check_d1    <= x_lr_check;
    x_lr_check_d2    <= x_lr_check_d1;
    x_lr_check_d3    <= x_lr_check_d2;
    x_lr_check_d4    <= x_lr_check_d3;
    x_lr_check_d5    <= x_lr_check_d4;
end

always @ (posedge clk) begin
    if (rst) begin
        x_clr              <= 0;
        clr_disp2_done     <= 1;
    end
    else if (clr_disp_ram) begin
        x_clr              <= 0;
        clr_disp2_done     <= 0;
    end
    else if (~clr_disp2_done) begin
        x_clr              <= x_clr+1;
        if (x_clr==i_width) //同样到i_width,如果到i_width-1,下次切换disp_ram_sel时第一时间修改的就是i_width-1
            clr_disp2_done  <= 1;
    end
end


(*mark_debug="true"*)
reg       [1:0][`WIDTH_BITS-1:0]         disp1_output_ram_addr;
(*mark_debug="true"*)
reg       [1:0]                          disp1_output_ram_wr_ena;
(*mark_debug="true"*)
reg            [`DISP_TYPE_BITS-1:0]     disp1_output_ram_din;
(*mark_debug="true"*)
wire      [1:0][`DISP_TYPE_BITS-1:0]     disp1_output_ram_dout;

reg            [`DISP_TYPE_BITS-1:0]     d1;
reg            [`DISP_TYPE_BITS-1:0]     d1_d1;
reg            [`DISP_TYPE_BITS-1:0]     d1_d2;
reg            [`DISP_TYPE_BITS-1:0]     d1_d3;

//int _d = d1 >> DISP_SHIFT;
//int d_ = (d1 + DISP_SCALE-1) >> DISP_SHIFT;

reg            [`WIDTH_BITS-1:0]         d_1; //_d
reg            [`WIDTH_BITS-1:0]         d_2; //d_
reg            [`WIDTH_BITS-1:0]         d_1_d1;
reg            [`WIDTH_BITS-1:0]         d_2_d1;
reg            [`WIDTH_BITS-1:0]         d_1_d2;
reg            [`WIDTH_BITS-1:0]         d_2_d2;

reg                                      x_1_sign;
reg                                      x_2_sign;
reg                                      x_1_sign_d1;
reg                                      x_2_sign_d1;
reg            [`WIDTH_BITS-1:0]         x_1_d1;
reg            [`WIDTH_BITS-1:0]         x_2_d1;
reg            [`WIDTH_BITS-1:0]         x_1_d2;
reg            [`WIDTH_BITS-1:0]         x_2_d2;
reg                                      lr_inconsistent;


wire           [`DISPD_BITS-1:0]         disp2_ram_val_a;
wire           [`DISPD_BITS-1:0]         disp2_ram_val_b;
reg            [`DISPD_BITS-1:0]         disp2_ram_val_a_d1;
reg            [`DISPD_BITS-1:0]         disp2_ram_val_b_d1;

assign disp2_ram_val_a = disp2_ram_sel==0?disp2_ptr_ram_doa[2]:
                         (disp2_ram_sel==1?disp2_ptr_ram_doa[1]:
                                           disp2_ptr_ram_doa[0]);

assign disp2_ram_val_b = disp2_ram_sel==0?disp2_ptr_ram_dob[2]:
                         (disp2_ram_sel==1?disp2_ptr_ram_dob[1]:
                                           disp2_ptr_ram_dob[0]);

always @ (posedge clk) begin
    if (rst||(rst_calc_cost&&reverse)) begin
    
    end
    else begin
        d1                    <= disp_ram_sel?disp1_ptr_ram_dout[0]:disp1_ptr_ram_dout[1];

        x_1                   <= x_lr_check_d3-(d1>>4);
        x_2                   <= x_lr_check_d3-((d1+15)>>4);
        d_1                   <= d1>>4;
        d_2                   <= (d1+15)>>4;
        x_1_sign              <= x_lr_check_d3>=(d1>>4)?0:1;
        x_2_sign              <= x_lr_check_d3>=((d1+15)>>4)?0:1;
        d1_d1                 <= d1;

        x_1_sign_d1           <= x_1_sign;
        x_2_sign_d1           <= x_2_sign;
        x_1_d1                <= x_1;
        x_2_d1                <= x_2;
        d_1_d1                <= d_1;
        d_2_d1                <= d_2;
        d1_d2                 <= d1_d1;

        //minD=0时，disp2ptr[i]=invalid_disp_scale 240,opencv=-16,disp2ptr[x_]>=minD不成立,还是invalid合理，opencv不合理
        //invalid y=15 x=80 d1 243 x_1 65 x_2 64 d_1 15 d_2 16 disp2ptr[x_1]  22 disp2ptr[x_2] 240
        //opencv:valid y=15 x=80 d1 243 x_1 65 x_2 64 d_1 15 d_2 16 disp2ptr[x_1] 22 disp2ptr[x_2] -16

        //minD=12,
        //  valid y=0 x=278 d1 721 x_1 233 x_2 232 d_1 45 d_2 46 disp2ptr[x_1]  58 disp2ptr[x_2] 176
        // opencv:invalid y=0 x=278 d1 721 x_1 233 x_2 232 d_1 45 d_2 46 disp2ptr[x_1] 58 disp2ptr[x_2] 176
        lr_inconsistent       <= x_1_sign_d1==0 && x_1_d1<i_width && disp2_ram_val_a>=i_min_disp &&
                                 //disp2_ram_val_a!=invalid_disp_scale[`DISPD_BITS-1:0]&&
                                 //disp2_ram_val_b!=invalid_disp_scale[`DISPD_BITS-1:0]&&
                                 (disp2_ram_val_a>d_1_d1&&disp2_ram_val_a>i_disp12_max_diff+d_1_d1 ||
                                 disp2_ram_val_a<=d_1_d1&&d_1_d1>i_disp12_max_diff+disp2_ram_val_a) &&
                                 x_2_sign_d1==0 && x_2_d1<i_width && disp2_ram_val_b>=i_min_disp &&
                                 (disp2_ram_val_b>d_2_d1&&disp2_ram_val_b>i_disp12_max_diff+d_2_d1 ||
                                 disp2_ram_val_b<=d_2_d1&&d_2_d1>i_disp12_max_diff+disp2_ram_val_b);
        d1_d3                 <= d1_d2;
        x_1_d2                <= x_1_d1;
        x_2_d2                <= x_2_d1;
        d_1_d2                <= d_1_d1;
        d_2_d2                <= d_2_d1;
        disp2_ram_val_a_d1    <= disp2_ram_val_a;
        disp2_ram_val_b_d1    <= disp2_ram_val_b;


        disp1_output_ram_din  <= lr_inconsistent?invalid_disp_scale:d1_d3;

            if (`log_lr_check&&y>=Y_Delay2+1+`log_start_row&&y<Y_Delay2+1+`log_end_row &&
                y<Y_Delay2+1+i_height&&
                x_lr_check>=i_max_disp+6&&x_lr_check<6+i_width)
                $fdisplay(fp_lr_check2, "%s y=%0d x=%0d d1 %0d x_1 %0d x_2 %0d d_1 %0d d_2 %0d disp2ptr[x_1] %d disp2ptr[x_2] %d",
                 lr_inconsistent?"invalid":"valid",y-Y_Delay2-1, x_lr_check-6,d1_d3,x_1_d2,x_2_d2,d_1_d2,d_2_d2,
                 disp2_ram_val_a_d1,disp2_ram_val_b_d1);


    end
end


generate
    for (i=0;i<2;i=i+1)
    begin: disp1_output_ram_label
        ram #(`WIDTH_BITS,`DISP_TYPE_BITS ) disp1_output_ram_inst(
            .clk(clk),
            .en(1'b1),
            .we(disp1_output_ram_wr_ena[i]),
            .addr(disp1_output_ram_addr[i]),
            .data_in(disp1_output_ram_din),
            .data_out(disp1_output_ram_dout[i])
        );
    end
endgenerate


always @ (*) begin

    if (disp_ram_sel) begin
        disp1_output_ram_addr[0]       = x_output;
        disp1_output_ram_addr[1]       = x_lr_check-7; //pipeline delay cycle
        disp1_output_ram_wr_ena[0]     = 0;
        disp1_output_ram_wr_ena[1]     = x_lr_check>=i_max_disp+7;
    end
    else begin
        disp1_output_ram_addr[0]       = x_lr_check-7;
        disp1_output_ram_addr[1]       = x_output;
        disp1_output_ram_wr_ena[0]     = x_lr_check>=i_max_disp+7;
        disp1_output_ram_wr_ena[1]     = 0;
    end
end

reg   [7:0][`DISP_TYPE_BITS-1:0]    disp_output_buf;
reg   [7:0][`DISP_TYPE_BITS-1:0]    disp_output_buf_bk;
reg                        [2:0]    output_i;
reg                                 kick_store;
reg                        [1:0]    phase;
reg                                 last_bid;
reg                        [7:0]    last_strb_hi;
reg                        [7:0]    last_strb_lo;

always @ (posedge clk) begin
    case (i_width[2:0])
        3'b000: begin last_strb_hi <= 8'hff; last_strb_lo <= 8'hff; end
        3'b001: begin last_strb_hi <= 8'h00; last_strb_lo <= 8'h03; end
        3'b010: begin last_strb_hi <= 8'h00; last_strb_lo <= 8'h0f; end
        3'b011: begin last_strb_hi <= 8'h00; last_strb_lo <= 8'h3f; end
        3'b100: begin last_strb_hi <= 8'h00; last_strb_lo <= 8'hff; end
        3'b101: begin last_strb_hi <= 8'h03; last_strb_lo <= 8'hff; end
        3'b110: begin last_strb_hi <= 8'h0f; last_strb_lo <= 8'hff; end
        3'b111: begin last_strb_hi <= 8'h3f; last_strb_lo <= 8'hff; end
    endcase
end


assign m_axi_awlen = 1;

localparam
FillBufferInvalid = 0,
FillBufferFromRam = 1,
WaitDdr = 2,
OutputOneRowDone = 3,
OutputEnd = 4,
OutputWaitLastBid=5;

localparam
WriteDdrIdle = 0,
WaitDdrAddr = 1,
WaitFirst8BytesDone = 2,
WaitSecond8BytesDone = 3;

reg    first_bid; //一行第一笔存ddr
always @ (posedge clk) begin
    if (rst) begin
        output_stage                        <= OutputEnd;
        output_done                         <= 1;
        x_output                            <= 0;
        y_output                            <= 0;
        disp_output_offset                  <= 0;
        disp_output_line_offset             <= 0;
        kick_store                          <= 0;
    end
    else if ((rst_calc_cost&&reverse)&&disp1_out_ram_valid) begin
        output_stage                        <= FillBufferInvalid;
        output_done                         <= 0;
        output_i                            <= 0;
        x_output                            <= 0;
        kick_store                          <= 0;
        last_bid                            <= 0;
        first_bid                           <= 1;
    end
    else begin
        if (output_stage==FillBufferInvalid&&disp1_out_ram_valid) begin
            if (x_output<i_max_disp) begin
                disp_output_buf[output_i]   <= invalid_disp_scale;
                output_i                    <= output_i+1;
                if (output_i==7)
                    output_stage            <= WaitDdr;
            end
            else begin
                output_stage                <= FillBufferFromRam;
            end

            x_output                        <= x_output+1;
            kick_store                      <= 0;
        end


        if (output_stage==FillBufferFromRam) begin
            disp_output_buf[output_i]       <= disp_ram_sel?disp1_output_ram_dout[0]:
                                                            disp1_output_ram_dout[1];


            if (x_output == i_width||output_i==7) begin
                last_bid                    <= x_output == i_width;
                output_stage                <= WaitDdr;

            end
            else begin
                x_output                    <= x_output+1;
            end
            output_i                        <= output_i+1;

            kick_store                      <= 0;


        end

        if (output_stage==WaitDdr && phase==WriteDdrIdle) begin
            kick_store                      <= 1;
            first_bid                       <= 0;
            if (~first_bid)
                disp_output_offset          <= disp_output_offset+16; //每个disp两字节
            if (x_output == i_width)
                output_stage                <= OutputWaitLastBid; //等待最后一笔写ddr完成
            else if (x_output<i_max_disp)
                output_stage                <= FillBufferInvalid;
            else
            begin
                output_stage                <= FillBufferFromRam;
                x_output                    <= x_output+1;
            end

        end

        if (output_stage==OutputWaitLastBid)
            kick_store                      <= 0;

        if (output_stage==OutputWaitLastBid &&~kick_store&& phase==WriteDdrIdle)
            output_stage                    <= OutputOneRowDone;

        if (output_stage==OutputOneRowDone) begin
            disp_output_offset              <= disp_output_line_offset+i_disp_stride;
            disp_output_line_offset         <= disp_output_line_offset+i_disp_stride;
            y_output                        <= y_output+1;
            output_done                     <= 1;
            output_stage                    <= OutputEnd;
        end

    end
end



//disp_output_buf 8个short，16字节，分两比写

assign m_axi_awaddr = i_disp_addr+disp_output_offset;
assign m_axi_wdata = disp_output_buf_bk[3:0];

always @ (posedge clk) begin
    if (rst||(rst_calc_cost&&reverse)) begin
        phase                     <= WriteDdrIdle;
        m_axi_awvalid             <= 0;
        m_axi_wvalid              <= 0;
        m_axi_wlast               <= 0;
    end
    else begin
        if (phase==WriteDdrIdle&&kick_store) begin
            m_axi_awvalid         <= 1;
            m_axi_wlast           <= 0;
            disp_output_buf_bk    <= disp_output_buf;
            phase                 <= WaitDdrAddr;
        end
        if (phase==WaitDdrAddr&&m_axi_awready) begin
            m_axi_awvalid         <= 0;
            m_axi_wvalid          <= 1;
            if (last_bid)
                m_axi_wstrb       <= last_strb_lo;
            else
                m_axi_wstrb       <= 8'hff;

            phase                 <= WaitFirst8BytesDone;
        end
        if (phase==WaitFirst8BytesDone&&m_axi_wready) begin
            m_axi_wlast           <= 1;
            if (last_bid)
                m_axi_wstrb       <= last_strb_hi;
            else
                m_axi_wstrb       <= 8'hff;
            phase                 <= WaitSecond8BytesDone;
            disp_output_buf_bk    <= {{(4*`DISP_TYPE_BITS){1'b0}},disp_output_buf_bk[7:4]};
        end
        if (phase==WaitSecond8BytesDone &&m_axi_wready) begin
            m_axi_wlast           <= 0;
            m_axi_wvalid          <= 0;
            phase                 <= WriteDdrIdle;
        end
    end
end



`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    m_axi_awvalid                      = {random_val,random_val};
    m_axi_wstrb                        = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    m_axi_wlast                        = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    m_axi_wvalid                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    x                                  = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    x_reverse                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    window_cost_done                   = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    window_cost_reverse_done           = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    clr_disp2_done                     = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    lr_check_done                      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    output_done                        = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    window_cost_valid                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    window_cost_pre_valid              = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    window_cost_reverse_valid          = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    window_cost_reverse_pre_valid      = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    state                              = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    bt_cost_valid_d1                   = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    bt_cost_valid_d2                   = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    bt_cost_valid_d3                   = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    delay_cycles1                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    delay_cycles2                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    read_right_left_aggr_ram           = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    read_down_right_aggr_ram           = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    disp2_update_valid                 = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    lr_check_ram_valid                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    x_log                              = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    hsum_add                           = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    first_windowed_cost                = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    windowed_cost_tmp0                 = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    windowed_cost_tmp1                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    windowed_cost                      = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    bt_cost_ram_wr_addr                = {random_val[31:0],random_val[31:0]};
    bt_cost_ram_rd_addr                = {random_val,random_val};
    start_read                         = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    Spd                                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    Spd_d1                             = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    clr_up_three_aggr_ram              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    minS_heap                          = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    bestDisp_heap                      = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    minS                               = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    minS_d1                            = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    minS_d2                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    minS_d3                            = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    bestDisp                           = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    disp_ram_sel                       = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    disp2_ram_sel                      = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    disp1_ptr_ram_addr                 = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    disp1_ptr_ram_wr_ena               = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    disp1_ptr_ram_din                  = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    disp2_ptr_ram_addra                = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    disp2_ptr_ram_addrb                = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    disp2_ptr_ram_wr_ena               = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    disp2_ptr_ram_dia                  = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    disp2_cost_ram_rd_addr             = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    disp2_cost_ram_wr_addr             = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    disp2_cost_ram_wr_ena              = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    disp2_cost_ram_din                 = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    denom2                             = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    denom2_d1                          = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    old_disp2_cost_in_ram              = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    minS_disp2_update                  = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    need_update_disp2                  = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    Spd_left                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    Spd_right                          = {random_val[31:0],random_val[31:0]};
    Spd_left_d1                        = {random_val,random_val};
    Spd_right_d1                       = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    do_interpolate                     = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    do_interpolate_d                   = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    d_d                                = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    x2                                 = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    x2_d1                              = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    x2_d2                              = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    x2_d3                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    d_scale_tmp_ge0                    = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    d_scale_tmp_lt0                    = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    d_scale_tmp_sign                   = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    d_scale_tmp_sign_d                 = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    d_scale                            = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    minD_minus1                        = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    invalid_disp_scale                 = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    x_output                           = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    y_output                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    x_lr_check                         = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    x_lr_check_d1                      = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    x_lr_check_d2                      = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    x_lr_check_d3                      = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    x_lr_check_d4                      = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    x_lr_check_d5                      = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    x_clr                              = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    disp_output_offset                 = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    disp_output_line_offset            = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    output_stage                       = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    ununique                           = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    uniqueness                         = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    unique_d                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    unique_operand1                    = {random_val,random_val};
    x_1                                = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    x_2                                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    disp1_out_ram_valid                = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    disp1_output_ram_addr              = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    disp1_output_ram_wr_ena            = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    disp1_output_ram_din               = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    d1                                 = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    d1_d1                              = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    d1_d2                              = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    d1_d3                              = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    d_1                                = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    d_2                                = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    d_1_d1                             = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    d_2_d1                             = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    d_1_d2                             = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    d_2_d2                             = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    x_1_sign                           = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    x_2_sign                           = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    x_1_sign_d1                        = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    x_2_sign_d1                        = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    x_1_d1                             = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    x_2_d1                             = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    x_1_d2                             = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    x_2_d2                             = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    lr_inconsistent                    = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    disp2_ram_val_a_d1                 = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    disp2_ram_val_b_d1                 = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    disp_output_buf                    = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    disp_output_buf_bk                 = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    output_i                           = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    kick_store                         = {random_val[31:0],random_val[31:0]};
    phase                              = {random_val,random_val};
    last_bid                           = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    last_strb_hi                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    last_strb_lo                       = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    first_bid                          = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
end
`endif




endmodule
