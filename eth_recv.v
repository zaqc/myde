module eth_recv_arp(
	input					clk,
	input					rst_n,
	input					i_data_vl,
	input		[7:0]		i_data,
	
	output	[7:0]		o_state,
	output	[47:0]	o_dst_mac,
	output	[47:0]	o_src_mac,
	output	[15:0]	o_frame_type,
	output	[31:0]	o_dst_ip,
	output	[31:0]	o_src_ip,
	output	[7:0]		o_rx_count,
	
	output	[47:0]	o_arp_SHA,
	output	[31:0]	o_arp_SPA,
	output	[47:0]	o_arp_THA,
	output	[31:0]	o_arp_TPA,
	
	output	[31:0]	o_crc32,
	
	output				o_crc_flag,
	
	output	[7:0]		o_dbg_data,
	output				o_dbg_data_vl
);

assign o_state = state;
assign o_dst_mac = dst_mac;
assign o_src_mac = src_mac;
assign o_frame_type = frame_type;
assign o_dst_ip = dst_ip;
assign o_src_ip = src_ip;
assign o_rx_count = rxb_count;

assign o_arp_SHA = arp_SHA;
assign o_arp_SPA = arp_SPA;
assign o_arp_THA = arp_THA;
assign o_arp_TPA = arp_TPA;

assign o_crc32 = crc32;

parameter		[4:0]			eth_none = 5'd0;
parameter		[4:0]			eth_preamble = 5'd1;
parameter		[4:0]			eth_sfd = 5'd2;
parameter		[4:0]			eth_dst_mac = 5'd3;
parameter		[4:0]			eth_src_mac = 5'd4;
parameter		[4:0]			eth_frame_type = 5'd5;
parameter		[4:0]			eth_src_ip = 5'd6;
parameter		[4:0]			eth_dst_ip = 5'd7;
parameter		[4:0]			eth_data_stream = 5'd8;
parameter		[4:0]			eth_crc32 = 5'd9;

parameter		[4:0]			eth_crc_ok = 5'd17;
parameter		[4:0]			eth_crc_err = 5'd18;

parameter		[4:0]			eth_paket_end =  5'd10;		// receive data to full packet length 46

// ARP parameter's
parameter		[4:0]			eth_arp_header	= 5'd12;
parameter		[4:0]			eth_arp_SHA = 5'd13;
parameter		[4:0]			eth_arp_SPA = 5'd14;
parameter		[4:0]			eth_arp_THA = 5'd15;
parameter		[4:0]			eth_arp_TPA = 5'd16;

// UDP parameter's

// ===========================================================================
// DEBUG
// ===========================================================================
reg		[7:0]			dbg_data;
assign o_dbg_data = (state == eth_crc32) ? crc_ok[7:0] : state;
reg		[0:0]			dbg_data_vl;
assign o_dbg_data_vl = (state != eth_preamble) && (state != eth_none) ? 1'b1 : 1'b0;

always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n) begin
		dbg_data <= 8'd0;
		dbg_data_vl <= 1'b0;
	end
	else begin
		if(i_data_vl == 1'b1) begin
			dbg_data <= i_data;
			dbg_data_vl <= 1'b1;
		end
		else
			dbg_data_vl <= 1'b0;
	end
end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
reg		[4:0]			state;
reg		[4:0]			new_state;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= eth_none;
	else
		if(i_data_vl == 1'b1 || new_state == eth_crc_err || 
				new_state == eth_crc_ok || new_state == eth_preamble || 
				new_state == eth_none)
			state <= new_state;
end

always @ (*) begin
	new_state = state;
	
	case(state)
		eth_none:
			if(rst_n == 1'b1)
				new_state = eth_preamble;
		
		eth_preamble:
			if(ds == 64'h55555555555555d5)
				new_state = eth_dst_mac;

		eth_sfd:
			if(rxb_count == 8'd1) begin
				if(ds[7:0] == 8'hD5)
					new_state = eth_dst_mac;
				else
					new_state = eth_none;
			end
		
		eth_dst_mac:
			if(rxb_count == 8'd6)
				new_state = eth_src_mac;

		eth_src_mac:
			if(rxb_count == 8'd6)
				new_state = eth_frame_type;

		eth_frame_type:
			if(rxb_count == 8'd2)
				if(ds[15:0] == 16'h0806)
					new_state = eth_arp_header;
				else //if(ds[15:0] == 16'h0800)
					new_state = eth_src_ip;
					
		// ARP Request decode
		eth_arp_header:
			if(rxb_count == 8'd8)
				new_state = eth_arp_SHA;
				
		eth_arp_SHA:
			if(rxb_count == 8'd6)
				new_state = eth_arp_SPA;
				
		eth_arp_SPA:
			if(rxb_count == 8'd4)
				new_state = eth_arp_THA;
				
		eth_arp_THA:
			if(rxb_count == 8'd6)
				new_state = eth_arp_TPA;
				
		eth_arp_TPA:
			if(rxb_count == 8'd4)
				new_state = eth_paket_end;
				
		eth_paket_end:
			if(rxb_count == 8'd18)
				new_state = eth_crc32;
			
		eth_crc32:
			if(rxb_count == 8'd4) begin
				new_state = eth_crc_ok;
				if(crc_ok == 8'h03)
					new_state = eth_crc_ok;
				else
					new_state = eth_crc_err;
			end
				
		eth_crc_ok:
			//if(rxb_count == 8'd1)			// CRC 32 OK
				new_state = eth_preamble;
				
		eth_crc_err:
			//if(rxb_count == 8'd1)			// CRC 32 ERROR
				new_state = eth_preamble;
				
		eth_src_ip:
			if(rxb_count == 8'd4)
				new_state = eth_dst_ip;
				
		eth_dst_ip:
			if(rxb_count == 8'd4)
				new_state = eth_crc32;
								
		eth_data_stream:
			;
						
		default: 
			;
			
	endcase
end

// ===========================================================================
//	Receives byte's counter
// ===========================================================================
reg		[7:0]		rxb_count;
always @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		rxb_count <= 8'd0;
	else
		if(new_state != state)
			if(i_data_vl == 1'b1)
				rxb_count <= 8'd1;
			else
				rxb_count <= 8'd0;
		else
			if(i_data_vl == 1'b1)
				rxb_count <= rxb_count + 8'd1;

// ===========================================================================
//	MAC getting
// ===========================================================================
reg		[63:0]		ds;
always @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		ds <= 64'd0;
	else if(i_data_vl == 1'b1)
		ds <= {ds[55:0], i_data};
		
// ===========================================================================
//	Store received value
// ===========================================================================
reg		[47:0]		src_mac;
reg		[47:0]		dst_mac;
reg		[31:0]		src_ip;
reg		[31:0]		dst_ip;
reg		[31:0]		frame_type;

reg		[15:0]		arp_HTYPE;
reg		[15:0]		arp_PTYPE;
reg		[7:0]			arp_HLEN;
reg		[7:0]			arp_PLEN;
reg		[15:0]		arp_OPER;
reg		[47:0]		arp_SHA;		// MAC
reg		[31:0]		arp_SPA;		// IP
reg		[47:0]		arp_THA;		// MAC
reg		[31:0]		arp_TPA;		// IP

always @ (posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0) begin
	end
	else if(state != new_state) begin
		case(state)
			eth_dst_mac: dst_mac <= ds[47:0];
			eth_src_mac: src_mac <= ds[47:0];
			eth_dst_ip: dst_ip <= ds[31:0];
			eth_src_ip: src_ip <= ds[31:0];
			eth_frame_type: frame_type <= ds[15:0];
			eth_arp_header: 
				begin
					arp_HTYPE <= ds[63:48];
					arp_PTYPE <= ds[47:32];
					arp_HLEN <= ds[31:24];
					arp_PLEN <= ds[23:16];
					arp_OPER <= ds[15:0];
				end
			eth_arp_SHA: arp_SHA <= ds[47:0];
			eth_arp_SPA: arp_SPA <= ds[31:0];
			eth_arp_THA: arp_THA <= ds[47:0];
			eth_arp_TPA: arp_TPA <= ds[47:0];
				
			default: ;
		endcase
	end
end
		
// ===========================================================================
//	Calc CRC 32
// ===========================================================================
reg		[0:0]			calc_crc_flag;
assign o_crc_flag = calc_crc_flag;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		calc_crc_flag <= 1'b0;
	else 
		if(state == eth_preamble && ds[55:0] == 56'h55555555555555 && i_data == 8'hD5 && i_data_vl == 1'b1)
			calc_crc_flag <= 1'b1;
		else if(state == eth_paket_end && rxb_count == 8'd17)
			calc_crc_flag <= 1'b0;
end

reg		[7:0]			crc_ok;
reg		[23:0]		crc_save;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		crc_ok <= 1'b0;
	else 
	if(new_state != state && new_state == eth_crc32) begin
		if(i_data_vl == 1'b1) begin
			if(i_data == crc32[7:0]) begin
				crc_ok <= 8'h00;
				crc_save <= crc32[31:8];
			end
			else
				crc_ok <= 8'hFF;
		end
	end
	else if(new_state == state && state == eth_crc32) begin
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
