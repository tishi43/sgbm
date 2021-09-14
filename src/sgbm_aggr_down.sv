//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`include "../include/sgbm_defines.v"

module sgbm_aggr_down
(
    input wire                           clk,
    input wire                           rst,

    input wire [`DISPD*`COST_BITS-1:0]   i_cost,
    input wire                           i_cost_valid,
    input wire                           i_cost_pre_valid, //cost valid前一周期
    input wire                           i_rst_aggr,
    input wire                           i_clr_ram,
    input wire  [`WIDTH_BITS-1:0]        i_width,
    input wire  [`DISPD_BITS-1:0]        i_min_disp,
    input wire  [`DISPD_BITS-1:0]        i_max_disp,
    input wire  [`COST_BITS-1:0]         i_P1,
    input wire  [`COST_BITS-1:0]         i_P2,

    output wire[`DISPD*`COST_BITS-1:0]   o_cost,
    output reg                           o_valid,
    output reg                           o_aggr_done

);

localparam
DispDHeapHeight = $clog2(`DISPD-1)+1,
DispDHeapWidth = 2**(DispDHeapHeight-1),
DispDHeapSize = 2**DispDHeapHeight-1;

wire [0:`DISPD-1 ][`COST_BITS-1:0]  cost_w;
assign cost_w = i_cost;

reg               [`COST_BITS-1:0]  Delta;
reg [0:`DISPD+1  ][`COST_BITS-1:0]  Lrp;
reg [0:`DISPD*4-1][`COST_BITS  :0]  Lr_p_stage0;
reg [0:`DISPD*2-1][`COST_BITS  :0]  Lr_p_stage1;
reg [0:`DISPD*1-1][`COST_BITS-1:0]  Lr_p_stage2;


reg [0:DispDHeapSize][`COST_BITS-1:0]  minL_heap;

integer ii;
reg       cost_valid_d1;
reg       first_cycle_clr_ram;

always @ (posedge clk) begin
    cost_valid_d1  <= i_cost_valid;
end

always @ (posedge clk) begin
    if (rst)
        first_cycle_clr_ram   <= 1;
    else if (i_clr_ram)
        first_cycle_clr_ram   <= 0;
end

wire        [0:`DISPD-1][`COST_BITS-1:0] Lr_ram_dout;

always @(*) begin
    Lrp[0]                   = `MAX_COST;
    Lrp[`DISPD+1]            = `MAX_COST;
    for (ii = 1; ii < `DISPD+1; ii = ii+1) begin
        if (ii>i_max_disp-i_min_disp) //D=80,Lrp[0]~Lrp[81]
            Lrp[ii]          = `MAX_COST;
        else
            Lrp[ii]          = Lr_ram_dout[ii-1];
    end
end


reg  [`COST_BITS-1:0] minLr;
wire [`COST_BITS-1:0] minL_ram_dout;

always @(*) begin
    minLr = minL_ram_dout;
    Delta = minLr + i_P2;
end

always @(*) begin
    for (ii = 0; ii < `DISPD; ii = ii+1) begin
        Lr_p_stage0[ii*4+0] = Lrp[ii+0]+i_P1;
        Lr_p_stage0[ii*4+1] = Lrp[ii+1];
        Lr_p_stage0[ii*4+2] = Lrp[ii+2]+i_P1;
        Lr_p_stage0[ii*4+3] = Delta;
    end
end

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
    for (ii = 0; ii < `DISPD; ii = ii+1) begin
        if (Lr_p_stage1[ii*2+0] < Lr_p_stage1[ii*2+1])
            Lr_p_stage2[ii]     = Lr_p_stage1[ii*2+0]+cost_w[ii]-Delta;
        else
            Lr_p_stage2[ii]     = Lr_p_stage1[ii*2+1]+cost_w[ii]-Delta;
    end
end


always @(posedge clk) begin
    for (ii = 0; ii < DispDHeapWidth; ii = ii + 1) begin
        if (ii < i_max_disp-i_min_disp)
            minL_heap[DispDHeapWidth+ii] <= Lr_p_stage2[ii];
        else
            minL_heap[DispDHeapWidth+ii] <= `MAX_COST;
    end
end

//      4
//  2  
//      5
//1     6
//   3  
//      7

always @(*) begin
    for (ii = DispDHeapWidth-1; ii >0 ; ii = ii - 1) begin
        if (minL_heap[ii*2] < minL_heap[ii*2+1])
            minL_heap[ii] = minL_heap[ii*2];
        else
            minL_heap[ii] = minL_heap[ii*2+1];
    end
end

reg  [`WIDTH_BITS-1:0]            Lr_ram_wr_addr;
reg  [`WIDTH_BITS-1:0]            Lr_ram_rd_addr;
reg                               Lr_ram_wr_ena;
reg  [0:`DISPD-1][`COST_BITS-1:0] Lr_ram_din;

always @(posedge clk) begin
        Lr_ram_din <= i_clr_ram?0:Lr_p_stage2;
end

always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        Lr_ram_wr_addr <= 1;
    end
    else if (first_cycle_clr_ram) begin
        Lr_ram_wr_addr <= 0;
    end
    else if (i_cost_valid == 1&&cost_valid_d1==0) begin
        Lr_ram_wr_addr <= 1;
    end
    else if ((i_cost_valid  && Lr_ram_wr_addr!=i_width-i_max_disp)||
              (i_clr_ram&&Lr_ram_wr_addr!=i_width-i_max_disp+1)) begin
        Lr_ram_wr_addr <= Lr_ram_wr_addr + 1'b1;
    end

end


always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        Lr_ram_rd_addr <= 1;
    end
    else if (i_cost_valid||i_cost_pre_valid) begin
        Lr_ram_rd_addr <= Lr_ram_rd_addr + 1'b1;
    end

end

//0地址是0，从1开始存,ram[1]存最左边聚合结果
//左下方向聚合时最左边点取到上一行的ram[0]地址
always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        Lr_ram_wr_ena <= 0;
    end
    else if ((i_cost_valid == 1&&cost_valid_d1==0)||
             (i_clr_ram&&Lr_ram_wr_addr != i_width-i_max_disp+1)) begin
        Lr_ram_wr_ena <= 1;
    end
    else if (~i_clr_ram&&Lr_ram_wr_addr == i_width-i_max_disp||
             i_clr_ram && Lr_ram_wr_addr == i_width-i_max_disp+1) begin
        Lr_ram_wr_ena <= 0;
    end
end

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


reg  [`WIDTH_BITS-1:0]   minL_ram_wr_addr;
reg  [`WIDTH_BITS-1:0]   minL_ram_rd_addr;
reg                      minL_ram_wr_ena;
reg   [`COST_BITS-1:0]   minL_ram_din;

always @(*) begin
    minL_ram_din = i_clr_ram?0:minL_heap[1];
end

//minLr比Lr晚一周期出结果
always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        minL_ram_wr_addr <= 1;
    end
    else if (first_cycle_clr_ram) begin
        minL_ram_wr_addr <= 0;
    end
    else if (i_cost_valid == 1&&cost_valid_d1==0) begin
        minL_ram_wr_addr <= 1;
    end
    else if ((i_cost_valid  && minL_ram_wr_addr!=i_width-i_max_disp)||
              (i_clr_ram&&minL_ram_wr_addr!=i_width-i_max_disp+1)) begin
        minL_ram_wr_addr <= minL_ram_wr_addr + 1'b1;
    end

end

always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        minL_ram_rd_addr <= 1;
    end
    else if (i_cost_valid||i_cost_pre_valid) begin
        minL_ram_rd_addr <= minL_ram_rd_addr + 1'b1;
    end
end


always @(posedge clk) begin
    if (rst||i_rst_aggr) begin
        minL_ram_wr_ena <= 0;
    end
    else if ((i_cost_valid == 1&&cost_valid_d1==0)||
             (i_clr_ram&&minL_ram_wr_addr != i_width-i_max_disp+1)) begin
        minL_ram_wr_ena <= 1;
    end
    else if (~i_clr_ram && Lr_ram_wr_addr == i_width-i_max_disp||
             i_clr_ram &&Lr_ram_wr_addr == i_width-i_max_disp+1 ) begin
        minL_ram_wr_ena <= 0;
    end
end




dp_ram #(`COST_BITS, `WIDTH_BITS) minL_ram_inst(
    .data(minL_ram_din),
    .wraddress(minL_ram_wr_addr),
    .rdaddress(minL_ram_rd_addr),
    .wren(minL_ram_wr_ena),
    .rdclock(clk),
    .wrclock(clk),
    .q(minL_ram_dout),
    .aclr(1'b0)
);

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
    o_valid                            = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    o_aggr_done                        = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    Delta                              = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    Lrp                                = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    Lr_p_stage0                        = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    Lr_p_stage1                        = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    Lr_p_stage2                        = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    minL_heap                          = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    cost_valid_d1                      = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    first_cycle_clr_ram                = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    minLr                              = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    Lr_ram_wr_addr                     = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    Lr_ram_rd_addr                     = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    Lr_ram_wr_ena                      = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    Lr_ram_din                         = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    minL_ram_wr_addr                   = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    minL_ram_rd_addr                   = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    minL_ram_wr_ena                    = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    minL_ram_din                       = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
end
`endif



endmodule