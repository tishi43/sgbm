//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`include "../include/sgbm_defines.v"

module sgbm_aggr_right_left
(
    input wire                           clk,
    input wire                           rst,

    input wire [`DISPD*`COST_BITS-1:0]   i_cost,
    input wire                           i_cost_valid,
    input wire  [`DISPD_BITS-1:0]        i_min_disp,
    input wire  [`DISPD_BITS-1:0]        i_max_disp,
    input wire                           i_rst_aggr,
    input wire                           i_reverse,
    input wire                           i_rd_req,
    input wire  [`WIDTH_BITS-1:0]        i_width,
    input wire  [`COST_BITS-1:0]         i_P1,
    input wire  [`COST_BITS-1:0]         i_P2,

    output wire [`DISPD*`COST_BITS-1:0]   o_cost_ram,
    output wire [`DISPD*`COST_BITS-1:0]   o_cost,
    output wire                          o_valid,
    output reg                           o_aggr_done

);

localparam
DispDHeapHeight = $clog2(`DISPD-1)+1,
DispDHeapWidth = 2**(DispDHeapHeight-1),
DispDHeapSize = 2**DispDHeapHeight-1;

wire [0:`DISPD-1 ][`COST_BITS-1:0]  cost_w;
assign cost_w = i_cost;
assign o_valid = i_cost_valid;

reg               [`COST_BITS-1:0]  Delta;
reg [0:`DISPD+1  ][`COST_BITS-1:0]  Lrp;
reg [0:`DISPD*4-1][`COST_BITS  :0]  Lr_p_stage0;
reg [0:`DISPD*2-1][`COST_BITS  :0]  Lr_p_stage1;
reg [0:`DISPD*1-1][`COST_BITS-1:0]  Lr_p_stage2;

reg [1:DispDHeapSize][`COST_BITS-1:0]  minL_heap;

reg                                 ram_dir; //0=从0地址开始存，1=从高地址i_width-1开始存

integer ii;

reg       cost_valid_d1;

always @ (posedge clk) begin
    cost_valid_d1  <= i_cost_valid;
end

always @ (posedge clk) begin
    if (rst) begin
        ram_dir       <= 0;
    end
    else if (i_rst_aggr) begin
        ram_dir       <= ~ram_dir;
    end

end

//这个Lr_ram用来存提前一行右左方向聚合的结果，第一遍从0地址开始存图像最右边的结果，假如图像宽1280，到地址1279存图像最左边的结果，
//外面sgbm.sv取的时候，从1279地址开始取图像最左边的结果，所以第二遍存的时候，从1279地址开始存，并且保证sgbm.sv取完之后再覆盖这个数据，

reg  [`WIDTH_BITS-1:0]            Lr_ram_wr_addr;
reg  [`WIDTH_BITS-1:0]            Lr_ram_rd_addr;
wire                              Lr_ram_wr_ena;
reg  [0:`DISPD-1][`COST_BITS-1:0] Lr_ram_din;

always @(*) begin
    Lr_ram_din = Lr_p_stage2;
end

always @(posedge clk) begin
    if (i_rst_aggr) begin
        Lr_ram_wr_addr <= ram_dir?0:i_width-1;
    end
    else if (i_cost_valid) begin
        Lr_ram_wr_addr <= ram_dir?Lr_ram_wr_addr-1:Lr_ram_wr_addr + 1'b1;
    end
end


always @(posedge clk) begin
    if (i_rst_aggr) begin
        Lr_ram_rd_addr <= ram_dir?i_max_disp:i_width-i_max_disp-1; //i_rst_aggr之后ram_dir即翻转，下次用的是~ram_dir
    end
    else if (i_rd_req) begin
        Lr_ram_rd_addr <= ram_dir?Lr_ram_rd_addr-1:Lr_ram_rd_addr + 1'b1;
    end
end

//左右比右左先window cost valid，所以肯定左右聚合先读出上次右左的结果，再右左聚合写入新的
assign Lr_ram_wr_ena = i_cost_valid&&i_reverse;


wire  [0:`DISPD-1][`COST_BITS-1:0] Lr_ram_dout;
assign o_cost_ram = Lr_ram_dout;

dp_ram #(`COST_BITS*`DISPD, `WIDTH_BITS) Lr_ram_inst(
    .data(Lr_ram_din),
    .wraddress(Lr_ram_wr_addr),
    .rdaddress(Lr_ram_rd_addr),
    .wren(Lr_ram_wr_ena),
    .rdclock(clk),
    .wrclock(clk),
    .q(Lr_ram_dout),
    .aclr(1'b0)
);

//Lrp,上一点的聚合结果，左右和右左方向都是刚刚计算出来的Lr_p_stage2，
//上面三个方向的聚合，来自上一行的计算结果，需要从ram中取

always @(posedge clk) begin
    Lrp[0]                <= `MAX_COST;
    Lrp[`DISPD+1]         <= `MAX_COST;

    for (ii = 1; ii <= `DISPD; ii = ii+1) begin
        if (~i_cost_valid) begin
            Lrp[ii]       <= '0;
        end
        else begin
            if (ii<=i_max_disp-i_min_disp)
                Lrp[ii]   <= Lr_p_stage2[ii-1];
            else
                Lrp[ii]   <= `MAX_COST;
        end
    end

end

reg  [`COST_BITS-1:0] minLr;

always @(posedge clk) begin
    if (~i_cost_valid) begin
        Delta <= i_P2;
    end
    else begin
        Delta <= minL_heap[1] + i_P2;
    end
end

//L0 = Cpd + std::min((int)Lr_p0[d], std::min(Lr_p0[d-1] + P1, std::min(Lr_p0[d+1] + P1, delta0))) - delta0;
//4个求最小值
//Lr_p_stage0[ii*4+0]=Lr_p0[d-1] + P1
//Lr_p_stage0[ii*4+1]=Lr_p0[d]
//Lr_p_stage0[ii*4+2]=Lr_p0[d+1] + P1
always @(*) begin
    for (ii = 0; ii < `DISPD; ii = ii+1) begin
        Lr_p_stage0[ii*4+0] = Lrp[ii+0]+i_P1;
        Lr_p_stage0[ii*4+1] = Lrp[ii+1];
        Lr_p_stage0[ii*4+2] = Lrp[ii+2]+i_P1;
        Lr_p_stage0[ii*4+3] = Delta;
    end
end

//Lr_p_stage1[ii+0]=min(Lr_p0[d],Lr_p0[d-1] + P1)
//Lr_p_stage1[ii+1]=min(Lrp[ii+2]+`P1,delta0)
always @(*) begin
        for (ii = 0; ii < `DISPD; ii = ii+1) begin
            if (Lr_p_stage0[ii*4+0] < Lr_p_stage0[ii*4+1])
                Lr_p_stage1[ii*2+0] = Lr_p_stage0[ii*4+0];
            else
                Lr_p_stage1[ii*2+0] = Lr_p_stage0[ii*4+1];
            if (Lr_p_stage0[ii*4+2] < Lr_p_stage0[ii*4+3])
                Lr_p_stage1[ii*2+1] = Lr_p_stage0[ii*4+2];
            else
                Lr_p_stage1[ii*2+1] = Lr_p_stage0[ii*4+3];
        end
end

//Lr_p_stage2=Cpd+std::min((int)Lr_p0[d], std::min(Lr_p0[d-1] + P1, std::min(Lr_p0[d+1] + P1, delta0)))-delta0
always @(*) begin
    for (ii = 0; ii < `DISPD; ii = ii+1) begin
        if (Lr_p_stage1[ii*2+0] < Lr_p_stage1[ii*2+1])
            Lr_p_stage2[ii] = Lr_p_stage1[ii*2+0]+cost_w[ii]-Delta;
        else
            Lr_p_stage2[ii] = Lr_p_stage1[ii*2+1]+cost_w[ii]-Delta;
    end
end


reg  [`DISPD_BITS-1:0]        disp_range;
always @ (posedge clk)
    disp_range       <= i_max_disp-i_min_disp;

//此处上面三个方向的聚合都是always @(posedge clk),可以pipeline，这里不行，下一个点的聚合需要用到上一个点的minL的结果
always @(*) begin
    for (ii = 0; ii < DispDHeapWidth; ii = ii + 1) begin
        if (ii < disp_range)
            minL_heap[DispDHeapWidth+ii] = Lr_p_stage2[ii];
        else
            minL_heap[DispDHeapWidth+ii] = `MAX_COST;
    end
end


always @(*) begin
    for (ii = DispDHeapWidth-1; ii >0; ii = ii - 1) begin
        if (minL_heap[ii*2] < minL_heap[ii*2+1])
            minL_heap[ii] = minL_heap[ii*2];
        else
            minL_heap[ii] = minL_heap[ii*2+1];
    end
end


assign o_cost = Lr_p_stage2;

always @(posedge clk) begin
    if (rst) begin
        o_aggr_done      <= 1;
    end
    else if (i_rst_aggr) begin
        o_aggr_done      <= 0;
    end
    else if (i_cost_valid==0&&cost_valid_d1==1) begin
        o_aggr_done      <= 1;
    end
end



`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_aggr_done                        = {random_val,random_val};
    Delta                              = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    Lrp                                = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    Lr_p_stage0                        = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    Lr_p_stage1                        = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    Lr_p_stage2                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    minL_heap                          = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    ram_dir                            = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    cost_valid_d1                      = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    Lr_ram_wr_addr                     = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    Lr_ram_rd_addr                     = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    Lr_ram_din                         = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    minLr                              = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    disp_range                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
end
`endif

endmodule