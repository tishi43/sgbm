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


��Ҫ�������²��֣�
line_buffer_8row.sv, ��ddr����ͼ����ͼ������8�У�Ϊʲô8�У�5x5��cost�Ӵ��������Ҫ7��ͼ�񣬴�7�������������һ��������ddr���롣
calc_bt_cost.sv�����ۼ��㣬����Ĵ��ۼ��㣬��x=minD��ʼ��width-1������Ĵ��ۼ��㣬��x=width-1��ʼ�����㵽x=minD��ΪʲôҪ������������۾ۺ�ʱ���Ǵ����ұ߿�ʼ�ģ�


sgbm_aggr_down.sv��sgbm_aggr_down_left.sv��sgbm_aggr_right_left.sv
5������Ĵ��۾ۺϣ�sgbm_aggr_down_left������down right��down left��������Ĵ��۾ۺϣ�Ŀ����Ϊ��ʡһЩ��Դ��
sgbm_aggr_right_left���������Һ�������Ĵ��۾ۺϡ�


sgbm.sv �����ļ���Ҳ����������������Ψһ�Լ�⣬����һ���Լ�⣬��������ddr��
