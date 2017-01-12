module chan_buff(
	sync_n,
	res_n,
	clk_wr,
	en_wr,
	din,
	wr_full,
	dst_ready,
	clk_rd,
	valid,
	data
);

input			sync_n;
input			res_n;
input			clk_wr;
input			en_wr;
input	[12:0]	din;
output			wr_full;
input			dst_ready;
input			clk_rd;
output			valid;
output	[12:0]	data;

wire			rdreq0;
wire			rdempty0;
wire			rdreq1;
wire			rdempty1;
wire			en_wr0;
wire			en_wr1;
wire			rd_en0;
wire			rd_en1;
reg				bank_sel;
reg				sync_tmp;
wire			sync_rise;
wire	[12:0] 	data0;
wire	[12:0] 	data1;
wire			fifo_clr0;
wire			fifo_clr1;
wire			wrfull0;
wire			wrfull1;


assign	sync_rise = ({sync_n,sync_tmp} == 2'b10);
assign	data = bank_sel ? data0 : data1;
assign	fifo_clr0 = bank_sel ? ~sync_n : 1'b0;
assign	fifo_clr1 = bank_sel ? 1'b0 : ~sync_n;
assign	en_wr0 = bank_sel ? 1'b0 : en_wr;
assign	en_wr1 = bank_sel ? en_wr : 1'b0;
assign	rd_en0 = bank_sel ? rdreq0 : 1'b0;
assign	rd_en1 = bank_sel ? 1'b0 : rdreq1;
assign	rdreq0 = ~rdempty0 & dst_ready;
assign	rdreq1 = ~rdempty1 & dst_ready;
assign	valid = bank_sel ? rdreq0 : rdreq1;
assign	wr_full = bank_sel ? wrfull1 : wrfull0;

data_fifo data_fifo_0(
	.aclr(fifo_clr0),
	.data(din),
	.rdclk(clk_rd),
	.rdreq(rd_en0),
	.wrclk(clk_wr),
	.wrreq(en_wr0),
	.q(data0),
	.rdempty(rdempty0),
	.wrfull(wrfull0)
);

data_fifo data_fifo_1(
	.aclr(fifo_clr1),
	.data(din),
	.rdclk(clk_rd),
	.rdreq(rd_en1),
	.wrclk(clk_wr),
	.wrreq(en_wr1),
	.q(data1),
	.rdempty(rdempty1),
	.wrfull(wrfull1)
);


always@(posedge clk_wr or negedge res_n)
begin
	if (~res_n) {bank_sel,sync_tmp} <= 2'b01;
	else
	begin
		sync_tmp <= sync_n;
		if (sync_rise) bank_sel <= ~bank_sel;
		else bank_sel <= bank_sel;
	end
end

endmodule