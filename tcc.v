module tcc(
	CLOCK_50, 
	
	LEDG,
	LEDR,
	
	KEY,
	
	UART_RXD,
	UART_TXD,
	
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

input					UART_RXD;
output				UART_TXD;

output				ENET0_GTX_CLK;

output				ENET0_RST_N;

input					ENET0_RX_CLK;
input		[3:0]		ENET0_RX_DATA;
input					ENET0_RX_DV;

input					ENET0_TX_CLK;
output	[3:0]		ENET0_TX_DATA;
output				ENET0_TX_EN;

inout		[35:0]	GPIO;

assign ENET0_RST_N = KEY[0];

assign LEDG[8] = cntr[24];

wire					tx_en;
wire		[7:0]		tx_out_data;
tx_ddio tx(
	.datain_h({tx_en, tx_out_data[3:0]}),
	.datain_l({tx_en, tx_out_data[7:4]}),
	.outclock(pll_clk_tx), //pll_clk_tx),
	.dataout({ENET0_TX_EN, ENET0_TX_DATA[3:0]})
);

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

wire		[7:0]		in_dbg_data;
wire					in_dbg_data_vl;
//eth_recv_arp eth_recv_arp_U1(
//	.rst_n(KEY[0]),
//	.clk(pll_clk_rx),
//	
//	.i_data(rx_in_data),
//	.i_data_vl(rx_dv),
//	
//	.o_dbg_data_vl(in_dbg_data_vl),
//	.o_dbg_data(in_dbg_data)
//);

wire		[1:0]		pkt_type;
wire		[47:0]	SHA;
wire		[31:0]	SPA;
wire		[47:0]	THA;
wire		[31:0]	TPA;

eth_recv eth_recv_U1(
	.rst_n(KEY[0]),
	.clk(pll_clk_rx),
	
	.i_data(rx_in_data),
	.i_data_vl(rx_dv),
	
	.i_self_mac(src_mac),
	.i_self_ip(src_ip),
	
	.o_data_vl(in_dbg_data_vl),
	.o_data(in_dbg_data),
	
	.o_pkt_type(pkt_type),
	.o_SHA(SHA),
	.o_SPA(SPA),
	.o_THA(THA),
	.o_TPA(TPA)
);


reg		[0:0]		prev_rx_dv;
always @ (posedge pll_clk_rx)
	prev_rx_dv <= rx_dv;

trace_sys nios_TraceUnit(
	.clk_clk(CLOCK_50),
	
	.pin_rxd(GPIO[7]),
	.pin_txd(GPIO[9]),
	
	.fifo_in_clk_clk(pll_clk_rx),
	
	.fifo_in_data(in_dbg_data),	//rx_in_data),
	.fifo_in_valid(in_dbg_data_vl), //rx_dv),
	
	.fifo_in_startofpacket(1'b0),	// rx_dv != prev_rx_dv && prev_rx_dv == 1'b1),
	.fifo_in_endofpacket(1'b0)		// rx_dv != prev_rx_dv && prev_rx_dv == 1'b0)
	
/*
		input  wire       pin_rxd,               //     pin.rxd
		output wire       pin_txd,               //        .txd
		input  wire [7:0] fifo_in_data,          // fifo_in.data
		input  wire       fifo_in_valid,         //        .valid
		output wire       fifo_in_ready,         //        .ready
		input  wire       fifo_in_startofpacket, //        .startofpacket
		input  wire       fifo_in_endofpacket    //        .endofpacket
*/
);

reg		[31:0]	cntr;
always @ (posedge pll_clk_rx) begin
	if(rx_dv == 1'b1)
		cntr <= cntr + 1;
end

assign LEDG[7:0] = cntr[7:0];

/*
pack_gen pg_U(
	.i_clk(pll_clk_rx),
	.i_rst(~KEY[0]),
	.o_data(tx_out_data),
	.TX_EN(tx_en)
);
*/

//reg [0:0] send_udp_pkt;
//initial send_udp_pkt = 1'b1;
//
//wire udp_enable;
//assign udp_enable = send_udp_pkt;
//wire udp_ready;
//
//wire arp_enable;
//assign arp_enable = ~send_udp_pkt;
//wire arp_ready;
//
//always @ (posedge clk) begin
//	if(udp_ready == 1'b1 && send_udp_pkt == 1'b1)
//		send_udp_pkt = 1'b0;
//	else 
//		if(arp_ready == 1'b0 && send_udp_pkt == 1'b0)
//			send_udp_pkt = 1'b1;
//end
//
udp_pkt_gen gen_U(
	.clk(pll_clk_tx), //pll_gtx_clk),
	.rst_n(KEY[0]),
	.o_data(tx_out_data),
	.tx_en(tx_en)
	
//	.i_enable(udp_enable),
//	.o_ready(udp_ready)
);

parameter	[47:0]	src_mac = {8'h00, 8'h23, 8'h54, 8'h3C, 8'h47, 8'h1B};
parameter	[47:0]	dst_mac = {8'h0c, 8'h54, 8'ha5, 8'h31, 8'h24, 8'h85};
parameter	[31:0]	src_ip = {8'h0A, 8'h00, 8'h00, 8'h21};	//{8'hC0, 8'hA8, 8'h4D, 8'h21};
parameter	[31:0]	dst_ip = {8'h0A, 8'h00, 8'h00, 8'h02};

//arp_send arp_send_U1(
//	.clk(pll_clk_tx), //pll_gtx_clk),
//	.rst_n(KEY[0]),
//	.o_data(tx_out_data),
//	.o_tx_en(tx_en),
//	
//	.i_dst_mac(48'hFFFFFFFFFFFF),
//	.i_src_mac(src_mac),
//	
//	.i_operation(2'b01),
//	.i_SHA(src_mac),
//	.i_SPA(src_ip),
//	.i_THA(48'd0),
//	.i_TPA(dst_ip),
//	
//	.i_enable(arp_enable),
//	.o_ready(arp_ready)
//);


reg	[15:0]	pkt_counter;
always @ (posedge tx_en)
	if(pkt_counter[14:0] == 15'd0)
		pkt_counter <= 16'd1;
	else
		pkt_counter <= {pkt_counter[14:0], 1'b0};
	
assign LEDR[15:0] = pkt_counter;

wire					rx_clk;
assign rx_clk = ENET0_RX_CLK;

wire					pll_clk_rx;
wire					pll_clk_tx;
wire					pll_gtx_clk;
//assign ENET0_TX_CLK = pll_clk_tx;

pll pll_90(
	.inclk0(rx_clk),
	.c0(pll_clk_rx),		// 0
	.c1(pll_clk_tx),		// 90
	.c2(pll_gtx_clk)		// 180
);

assign ENET0_GTX_CLK = pll_gtx_clk;

endmodule
