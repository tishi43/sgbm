//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

module div_by_shift_sum #(
    parameter WidthD0=64,
    parameter WidthD1=32,
    parameter WidthQ=WidthD0+WidthD1)
(
    input wire                  clk,
    input wire  [WidthD0-1:0]   a,
    input wire  [WidthD1-1:0]   b,

    output wire [WidthD0-1:0]   result
);


reg  [WidthD1-1:0]   b_d[0:WidthD0];
reg  [WidthQ-1:0]    div_result_d[0:WidthD0];
reg  [WidthD1-1:0]   div_sub_val[0:WidthD0];

always @ (posedge clk) begin
    b_d[0]           <= b;
    div_result_d[0]  <= {{(WidthD1-1){1'b0}}, a,1'b0};
end

integer ii;

always @(*) begin
    for (ii = 0; ii <= WidthD0; ii = ii + 1) begin
        div_sub_val[ii] = div_result_d[ii][WidthQ-1:WidthD0]-b_d[ii];
    end
end

always @(posedge clk) begin
    for (ii = 1; ii <= WidthD0; ii = ii + 1) begin
        if (div_result_d[ii-1][WidthQ-1:WidthD0]>=b_d[ii-1])
            div_result_d[ii]  <= ({div_sub_val[ii-1],div_result_d[ii-1][WidthD0-1:0]} << 1) | 1;
        else
            div_result_d[ii]  <= div_result_d[ii-1][WidthQ-1:0] << 1;

        b_d[ii]               <= b_d[ii-1];

    end
end

assign result = div_result_d[WidthD0][WidthD0-1:0];

endmodule


