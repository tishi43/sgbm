//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`timescale 1ns / 1ns // timescale time_unit/time_presicion

`default_nettype none

`define COST_BITS        12  //5x5窗口之后和一个方向聚合之后的cost位宽
`define FINAL_COST_BITS  16  //最终5个方向聚合相加之后的cost位宽
`define MAX_COST         12'hfff
`define MAX_FINAL_COST   16'hffff
`define WIDTH_BITS       11      //2047, max 1280
`define HEIGHT_BITS      11
`define STRIDE_BITS      12    //2048
`define OUT_STRIDE_BITS  13    //4096
`define PIC_SIZE_BITS    21   //max 1280*1080
`define DISPD            128
`define DISPD_BITS       8    //minDisp+DISPD的位数
`define DISP_TYPE_BITS   16

`define log_cost 1
`define log_intermediate 1
`define log_window 1
`define log_hsum 1
`define log_aggr_left_right 1
`define log_aggr_right_left 1
`define log_aggr_down_left 1
`define log_aggr_down 1
`define log_aggr_down_right 1
`define log_aggr 1
`define log_unique 1
`define log_lr_check 1

`define log_start_row 0
`define log_end_row 1

//`define RANDOM_INIT

