module fifo_awaiba(
//external interface
	clk_data,	//data clock from connector
	data,		//13 bit data from connector
	ready,		//ready to connector
	valid,		//valid from connector
//system interface
	clk,		//data clock from system (125 MHz)
	reset_n,	//system reset
	sync,		//sync from system
	data_out,	//output data to system
	valid_out,	//valid to system
	ready_sys	//ready from system
);

input			clk_data;
input	[12:0]	data;
output			ready;
input			valid;
input			clk;
input			reset_n;
input			sync;
output	[12:0]	data_out;
output			valid_out;
input			ready_sys;

wire	wr_full;

assign	ready = ~wr_full;

chan_buff chan_buff_inst(
	.sync_n(sync),
	.res_n(reset_n),
	.clk_wr(clk_data),
	.en_wr(valid),
	.din(data),
	.wr_full(wr_full),
	.dst_ready(ready_sys),
	.clk_rd(clk),
	.valid(valid_out),
	.data(data_out)
);



endmodule