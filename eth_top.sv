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
wire		[7:0]		arp_tx_data;
wire					arp_tx_data_en;
wire		[7:0]		udp_tx_data;
wire					udp_tx_data_en;

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
