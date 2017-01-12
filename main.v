module main(
	CLOCK_50, 
	
	LEDG,
	LEDR,
	
	KEY,
	
//	UART_RXD,
//	UART_TXD,
	
	ENET0_GTX_CLK,	// 125 MHz out to PHY
	
	ENET0_RST_N,
	
	ENET0_RX_CLK,	// 125 MHz input
	ENET0_RX_DATA,
	ENET0_RX_DV,
	
	ENET0_TX_CLK,
	ENET0_TX_DATA,
	ENET0_TX_EN,
	
	GPIO
);

input					CLOCK_50;

output	[8:0]		LEDG;
output	[17:0]	LEDR;

input		[3:0]		KEY;

//input					UART_RXD;
//output				UART_TXD;

output				ENET0_GTX_CLK;

output				ENET0_RST_N;

input					ENET0_RX_CLK;
input		[3:0]		ENET0_RX_DATA;
input					ENET0_RX_DV;

input					ENET0_TX_CLK;
output	[3:0]		ENET0_TX_DATA;
output				ENET0_TX_EN;

inout		[35:0]	GPIO;

// ===========================================================================
//	AWAIBA
// ===========================================================================
wire		[12:0]	awb_data;
assign awb_data = GPIO[22:10];
wire					awb_sync_ready;
assign awb_sync_ready = GPIO[26];
wire					awb_sync;
assign GPIO[6] = awb_sync;
wire					awb_clk;
assign awb_clk = GPIO[23];
wire					awb_rdy;
assign GPIO[24] = awb_rdy;
wire					awb_vld;
assign awb_vld = GPIO[25];

//wire					awb_rst_n;
assign GPIO[9] = (KEY[0] == 1'b0) ? 1'b0 : 1'b1; //awb_rst_n;
//assign awb_rst_n = ;

assign awb_sync = send_sync;

wire					send_sync;
wire		[12:0]	send_data;
wire					send_rd;

fifo_awaiba fifo_awaiba_unit(
	.clk_data(awb_clk),
	.data(awb_data),
	.ready(awb_rdy),
	.valid(awb_vld),
	
	.clk(pll_clk_tx),	// 125 MHz
	.reset_n(rst_n),
	.sync(send_sync),			// input
	.data_out(send_data),	// output
	//.valid_out(),
	.ready_sys(send_rd)		// input
);

wire					rst_n;
assign rst_n = KEY[0];
reg		[15:0]	clk_div;
always @ (posedge pll_clk_rx or negedge rst_n) 
	if(1'b0 == rst_n)
		clk_div <= 16'd0;
	else
		clk_div <= {clk_div[14:0], ~clk_div[15]};
		
		
wire							spi_miso;
wire							spi_mosi;
wire							spi_clk;
wire							spi_cs_n;
wire							spi_abn_cdp;
assign spi_miso = GPIO[1];
assign GPIO[3] = spi_mosi;
assign GPIO[5] = spi_clk;
assign GPIO[0] = spi_cs_n;
assign GPIO[4] = spi_abn_cdp;

wire			[32:0]		cmd_data;
wire							cmd_vld;
wire							cmd_rdy;

spi_awaiba spi_awaiba_unit(
	.clk_spi(clk_div[15]),
	.clk(pll_clk_rx),
	.res_n(rst_n),
	.data_mo(cmd_data[15:0]),
	.valid_mo(cmd_vld),
	.ready_mo(cmd_rdy),
	.address(cmd_data[16]),
	
	.mosi(spi_mosi),
	.miso(spi_miso),
	.sclk(spi_clk),
	.cs_n(spi_cs_n),
	.spi_abn_cdp(spi_abn_cdp)
);

//reg		[31:0]		awb_cnt;
//always @ (posedge awb_sync) awb_cnt <= awb_cnt + 32'd1;
//assign LEDR = awb_cnt[17:0];

//----------------------------------------------------------------------------

assign ENET0_RST_N = KEY[0];

//----------------------------------------------------------------------------

wire					tx_en;
wire		[7:0]		tx_out_data;
tx_ddio tx(
	.datain_h({tx_en, tx_out_data[3:0]}),
	.datain_l({tx_en, tx_out_data[7:4]}),
	.outclock(pll_clk_tx), //pll_clk_tx),
	.dataout({ENET0_TX_EN, ENET0_TX_DATA[3:0]})
);

//----------------------------------------------------------------------------

wire					rx_dv_l;
wire					rx_dv_h;
wire					rx_dv;
assign rx_dv = rx_dv_h & rx_dv_l;
wire		[7:0]		rx_in_data;
rx_ddio rx(
	.datain({ENET0_RX_DV, ENET0_RX_DATA[3:0]}),
	.inclock(pll_clk_rx),
	.dataout_h({rx_dv_h, rx_in_data[7:4]}),
	.dataout_l({rx_dv_l, rx_in_data[3:0]})
);

//----------------------------------------------------------------------------

wire					rx_clk;
assign rx_clk = ENET0_RX_CLK;
wire					pll_clk_rx;
wire					pll_clk_tx;
wire					pll_gtx_clk;
pll pll_90(
	.inclk0(rx_clk),
	.c0(pll_clk_rx),		// 0
	.c1(pll_clk_tx),		// 90
	.c2(pll_gtx_clk)		// 180
);

assign ENET0_GTX_CLK = pll_gtx_clk;

//----------------------------------------------------------------------------

eth_top eth_top_unit(
	.rst_n(rst_n),
	
	.LEDG(LEDG),
	.LEDR(LEDR),
	
	.eth_rx_clk(pll_clk_rx),
	.eth_rx_data(rx_in_data),
	.eth_rx_data_vl(rx_dv),
	
	.eth_tx_clk(pll_clk_tx),
	.eth_tx_data(tx_out_data),
	.eth_tx_data_en(tx_en),
	
	.o_send_sync(send_sync),
	.i_send_data(send_data[7:0]),
	.o_send_rd(send_rd),
	
	.o_cmd_data(cmd_data),
	.o_cmd_vld(cmd_vld),
	.i_cmd_rdy(cmd_rdy)
);

endmodule
