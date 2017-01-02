module eth_top(
	input					rst_n,
	input					clk,
	
	input					i_rx_clk,
	output	[7:0]		o_phy_data,
	output				o_phy_tx_en,	// tx data enable
	
	input					i_tx_clk,
	input		[7:0]		i_phy_data,
	input					i_phy_rx_dv,	// rx data valid
	
	input		[7:0]		i_data,
	input		[9:0]		i_data_len,
	input					i_snd_start,	// 0 -> 1 to start
	output				o_snd_rdy
);

parameter	[47:0]	hostMAC = {8'h00, 8'h23, 8'h54, 8'h3C, 8'h47, 8'h1B};	// it's my MAC address
parameter	[31:0]	hostIP = {8'h0A, 8'h00, 8'h00, 8'h21};						// it's my IP address
parameter	[47:0]	broadcastMAC = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};	// Broadcast MAC address

parameter	[31:0]	clientIP = {8'h0A, 8'h00, 8'h00, 8'h02};	// default target IP

reg			[47:0]	reqMAC;	// MAC of ARP request sender
reg			[31:0]	reqIP;	// IP of ARP request sender

wire			[47:0]	tgMAC = (state == send_arp_response) ? reqMAC : broadcastMAC;
wire			[47:0]	tgIP = (state == send_arp_response) ? reqIP : clientIP;
wire			[1:0]		arp_pkt_type = (state == send_arp_request) ? 2'd1 : (state == send_arp_response) ? 2'd2 : 2'd0;

/*
arp_send u_arp_send(
	.rst_n(rst_n),
	.clk(clk),
	.o_pkt_type(arp_pkt_type),
	.o_arp_SHA(hostMAC),
	.o_arp_SPA(hostIP),
	.o_arp_THA(tdMAC),
	.o_arp_TPA(tgIP)
);
*/

parameter	[4:0]		state_none = 5'd0;

parameter	[4:0]		init_param = 5'd1;

parameter	[4:0]		send_arp_request = 5'd2;
parameter	[4:0]		send_arp_response = 5'd3;
parameter	[4:0]		wait_arp_answer = 5'd4;
parameter	[4:0]		send_udp_packet = 5'd5;
parameter	[4:0]		send_arp_answer = 5'd6;

reg			[0:0]		arp_request_flag;		// flag Set when ARP request received
reg			[47:0]	own_mac;
reg			[31:0]	own_ip;
// ===========================================================================
// INIT
// ===========================================================================
initial begin
	arp_request_flag = 1'b0;
end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
reg		[4:0]			state;
reg		[4:0]			new_state;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= state_none;
	else
		state <= new_state;
end

always @ * begin
	new_state = state;
	
	case(state)
		state_none:
			;
	endcase
end

// ===========================================================================
// Receiver
// ===========================================================================

// on start
// SEND: ARP Request (MyMAC, MyIP, bcMAC. TgIP)
// RECV: wait for ARP Responce
// SEND: UDP Packet
// RECV: UDP Command

// RECV: ARP Request
// if(arpReq.MAC == myMAC || (arpReq.MAC == broadcast.MAC && arpReq.IP == myIP)) send arp Resp

//pkt_recv U_pkt_recv(
//	.rst_n(rst_n),
//	.clk(i_rx_clk),
//);

// ===========================================================================
// Sender
// ===========================================================================


endmodule
