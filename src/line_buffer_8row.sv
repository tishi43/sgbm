//--------------------------------------------------------------------------------------------------
// Copyright (C) 2021 tianqishi
// All rights reserved
// Design    : sgbm
// Author(s) : tianqishi
// Email     : tishi1@126.com
// QQ        : 2483210587
//-------------------------------------------------------------------------------------------------

`include "../include/sgbm_defines.v"

module line_buffer_8row
(
    input wire                     clk,
    input wire                     rst,
    input wire [`WIDTH_BITS-1:0]   i_width,
    input wire [`WIDTH_BITS-1:0]   i_height,
    input wire[`STRIDE_BITS-1:0]   i_stride,
    input wire            [31:0]   i_left_image_addr,
    input wire            [31:0]   i_right_image_addr,
    input wire [`DISPD_BITS-1:0]   i_min_disp,
    input wire [`DISPD_BITS-1:0]   i_max_disp,
    input wire                     i_reverse_done,
    input wire                     i_all_done,

    output reg                     o_rst_calc_cost,
    output reg                     o_clr_disp_ram,
    output reg [`HEIGHT_BITS-1:0]  y,

    input  wire                    m_axi_arready,
    output wire                    m_axi_arvalid,
    output wire           [ 3:0]   m_axi_arlen,
    output wire           [31:0]   m_axi_araddr,

    output wire                    m_axi_rready,
    input  wire           [63:0]   m_axi_rdata,
    input  wire                    m_axi_rvalid,
    input  wire                    m_axi_rlast,

    output reg                     o_reverse, //1=reverse
    output reg            [ 2:0]   o_calcing_state,
    output reg            [47:0]   o_data0,
    output reg            [47:0]   o_data1,
    output reg            [47:0]   o_data2,
    output reg            [47:0]   o_data3,
    output reg            [47:0]   o_data4

);


//reverse_data: ������ľۺϴ��ҵ�����Ҫ�ȼ������ұߵ�cost,�������ݴ��������
//���ڴ�С5x5����5��btcost��Ҫ7��ͼ�����ݣ�����������ۺ���ǰһ�н��У���8�У���һ�����ڴ�ddr���棬��9��
//5x5 windowingΪʲô��Ҫ5�����ݣ����������м���������һ���м�����Ҫ1280*COST_BITS*DISPD=1.9Mb��bram��

genvar                            ii;

(*mark_debug="true"*)
wire   [7:0][`WIDTH_BITS-1:0]     ram_addr_left;
(*mark_debug="true"*)
wire   [7:0][`WIDTH_BITS-1:0]     ram_addr_right;
(*mark_debug="true"*)
reg         [`WIDTH_BITS-1:0]     ram_rd_addr_left;
(*mark_debug="true"*)
reg         [`WIDTH_BITS-1:0]     ram_rd_addr_right;
(*mark_debug="true"*)
wire        [`WIDTH_BITS-1:0]     ram_wr_addr;


wire                    [7:0]     ram_wr_ena;
wire               [7:0][7:0]     ram_left_dout;
wire               [7:0][7:0]     ram_right_dout;


reg          [`WIDTH_BITS-1:0]     x;
reg          [`WIDTH_BITS-1:0]     x_to_store;
reg          [`WIDTH_BITS-1:0]     store_x;
reg         [`HEIGHT_BITS-1:0]     height_minus1;
reg          [`WIDTH_BITS-1:0]     width_minus1;


localparam
Idle = 0,
PrepAddr = 1,
FetchData = 2,
WaitStoreRam = 3,
OneRowDone = 4,
End = 5;

localparam
Calcing_idle =0,
Calcing_reverse = 1,
Calcing_forward = 2,
Calcing_wait1cycle=3,
Calcing_end = 4;


reg    [ 7:0][63:0]             line_buf_left       ;
reg    [ 7:0][63:0]             line_buf_left_bk    ;
wire   [63:0][ 7:0]             line_buf_left_w     ;

reg    [ 7:0][63:0]             line_buf_right      ;
reg    [ 7:0][63:0]             line_buf_right_bk   ;
wire   [63:0][ 7:0]             line_buf_right_w    ;

(*mark_debug="true"*)
reg    [ 2:0]                   fetch_stage         ;
(*mark_debug="true"*)
reg    [ 1:0]                   store_stage         ;


//����ȡ��ͼ�����ͼ��64�ֽڣ���ʾ64�ֽ�ȡ��
(*mark_debug="true"*)
reg                             left_fetch_done     ;
(*mark_debug="true"*)
reg                             right_fetch_done    ;
(*mark_debug="true"*)
reg    [`PIC_SIZE_BITS-1:0]     pic_offset          ; //��ǰҪȡ��64�ֽ����ͼ����ʼ��ַ��ƫ��
(*mark_debug="true"*)
reg    [`PIC_SIZE_BITS-1:0]     line_offset         ; //��ǰҪȡ���п�ͷ���ͼ����ʼ��ַ��ƫ��
(*mark_debug="true"*)
reg    [ 2:0]                   fetch_i             ;
(*mark_debug="true"*)
reg    [ 5:0]                   store_ram_i         ;
(*mark_debug="true"*)
reg                             kick_store          ;
(*mark_debug="true"*)
reg    [ 2:0]                   ram_write_index     ; //д���ĸ�ram��ram0,ram1,ram2,ram3��Ӧ0,1,2,3


(*mark_debug="true"*)
reg                             last_output                  ; //���һ�������������չһ��
(*mark_debug="true"*)
reg                             stop_write_ram               ;
(*mark_debug="true"*)
reg                             first_idle                   ;
(*mark_debug="true"*)
reg                             go                           ;

assign   line_buf_left_w    = line_buf_left_bk;
assign   line_buf_right_w   = line_buf_right_bk;
assign   m_axi_arlen        = 7;
assign   m_axi_araddr       = left_fetch_done? i_right_image_addr+pic_offset:
                                               i_left_image_addr+pic_offset;
assign   m_axi_arvalid      = fetch_stage == PrepAddr? 1:0;
assign   m_axi_rready       = 1;

always @ (posedge clk)
if (rst) begin
    fetch_stage                  <= Idle;
    left_fetch_done              <= 0;
    right_fetch_done             <= 0;
    fetch_i                      <= 0;
    height_minus1                <= i_height-1;
    x                            <= 0;
    x_to_store                   <= 0;
    kick_store                   <= 0;
    pic_offset                   <= 0;
    line_offset                  <= 0;
    go                           <= 1;
    width_minus1                 <= i_width-1;
    height_minus1                <= i_height-1;


end else begin
    if (fetch_stage == Idle && o_calcing_state==Calcing_idle&&go) begin

        if (~first_idle) begin //first_idle������reset֮���һ��idle���������һ��֮��ع�����idle
            pic_offset           <= line_offset+i_stride;
            line_offset          <= line_offset+i_stride;
        end

        if (y>=height_minus1) begin
            fetch_stage              <= End;
        end else begin
            fetch_stage              <= PrepAddr;
        end

        left_fetch_done              <= 0;
        right_fetch_done             <= 0;

    end


    if (fetch_stage == PrepAddr && m_axi_arready) begin
        fetch_stage              <= FetchData;
        kick_store               <= 0;
        fetch_i                  <= 0;
    end

    if (fetch_stage == FetchData && m_axi_rvalid) begin
        if (left_fetch_done)
            line_buf_right       <= {m_axi_rdata,line_buf_right[7:1]};
        else
            line_buf_left        <= {m_axi_rdata,line_buf_left[7:1]};
        fetch_i                  <= fetch_i+1;
        if (fetch_i == 7) begin
            if (~left_fetch_done) begin
                left_fetch_done  <= 1;
                fetch_stage      <= PrepAddr;
            end else begin
                right_fetch_done <= 1;
                fetch_stage      <= WaitStoreRam;
            end

        end
    end

    if (fetch_stage == WaitStoreRam&&store_stage==0) begin
        left_fetch_done          <= 0;
        right_fetch_done         <= 0;
        kick_store               <= 1;
        x_to_store               <= x;
        if (x[`WIDTH_BITS-1:6]==width_minus1[`WIDTH_BITS-1:6]) begin
            x                    <= 0;
            fetch_stage          <= OneRowDone;
        end else begin
            x                    <= x+64;
            fetch_stage          <= PrepAddr;
            pic_offset           <= pic_offset+64;
        end
    end

    if (fetch_stage == OneRowDone)
        kick_store               <= 0;

    if (fetch_stage == OneRowDone && store_stage==0 &&
        kick_store ==0) begin //�ȴ����һ�ʴ���
        fetch_stage              <= Idle;

    end

end

always @ (posedge clk)
if (rst) begin
    y                            <= 0;
    ram_write_index              <= 0;
    last_output                  <= 0;
    o_calcing_state              <= Calcing_idle;
    o_reverse                    <= 1;
    first_idle                   <= 1;
    o_clr_disp_ram               <= 0;
    stop_write_ram               <= 0;
    o_rst_calc_cost              <= 0;

end else begin
    if ((fetch_stage == Idle||fetch_stage==End) &&
          o_calcing_state==Calcing_idle&&go) begin


        first_idle               <= 0;
        if (~first_idle) begin //first_idle������reset֮���һ��idle���������һ��֮��ع�����idle
            y                    <= y+1;
        end

        if (~first_idle&&y<=i_height) begin
            ram_write_index      <= ram_write_index+1; //������5����
        end

        o_rst_calc_cost          <= y>=3?1:0; //0,1,2,3������ȡ��4�У�
        o_clr_disp_ram           <= y>=2?1:0; //����ǰ1����ram
        o_reverse                <= 1;
        o_calcing_state          <= y>=2?Calcing_wait1cycle:Calcing_idle; //y=2,��������Calcing_wait1cycle���o_clr_disp_ram������Calcing_idle


        //�����20��y=19�����(12,13,14)(13,14,15)(14,15,16)(15,16,17)(16,17,18) ram_write_index=3
        //y=20,���(13,14,15)(14,15,16)(15,16,17)(16,17,18)(17,18,19), ram_write_index=4,ʵ�ʲ�����д������Ḳ��
        //���һ��y=21��(14,15,16)(15,16,17)(16,17,18)(17,18,19),(18,19,19) ram_write_index=5,ʵ�ʲ�����д
        //window cost����2�ʣ�y=22,y=23�������(14,15,16)(15,16,17)(16,17,18)(17,18,19),(18,19,19)

        if (y==i_height-1)
            stop_write_ram           <= 1;

        if (y==i_height)
            last_output              <= 1;

        if (y==i_height+5) begin //window cost+aggr, lr check, output delay
            o_rst_calc_cost          <= 0;
            o_clr_disp_ram           <= 0;
            o_calcing_state          <= Calcing_end;
        end

    end

    if (o_calcing_state==Calcing_wait1cycle) begin
        o_calcing_state            <= y==3?Calcing_idle:(o_reverse?Calcing_reverse:Calcing_forward);
        o_rst_calc_cost          <= 0;
        o_clr_disp_ram           <= 0;
    end

    if (o_calcing_state==Calcing_reverse&&i_reverse_done) begin
        o_rst_calc_cost          <= y>=3?1:0;
        o_reverse                <= 0;
        o_calcing_state          <= Calcing_wait1cycle;
    end

    if (o_calcing_state==Calcing_forward&&i_all_done) begin
        o_calcing_state            <= Calcing_idle;
    end

end


always @ (posedge clk) begin
    if (rst) begin
        store_stage              <= 0;
        store_ram_i              <= 0;
        store_x                  <= 0;
    end
    else begin
        if (store_stage==0 && kick_store) begin
            store_ram_i          <= 0;
            line_buf_left_bk     <= line_buf_left;
            line_buf_right_bk    <= line_buf_right;
            store_x              <= x_to_store;
            store_stage          <= 1;
        end

        if (store_stage==1) begin
            line_buf_left_bk     <= {8'd0,line_buf_left_w[63:1]};
            line_buf_right_bk    <= {8'd0,line_buf_right_w[63:1]};
            store_ram_i          <= store_ram_i+1;

            if (store_ram_i==63) begin
                store_stage      <= 0;
            end

        end

    end
end

reg    [`WIDTH_BITS-1:0]    delay_cycles;
reg    [`WIDTH_BITS-1:0]    delay_cycles2;
reg                         stay_2cycles; //��calc_bt_cost��keep_first_cost_2cycles����һ�£�

//width=512,min_disparity=12,max_disparity=92,x��92ʱ�������Ч���ݣ�
//��ͼx=92����ͼ0~79�Ƚϣ�
//���ұߣ���ͼx=511����ͼx=511-92~511-12�Ƚ�

//��ͼ��line_buffer_9row������Ҫ����ͼ�ӳ�12���ڣ�������ͼx=92ʱ����ͼ���µ�����x=80����right_buffer[127]
//x=80,right_buffer[127],x=79,right_buffer[126]

//������ͼһֱ�ӳٵ�x=511-12������right_buffer[0]Ϊֹ,x=511-92,��Ӧright_buffer[79]��
//x=511,D=12�Ĵ���u-right_buffer[0],D=92�Ĵ���u-right_buffer[79], [0:79]��Ч


always @ (posedge clk)
if (rst) begin
    ram_rd_addr_left            <= 0;
    delay_cycles2               <= 0;
    delay_cycles                <= 0;
    stay_2cycles                <= 0;
    ram_rd_addr_right           <= i_width-1;
end
else if (o_rst_calc_cost) begin
    if (~o_reverse)
        ram_rd_addr_left        <= 0;

    delay_cycles2               <= 0;
    delay_cycles                <= 0;
    stay_2cycles                <= 0;
    if (o_reverse) begin
        ram_rd_addr_right       <= i_width-1;
    end
    else begin
        if (i_min_disp==0)
            ram_rd_addr_right   <= 0;
    end
end else begin
    if (~o_reverse) begin
        if (delay_cycles2<i_width)
            delay_cycles2       <= delay_cycles2+1;
        if (delay_cycles2==i_max_disp+5) //��calc_bt_cost��x��ǰ1����
            stay_2cycles        <= 1;
        if (delay_cycles2==i_max_disp+7)
            stay_2cycles        <= 0;

    end
    else begin
        if (delay_cycles<i_width)    //delay_cycles����`DISPD+i_min_disp-2һ��
            delay_cycles        <= delay_cycles+1;
        if (delay_cycles==`DISPD+i_min_disp+4) //��calc_bt_cost��x��ǰ1����
            stay_2cycles        <= 1;
        if (delay_cycles==`DISPD+i_min_disp+6)
            stay_2cycles        <= 0;
    end

    if (~o_reverse) begin
        if (~stay_2cycles)
            ram_rd_addr_left           <= ram_rd_addr_left+1;
    end
    else begin
        if (delay_cycles==`DISPD+i_min_disp-2) begin
            ram_rd_addr_left           <= width_minus1;
        end else begin
            if (~stay_2cycles)
                ram_rd_addr_left       <= ram_rd_addr_left-1;
        end
    end


    if (~o_reverse) begin
        if (i_min_disp==0) begin
            if (~stay_2cycles)
                ram_rd_addr_right      <= ram_rd_addr_right+1;
        end
        else begin
            if (delay_cycles2==i_min_disp-1) begin
                ram_rd_addr_right      <= 0;
            end else begin
                if (~stay_2cycles)
                    ram_rd_addr_right  <= ram_rd_addr_right+1;
            end
        end
    end
    else begin
        if (~stay_2cycles)
            ram_rd_addr_right          <= ram_rd_addr_right-1;
    end


end




assign ram_wr_addr = {store_x[`WIDTH_BITS-1:6],store_ram_i};

generate
    for (ii=0;ii<8;ii=ii+1)
    begin: ram_addr_label
        assign ram_addr_left[ii] = ram_write_index==ii&&(~stop_write_ram)?ram_wr_addr:ram_rd_addr_left;
        assign ram_addr_right[ii] = ram_write_index==ii&&(~stop_write_ram)?ram_wr_addr:ram_rd_addr_right;
    end
endgenerate

//last_output֮��������д������
generate
    for (ii=0;ii<8;ii=ii+1)
    begin: ram_wr_ena_label
        assign ram_wr_ena[ii] = store_stage == 1 && ram_write_index==ii&&~stop_write_ram;
    end
endgenerate


generate
    for (ii=0;ii<8;ii=ii+1)
    begin: ram_left_label
        ram #(`WIDTH_BITS, 8) ram_left(
            .clk(clk),
            .en(1'b1),
            .we(ram_wr_ena[ii]),
            .addr(ram_addr_left[ii]),
            .data_in(line_buf_left_w[0]),
            .data_out(ram_left_dout[ii])
        );


    end
endgenerate

generate
    for (ii=0;ii<8;ii=ii+1)
    begin: ram_right_label
        ram #(`WIDTH_BITS, 8) ram_right(
            .clk(clk),
            .en(1'b1),
            .we(ram_wr_ena[ii]),
            .addr(ram_addr_right[ii]),
            .data_in(line_buf_right_w[0]),
            .data_out(ram_right_dout[ii])
        );
    end
endgenerate

//ram_index 
// [0]                    ͼ��y=98
// [1]                    ͼ��y=99
// [2]  ram_write_index=2,ͼ��y=100
// [3]
// [4]
// [5]                    ͼ��y=94
// [6]                    ͼ��y=95
// [7]                    ͼ��y=96
// [8]                    ͼ��y=97

//ram_index   first_output_reverse,output 001,012,123,234,345
// [0]                    ͼ��y=0
// [1]                    ͼ��y=1
// [2]                    ͼ��y=2
// [3]                    ͼ��y=3
// [4]                    ͼ��y=4
// [5]                    ͼ��y=5
// [6] ram_write_index=6
// [7]
// [8]

// line 001  cost 0   windowed cost �������3��   
//      012       1                               
//      123       2                               cost0 *3+cost1+cost2          ��4�����ݿ������һ��windowed cost
//      234       3                               cost0*2+cost1+cost2+cost3     ��5������
//      345       4                               cost0+cost1+cost2+cost3+cost4 ��6������
//      456       5
//      567       6   
//      780           write_index
//      801


//2f
//36
//3a
//3e
//35
//43
//38

//reverse right
//a8
//a9
//a9
//aa
//ac
//ac
//ae
//ad
//af

//ͼ���20
// line 0,0,1  cost      0   windowed cost �������3��   
//      0,1,2            1                               
//      1,2,3            2                               cost0 *3+cost1+cost2          ��4�����ݿ������һ��windowed cost0
//      2,3,4            3                               cost0*2+cost1+cost2+cost3     ��5������
//      3,4,5            4                               cost0+cost1+cost2+cost3+cost4 ��6������
//      4,5,6            5
//      5,6,7            6   
//      6,7,8            7
//      7,8,9            8
//      8,9,10           9
//      9,10,11          10
//      10,11,12         11
//      11,12,13         12
//      12,13,14         13
//      13,14,15         14
//      14,15,16         15                             
//      15,16,17         16
//      16,17,18         17
//      17,18,19         18                              cost14+cost15+cost16+cost17+cost18       windowed cost16
//      18,19,19         19                              cost15+cost16+cost17+cost18+cost19       windowed cost17
//                                  y=20 last_output=1   cost15+cost16+cost17+cost18+cost19       windowed cost18
//                                                       cost15+cost16+cost17+cost18+cost19       windowed cost19
//18��19���е�windowed cost������cost16+cost17+cost18+cost19*2��cost17+cost18+cost19*3�����Ǹ�17��һ����

//y=4,                                   o_reverse_data=001,012,123,234,345(4,5��Ч)   ��reverse windowed cost0
//y=5,o_data=001,012,123,234,345(5��Ч)                                                ��reverse windowed cost1,windowed cost0
//y=6,o_data=001,012,123,234,345
//y=7,o_data=001,012,123,234,345                                                                                windowed cost2



wire       [2:0]     data_index0;
wire       [2:0]     data_index1;
wire       [2:0]     data_index2;
wire       [2:0]     data_index3;
wire       [2:0]     data_index4;
wire       [2:0]     data_index5;
wire       [2:0]     data_index6;
wire       [2:0]     data_index7;

assign data_index1 = ram_write_index-7;
assign data_index2 = ram_write_index-6;
assign data_index3 = ram_write_index-5;
assign data_index4 = ram_write_index-4;
assign data_index5 = ram_write_index-3;
assign data_index6 = ram_write_index-2;
assign data_index7 = ram_write_index-1;


always @(*) begin
    if (y==4) begin
        o_data0     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data1     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data2     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data3     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[1],
                       ram_right_dout[1],ram_left_dout[2],ram_right_dout[2]};
        o_data4     = {ram_left_dout[1],ram_right_dout[1],ram_left_dout[2],
                       ram_right_dout[2],ram_left_dout[3],ram_right_dout[3]};
    end else if (y==5) begin
        o_data0     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data1     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data2     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[1],
                       ram_right_dout[1],ram_left_dout[2],ram_right_dout[2]};
        o_data3     = {ram_left_dout[1],ram_right_dout[1],ram_left_dout[2],
                       ram_right_dout[2],ram_left_dout[3],ram_right_dout[3]};
        o_data4     = {ram_left_dout[2],ram_right_dout[2],ram_left_dout[3],
                       ram_right_dout[3],ram_left_dout[4],ram_right_dout[4]};
    end else if (y==6) begin
        o_data0     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[0],
                       ram_right_dout[0],ram_left_dout[1],ram_right_dout[1]};
        o_data1     = {ram_left_dout[0],ram_right_dout[0],ram_left_dout[1],
                       ram_right_dout[1],ram_left_dout[2],ram_right_dout[2]};
        o_data2     = {ram_left_dout[1],ram_right_dout[1],ram_left_dout[2],
                       ram_right_dout[2],ram_left_dout[3],ram_right_dout[3]};
        o_data3     = {ram_left_dout[2],ram_right_dout[2],ram_left_dout[3],
                       ram_right_dout[3],ram_left_dout[4],ram_right_dout[4]};
        o_data4     = {ram_left_dout[3],ram_right_dout[3],ram_left_dout[4],
                       ram_right_dout[4],ram_left_dout[5],ram_right_dout[5]};
    end else begin

        o_data0     = {ram_left_dout[data_index1],
                       ram_right_dout[data_index1],
                       ram_left_dout[data_index2],
                       ram_right_dout[data_index2],
                       ram_left_dout[data_index3],
                       ram_right_dout[data_index3]};

        o_data1     = {ram_left_dout[data_index2],
                       ram_right_dout[data_index2],
                       ram_left_dout[data_index3],
                       ram_right_dout[data_index3],
                       ram_left_dout[data_index4],
                       ram_right_dout[data_index4]};

        o_data2     = {ram_left_dout[data_index3],
                       ram_right_dout[data_index3],
                       ram_left_dout[data_index4],
                       ram_right_dout[data_index4],
                       ram_left_dout[data_index5],
                       ram_right_dout[data_index5]};

        o_data3     = {ram_left_dout[data_index4],
                       ram_right_dout[data_index4],
                       ram_left_dout[data_index5],
                       ram_right_dout[data_index5],
                       ram_left_dout[data_index6],
                       ram_right_dout[data_index6]};

        o_data4     = last_output?
                      {ram_left_dout[data_index5],
                       ram_right_dout[data_index5],
                       ram_left_dout[data_index6],
                       ram_right_dout[data_index6],
                       ram_left_dout[data_index6],
                       ram_right_dout[data_index6]}:
                       {ram_left_dout[data_index5],
                       ram_right_dout[data_index5],
                       ram_left_dout[data_index6],
                       ram_right_dout[data_index6],
                       ram_left_dout[data_index7],
                       ram_right_dout[data_index7]};

    end
end



`ifdef RANDOM_INIT
integer  seed;
integer random_val;
initial  begin
    seed                               = $get_initial_random_seed(); 
    random_val                         = $random(seed);
    o_rst_calc_cost                    = {random_val,random_val};
    o_clr_disp_ram                     = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    y                                  = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    o_reverse                          = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
    o_calcing_state                    = {random_val[4:0],random_val[31:5],random_val[4:0],random_val[31:5]};
    o_data0                            = {random_val[5:0],random_val[31:6],random_val[5:0],random_val[31:6]};
    o_data1                            = {random_val[6:0],random_val[31:7],random_val[6:0],random_val[31:7]};
    o_data2                            = {random_val[7:0],random_val[31:8],random_val[7:0],random_val[31:8]};
    o_data3                            = {random_val[8:0],random_val[31:9],random_val[8:0],random_val[31:9]};
    o_data4                            = {random_val[9:0],random_val[31:10],random_val[9:0],random_val[31:10]};
    ram_rd_addr_left                   = {random_val[10:0],random_val[31:11],random_val[10:0],random_val[31:11]};
    ram_rd_addr_right                  = {random_val[11:0],random_val[31:12],random_val[11:0],random_val[31:12]};
    x                                  = {random_val[12:0],random_val[31:13],random_val[12:0],random_val[31:13]};
    x_to_store                         = {random_val[13:0],random_val[31:14],random_val[13:0],random_val[31:14]};
    store_x                            = {random_val[14:0],random_val[31:15],random_val[14:0],random_val[31:15]};
    height_minus1                      = {random_val[15:0],random_val[31:16],random_val[15:0],random_val[31:16]};
    width_minus1                       = {random_val[16:0],random_val[31:17],random_val[16:0],random_val[31:17]};
    line_buf_left                      = {random_val[17:0],random_val[31:18],random_val[17:0],random_val[31:18]};
    line_buf_left_bk                   = {random_val[18:0],random_val[31:19],random_val[18:0],random_val[31:19]};
    line_buf_right                     = {random_val[19:0],random_val[31:20],random_val[19:0],random_val[31:20]};
    line_buf_right_bk                  = {random_val[20:0],random_val[31:21],random_val[20:0],random_val[31:21]};
    fetch_stage                        = {random_val[21:0],random_val[31:22],random_val[21:0],random_val[31:22]};
    store_stage                        = {random_val[22:0],random_val[31:23],random_val[22:0],random_val[31:23]};
    left_fetch_done                    = {random_val[23:0],random_val[31:24],random_val[23:0],random_val[31:24]};
    right_fetch_done                   = {random_val[24:0],random_val[31:25],random_val[24:0],random_val[31:25]};
    pic_offset                         = {random_val[25:0],random_val[31:26],random_val[25:0],random_val[31:26]};
    line_offset                        = {random_val[26:0],random_val[31:27],random_val[26:0],random_val[31:27]};
    fetch_i                            = {random_val[27:0],random_val[31:28],random_val[27:0],random_val[31:28]};
    store_ram_i                        = {random_val[28:0],random_val[31:29],random_val[28:0],random_val[31:29]};
    kick_store                         = {random_val[29:0],random_val[31:30],random_val[29:0],random_val[31:30]};
    ram_write_index                    = {random_val[30:0],random_val[31],random_val[30:0],random_val[31]};
    last_output                        = {random_val[31:0],random_val[31:0]};
    stop_write_ram                     = {random_val,random_val};
    first_idle                         = {random_val[1:0],random_val[31:2],random_val[1:0],random_val[31:2]};
    delay_cycles                       = {random_val[2:0],random_val[31:3],random_val[2:0],random_val[31:3]};
    delay_cycles2                      = {random_val[3:0],random_val[31:4],random_val[3:0],random_val[31:4]};
end
`endif



endmodule

