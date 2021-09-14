//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

module minmax3_0cycle #(parameter Width=8) (
	input wire [Width-1:0] i_d0,
	input wire [Width-1:0] i_d1,
	input wire [Width-1:0] i_d2,
	output reg [Width-1:0] o_min,
	output reg [Width-1:0] o_max
);

reg pixel_0g1;
reg pixel_0g2;
reg pixel_1g2;

always @(*) begin
	if (i_d0 > i_d1)
		pixel_0g1 = 1;
	else
		pixel_0g1 = 0;

	if (i_d0 > i_d2)
		pixel_0g2 = 1;
	else
		pixel_0g2 = 0;

	if ( i_d1 > i_d2)
		pixel_1g2 = 1;
	else
		pixel_1g2 = 0;

end


always @(*) begin
	if (pixel_0g1 && pixel_0g2)
		o_max = i_d0;
	else if (pixel_1g2 && ~pixel_0g1)
		o_max = i_d1;
	else 
		o_max = i_d2;

	if (~pixel_0g1 && ~pixel_0g2)
		o_min = i_d0;
	else if (~pixel_1g2 && pixel_0g1)
		o_min = i_d1;
	else 
		o_min = i_d2;
end



endmodule

