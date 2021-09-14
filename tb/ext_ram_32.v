//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------
`include "../include/sgbm_defines.v"

module ext_ram_32
(
    input  wire                       m_axi_wclk, 
    output wire                       m_axi_awready, // Indicates slave is ready to accept a 
    input  wire  [ 5:0]               m_axi_awid,    // Write ID
    input  wire  [31:0]               m_axi_awaddr,  // Write address
    input  wire  [ 3:0]               m_axi_awlen,   // Write Burst Length
    input  wire  [ 2:0]               m_axi_awsize,  // Write Burst size
    input  wire  [ 1:0]               m_axi_awburst, // Write Burst type
    input  wire  [ 1:0]               m_axi_awlock,  // Write lock type
    input  wire  [ 3:0]               m_axi_awcache, // Write Cache type
    input  wire  [ 2:0]               m_axi_awprot,  // Write Protection type
    input  wire                       m_axi_awvalid, // Write address valid

    output wire                       m_axi_wready,  // Write data ready
    input  wire  [ 5:0]               m_axi_wid,     // Write ID tag
    input  wire  [63:0]               m_axi_wdata,    // Write data
    input  wire  [ 7:0]               m_axi_wstrb,    // Write strobes
    input  wire                       m_axi_wlast,    // Last write transaction   
    input  wire                       m_axi_wvalid,   // Write valid

    output wire  [ 5:0]               m_axi_bid,     // Response ID
    output wire  [ 1:0]               m_axi_bresp,   // Write response
    input  wire                       m_axi_bvalid,  // Write reponse valid
    input  wire                       m_axi_bready,  // Response ready

    input  wire                       m_axi_clk,
    input  wire                       m_axi_rst,
    output wire                       m_axi_arready,
    input  wire                       m_axi_arvalid, 
    input  wire  [ 3:0]               m_axi_arlen,
    input  wire  [31:0]               m_axi_araddr,
    input  wire                       m_axi_rready,
    output reg   [63:0]               m_axi_rdata,
    output wire                       m_axi_rvalid,
    output wire                       m_axi_rlast,
    input  wire  [ 5:0]               m_axi_arid,
    input  wire  [ 2:0]               m_axi_arsize,
    input  wire  [ 1:0]               m_axi_arburst,
    input  wire  [ 2:0]               m_axi_arprot,
    input  wire  [ 3:0]               m_axi_arcache,
    input  wire  [ 1:0]               m_axi_arlock,
    input  wire  [ 3:0]               m_axi_arqos,
    input  wire  [ 5:0]               m_axi_rrid,
    output wire  [ 1:0]               m_axi_rresp


);


reg[7:0] ram[2**30-1:0];

reg       [31:0]  rvalid_cycles;
always @ (posedge m_axi_clk)
if (m_axi_rst) begin
    rvalid_cycles     <= 0;
end else begin
    if (m_axi_rvalid)
        rvalid_cycles <= rvalid_cycles+1;
end





integer           fp_w;
reg       [7:0]   data;
integer           i,j,idx;
integer           frame_size;
integer           fp_img;
integer           addr_file;
integer           ch;



parameter
PicWidth = 1280,
PicHeight = 960,
PicChannels = 1,
PicPixelsNum = PicWidth*PicHeight;
parameter StreamRamSize = PicPixelsNum*PicChannels;

initial
begin

    $fputc(0,0);
    #6000000 $display("%t write disparity", $time);


        for (i=0; i< PicHeight; i=i+1) begin
            for (j= 0; j < PicWidth; j= j + 1) begin
                idx = 32'h22000000+i*4096 + j*2;

                $fputc(ram[idx],1);
                $fputc(ram[idx+1],1);
            end
        end


        $fputc(0,2);


end

initial
begin
    addr_file = 0;
    fp_img = $fopen("left1", "rb");
    while(addr_file < StreamRamSize) begin:loop0
        ch = $fgetc(fp_img);
        if (ch >= 0 && ch <256) begin
            ram[(addr_file/PicWidth)*2048+(addr_file%PicWidth)+32'h20000000] = ch;  //stride=2048
            addr_file = addr_file + 1;
        end
        else begin
            addr_file = 32'h7fffffff;
        end
    end

    $fclose(fp_img);
    addr_file = 0;
    fp_img = $fopen("right1", "rb");
    while(addr_file < StreamRamSize) begin:loop1
        ch = $fgetc(fp_img);
        if (ch >= 0 && ch <256) begin
            ram[(addr_file/PicWidth)*2048+(addr_file%PicWidth)+32'h21000000] = ch;
            addr_file = addr_file + 1;
        end
        else begin
            addr_file = 32'h7fffffff;
        end
    end
end


wire [31:0] wr_addr_int;
reg [31:0] wr_addr_int_reg;
wire [31:0] rd_addr_int;


wire aw_handshake = m_axi_awready && m_axi_awvalid;
wire w_handshake = m_axi_wready && m_axi_wvalid;

always @(posedge m_axi_wclk)
if (w_handshake)
    wr_addr_int_reg <= wr_addr_int;

always @ (*)
     m_axi_rdata <= {ram[rd_addr_int+7], ram[rd_addr_int+6],ram[rd_addr_int+5], ram[rd_addr_int+4],
                     ram[rd_addr_int+3], ram[rd_addr_int+2],ram[rd_addr_int+1], ram[rd_addr_int]};


/////////////////////////////////////////////////
//read
reg             rd_empty;
wire            rvalid;
reg             rvalid_and_reg;
wire    [31:0]  m_axi_araddr_q;
wire    [ 3:0]  m_axi_arlen_q;
reg     [15:0]  prep_data_ready; //ar_handshake之后ddr至少延迟1周期准备好数据

wire ar_handshake = m_axi_arready && m_axi_arvalid;
wire r_handshake = m_axi_rready && m_axi_rvalid;

reg   [3:0]  ar_ram_wr_addr;
reg   [3:0]  ar_ram_wr_addr_save;
reg   [3:0]  ar_ram_rd_addr;
wire         inc_ar_ram_rd_addr;
reg   [7:0]  rd_addr_offset;

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst) begin
    ar_ram_wr_addr                       <= 0;
    prep_data_ready                      <= 16'd0;
end else if (ar_handshake) begin
    ar_ram_wr_addr                       <= ar_ram_wr_addr + 1'b1;
    prep_data_ready[ar_ram_wr_addr]      <= 0;
    ar_ram_wr_addr_save                  <= ar_ram_wr_addr;
end else begin
    prep_data_ready[ar_ram_wr_addr_save] <= 1;
end

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst)
    ar_ram_rd_addr <= 0;
else if (inc_ar_ram_rd_addr)
    ar_ram_rd_addr <= ar_ram_rd_addr + 1'b1;


reg [1:0]  random_val;
always @ (posedge m_axi_clk)
begin
    random_val  <= $random()%4;
end

reg   random_val0;
always @ (posedge m_axi_clk)
begin
    random_val0  <= $random()%2;
end



assign m_axi_rvalid = rvalid_and_reg & rvalid;
assign m_axi_arready = ~(ar_ram_rd_addr[3] != ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0]) && (random_val0==1);

reg rd_empty_reg;
always @(*)
    rd_empty <= ar_ram_rd_addr[3] == ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0];

always @(posedge m_axi_clk)
    rd_empty_reg <= ar_ram_rd_addr[3] == ar_ram_wr_addr[3] && ar_ram_rd_addr[2:0] == ar_ram_wr_addr[2:0];

assign rvalid = ~rd_empty && ~rd_empty_reg;


//always @ (*)
//begin
//    rvalid_and_reg = prep_data_ready[ar_ram_rd_addr];
//end

always @ (*)
begin
    rvalid_and_reg = /*prep_data_ready[ar_ram_rd_addr]&&*/(random_val==0);
end

//always @(posedge m_axi_clk)
//    rvalid_and_reg <= 1;//$random() % 16;    //binq



dp_ram_async_read #(32+4, 4) ar_ram(
    .aclr(m_axi_rst),
    .data({m_axi_araddr,m_axi_arlen}),
    .rdaddress(ar_ram_rd_addr ), 
    .wraddress(ar_ram_wr_addr),
    .wren(ar_handshake), 
    .rdclock(m_axi_clk), 
    .wrclock(m_axi_clk),
    .q({m_axi_araddr_q,m_axi_arlen_q})
);

assign rd_addr_int = m_axi_araddr_q + rd_addr_offset*8;
assign m_axi_rlast = rd_addr_offset == m_axi_arlen_q && ~rd_empty;
assign inc_ar_ram_rd_addr = m_axi_rlast && r_handshake;

always @(posedge m_axi_clk or posedge m_axi_rst)
if (m_axi_rst) begin
    rd_addr_offset <= 0;
end
else begin
    if (r_handshake && rd_addr_offset < m_axi_arlen_q) begin
        rd_addr_offset <= rd_addr_offset + 1;
    end
    else if (r_handshake)
        rd_addr_offset <= 0;
end

/////////////////////////////////////////////////
//write, assume that addr always comes first
reg rd_empty1;
wire [31:0] m_axi_awaddr_q;
wire [3:0] m_axi_awlen_q;




reg [5:0] aw_ram_wr_addr;
reg [5:0] aw_ram_rd_addr;
wire inc_aw_ram_rd_addr;
reg [7:0] wr_addr_offset;
reg wr_full;

always @(posedge m_axi_wclk)
if (m_axi_rst)
    aw_ram_wr_addr <= 0;
else if (aw_handshake) //aw_handshake之后，ram地址+1，ddr地址已存到未+1的那个ram地址
    aw_ram_wr_addr <= aw_ram_wr_addr + 1'b1;

always @(posedge m_axi_wclk)
if (m_axi_rst)
    aw_ram_rd_addr <= 0;
else if (inc_aw_ram_rd_addr)
    aw_ram_rd_addr <= aw_ram_rd_addr + 1'b1;

always @(*)
    wr_full <= aw_ram_rd_addr[3] != aw_ram_wr_addr[3] && aw_ram_rd_addr[2:0] == aw_ram_wr_addr[2:0];
reg awready_and_reg;
reg wready_and_reg;

always @(posedge m_axi_wclk)begin
    awready_and_reg <= 1/*$random() % 3 == 0*/;
    wready_and_reg <= 1/*$random() % 3 == 0*/;
end

assign m_axi_wready = wready_and_reg;
assign m_axi_awready = ~wr_full&&awready_and_reg;

dp_ram_async_read #(32+4, 6) aw_ram(
    .aclr(m_axi_rst),
    .data({m_axi_awaddr,m_axi_awlen}),
    .rdaddress(aw_ram_rd_addr ), 
    .wraddress(aw_ram_wr_addr),
    .wren(aw_handshake), 
    .rdclock(m_axi_wclk), 
    .wrclock(m_axi_wclk),
    .q({m_axi_awaddr_q,m_axi_awlen_q})
);

assign wr_addr_int = m_axi_awaddr_q + wr_addr_offset*8;
assign inc_aw_ram_rd_addr = m_axi_wlast && w_handshake;

always @(posedge m_axi_wclk)
if (m_axi_rst) begin
    wr_addr_offset <= 0;
end
else begin
    if (w_handshake && wr_addr_offset < m_axi_awlen_q) begin
        wr_addr_offset <= wr_addr_offset + 1;
    end
    else if (w_handshake)
        wr_addr_offset <= 0;
end

//write
always @ (posedge m_axi_wclk)
if (w_handshake) begin
    if (m_axi_wstrb[0])
        ram[wr_addr_int] <= m_axi_wdata[7:0];
    if (m_axi_wstrb[1])
        ram[wr_addr_int+1] <= m_axi_wdata[15:8];
    if (m_axi_wstrb[2])
        ram[wr_addr_int+2] <= m_axi_wdata[23:16];
    if (m_axi_wstrb[3])
        ram[wr_addr_int+3] <= m_axi_wdata[31:24];
    if (m_axi_wstrb[4])
        ram[wr_addr_int+4] <= m_axi_wdata[39:32];
    if (m_axi_wstrb[5])
        ram[wr_addr_int+5] <= m_axi_wdata[47:40];
    if (m_axi_wstrb[6])
        ram[wr_addr_int+6] <= m_axi_wdata[55:48];
    if (m_axi_wstrb[7])
        ram[wr_addr_int+7] <= m_axi_wdata[63:56];
end

endmodule

    
