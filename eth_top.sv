module eth_top(
	input					rst_n,

	output	[8:0]		LEDG,
	output	[17:0]	LEDR,

	input					eth_rx_clk,
	input		[7:0]		eth_rx_data,
	input					eth_rx_data_vl,

	input					eth_tx_clk,
	output	[7:0]		eth_tx_data,
	output				eth_tx_data_en,
	
	output				o_send_sync,
	input		[7:0]		i_send_data,
	output				o_send_rd,
	
	output	[31:0]	o_cmd_data,
	output				o_cmd_vld,
	input					i_cmd_rdy

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
		SEND_UDP_PACKET,
		send_udp: begin
			eth_tx_data = udp_tx_data;
			eth_tx_data_en = udp_tx_data_en;
		end 
		SEND_ARP_REQUEST, 
		SEND_ARP_RESPONSE,
		SEND_ARP_PERIODIC: begin
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
parameter	[31:0]	self_ip = {8'd192, 8'd168, 8'd1, 8'd131};
parameter	[31:0]	target_ip = {8'd192, 8'd168, 8'd1, 8'd211};
//parameter	[31:0]	self_ip = {8'h0A, 8'h00, 8'h00, 8'h21};
//parameter	[31:0]	target_ip = {8'h0A, 8'h00, 8'h00, 8'h02};

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
	case(state)
		START_ARP_REQUEST, SEND_ARP_REQUEST: begin
			arp_oper = 2'd1;
			arp_dst_mac = 48'hFFFFFFFFFFFF;	// Broadcast ARP Reqest
			arp_tg_mac = 48'h000000000000; 	// Unknown MAC
			arp_tg_ip = target_ip;
		end
		START_ARP_RESPONSE, SEND_ARP_RESPONSE: begin
			arp_oper = 2'd2;
			arp_dst_mac = save_SHA; // rqstr_mac;
			arp_tg_mac = save_SHA;	// rqstr_mac;
			arp_tg_ip = save_SPA;	// rqstr_ip;
		end
		START_ARP_PERIODIC, SEND_ARP_PERIODIC: begin
			arp_oper = 2'd1;
			arp_dst_mac = 48'hFFFFFFFFFFFF; 
			arp_tg_mac = 48'h000000000000; 	// Unknown MAC
			arp_tg_ip = target_ip;
		end
		default: begin
			arp_oper = 2'd0;
			arp_dst_mac = 48'd0;
			arp_tg_mac = 48'd0;
			arp_tg_ip = 32'd0;
		end
	endcase
end

reg			[0:0]		arp_sender_ready;
wire						ase;
assign ase = (state == START_ARP_REQUEST || 
					state == START_ARP_RESPONSE || 
					state == START_ARP_PERIODIC) ? 1'b1 : 1'b0;

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
	
	.i_enable(ase),
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
	if(arp_sender_ready != prev_arp_sender_ready && arp_sender_ready == 1'b1)
		arp_rdy_cntr <= arp_rdy_cntr + 4'd1;
		
assign LEDG[8:5] = arp_rdy_cntr;

// ===========================================================================
// SEND UDP PACKET
// ===========================================================================

reg			[0:0]		udp_sender_ready;
wire						usen;
assign usen = (state == START_UDP_PACKET || state == start_udp) ? 1'b1 : 1'b0;

//reg			[7:0]			dd_cnt;
//always_ff @ (posedge eth_tx_clk) dd_cnt <= dd_cnt + 8'd1;

udp_send udp_send_unit(
	.rst_n(rst_n),
	.clk(eth_tx_clk),
	
	.o_data(udp_tx_data),
	.o_tx_en(udp_tx_data_en),
	
	.i_dst_mac(save_SHA), //pegatron_mac),
	.i_src_mac(self_mac),
	
	.i_src_ip(self_ip),
	.i_dst_ip(target_ip),
	
	.i_src_port(50000),
	.i_dst_port(50016),
	
	.i_in_data(i_send_data), // dd_cnt),
	.o_rd(o_send_rd),
	.i_data_len(16'd4160),
	
	.i_enable(usen),
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

wire			[15:0]	recv_src_port;
wire			[15:0]	recv_dst_port;
wire			[31:0]	recv_udp_cmd;

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
	.o_TPA(recv_TPA),
	
	.o_src_port(recv_src_port),	// UDP
	.o_dst_port(recv_dst_port),
	.o_udp_cmd(recv_udp_cmd)
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

reg			[31:0]	udp_cmd;
assign LEDR = udp_cmd[17:0];
reg			[0:0]		udp_cmd_latch;

assign o_cmd_data = udp_cmd;
assign o_cmd_vld = udp_cmd_latch;

always_ff @ (posedge eth_rx_clk or negedge rst_n)
	if(1'b0 == rst_n) begin
		save_SHA <= 48'd0;
		save_SPA <= 32'd0;
		save_THA <= 48'd0;
		save_TPA <= 32'd0;
		arp_resp_cntr <= 9'd0;
		arp_req_cntr <= 9'd0;
		udp_cmd_latch <= 1'b0;
	end
	else 
		if(prev_pkt_type != recv_pkt_type) begin
			case(recv_pkt_type)
				eth_recv.UDP: begin
					udp_cntr <= udp_cntr + 9'd1;
					if(recv_src_port == 16'd50016 && recv_dst_port == 16'd17584) begin
						udp_cmd <= recv_udp_cmd;
						udp_cmd_latch <= 1'b1;
					end
				end
				eth_recv.ARP_REQ: begin
					if(recv_TPA == self_ip) begin
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
				default:
					udp_cmd_latch <= 1'b0;
			endcase
		end
		else
			if(i_cmd_rdy == 1'b1)
				udp_cmd_latch <= 1'b0;
		
		
// ===========================================================================
// SYNC FLAG
// ===========================================================================
reg			[0:0]		sync_flag;
reg			[8:0]		sf_cnt;
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n) begin
		sync_flag <= 1'b0;
		sf_cnt <= 8'd0;
	end
	else
		if(sync_flag == 1'b0) begin
			if(new_state != state && state == SEND_UDP_PACKET) begin
				sync_flag <= 1'b1;
				sf_cnt <= 8'h00;
			end
		end
		else 
			if(sf_cnt != 8'hFF)
				sf_cnt <= sf_cnt + 8'h01;
			else
				sync_flag = 1'b0;
				
assign o_send_sync = ~sync_flag;

// ===========================================================================
// STATE MACHINE
// ===========================================================================
enum logic [3:0] {
	NONE = 4'd0,
	STATE_IDLE = 4'd1,
	START_ARP_REQUEST = 4'd2,
	SEND_ARP_REQUEST = 4'd3,
	WAIT_ARP_RESPONSE = 4'd4,
	START_ARP_RESPONSE = 4'd5,
	SEND_ARP_RESPONSE = 4'd6,
	START_ARP_PERIODIC = 4'd7,
	SEND_ARP_PERIODIC = 4'd8,
	START_UDP_PACKET = 4'd9,
	SEND_UDP_PACKET = 4'd10,
	IDLE_MODE = 4'd11,
	start_udp = 4'd12,
	send_udp = 4'd13
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
		if(state == IDLE_MODE)
			prev_arp_resp_cntr <= cc_arp_resp_cntr;
end

reg			[8:0]		cc_arp_resp_cntr;
always_ff @  (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		cc_arp_resp_cntr <= 9'd0;
	else
		cc_arp_resp_cntr <= arp_resp_cntr;

//----------------------------------------------------------------------------

always_comb begin
	new_state = state;
	case(state)
		NONE: if(1'b1 == rst_n && arp_sender_ready == 1'b1) new_state = START_ARP_REQUEST;
		
		START_ARP_REQUEST: if(arp_sender_ready == 1'b0) new_state = SEND_ARP_REQUEST;		
		SEND_ARP_REQUEST: if(arp_sender_ready == 1'b1) new_state = WAIT_ARP_RESPONSE;
		WAIT_ARP_RESPONSE: 
			if(prev_arp_resp_cntr != cc_arp_resp_cntr)
				new_state = IDLE_MODE;
			else
				if(arp_wait_counter == 32'd125000000 && arp_sender_ready == 1'b1)		// ~ 1 sec TimeOut on 125 MHz
					new_state = START_ARP_REQUEST;
					
		START_ARP_RESPONSE: if(arp_sender_ready == 1'b0) new_state = SEND_ARP_RESPONSE;
		SEND_ARP_RESPONSE: if(arp_sender_ready == 1'b1) new_state = IDLE_MODE;
		
		START_ARP_PERIODIC: if(arp_sender_ready == 1'b0) new_state = SEND_ARP_PERIODIC;
		SEND_ARP_PERIODIC: if(arp_sender_ready == 1'b1) new_state = IDLE_MODE;
		
		START_UDP_PACKET: if(udp_sender_ready == 1'b0) new_state = SEND_UDP_PACKET;
		SEND_UDP_PACKET: if(udp_sender_ready == 1'b1) new_state = IDLE_MODE; //start_udp;
		
		start_udp: if(udp_sender_ready == 1'b0) new_state = send_udp;
		send_udp: if(udp_sender_ready == 1'b1) new_state = IDLE_MODE;
		
		IDLE_MODE: begin
			if(idle_mode_counter == 32'd250000 && udp_sender_ready == 1'b1)
				new_state = START_UDP_PACKET;
			else
				if(prev_arp_req_flag != cc_arp_req_flag && arp_sender_ready == 1'b1)
					new_state = START_ARP_RESPONSE;
				else
					if(arp_req_period == 32'd1000000000 && arp_sender_ready == 1'b1)	// ~ 8 sec
						new_state = START_ARP_PERIODIC;
		end
	endcase
end

//----------------------------------------------------------------------------

reg			[0:0]			udp_start;
always_ff @ (posedge eth_tx_clk)
	if(new_state != state && new_state == START_UDP_PACKET)
		udp_start = ~udp_start;
assign LEDG[3] = udp_start;

reg			[0:0]			udp_send_flag;
always_ff @ (posedge eth_tx_clk)
	if(new_state != state && new_state == SEND_UDP_PACKET)
		udp_send_flag = ~udp_send_flag;
assign LEDG[4] = udp_send_flag;


reg			[31:0]		idle_mode_counter;
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		idle_mode_counter <= 32'd0;
	else
	begin
		if(state == IDLE_MODE) begin
			if(idle_mode_counter != 32'd250000)	// 1 sec
				idle_mode_counter <= idle_mode_counter + 32'd1;
		end
		else
			idle_mode_counter <= 32'd0;
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

reg			[0:0]			prev_arp_req_flag;	// arp ask trigger
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		prev_arp_req_flag <= 1'b0;
	else
		if(new_state != state && state == START_ARP_RESPONSE)
			prev_arp_req_flag <= cc_arp_req_flag;
		
reg			[0:0]			cc_arp_req_flag;
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		cc_arp_req_flag <= 1'b0;
	else
		cc_arp_req_flag <= arp_req_flag;

reg			[0:0]			arp_req_flag;
always_ff @ (posedge eth_rx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		arp_req_flag <= 1'b0;
	else
		if(recv_pkt_type != prev_pkt_type && recv_pkt_type == eth_recv.ARP_REQ)
			arp_req_flag <= ~arp_req_flag;

//----------------------------------------------------------------------------
				
reg			[31:0]		arp_req_period;		// periodic ARP request
always_ff @ (posedge eth_tx_clk or negedge rst_n)
	if(1'b0 == rst_n)
		arp_req_period <= 32'd0;
	else
		if(new_state != state && (new_state == START_ARP_PERIODIC || 
				new_state == SEND_ARP_PERIODIC || state == START_ARP_RESPONSE || 
				state == SEND_ARP_RESPONSE))
			arp_req_period <= 32'd0;
		else
			if(arp_req_period != 32'd1000000000)
				arp_req_period <= arp_req_period + 32'd1;

//----------------------------------------------------------------------------

endmodule
