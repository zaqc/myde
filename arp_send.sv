module arp_send(
	input						clk,
	input						rst_n,
	
	output	[7:0]			o_data,
	output reg				o_tx_en,

	output	[31:0]		o_crc32,
	
	input 	[47:0]		i_dst_mac,
	input		[47:0]		i_src_mac,
	
	input		[1:0]			i_operation,
	input		[47:0]		i_SHA,
	input		[31:0]		i_SPA,
	input		[47:0]		i_THA,
	input		[31:0]		i_TPA,
	
	input						i_enable,	// start send frame
	output					o_ready		// set when frame transfer complite
);

reg			[0:0]			rdy;
assign o_ready = rdy;

always_ff @ (posedge clk or negedge rst_n)
	if(1'b0 == rst_n)
		rdy <= 1'b0;
	else
		if(new_state != state)
			rdy <= (new_state == STATE_IDLE) ? 1'b1 : 1'b0;
			else rdy <= 1;

// ===========================================================================
// PARAMETERS
// ===========================================================================
wire 			[63:0]		arp_header;
parameter	[15:0]		ARP_HTYPE = 16'h0001;
parameter	[15:0]		ARP_PTYPE = 16'h0800;
parameter	[7:0]			ARP_HLEN = 8'h06;	//	MAC size
parameter	[7:0]			ARP_PLEN = 8'h04;	// for IPv4
assign arp_header = {ARP_HTYPE, ARP_PTYPE, ARP_HLEN, ARP_PLEN, {14'd0, i_operation}};

// ===========================================================================
// STATE MACHINE
// ===========================================================================
enum logic [3:0] {
	STATE_IDLE = 4'd0,
	SEND_PREAMBLE = 4'd1,
	SEND_DST_MAC = 4'd2,
	SEND_SRC_MAC = 4'd3,
	SEND_ETHER_TYPE = 4'd4,
	SEND_ARP_HEADER = 4'd5,
	SEND_SHA = 4'd6,
	SEND_SPA = 4'd7,
	SEND_THA = 4'd8,
	SEND_TPA = 4'd9,
	SEND_DUMMY_BYTES = 4'd10,
	SEND_CRC32 = 4'd11,
	DELAY = 4'd12,
	SET_READY = 4'd13
} state, new_state;

always_ff @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n)
		state <= STATE_IDLE;
	else
		state <= new_state;
end

logic	data_push_out;
assign data_push_out = (ds_cnt == ds_len) ? 1'b1 : 1'b0;

always_comb begin
	new_state = state;
	case(state)
		STATE_IDLE: if(1'b1 == rst_n 
			&& send_flag == 1'b1 && i_enable == 1'b1) new_state = SEND_PREAMBLE;
		SEND_PREAMBLE: if(data_push_out) new_state = SEND_DST_MAC;
		SEND_DST_MAC: if(data_push_out) new_state = SEND_SRC_MAC;
		SEND_SRC_MAC: if(data_push_out) new_state = SEND_ETHER_TYPE;
		SEND_ETHER_TYPE: if(data_push_out) new_state = SEND_ARP_HEADER;
		SEND_ARP_HEADER: if(data_push_out) new_state = SEND_SHA;
		SEND_SHA: if(data_push_out) new_state = SEND_SPA;
		SEND_SPA: if(data_push_out) new_state = SEND_THA;
		SEND_THA: if(data_push_out) new_state = SEND_TPA;
		SEND_TPA: if(data_push_out) new_state = SEND_DUMMY_BYTES;
		SEND_DUMMY_BYTES: if(data_push_out) new_state = SEND_CRC32;
		SEND_CRC32: if(data_push_out) new_state = STATE_IDLE;
	endcase
end

assign o_tx_en = (state != STATE_IDLE && state < DELAY) ? 1'b1 : 1'b0;

// ===========================================================================
//	DELAY for PACKET SEND
// ===========================================================================
reg	[31:0]	send_delay;
reg	[0:0]		send_flag;
always_ff @ (posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0) begin
		send_delay <= 32'h08FFFFFF;
		send_flag <= 1'b0;
	end
	else begin
		if(state == STATE_IDLE) begin
			if(send_delay != 32'h08FFFFFF)
				send_delay <= send_delay + 32'd1;
			else
				send_flag <= 1'b1;
		end
		else begin
			send_delay <= 32'd0;
			send_flag <= 1'b0;
		end
	end
end

// ===========================================================================
//	DATA SHIFT & SEND
// ===========================================================================
assign o_data = (state == SEND_CRC32) ? crc32[7:0] : ds[63:56];

reg			[63:0]		ds;
reg			[4:0]			ds_cnt;
reg			[4:0]			ds_len;
always_ff @ (posedge clk or negedge rst_n) begin
	if(rst_n == 1'b0) begin
		ds <= 64'd0;
		ds_cnt <= 11'd0;
		ds_len <= 11'd0;
	end
	else begin
		if(new_state != state) begin
			case(new_state)
				SEND_PREAMBLE: begin
					ds_len <= 5'd8;
					ds <= 64'h55555555555555d5;
				end
				SEND_DST_MAC: begin
					ds_len <= 5'd6;
					ds <= {i_dst_mac, 16'd0};
				end
				SEND_SRC_MAC: begin
					ds_len <= 5'd6;
					ds <= {i_src_mac, 16'd0};
				end
				SEND_ETHER_TYPE: begin
					ds_len <= 5'd2;
					ds <= {16'h0806, 48'd0};	// ARP frame
				end
				SEND_ARP_HEADER: begin
					ds_len <= 5'd8;
					ds <= arp_header;
				end
				SEND_SHA: begin
					ds_len <= 5'd6;
					ds <= {i_SHA, 16'd0};
				end
				SEND_SPA: begin
					ds_len <= 5'd4;
					ds <= {i_SPA, 32'd0};
				end
				SEND_THA: begin
					ds_len <= 5'd6;
					ds <= {i_THA, 16'd0};
				end
				SEND_TPA: begin
					ds_len <= 5'd4;
					ds <= {i_TPA, 32'd0};
				end
				SEND_DUMMY_BYTES: begin
					ds_len <= 5'd18;
					ds <= 64'd0;
				end
				SEND_CRC32: begin
					ds_len <= 5'd4;
					ds <= 64'd0;
				end
			endcase
			ds_cnt <= 11'd1;
		end 
		else begin
			if(!data_push_out) begin
				ds <= {ds[55:0], 8'h00};
				ds_cnt <= ds_cnt + 5'd1;
			end 
		end
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
			if(new_state == SEND_DST_MAC)
				calc_crc_flag <= 1'b1;
			else 
				if(new_state == SEND_CRC32)
					calc_crc_flag <= 1'b0;
		end
end

wire		[31:0]		crc32;
assign o_crc32 = crc32;

calc_crc32 u_crc32(
	.rst_n(rst_n),
	.clk(clk),
	.i_calc(calc_crc_flag),
	.i_vl(o_tx_en),
	.i_data(o_data),
	.o_crc32(crc32)
);

endmodule
