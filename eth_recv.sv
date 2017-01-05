module eth_recv(
	input					rst_n,
	input					clk,
	
	input		[7:0]		i_data,		// Stream from PHY
	input					i_data_vl,
	
	input		[47:0]	i_self_mac,	// Default param
	input		[31:0]	i_self_ip,
	
	output	[47:0]	o_dst_mac,	// Ethernet Frame
	output	[47:0]	o_src_mac,
	
	output	[15:0]	o_src_port,	// UDP
	output	[15:0]	o_dst_port,
	
	output	[10:0]	o_udp_len,
	
	output	[47:0]	o_SHA,		// ARP Params (or UDP depends of o_pkt_type)
	output	[31:0]	o_SPA,
	output	[47:0]	o_THA,
	output	[31:0]	o_TPA,

	output	[1:0]		o_pkt_type,	// NONE=0, ARP_REQ=1, ARP_RESP=2 or UDP=3
	
	output	[7:0]		o_data,		// stream for UDP data
	output				o_data_vl
	
);

assign o_data_vl = (state > RECV_PREAMBLE && state <= CRC32_ERR) ? 1'b1 : 1'b0;
assign o_data = (state == RECV_CRC32) ? crc32[7:0] : 
	((state == CRC32_ERR || state == CRC32_OK) ? { 6'd0, pkt_type } : state);

// ===========================================================================
// Output PACKET TYPE
// ===========================================================================
enum logic [1:0] {
	NONE = 2'b00,
	ARP_REQ = 2'b01,
	ARP_RESP = 2'b10,
	UDP = 2'b11
} pkt_type;

assign o_pkt_type = pkt_type;

always_ff @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		pkt_type <= NONE;
	else
		if(new_state != state) begin
			if(new_state == CRC32_OK) begin
				case(ether_type)
					16'h0800: pkt_type <= UDP;
					16'h0806: if(ARP_OPER == 16'd1) pkt_type <= ARP_REQ; 
									else if(ARP_OPER == 16'd2) pkt_type <= ARP_RESP; 
									else pkt_type <= NONE;
					default: pkt_type <= NONE;
				endcase
			end
			else
				pkt_type <= NONE;
		end
		else
			pkt_type <= NONE;
end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
enum logic [4:0] {
	STATE_IDLE = 5'd0,
	RECV_PREAMBLE = 5'd1,
	RECV_DST_MAC = 5'd2,
	RECV_SRC_MAC = 5'd3,
	RECV_ETHER_TYPE = 5'd4,
	
	RECV_ARP_HEADER = 5'd5,
	RECV_ARP_SHA = 5'd6,
	RECV_ARP_SPA = 5'd7,
	RECV_ARP_THA = 5'd8,
	RECV_ARP_TPA = 5'd9,
	RECV_ARP_DUMMY = 5'd10,

	RECV_IP_HDR1 = 5'd11,
	RECV_IP_HDR2 = 5'd12,
	RECV_IP_HDR3 = 5'd13,
	RECV_IP_SRC_IP = 5'd14,
	RECV_IP_DST_IP = 5'd15,
	RECV_UDP_SRC_PORT = 5'd16,
	RECV_UDP_DST_PORT = 5'd17,
	RECV_UDP_LEN = 5'd18,
	RECV_UDP_CRC = 5'd19,
	
	RECV_UDP_DATA = 5'd20,

	RECV_CRC32 = 5'd28,
	
	CRC32_OK = 5'd29,
	CRC32_ERR = 5'd30
} state, new_state;

//----------------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= STATE_IDLE;
	else
		state <= new_state;
end

//----------------------------------------------------------------------------

always_comb begin
	new_state = state;
	
	case(state)
		STATE_IDLE: if(rst_n == 1'b1) new_state = RECV_PREAMBLE;
		RECV_PREAMBLE: if(rx == 64'h55555555555555d5) new_state = RECV_DST_MAC;
		RECV_DST_MAC: if(rx_count == 11'd6) new_state = RECV_SRC_MAC;
		RECV_SRC_MAC: if(rx_count == 11'd6) new_state = RECV_ETHER_TYPE;
		RECV_ETHER_TYPE: if(rx_count == 11'd2) 
			case(rx[15:0])
				16'h0800: new_state = RECV_IP_HDR1;
				16'h0806: new_state = RECV_ARP_HEADER;
				default: new_state = STATE_IDLE;
			endcase
			
		RECV_IP_HDR1: if(rx_count == 11'd4) new_state = RECV_IP_HDR2;
		RECV_IP_HDR2: if(rx_count == 11'd4) new_state = RECV_IP_HDR3;
		RECV_IP_HDR3: if(rx_count == 11'd4) 
			case(ip_pkt_type)
				8'd17: new_state = RECV_IP_SRC_IP; // UDP
				default: new_state = STATE_IDLE;
			endcase
		RECV_IP_SRC_IP: if(rx_count == 11'd4) new_state = RECV_IP_DST_IP;
		RECV_IP_DST_IP: if(rx_count == 11'd4) new_state = RECV_UDP_SRC_PORT;
		RECV_UDP_SRC_PORT: if(rx_count == 11'd2) new_state = RECV_UDP_DST_PORT;
		RECV_UDP_DST_PORT: if(rx_count == 11'd2) new_state = RECV_UDP_LEN;
		RECV_UDP_LEN: if(rx_count == 11'd2) new_state = RECV_UDP_CRC;
		RECV_UDP_CRC: if(rx_count == 11'd2) new_state = RECV_UDP_DATA;
		RECV_UDP_DATA: if(rx_count == udp_len[10:0] - 11'd8) new_state = RECV_CRC32;

		RECV_ARP_HEADER: if(rx_count == 11'd8)  new_state = RECV_ARP_SHA;
		RECV_ARP_SHA: if(rx_count == 11'd6)  new_state = RECV_ARP_SPA;
		RECV_ARP_SPA: if(rx_count == 11'd4)  new_state = RECV_ARP_THA;
		RECV_ARP_THA: if(rx_count == 11'd6)  new_state = RECV_ARP_TPA;
		RECV_ARP_TPA: if(rx_count == 11'd4)  new_state = RECV_ARP_DUMMY;
		RECV_ARP_DUMMY: if(rx_count == 11'd18)  new_state = RECV_CRC32;
		
		RECV_CRC32: if(rx_count == 11'd4)  new_state = (crc_ok == 8'hFF) ? CRC32_ERR : CRC32_OK;
		CRC32_OK: new_state = RECV_PREAMBLE;
		CRC32_ERR: new_state = RECV_PREAMBLE;
	endcase
end

// ===========================================================================
// DATA RECEIVE & SHIFT
// ===========================================================================
reg		[63:0]		rx;
reg		[10:0]		rx_count;

//----------------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		rx_count <= 11'd0;
	else
		if(state == STATE_IDLE)
			rx_count <= 11'd0;
		else
			if(new_state != state) 
				rx_count <= (1'b1 == i_data_vl) ? 11'd1 : 11'd0;
			else
				if(1'b1 == i_data_vl)
					rx_count <= rx_count + 11'd1;
				
//----------------------------------------------------------------------------
				
always_ff @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		rx <= 64'd0;
	else
		if(state == STATE_IDLE)
			rx <= 64'd0;
		else
			if(1'b1 == i_data_vl)
					rx <= {rx[55:0], i_data};

// ===========================================================================
// STORE DATA TO REG'S
// ===========================================================================
// -------------------- Ethernet Frame ------------------------
reg		[47:0]		dst_mac;				// DST MAC (sender)
assign o_dst_mac = dst_mac;
reg		[47:0]		src_mac;				// SRC MAC (receiver/target)
assign o_src_mac = src_mac;
reg		[15:0]		ether_type;			// Ether Type (ARP/UDP)

// --------------------------- IPv4 ---------------------------
reg		[31:0]		ip_hdr1;				// IPv4 HEADER 1
wire		[3:0]			ip_header_ver;		// 4 - for IPv4
wire		[3:0]			ip_header_size;	// size in 32bit word's (min=5)
wire		[7:0]			ip_DSCP_ECN;		// ?
wire		[15:0]		ip_pkt_size;
assign ip_header_ver = ip_hdr1[31:28];
assign ip_header_size = ip_hdr1[27:24];
assign ip_DSCP_ECN = ip_hdr1[23:16];
assign ip_pkt_size = ip_hdr1[15:0];
wire		[15:0]		ip_len;
assign ip_len = ip_pkt_size - 16'h001C;// 16'h002E size of UDP packet

reg		[31:0]		ip_hdr2;				// IPv4 HEADER 2
wire		[15:0]		ip_pkt_id;			// pkt id
wire		[2:0]			ip_pkt_flags;		// pkt flags
wire		[12:0]		ip_pkt_offset;		// pkt offset
assign ip_pkt_id = ip_hdr2[31:16];
assign ip_pkt_flags = ip_hdr2[15:13];
assign ip_pkt_offset = ip_hdr2[12:0];

reg		[31:0]		ip_hdr3;				// IPv4 HEADER 3
wire		[7:0]			ip_pkt_TTL;			// pkt TTL
wire		[7:0]			ip_pkt_type;		// pkt UDP == 17
wire		[15:0]		ip_pkt_CRC;			// pkt flags
assign ip_pkt_TTL = ip_hdr3[31:24];
assign ip_pkt_type = ip_hdr3[23:16];
assign ip_pkt_CRC = ip_hdr3[15:0];

// --------------------- Calc Header CRC ----------------------
wire		[31:0]		tmp_crc;
assign tmp_crc = ip_hdr1[31:16] + ip_hdr1[15:0] +
	ip_hdr2[31:16] + ip_hdr2[15:0] + ip_hdr3[31:16] + // ip_hdr3[15:0] +
	ip_src_ip[31:16] + ip_src_ip[15:0] + ip_dst_ip[31:16] + ip_dst_ip[15:0];
wire		[15:0]		ip_hdr_calc_CRC;
assign ip_hdr_calc_CRC = ~(tmp_crc[31:16] + tmp_crc[15:0]);


reg		[31:0]		ip_src_ip;			// IPv4 SRC IP
reg		[31:0]		ip_dst_ip;			// IPv4 DST IP

// --------------------------- UDP ---------------------------
reg		[15:0]		udp_src_port;	
assign o_src_port = udp_src_port;
reg		[15:0]		udp_dst_port;
assign o_dst_port = udp_dst_port;
reg		[15:0]		udp_len;
assign o_udp_len = udp_len;
reg		[15:0]		udp_crc;

// --------------------------- ARP ---------------------------

reg 		[63:0]		arp_header;			// Header for ARP Req/Resp
wire		[15:0]		ARP_HTYPE;			// 16'h0001
wire		[15:0]		ARP_PTYPE;			// 16'h0800
wire		[7:0]			ARP_HLEN;			// 8'h06	MAC size
wire		[7:0]			ARP_PLEN;			// 8'h04 IP Address size for IPv4
wire		[15:0]		ARP_OPER;
assign ARP_HTYPE = arp_header[63:48];
assign ARP_PTYPE = arp_header[47:32];
assign ARP_HLEN = arp_header[31:24];
assign ARP_PLEN = arp_header[23:16];
assign ARP_OPER = arp_header[15:0];		// 1-Req 2-Resp

reg		[47:0]		arp_SHA;			
assign o_SHA = arp_SHA;
reg		[31:0]		arp_SPA;
assign o_SPA = arp_SPA;
reg		[47:0]		arp_THA;
assign o_THA = arp_THA;
reg		[31:0]		arp_TPA;
assign o_TPA = arp_TPA;

//----------------------------------------------------------------------------

always_ff @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n) begin
	end
	else begin
		if(new_state != state) begin
			case(state)
				RECV_DST_MAC: dst_mac <= rx[47:0];
				RECV_SRC_MAC: src_mac <= rx[47:0];
				RECV_ETHER_TYPE: ether_type <= rx[15:0];
				
				RECV_IP_HDR1: ip_hdr1 <= rx[31:0];
				RECV_IP_HDR2: ip_hdr2 <= rx[31:0];
				RECV_IP_HDR3: ip_hdr3 <= rx[31:0];
				RECV_IP_SRC_IP: ip_src_ip <= rx[31:0];
				RECV_IP_DST_IP: ip_dst_ip <= rx[31:0];
				RECV_UDP_SRC_PORT: udp_src_port <= rx[15:0];
				RECV_UDP_DST_PORT: udp_dst_port <= rx[15:0];
				RECV_UDP_LEN: udp_len <= rx[15:0];
				RECV_UDP_CRC: udp_crc <= rx[15:0];
				
				RECV_ARP_HEADER: arp_header <= rx[63:0];
				RECV_ARP_SHA: arp_SHA <= rx[47:0];
				RECV_ARP_SPA: arp_SPA <= rx[31:0];
				RECV_ARP_THA: arp_THA <= rx[47:0];
				RECV_ARP_TPA: arp_TPA <= rx[31:0];
			endcase
		end
	end
end

// ===========================================================================
//	Calc CRC 32
// ===========================================================================
reg		[0:0]			calc_crc_flag;
//assign o_crc_flag = calc_crc_flag;
always_ff @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		calc_crc_flag <= 1'b0;
	else
		if(state == STATE_IDLE)
			calc_crc_flag <= 1'b0;
		else
			if(state == RECV_PREAMBLE && rx[55:0] == 56'h55555555555555 && i_data == 8'hD5 && i_data_vl == 1'b1)
				calc_crc_flag <= 1'b1;
			else if((i_data_vl == 1'b1) &&	
						((state == RECV_ARP_DUMMY && rx_count == 11'd17) || 
						 (state == RECV_UDP_DATA && rx_count == udp_len[10:0] - 11'd8)))
				calc_crc_flag <= 1'b0;
end

//----------------------------------------------------------------------------

reg		[7:0]			crc_ok;
reg		[23:0]		crc_save;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		crc_ok <= 1'b0;
	else 
	if(new_state != state && new_state == RECV_CRC32) begin
		if(i_data_vl == 1'b1) begin
			if(i_data == crc32[7:0]) begin
				crc_ok <= 8'h00;
				crc_save <= crc32[31:8];
			end
			else
				crc_ok <= 8'hFF;
		end
	end
	else if(new_state == state && state == RECV_CRC32) begin
		if(i_data_vl == 1'b1) begin
			if(i_data == crc_save[7:0] && crc_ok != 8'hFF) begin
				crc_ok <= crc_ok + 8'd1;
				crc_save <= {8'd0, crc_save[23:8]};
			end
			else
				crc_ok <= 8'hFF;
		end
	end
end

//----------------------------------------------------------------------------

wire		[31:0]		crc32;
calc_crc32 u_crc32(
	.clk(clk),
	.rst_n(rst_n),
	.i_calc(calc_crc_flag),
	.i_data(i_data),
	.i_vl(i_data_vl),
	.o_crc32(crc32)
);

endmodule
