module fifo_awaiba(
//external interface
	clk_data,	//data clock from connector
	data,		//13 bit data from connector
	ready,		//ready to connector
	valid,		//valid from connector
	address,
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
output	[1:0]	address;
reg		[1:0]	address;
input			clk;
input			reset_n;
input			sync;
output	[12:0]	data_out;
output			valid_out;
input			ready_sys;

wire	wr_full;
reg		valid_tmp;
wire	valid_fall;

assign	valid_fall = ({valid,valid_tmp} == 2'b01);

always@(posedge clk_data or negedge reset_n)
begin
	if (~reset_n) {address,valid_tmp} <= 3'b000;
	else
	begin
		valid_tmp <= valid;
		casex ({sync,valid_fall})
			2'b0x: address <= 0;
			2'b11: address <= address + 1'b1;
			2'b10: address <= address;
		endcase
	end
end

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