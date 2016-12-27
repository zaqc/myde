module ip_udp_gen(
	input					clk,
	input					rst_n,
	output	[7:0]		o_data
);

// input parameter's
parameter	[47:0]	dst_mac = {8'hD8, 8'hD3, 8'h85, 8'h26, 8'hC5, 8'h78};
parameter	[47:0]	src_mac = {8'h00, 8'h23, 8'h54, 8'h3C, 8'h47, 8'h1B};
parameter	[31:0]	src_ip = {8'hC0, 8'hA8, 8'h4D, 8'h21};
parameter	[31:0]	dst_ip = {8'hC0, 8'hA8, 8'h4D, 8'hD9};
parameter	[15:0]	src_port = {8'hC3, 8'h50};
parameter	[15:0]	dst_port = {8'hC3, 8'h60};

// SM state's
parameter	[3:0]		eth_none = 4'd0;			// send 0x55 seven times
parameter	[3:0]		eth_preamble = 4'd1;		// send 0x55 seven times
parameter	[3:0]		eth_sdf = 4'd2;			// send end of preamble 0x5D
parameter	[3:0]		eth_dst_mac = 4'd3;		// send destination MAC Address
parameter	[3:0]		eth_src_mac = 4'd4;		// send self MAC Address
parameter	[3:0]		eth_type = 4'd5;			// send 0x0800
parameter	[3:0]		udp_src_mac = 4'd4;		// 

// header sender
reg	[47:0]	data_ts;
reg	[3:0]		cnt_ts;
reg	[47:0]	send_data;
assign o_data = send_data[47:40];
reg	[3:0]		send_cnt;
reg	[3:0]		state;
reg	[3:0]		new_state;
always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n) begin
		send_data <= 48'd0;
		send_cnt <= 4'd0;
		state <= 4'd0;
		//new_state <= 4'd0;
	end
	else begin
		if(state != new_state) begin
			send_data <= data_ts;
			send_cnt <= 4'd0;
			state <= new_state;
		end
		else begin
			if(send_cnt != cnt_ts) begin
				send_cnt <= send_cnt + 1;
				send_data <= {send_data[40:0], 8'hFF};
			end
		end
	end
end

always @* begin
	case(state)
		eth_none: 
			if(1'b0 != rst_n) begin
				new_state = eth_preamble;
				data_ts = 48'h555555555555;
				cnt_ts = 4'd6;
			end

		eth_preamble:
			if(send_cnt == cnt_ts) begin
				new_state = eth_sdf;
				data_ts = 48'h555d00000000;
				cnt_ts = 4'd2;
			end
			
		eth_sdf:
			if(send_cnt == cnt_ts) begin
				new_state = eth_dst_mac;
				data_ts = dst_mac;
				cnt_ts = 4'd6;
			end

		eth_dst_mac:
			if(send_cnt == cnt_ts) begin
				new_state = eth_src_mac;
				data_ts = src_mac;
				cnt_ts = 4'd6;
			end
			
		eth_src_mac:
			if(send_cnt == cnt_ts) begin
				new_state = eth_type;
				data_ts = 48'h0800FFFFFFFF;
				cnt_ts = 4'd2;
			end
			
		default:	;
	endcase
end

endmodule 
