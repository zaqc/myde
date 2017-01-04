module udp_pkt_gen(
	input					clk,
	input					rst_n,
	output	[7:0]		o_data,
	output reg			tx_en,

	output 	[31:0]	crc_out,
	
	input					i_enable,	// start send frame
	output				o_ready		// set when frame transfer complite
);

// assign o_ready = (new_state == eth_preamble) ? 1'b1 : 1'b0;

// ===========================================================================
// input array
// ===========================================================================
reg	[7:0]		in_data[0:1500];
reg	[15:0]	in_data_len;
reg	[15:0]	in_data_cntr;
integer i;
initial begin
	in_data_len = 16'd1040;	// default: 18
	in_data[0] = 8'h01;
	in_data[1] = 8'h02;
	in_data[2] = 8'h03;
	in_data[3] = 8'h04;
	in_data[4] = 8'h01;
	in_data[5] = 8'h01;
	in_data[6] = 8'h01;
	in_data[7] = 8'h01;
	in_data[8] = 8'h01;
	in_data[9] = 8'h01;
	in_data[10] = 8'h01;
	in_data[11] = 8'h01;
	in_data[12] = 8'h01;
	in_data[13] = 8'h01;
	in_data[14] = 8'h12;
	in_data[15] = 8'h34;
	in_data[16] = 8'h56;
	in_data[17] = 8'h78;
	for(i = 18; i < 1500; i = i + 1) in_data[i] = i;
end

// ===========================================================================
// IP/UDP parameters & header
// ===========================================================================
// input parameter's
//parameter	[47:0]	dst_mac = {8'hD8, 8'hD3, 8'h85, 8'h26, 8'hC5, 8'h78};
parameter	[47:0]	src_mac = {8'h00, 8'h23, 8'h54, 8'h3C, 8'h47, 8'h1B};
parameter	[47:0]	dst_mac = {8'h0c, 8'h54, 8'ha5, 8'h31, 8'h24, 8'h85};

parameter	[31:0]	src_ip = {8'h0A, 8'h00, 8'h00, 8'h21};	//{8'hC0, 8'hA8, 8'h4D, 8'h21};
parameter	[31:0]	dst_ip = {8'h0A, 8'h00, 8'h00, 8'h02};
parameter	[15:0]	src_port = {8'hC3, 8'h50};
parameter	[15:0]	dst_port = {8'hC3, 8'h60};

parameter	[3:0]		ip_header_ver = 4'h4;		// 4 - for IPv4
parameter	[3:0]		ip_header_size = 4'h5;		// size in 32bit word's
parameter	[7:0]		ip_DSCP_ECN = 8'h00;			// ?
wire			[15:0]	ip_pkt_size;
assign  ip_pkt_size = in_data_len + 16'h001C;	// 16'h002E size of UDP packet
wire			[31:0]	ip_hdr1;
assign ip_hdr1 = {ip_header_ver, ip_header_size, ip_DSCP_ECN, ip_pkt_size};

parameter	[15:0]	ip_pkt_id = 16'h0;			// pkt id
parameter	[2:0]		ip_pkt_flags = 3'h0;			// pkt flags
reg			[12:0]	ip_pkt_offset = 13'h0;		// pkt offset
wire			[31:0]	ip_hdr2;
assign ip_hdr2 = {ip_pkt_id, ip_pkt_flags, ip_pkt_offset};

parameter	[7:0]		ip_pkt_TTL = 8'hC8;			// pkt TTL
parameter	[7:0]		ip_pkt_type = 8'd17;			// pkt UDP == 17
wire			[15:0]	ip_pkt_CRC;						// pkt flags
wire			[31:0]	tmp_crc;
assign tmp_crc = ip_hdr1[31:16] + ip_hdr1[15:0] +
	ip_hdr2[31:16] + ip_hdr2[15:0] + ip_hdr3[31:16] + // ip_hdr3[15:0] +
	ip_src[31:16] + ip_src[15:0] + ip_dst[31:16] + ip_dst[15:0];
assign ip_pkt_CRC = ~(tmp_crc[31:16] + tmp_crc[15:0]);
wire			[31:0]	ip_hdr3;	
assign ip_hdr3 = {ip_pkt_TTL, ip_pkt_type, ip_pkt_CRC};

wire			[31:0]	ip_src;
assign ip_src = src_ip;

wire			[31:0]	ip_dst;
assign ip_dst = dst_ip;

reg			[15:0]	udp_length;
reg			[15:0]	udp_crc;


// SM state's
parameter	[4:0]		eth_none = 5'd0;			// none
parameter	[4:0]		eth_idle = 5'd1;
parameter	[4:0]		eth_preamble = 5'd2;		// send 0x55 seven times
parameter	[4:0]		eth_sdf = 5'd3;				// send end of preamble 0x5D
parameter	[4:0]		eth_dst_mac = 5'd4;		// send destination MAC Address
parameter	[4:0]		eth_src_mac = 5'd5;		// send self MAC Address
parameter	[4:0]		eth_type = 5'd6;			// send 0x0800
parameter	[4:0]		eth_hdr1 = 5'd7;
parameter	[4:0]		eth_hdr2 = 5'd8;
parameter	[4:0]		eth_hdr3 = 5'd9;
parameter	[4:0]		eth_src_ip = 5'd10;
parameter	[4:0]		eth_dst_ip = 5'd11;
parameter	[4:0]		eth_udp_src_dst_port = 5'd12;
parameter	[4:0]		eth_udp_len_crc = 5'd13;
parameter	[4:0]		eth_wait = 5'd14;
parameter	[4:0]		eth_data_stream = 5'd15;
parameter	[4:0]		eth_crc32 = 5'd16;
parameter	[4:0]		eth_done = 5'd17;
parameter	[4:0]		enable_rise = 5'd18;

// ===========================================================================
// DATA GENERATOR
// ===========================================================================
reg			[7:0]		bc;
always @ (posedge clk) bc <= bc + 8'd1;

// ===========================================================================
// SHIFTER & SENDER
// ===========================================================================
reg	[47:0]	data_ts;
reg	[3:0]		cnt_ts;
reg	[47:0]	send_data;
assign o_data = (state == eth_crc32) ? crc32[7:0] : ((state == eth_data_stream) ? bc /* in_data[in_data_cntr] */ : send_data[47:40]);
reg	[3:0]	send_cnt;
reg	[3:0]	send_len;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n) begin
		send_data <= 48'd0;
		send_cnt <= 4'd0;
		send_len <= 4'd0;
	end
	else begin
		if(state != new_state) begin
			send_data <= data_ts;
			send_cnt <= 4'd0;
			if(cnt_ts > 4'd0)
				send_len <= cnt_ts - 4'd1;
			else
				send_len <= 4'd0;
			
			if(new_state == eth_udp_len_crc) begin
				udp_length <= in_data_len + 16'd8; //14'h001A;
				udp_crc <= 16'd0;
			end
				
			if(new_state == eth_data_stream)
					in_data_cntr <= 16'd1;
					
//			if(new_state == eth_crc32) begin
//				send_data <= { crc32, 16'd0 };
//				send_len <= 4'd3;
//			end
		end
		else begin
			if(state == eth_data_stream) begin
				in_data_cntr <= in_data_cntr + 16'd1;
			end else
				if(send_len != 4'd0 && send_cnt != send_len) begin
					send_cnt <= send_cnt + 4'd1;
					send_data <= {send_data[40:0], 8'hFF};
				end
		end
	end
end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
reg		[4:0]			state;
reg		[4:0]			new_state;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= 5'd0;
	else
		state <= new_state;
end

always @ (*) begin
	new_state = state;

	case(state)
		eth_none: if(1'b0 != rst_n) new_state = eth_idle;
			
		eth_idle:
			if(1'b1 != i_enable) begin
				new_state = eth_preamble;
				data_ts = 48'd0;
				cnt_ts = 4'd0;
			end
			
		eth_preamble:
			if(send_cnt == send_len) begin
				new_state = eth_sdf;
				data_ts = 48'h555555555555;
				cnt_ts = 4'd6;
			end
			
		eth_sdf:
			if(send_cnt == send_len) begin
				new_state = eth_dst_mac;
				data_ts = 48'h55D500000000;
				cnt_ts = 4'd2;
			end
		
		eth_dst_mac: 
			if(send_cnt == send_len) begin
				new_state = eth_src_mac;
				data_ts = dst_mac;
				cnt_ts = 4'd6;
			end
		
		eth_src_mac:
			if(send_cnt == send_len) begin
				new_state = eth_type;
				data_ts = src_mac;
				cnt_ts = 4'd6;
			end
			
		eth_type:
			if(send_cnt == send_len) begin
				new_state = eth_hdr1;
				data_ts = 48'h0800FFFFFFFF;
				cnt_ts = 4'd2;
			end
			
		eth_hdr1:
			if(send_cnt == send_len) begin
				new_state = eth_hdr2;
				data_ts = {ip_hdr1, 16'd0};
				cnt_ts = 4'd4;
			end

		eth_hdr2:
			if(send_cnt == send_len) begin
				new_state = eth_hdr3;
				data_ts = {ip_hdr2, 16'd0};
				cnt_ts = 4'd4;
			end

		eth_hdr3:
			if(send_cnt == send_len) begin
				new_state = eth_src_ip;
				data_ts = {ip_hdr3, 16'd0};
				cnt_ts = 4'd4;
			end

		eth_src_ip:
			if(send_cnt == send_len) begin
				new_state = eth_dst_ip;
				data_ts = {ip_src, 16'd0};
				cnt_ts = 4'd4;
			end
			
		eth_dst_ip:
			if(send_cnt == send_len) begin
				new_state = eth_udp_src_dst_port;
				data_ts = {ip_dst, 16'd0};
				cnt_ts = 4'd4;
			end

		eth_udp_src_dst_port:
			if(send_cnt == send_len) begin
				new_state = eth_udp_len_crc;
				data_ts = {src_port, dst_port, 16'd0};
				cnt_ts = 4'd4;
			end
			
		eth_udp_len_crc:
			if(send_cnt == send_len) begin
				new_state = eth_wait;
				data_ts = {udp_length, udp_crc, 16'd0};
				cnt_ts = 4'd4;
			end
			
		eth_wait:
			if(send_cnt == send_len)
				new_state = eth_data_stream;
				
		eth_data_stream:
			if(in_data_len == in_data_cntr) begin
				new_state = eth_crc32;
				data_ts = {crc32[7:0], crc32[15:8], crc32[23:16], crc32[31:24], 16'd0};
				cnt_ts = 4'd4;
			end
			
			
		eth_crc32:
			if(send_cnt == send_len) begin
				new_state = eth_done;
				data_ts = 48'h000000000000;
				cnt_ts = 4'd4;
			end
			
		eth_done:
			if(pause_cntr == 32'h07735940) begin	// 1 sec
				new_state = enable_rise;
				data_ts = 48'h000000000000;
				cnt_ts = 4'd6;
			end
			
		enable_rise: if(1'b0 == i_enable) new_state = eth_idle;
	endcase
end

// ===========================================================================
// READY
// ===========================================================================

reg		[0:0]			rdy;
always @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		rdy <= 1'b0;
	else
		if(new_state != state) begin
			if(new_state == eth_idle)
				rdy <= 1'b1;
			else
				if(new_state == eth_preamble)
					rdy <= 1'b0;
		end
		
assign o_ready = rdy;
		
// ===========================================================================
// Pkt pause counter
// ===========================================================================
reg		[31:0]		pause_cntr;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		pause_cntr <= 32'd0;
	else begin
		if((new_state != state) && (new_state == eth_done)) 
			pause_cntr <= 32'd0;
		else 
			pause_cntr <= pause_cntr + 32'd1;
	end
end

// ===========================================================================
// TX Enable
// ===========================================================================
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		tx_en <= 1'b0;
	else 
		if(new_state != state) begin
			if(new_state == eth_sdf)
				tx_en <= 1'b1;
			else 
				if(new_state == eth_done)
					tx_en <= 1'b0;
		end
end

// ===========================================================================
// CRC 32
// ===========================================================================
reg		[0:0]			calc_crc_flag;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		calc_crc_flag <= 1'b0;
	else 
		if(new_state != state) begin
			if(new_state == eth_src_mac)
				calc_crc_flag <= 1'b1;
			else 
				if(new_state == eth_crc32)
					calc_crc_flag <= 1'b0;
		end
end

wire		[31:0]		crc32;
calc_crc32 u_crc32(
	.rst_n(rst_n),
	.clk(clk),
	.i_calc(calc_crc_flag),
	.i_vl(tx_en),
	.i_data(o_data),
	.o_crc32(crc32)
);

assign crc_out = crc32;
	
endmodule

