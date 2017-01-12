module spi_awaiba(
//bus interface
	clk_spi,	// 0 < clk_spi < 20 MHz and clk_spi < mclk/2 (mclk = 25 MHz at this moment)
	clk,		//fifo bus clock
	res_n,		// reset active low
	data_mo,	// spi data to transmit 16 bit d[7:0] - data, d[15:8] awaiba register address
	valid_mo,	//valid transmit data
	ready_mo,	//transmitter ready
	data_mi,	//data reseived from awaiba
	ready_mi,	//ready to accept reseived data
	valid_mi,	//reseived data valid
	address,	//select destination a,b (address = 0) or c,d (address = 1)
//spi interface
	mosi,		//spi master output
	miso,		//spi master input
	sclk,		//spi_sclk
	cs_n,		//spi cs active low
	spi_abn_cdp	// = address
);

input			clk_spi;
input			clk;
input			res_n;
input	[15:0]	data_mo;
input			valid_mo;
output			ready_mo;
output	[7:0]	data_mi;
input			ready_mi;
output			valid_mi;
//reg				valid_mi;
input			address;
output			mosi;
input			miso;
output			sclk;
output			cs_n;
output			spi_abn_cdp;

reg		[15:0]	mo_reg;
reg		[15:0]	mo_tmp;
reg		[7:0]	mi_reg;
reg		[7:0]	mi_tmp;
reg				cs_tmp;
wire			cs_rise;
reg		[18:0]	csreg_w;
reg		[27:0]	csreg_r;
reg				start_mo;
wire			r_w;
wire			sclk_en;
wire	[15:0]	fifo_mo;
wire			empty_mo;
wire			full_mo;
wire			valid_mo_f;
wire			ready_mo_f;
wire			rdreq_mo;
wire			wrreq_mo;
wire			empty_mi;
wire			full_mi;
reg				valid_mi_f;
wire			ready_mi_f;
wire			rdreq_mi;
wire			wrreq_mi;

assign	spi_abn_cdp = address;
assign	cs_n = r_w ? csreg_r[0] : csreg_w[0];
assign	r_w = (mo_tmp[15:8] == 8'd15);
assign	sclk_en = ~cs_n;
assign	sclk = sclk_en ? clk_spi : 1'b0;
//assign	data_mi = mi_tmp;
assign	ready_mo_f = (cs_n & (~start_mo));
assign	mosi = mo_reg[0];
assign	cs_rise = ({cs_n,cs_tmp} == 2'b10);

assign	ready_mo = ~full_mo;
assign	wrreq_mo = (valid_mo & ready_mo);
assign	valid_mo_f = ~empty_mo;
assign	rdreq_mo = ready_mo_f & valid_mo_f;

assign	wrreq_mi = (valid_mi_f & ready_mi_f);
assign	ready_mi_f = ~full_mi;
assign	valid_mi = ~empty_mi;
assign	rdreq_mi = ready_mi & valid_mi;

fifo_64x16 fifo_64x16_inst(
	.data(data_mo),
	.rdclk(clk_spi),
	.rdreq(rdreq_mo),
	.wrclk(clk),
	.wrreq(wrreq_mo),
	.q(fifo_mo),
	.rdempty(empty_mo),
	.wrfull(full_mo)
);

fifo_64x8 fifo_64x8_inst(
	.data(mi_tmp),
	.rdclk(clk),
	.rdreq(rdreq_mi),
	.wrclk(clk_spi),
	.wrreq(wrreq_mi),
	.q(data_mi),
	.rdempty(empty_mi),
	.wrfull(full_mi)
);

always@(posedge clk_spi or negedge res_n)
begin
	if (~res_n) {mo_tmp,start_mo} <= 0;
	else
	begin
		case ({valid_mo_f,ready_mo_f,start_mo})
			3'b110: {mo_tmp,start_mo} <= {fifo_mo,1'b1};
			default: {mo_tmp,start_mo} <= {mo_tmp,1'b0};
		endcase
	end
end

always@(negedge clk_spi or negedge res_n)
begin
	if (~res_n)
	begin
		csreg_r <= 28'hfffffff;
		csreg_w <= 19'h7ffff;
		mo_reg <= 0;
		mi_reg <= 0;
	end
	else
	begin
		case ({start_mo,cs_n,r_w})
			3'b110:
			begin
				csreg_r <= csreg_r;
				csreg_w <= 0;
				mo_reg <= mo_tmp;
				mi_reg <= 0;
			end
			3'b000:
			begin
				csreg_r <= csreg_r;
				csreg_w <= {1'b1,csreg_w[18:1]};
				mo_reg <= {1'b0,mo_reg[15:1]};
				mi_reg <= 0;
			end
			3'b111:
			begin
				csreg_r <= 0;
				csreg_w <= csreg_w;
				mo_reg <= mo_tmp;
				mi_reg <= 0;
			end
			3'b001:
			begin
				csreg_r <= {1'b1,csreg_r[27:1]};
				csreg_w <= csreg_w;
				mo_reg <= {1'b0,mo_reg[15:1]};
				mi_reg <= {miso,mi_reg[7:1]};
			end
			default:
			begin
				csreg_r <= csreg_r;
				csreg_w <= csreg_w;
				mo_reg <= mo_reg;
				mi_reg <= mi_reg;
			end
		endcase
	end
end


always@(posedge clk_spi or negedge res_n)
begin
	if (~res_n) {mi_tmp,valid_mi_f,cs_tmp} <= {8'h00,1'b0,1'b1};
	else
	begin
		cs_tmp <= cs_n;
		casex ({r_w,cs_rise,valid_mi_f,ready_mi_f})
			4'b110x: {mi_tmp,valid_mi_f} <= {mi_reg,1'b1};
			4'bxx11: {mi_tmp,valid_mi_f} <= {mi_tmp,1'b0};
			default: {mi_tmp,valid_mi_f} <= {mi_tmp,valid_mi_f};
		endcase
	end
end

endmodule