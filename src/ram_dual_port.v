//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------


// used for storing intra4x4_pred_mode, ref_idx, mvp etc
// 
module ram_d
(
clk,
en,
we,
addra,
addrb,
dia,
doa,
dob
);

parameter addr_bits = 8;
parameter data_bits = 16;
input     clk;
input     en;
input     we;
input     [addr_bits-1:0]  addra;
input     [addr_bits-1:0]  addrb;
input     [data_bits-1:0]  dia;
output    [data_bits-1:0]  doa;
output    [data_bits-1:0]  dob;

wire      clk;
wire      en;
wire      we;
wire      [addr_bits-1:0]  addra;
wire      [addr_bits-1:0]  addrb;
wire      [data_bits-1:0]  dia;
reg       [data_bits-1:0]  doa;
reg       [data_bits-1:0]  dob;

(* ram_style = "block" *)
reg       [data_bits-1:0]  ram[0:(1 << addr_bits) -1];


`ifdef RANDOM_INIT
integer  seed;
integer random_val;
integer i;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    for (i=0;i<(1 << addr_bits);i=i+1)
        ram[i] = random_val;
end
`endif


//read
always @ ( posedge clk )
begin
    if (en)
        dob <= ram[addrb];
end 

always @ ( posedge clk )
begin
    if (en)
        doa <= ram[addra];
end 

//write
always @ (posedge clk)
begin
    if (we && en)
        ram[addra] <= dia;
end

endmodule
