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
	case(state)
		SEND_UDP_PACKET: begin
			eth_tx_data = udp_tx_data;
			eth_tx_data_en = udp_tx_data_en;
		end 
		SEND_ARP_REQUEST, SEND_ARP_RESPONSE, SEND_ARP_PERIODIC: begin
			eth_tx_data = arp_tx_data;
			eth_tx_data_en = arp_tx_data_en;
		end
		default: begin
			eth_tx_data = 8'h00;
			eth_tx_data_en = 1'b0;
		end
	endcase
	
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
			arp_dst_mac = save_SHA; // rqstr_mac;
			arp_tg_mac = save_SHA;	// rqstr_mac;
			arp_tg_ip = save_SPA;	// rqstr_ip;
		end
		SEND_ARP_PERIODIC: begin
			arp_oper = 2'd1;
			arp_dst_mac = 48'hFFFFFFFFFFFF; 
			arp_tg_mac = 48'h000000000000; 	// Unknown MAC
			arp_tg_ip = target_ip;
		end
	endcase
end

wire						arp_sender_ready;
	
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
	
	.i_enable((state == START_SENDING_ARP) ? 1'b1 : 1'b0),
	.o_ready(arp_sender_ready)
);
// ===========================================================================
// DEBUG
// ===========================================================================

reg			[0:0]		prev_arp_sender_ready;
always_ff @ (posedge eth_tx_clk) 
	prev_arp_sender_ready <= arp_sender_ready;

reg			[3:0]		arp_rdy_cntr;
always_ff @ (posedge eth_tx_clk) 
	if(arp_sender_ready != prev_arp_sender_ready)
		arp_rdy_cntr <= arp_rdy_cntr + 4'd1;
		
assign LEDG[8:5] = arp_rdy_cntr;

// ===========================================================================
// SEND UDP PACKET
// ===========================================================================

wire						udp_sender_ready;

udp_pkt_gen udp_pkt_gen_unit1(
	.rst_n(rst_n),
	.clk(eth_tx_clk),
	
	.o_data(udp_tx_data),
	.tx_en(udp_tx_data_en),
	
	.o_ready(udp_sender_ready)
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
		prev_pkt_type <= eth_recv.NONE;
	else
		prev_pkt_type <= recv_pkt_type;
		
reg			[47:0]	save_SHA;
reg			[31:0]	save_SPA;
reg			[47:0]	save_THA;
reg			[31:0]	save_TPA;

reg			[8:0]		arp_resp_cntr;
reg			[8:0]		arp_req_cntr;
reg			[8:0]		udp_cntr;
assign LEDG[0] = arp_resp_cntr[0];
assign LEDG[1] = arp_req_cntr[0];
assign LEDG[2] = udp_cntr[0];

always_ff @ (posedge eth_rx_clk or negedge rst_n)
	if(1'b0 == rst_n) begin
		save_SHA <= 48'd0;
		save_SPA <= 32'd0;
		save_THA <= 48'd0;
		save_TPA <= 32'd0;
		arp_resp_cntr <= 9'd0;
		arp_req_cntr <= 9'd0;
	end
	else 
		if(prev_pkt_type != recv_pkt_type) begin
			case(recv_pkt_type)
				eth_recv.UDP: udp_cntr <= udp_cntr + 9'd1;
				eth_recv.ARP_REQ: begin
					if(/*recv_THA == self_mac &&*/ recv_TPA == self_ip) begin
						arp_req_cntr <= arp_req_cntr + 9'd1;
					end
				end
				eth_recv.ARP_RESP: begin
					if(recv_THA == self_mac && recv_TPA == self_ip) begin
						save_SHA <= recv_SHA;
						save_SPA <= recv_SPA;
						save_THA <= recv_THA;
						save_TPA <= recv_TPA;
						arp_resp_cntr <= arp_resp_cntr + 9'd1;
					end
				end
			endcase
		end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
enum logic [3:0] {
	NONE = 4'd0,
	STATE_IDLE = 4'd1,
	START_SENDING_ARP = 4'd2,
	SEND_ARP_REQUEST = 4'd3,
	WAIT_ARP_RESPONSE = 4'd4,
	SEND_ARP_RESPONSE = 4'd5,
	SEND_ARP_PERIODIC = 4'd6,
	SEND_UDP_PACKET = 4'd7
} state, new_state;

//----------------------------------------------------------------------------

always_ff @  (posedge eth_tx_clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= NONE;
	else
		state <= new_state;
end

//----------------------------------------------------------------------------

reg			[8:0]		prev_arp_resp_cntr;
always_ff @  (posedge eth_tx_clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		prev_arp_resp_cntr <= 9'd0;
	else
		if(state == SEND_UDP_PACKET)
			prev_arp_resp_cntr <= arp_resp_cntr;
end

always_comb begin
	new_state = state;
	case(state)
		NONE: if(1'b1 == rst_n && arp_sender_ready == 1'b1) new_state = START_SENDING_ARP;
		
		START_SENDING_ARP: 
			if(arp_sender_ready == 1'b0) 
				new_state = SEND_ARP_REQUEST;
		
		SEND_ARP_REQUEST:
			if(arp_sender_ready == 1'b1) 
				new_state = WAIT_ARP_RESPONSE;
		
		WAIT_ARP_RESPONSE: begin
			if(prev_arp_resp_cntr != arp_resp_cntr
					&& save_THA == self_mac && save_TPA == self_ip)
				new_state = SEND_UDP_PACKET;
			else
				if(arp_wait_counter == 32'd125000000)		// ~ 1 sec TimeOut on 125 MHz
					new_state = START_SENDING_ARP;
		end
		
		SEND_ARP_RESPONSE: begin
			if(arp_sender_ready == 1'b1) 
				new_state = SEND_UDP_PACKET;
		end
		
		SEND_UDP_PACKET: begin
			if(udp_sender_ready == 1'b1) begin
				if(arp_req_flag == 1'b1)
					new_state = SEND_ARP_RESPONSE;
				else
					if(arp_req_period != 32'd500000000)	// ~ 4 sec
						new_state = SEND_ARP_PERIODIC;
			end
		end
		
		SEND_ARP_PERIODIC: begin
			if(arp_sender_ready == 1'b1) 
				new_state = SEND_UDP_PACKET;
		end
	endcase
end

//----------------------------------------------------------------------------

reg			[31:0]		arp_wait_counter;
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		arp_wait_counter <= 32'd0;
	else
		if(state == WAIT_ARP_RESPONSE) begin
			if(arp_wait_counter != 32'd125000000)
				arp_wait_counter <= arp_wait_counter + 32'd1;
		end 
		else
			arp_wait_counter <= 32'd0;
		
//----------------------------------------------------------------------------

reg			[0:0]			arp_req_flag;		// arp ask trigger
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		arp_req_flag <= 1'b0;
	else
		if(new_state != state && new_state == SEND_ARP_RESPONSE)
			arp_req_flag <= 1'b0;
		else
			if(recv_pkt_type != prev_pkt_type && recv_pkt_type == eth_recv.ARP_REQ)
				arp_req_flag <= 1'b1;

//----------------------------------------------------------------------------
				
reg			[31:0]		arp_req_period;	// periodic ARP request
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		arp_req_period <= 32'd0;
	else
		if(state != SEND_UDP_PACKET)
			arp_req_period <= 32'd0;
		else
			if(arp_req_period != 32'd500000000)	// ~4 sec
				arp_req_period <= arp_req_period + 32'd1;

//----------------------------------------------------------------------------

endmodule
