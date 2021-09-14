//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------
`include "../include/sgbm_defines.v"

`timescale 1ns / 1ns // timescale time_unit/time_presicion

module bitstream_tb;
reg rst;
reg dec_clk;

wire                                       m_axi_arready;
wire                                       m_axi_arvalid;
wire[3:0]                                  m_axi_arlen;
wire[31:0]                                 m_axi_araddr;
wire                                       m_axi_rready;
wire [63:0]                                m_axi_rdata;
wire                                       m_axi_rvalid;
wire                                       m_axi_rlast;
wire [5:0]                                 m_axi_arid;
wire [2:0]                                 m_axi_arsize;
wire [1:0]                                 m_axi_arburst;
wire [2:0]                                 m_axi_arprot;
wire [3:0]                                 m_axi_arcache;
wire [1:0]                                 m_axi_arlock;
wire [3:0]                                 m_axi_arqos;


wire                                       m_axi_awready;
wire [5:0]                                 m_axi_awid;
wire [31:0]                                m_axi_awaddr;
wire [3:0]                                 m_axi_awlen;
wire [2:0]                                 m_axi_awsize;
wire [1:0]                                 m_axi_awburst;
wire [1:0]                                 m_axi_awlock;
wire [3:0]                                 m_axi_awcache;
wire [2:0]                                 m_axi_awprot;
wire                                       m_axi_awvalid;

wire                                       m_axi_wready;
wire [5:0]                                 m_axi_wid;
wire [63:0]                                m_axi_wdata;
wire [7:0]                                 m_axi_wstrb;
wire                                       m_axi_wlast;
wire                                       m_axi_wvalid;

wire [5:0]                                 m_axi_bid;
wire [1:0]                                 m_axi_bresp;
wire                                       m_axi_bvalid;
wire                                       m_axi_bready;

wire [5:0]                                 m_axi_rrid;
wire [1:0]                                 m_axi_rresp;

integer fp_cost;
integer fp_intermediate;
integer fp_window;
integer fp_window_reverse;
integer fp_hsum;
integer fp_aggr_left_right;
integer fp_aggr_right_left;
integer fp_aggr_down_left;
integer fp_aggr_down;
integer fp_aggr_down_right;
integer fp_aggr;
integer fp_unique;
integer fp_lr_check;
integer fp_lr_check2;

initial begin
    fp_cost                 = $fopen("cost.log", "w");
    fp_intermediate         = $fopen("intermediate.log", "w");
    fp_window               = $fopen("window.log","w");
    fp_window_reverse       = $fopen("window_reverse.log","w");
    fp_hsum                 = $fopen("hsum.log","w");
    fp_aggr_left_right      = $fopen("aggr_left_right.log","w");
    fp_aggr_right_left      = $fopen("aggr_right_left.log","w");
    fp_aggr_down_left       = $fopen("aggr_down_left.log","w");
    fp_aggr_down            = $fopen("aggr_down.log","w");
    fp_aggr_down_right      = $fopen("aggr_down_right.log","w");
    fp_aggr                 = $fopen("aggr.log","w");
    fp_unique               = $fopen("unique.log","w");
    fp_lr_check             = $fopen("lr_check.log","w");
    fp_lr_check2            = $fopen("lr_check2.log","w");

    rst = 0;
    #100 rst = 1;
    #100 rst = 0;
    #1000000000 $fclose(fp_cost);
    #100       $fclose(fp_intermediate);
    #100       $fclose(fp_window);
    #100       $fclose(fp_window_reverse);
    #100       $fclose(fp_hsum);
    #100       $fclose(fp_aggr_left_right);
    #100       $fclose(fp_aggr_right_left);
    #100       $fclose(fp_aggr_down_left);
    #100       $fclose(fp_aggr_down);
    #100       $fclose(fp_aggr_down_right);
    #100       $fclose(fp_aggr);
    #100       $fclose(fp_unique);
    #100       $fclose(fp_lr_check);
    #100       $fclose(fp_lr_check2);
end



always
begin
    #1 dec_clk = 0;
    #1 dec_clk = 1;
end

reg [1:0]  random_val;
always @ (posedge dec_clk)
begin
    random_val  <= $random()%4;
end

sgbm sgbm_inst(
    .clk                             (dec_clk),

    .rst                             (rst),

    .i_width                         (`WIDTH_BITS'd1280),
    .i_height                        (`HEIGHT_BITS'd960),
    .i_stride                        (2048),
    .i_left_image_addr               (32'h20000000),
    .i_right_image_addr              (32'h21000000),
    .i_disp_addr                     (32'h22000000),
    .i_disp_stride                   (4096),
    .i_P1                            (`COST_BITS'd200),
    .i_P2                            (`COST_BITS'd800),
    .i_min_disp                      (`DISPD_BITS'd0),
    .i_max_disp                      (`DISPD_BITS'd128),
    .i_unique_ratio                  (8'd10), //0~100
    .i_disp12_max_diff               (`DISPD_BITS'd1),

    .fp_cost                         (fp_cost),
    .fp_intermediate                 (fp_intermediate),
    .fp_window                       (fp_window),
    .fp_window_reverse               (fp_window_reverse),
    .fp_hsum                         (fp_hsum),
    .fp_aggr_left_right              (fp_aggr_left_right),
    .fp_aggr_right_left              (fp_aggr_right_left),
    .fp_aggr_down_left               (fp_aggr_down_left),
    .fp_aggr_down                    (fp_aggr_down),
    .fp_aggr_down_right              (fp_aggr_down_right),
    .fp_aggr                         (fp_aggr),
    .fp_unique                       (fp_unique),
    .fp_lr_check                     (fp_lr_check),
    .fp_lr_check2                    (fp_lr_check2),

    .m_axi_awready                   (m_axi_awready),
    .m_axi_awid                      (m_axi_awid),
    .m_axi_awaddr                    (m_axi_awaddr),
    .m_axi_awlen                     (m_axi_awlen),
    .m_axi_awsize                    (m_axi_awsize),
    .m_axi_awburst                   (m_axi_awburst),
    .m_axi_awlock                    (m_axi_awlock),
    .m_axi_awcache                   (m_axi_awcache),
    .m_axi_awprot                    (m_axi_awprot),
    .m_axi_awvalid                   (m_axi_awvalid),
   
    .m_axi_wready                    (m_axi_wready),
    .m_axi_wid                       (m_axi_wid),
    .m_axi_wdata                     (m_axi_wdata),
    .m_axi_wstrb                     (m_axi_wstrb),
    .m_axi_wlast                     (m_axi_wlast),
    .m_axi_wvalid                    (m_axi_wvalid),

    .m_axi_bid                       (m_axi_bid),
    .m_axi_bresp                     (m_axi_bresp),
    .m_axi_bvalid                    (m_axi_bvalid),
    .m_axi_bready                    (m_axi_bready),

    .m_axi_arready                   (m_axi_arready),
    .m_axi_arvalid                   (m_axi_arvalid), 
    .m_axi_arlen                     (m_axi_arlen),
    .m_axi_araddr                    (m_axi_araddr),
    .m_axi_rready                    (m_axi_rready),
    .m_axi_rdata                     (m_axi_rdata),
    .m_axi_rvalid                    (m_axi_rvalid),
    .m_axi_rlast                     (m_axi_rlast),
    .m_axi_arid                      (m_axi_arid),
    .m_axi_arsize                    (m_axi_arsize),
    .m_axi_arburst                   (m_axi_arburst),
    .m_axi_arprot                    (m_axi_arprot),
    .m_axi_arcache                   (m_axi_arcache),
    .m_axi_arlock                    (m_axi_arlock),
    .m_axi_arqos                     (m_axi_arqos),
    .m_axi_rrid                      (m_axi_rrid),
    .m_axi_rresp                     (m_axi_rresp)

);

ext_ram_32 ext_ram_32
(
    .m_axi_wclk                          (dec_clk),
    .m_axi_awready                       (m_axi_awready),
    .m_axi_awid                          (m_axi_awid),
    .m_axi_awaddr                        (m_axi_awaddr),
    .m_axi_awlen                         (m_axi_awlen),
    .m_axi_awsize                        (m_axi_awsize),
    .m_axi_awburst                       (m_axi_awburst),
    .m_axi_awlock                        (m_axi_awlock),
    .m_axi_awcache                       (m_axi_awcache),
    .m_axi_awprot                        (m_axi_awprot),
    .m_axi_awvalid                       (m_axi_awvalid),
   
    .m_axi_wready                        (m_axi_wready),
    .m_axi_wid                           (m_axi_wid),
    .m_axi_wdata                         (m_axi_wdata),
    .m_axi_wstrb                         (m_axi_wstrb),
    .m_axi_wlast                         (m_axi_wlast),
    .m_axi_wvalid                        (m_axi_wvalid),
   
    .m_axi_bid                           (m_axi_bid),
    .m_axi_bresp                         (m_axi_bresp),
    .m_axi_bvalid                        (m_axi_bvalid),
    .m_axi_bready                        (m_axi_bready),

    .m_axi_clk                           (dec_clk),
    .m_axi_rst                           (rst),
    .m_axi_arready                       (m_axi_arready),
    .m_axi_arvalid                       (m_axi_arvalid),
    .m_axi_arlen                         (m_axi_arlen),
    .m_axi_araddr                        (m_axi_araddr),
    .m_axi_rready                        (m_axi_rready),
    .m_axi_rdata                         (m_axi_rdata),
    .m_axi_rvalid                        (m_axi_rvalid),
    .m_axi_rlast                         (m_axi_rlast),
    .m_axi_arid                          (m_axi_arid),
    .m_axi_arsize                        (m_axi_arsize),
    .m_axi_arburst                       (m_axi_arburst),
    .m_axi_arprot                        (m_axi_arprot),
    .m_axi_arcache                       (m_axi_arcache),
    .m_axi_arlock                        (m_axi_arlock),
    .m_axi_arqos                         (m_axi_arqos),
    .m_axi_rrid                          (m_axi_rrid),
    .m_axi_rresp                         (m_axi_rresp)
);


endmodule


