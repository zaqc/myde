module eth_top(
	input					rst_n,
	
	output	[8:0]		LEDG,
	
	input					eth_rx_clk,
	input		[7:0]		eth_rx_data,
	input					eth_rx_data_vl,
	
	input					eth_tx_clk,
	output	[7:0]		eth_tx_data,
	output				eth_tx_data_en
);

// ===========================================================================
// INPUT & OUTPUT
// ===========================================================================
wire			[7:0]		arp_tx_data;
wire						arp_tx_data_en;
wire			[7:0]		udp_tx_data;
wire						udp_tx_data_en;

always_comb
	if(state == SEND_UDP_PACKET) begin
		eth_tx_data = udp_tx_data;
		eth_tx_data_en = udp_tx_data_en;
	end 
	else begin
		eth_tx_data = arp_tx_data;
		eth_tx_data_en = arp_tx_data_en;
	end
	
// ===========================================================================
// PARAMETERS
// ===========================================================================
parameter	[47:0]	self_mac = {8'h00, 8'h23, 8'h54, 8'h3C, 8'h47, 8'h1B};
parameter	[31:0]	self_ip = {8'h0A, 8'h00, 8'h00, 8'h21};
parameter	[31:0]	target_ip = {8'h0A, 8'h00, 8'h00, 8'h02};

// ===========================================================================
// SEND ARP PACKET
// ===========================================================================
wire			[1:0]		arp_oper;		// operation type Req/Resp
wire			[47:0]	arp_dst_mac;	// Ethernet DST_MAC
wire			[31:0]	arp_tg_ip;		// ARP Target IP
wire			[47:0]	arp_tg_mac;		// ARP Target MAC
reg			[47:0]	rqstr_mac;		// ARP Requester MAC
reg			[31:0]	rqstr_ip;		// ARP Requester IP
always_comb begin
	arp_oper = 2'd0;
	arp_dst_mac = 48'd0;
	arp_tg_mac = 48'd0;
	arp_tg_ip = 32'd0;
	case(state)
		SEND_ARP_REQUEST: begin
			arp_oper = 2'd1;
			arp_dst_mac = 48'hFFFFFFFFFFFF;	// Broadcast ARP Reqest
			arp_tg_mac = 48'h000000000000; 	// Unknown MAC
			arp_tg_ip = target_ip;
		end
		SEND_ARP_RESPONSE: begin
			arp_oper = 2'd2;
			arp_dst_mac = rqstr_mac;
			arp_tg_mac = rqstr_mac;
			arp_tg_ip = rqstr_ip;
		end
	endcase
end
	
arp_send arp_send_unit1(
	.rst_n(rst_n),
	.clk(eth_tx_clk),
	
	.o_data(arp_tx_data),
	.o_tx_en(arp_tx_data_en),
	
	.i_dst_mac(arp_dst_mac),
	.i_src_mac(self_mac),
	
	.i_operation(arp_oper),
	.i_SHA(self_mac),
	.i_SPA(self_ip),
	.i_THA(arp_tg_mac),
	.i_TPA(arp_tg_ip),
	
	.i_enable(1'b1)
);
 
// ===========================================================================
// ETHERNET RECEIVE ANY PACKETS
// ===========================================================================
wire			[47:0]	recv_src_mac;
wire			[47:0]	recv_dst_mac;
wire			[1:0]		recv_pkt_type;
wire			[47:0]	recv_SHA;
wire			[31:0]	recv_SPA;
wire			[47:0]	recv_THA;
wire			[31:0]	recv_TPA;

eth_recv eth_recv_unit1(
	.rst_n(rst_n),
	.clk(eth_rx_clk),
	
	.i_data(eth_rx_data),
	.i_data_vl(eth_rx_data_vl),
	
	.i_self_mac(self_mac),
	.i_self_ip(self_ip),
	
	.o_dst_mac(recv_dst_mac),
	.o_src_mac(recv_src_mac),
	
	.o_pkt_type(recv_pkt_type),
	
	.o_SHA(recv_SHA),	// reaceive param's from ARP Reqest
	.o_SPA(recv_SPA),
	.o_THA(recv_THA),
	.o_TPA(recv_TPA)
);

reg		[1:0]		prev_pkt_type;
always_ff @ (posedge eth_rx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		prev_pkt_type <= 2'd0;
	else
		prev_pkt_type <= recv_pkt_type;
		
reg			[47:0]	save_SHA;
reg			[31:0]	save_SPA;
reg			[47:0]	save_THA;
reg			[31:0]	save_TPA;

reg			[8:0]		pkt_cntr;
assign LEDG[0] = pkt_cntr[0];

always_ff @ (posedge eth_rx_clk)
	if(prev_pkt_type != recv_pkt_type) begin
		case(recv_pkt_type)
			eth_recv.ARP_REQ: begin
			end			
			eth_recv.ARP_RESP: begin
				pkt_cntr <= pkt_cntr + 9'd1;
			end
		endcase
	end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
enum logic [3:0] {
	NONE = 4'd0,
	STATE_IDLE = 4'd1,
	SEND_ARP_REQUEST = 4'd2,
	WAIT_ARP_RESPONSE = 4'd3,
	SEND_ARP_RESPONSE = 4'd4,
	SEND_UDP_PACKET = 4'd5
} state, new_state;

always_ff @  (posedge eth_rx_clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= NONE;
	else
		state <= new_state;
end

always_comb begin
	new_state = state;
	case(state)
		NONE: if(1'b1 == rst_n) new_state = SEND_ARP_REQUEST;
		
		SEND_ARP_REQUEST: begin
		end
		
		WAIT_ARP_RESPONSE: begin
			if(recv_pkt_type != prev_pkt_type && recv_pkt_type == eth_recv.ARP_RESP) new_state = state;
		end
		
		SEND_ARP_RESPONSE: begin
		end
		
		SEND_UDP_PACKET: begin
		end
		
		default: begin
		end
	endcase
end

endmodule
