Implementation of SGBM in opencv, verified on Xilinx ZYNQ7035

1. Content
Folder "src" contains all decode source file.
Folder "tb" contains test bench file, ext_ram_32.v emulate ddr with axi3 interface.
pli_fputc.dll is verilog pli used to write output bin to file when run simulation.
left1 and right1 is the default test image bin file with the size of 1280x960

2. How to use
Simulation: add all test bench and source code file to your simulation project source, for example, modelsim.
put the test file, "left1","right1" to your simulation project folder.
then run, for example, for modelsim, run "vsim -pli pli_fputc.dll bitstream_tb".
The output is out.yuv, and some log files.

Run on FPGA board: add the source file in "src" folder to your FPGA project.
The top file is sgbm.sv.

3. ToDo
SAD win size is fixed to 5, should be setable by user.
Add removeSpeckle in opencv.
Due to huge bram utilization, for asic usage, these bram all be removed and put the temp data in ddr, and to reduce ddr read/write, memory compaction method should be used.


主要包含以下部分：
line_buffer_8row.sv, 从ddr读左图和右图，缓存8行，为什么8行，5x5的cost加窗运算最多要7行图像，此7行用来输出，另一行用来从ddr读入。
calc_bt_cost.sv，代价计算，正向的代价计算，从x=minD开始到width-1，反向的代价计算，从x=width-1开始，计算到x=minD，为什么要反向，右左方向代价聚合时，是从最右边开始的，


sgbm_aggr_down.sv，sgbm_aggr_down_left.sv，sgbm_aggr_right_left.sv
5个方向的代价聚合，sgbm_aggr_down_left复用了down right和down left两个方向的代价聚合，目的是为了省一些资源，
sgbm_aggr_right_left复用了左右和右左方向的代价聚合。


sgbm.sv 顶层文件，也包含其它处理，包括唯一性检测，左右一致性检测，输出结果到ddr。
