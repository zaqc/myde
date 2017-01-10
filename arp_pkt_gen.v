module arp_pkt_gen(
	input					clk,
	input					rst_n,
	output	[7:0]		o_data,
	output reg			o_tx_en,
	
	input 	[47:0]	i_dst_mac,
	input		[47:0]	i_src_mac,
	
	input		[1:0]		i_Operation,
	input		[47:0]	i_SHA,
	input		[31:0]	i_SPA,
	input		[47:0]	i_THA,
	input		[31:0]	i_TPA
);

// ===========================================================================
//	Data Sender
// ===========================================================================
reg			[63:0]		dts;
reg			[10:0]		dts_len;

reg			[63:0]		ds;
reg			[10:0]		ds_cnt;
reg			[10:0]		ds_len;
always @ (posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0) begin
	end
	else begin
		if(new_state != state) begin
			ds <= dts;
			ds_len <= dts_len;
			ds_cnt <= 4'd1;
		end 
		else begin
			if(ds_cnt != ds_len) begin
				ds <= {ds[55:0], 8'h00};
				ds_cnt <= ds_cnt + 4'd1;
			end
		end
	end
end

// ===========================================================================
// STATE MACHINE
// ===========================================================================
parameter	[4:0]			state_none = 5'd0;
parameter	[4:0]			send_preamble = 5'd1;
parameter	[4:0]			send_dst_mac = 5'd2;
parameter	[4:0]			send_src_mac = 5'd3;
parameter	[4:0]			send_ether_type = 5'd4;

wire 			[63:0]		arp_header;
parameter	[15:0]		ARP_HTYPE = 16'h0001;
parameter	[15:0]		ARP_PTYPE = 16'h0800;
parameter	[7:0]			ARP_HLEN = 8'h06;	//	MAC size
parameter	[7:0]			ARP_PLEN = 8'h04;	// for IPv4
assign arp_header = {ARP_HTYPE, ARP_PTYPE, ARP_HLEN, ARP_PLEN, {6'd0, i_Operation}};
parameter	[4:0]			send_arp_header =  5'd5;

parameter	[4:0]			send_SHA = 5'd6;
parameter	[4:0]			send_SPA = 5'd7;
parameter	[4:0]			send_THA = 5'd8;
parameter	[4:0]			send_TPA = 5'd9;

parameter	[4:0]			send_dummy_bytes = 5'd10;	// data size is 46-1500 bytes

parameter	[4:0]			send_crc32 = 5'd17;

reg			[4:0]			state;
reg			[4:0]			new_state;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= state_none;
	else
		state <= new_state;
end

always @ (*) begin
	new_state = state;

	case(state)
		state_none:
			if(rst_n == 1'b1)
				new_state = send_preamble;
				
		send_preamble:
			begin
				dts = 64'h55555555555555d5;
				dts_len = 11'd8;
				new_state = send_dst_mac;
			end
			
		send_dst_mac:
			if(ds_cnt == ds_len) begin
				dts = {i_dst_mac, 16'd0};
				dts_len = 11'd6;
				new_state = send_src_mac;
			end

		send_src_mac:
			if(ds_cnt == ds_len) begin
				dts = {i_src_mac, 16'd0};
				dts_len = 11'd6;
				new_state = send_ether_type;
			end
			
		send_ether_type:
			if(ds_cnt == ds_len) begin
				dts = {16'h0806, 48'd0};
				dts_len = 11'd2;
				new_state = send_arp_header;
			end
			
		send_arp_header:
			if(ds_cnt == ds_len) begin
				dts = arp_header;
				dts_len = 11'd8;
				new_state = send_SHA;
			end
			
		send_SHA:
			if(ds_cnt == ds_len) begin
				dts = {i_SHA, 16'd0};
				dts_len = 11'd6;
				new_state = send_SPA;
			end
			
		send_SPA:
			if(ds_cnt == ds_len) begin
				dts = {i_SPA, 32'd0};
				dts_len = 11'd6;
				new_state = send_THA;
			end
			
		send_THA:
			if(ds_cnt == ds_len) begin
				dts = {i_THA, 16'd0};
				dts_len = 11'd6;
				new_state = send_TPA;
			end
			
		send_TPA:
			if(ds_cnt == ds_len) begin
				dts = {i_TPA, 32'd0};
				dts_len = 11'd6;
				new_state = send_dummy_bytes;
			end
			
		send_dummy_bytes:
			if(ds_cnt == ds_len) begin
				dts = 64'd0;
				dts_len = 11'd18;
				new_state = send_crc32;
			end
			
	endcase
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
			if(new_state == send_src_mac)
				calc_crc_flag <= 1'b1;
			else 
				if(new_state == send_crc32)
					calc_crc_flag <= 1'b0;
		end
end

wire		[31:0]		crc32;
calc_crc32 u_crc32(
	.rst_n(rst_n),
	.clk(clk),
	.i_calc(calc_crc_flag),
	.i_vl(o_tx_en),
	.i_data(o_data),
	.o_crc32(crc32)
);


endmodule
