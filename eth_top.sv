module ethernet_top(
	input					rst_n,
	input					clk,
	
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
parameter	[31:0]	self_ip = {8'h0A, 8'h00, 8'h00, 8'h21};	//{8'hC0, 8'hA8, 8'h4D, 8'h21};
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
always_comb
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
	
arp_send arp_send_unit1(
	.rst_n(rst_n),
	.clk(eth_tx_clk),
	
	.o_data(arp_tx_data),
	.o_data_en(arp_tx_data_en),
	
	.i_dst_mac(arp_dst_mac),
	.i_src_mac(self_mac),
	
	.i_operation(arp_oper),
	.i_SHA(self_mac),
	.i_SPA(self_ip),
	.i_THA(arp_tg_mac),
	.i_TPA(arp_tg_ip)
);
 
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

always_ff @  (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= NONE;
	else
		state <= new_state;
end

always_comb begin
	new_state = state;
	case(state)
		SEND_ARP_REQUEST: begin
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
