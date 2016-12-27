module pack_gen
(
        input i_clk,
        input i_rst,
        
        output [7:0] o_data,
        output reg   TX_EN,
		  output cntr,
		  
		  output CRC_rd,
		  output CRC_init
);

`define FAST (1'b0)
`define HIGH (1'b1)

parameter SPEED = `HIGH; // Determines that to send bytes or nibbles

reg [26:0] clk_counter; // Number of bits determines pause time
reg [7:0] byte;            // Current output byte

wire [26:0] clk_bytes;

assign cntr = clk_counter[26];

assign clk_bytes = (SPEED == `FAST) ? clk_counter[9:1] : clk_counter; 
assign o_data    = (SPEED == `FAST) ? (clk_counter[0] ? byte[3:0] : byte[7:4]) : byte;

assign CRC_rd = ((clk_bytes >= 69) && (clk_bytes < 73)) ? 1'b1 : 1'b0;
assign CRC_init = (clk_bytes < 9) ? 1'b1 : 1'b0;

always @(posedge i_clk)
        begin
                if (i_rst)
                        clk_counter <= 0;
                else
                 begin
                        clk_counter <= clk_counter + 1'b1;
                        
                        if ((clk_bytes >= 9'h0) && (clk_bytes < 9'd72))
                                TX_EN <= 1'b1; // Transmission is enabled
                        else
                                TX_EN <= 1'b0;
                        
                case (clk_bytes)
                        // Sending the preambule and asserting TX_EN
                        0: byte <= 8'h55;
                        1: byte <= 8'h55; 
                        2: byte <= 8'h55; 
                        3: byte <= 8'h55; 
                        4: byte <= 8'h55; 
                        5: byte <= 8'h55; 
                        6: byte <= 8'h55; 
                        7: byte <= 8'hd5;
                                
                        default: 
                        
                                case (clk_bytes-8)
                                        // Sending the UDP/IP-packet itself
                                        0: byte <= 8'hd8;
                                        1: byte <= 8'hd3; 
                                        2: byte <= 8'h85; 
                                        3: byte <= 8'h26; 
                                        4: byte <= 8'hc5; 
                                        5: byte <= 8'h78; 
                                        6: byte <= 8'h00; 
                                        7: byte <= 8'h23; 
                
                                        8: byte <= 8'h54; 
                                        9: byte <= 8'h3c; 
                                        10: byte <= 8'h47; 
                                        11: byte <= 8'h1b; 
                                        12: byte <= 8'h08; 
                                        13: byte <= 8'h00; 
                                        14: byte <= 8'h45; 
                                        15: byte <= 8'h00; 
                
                                        16: byte <= 8'h00; 
                                        17: byte <= 8'h2e; 
                                        18: byte <= 8'h00; 
                                        19: byte <= 8'h00; 
                                        20: byte <= 8'h00; 
                                        21: byte <= 8'h00; 
                                        22: byte <= 8'hc8; 
                                        23: byte <= 8'h11;
                
                                        24: byte <= 8'hd6; 
                                        25: byte <= 8'h73; 
                                        26: byte <= 8'hc0; 
                                        27: byte <= 8'ha8; 
                                        28: byte <= 8'h4d; 
                                        29: byte <= 8'h21; 
                                        30: byte <= 8'hc0; 
                                        31: byte <= 8'ha8;
                
                                        32: byte <= 8'h4d; 
                                        33: byte <= 8'hd9; 
                                        34: byte <= 8'hc3; 
                                        35: byte <= 8'h50; 
                                        36: byte <= 8'hc3; 
                                        37: byte <= 8'h60; 
                                        38: byte <= 8'h00; 
                                        39: byte <= 8'h1a; 
                
                                        40: byte <= 8'h00; 
                                        41: byte <= 8'h00; 
                                        42: byte <= 8'h01; 
                                        43: byte <= 8'h02; 
                                        44: byte <= 8'h03; 
                                        45: byte <= 8'h04; 
                                        46: byte <= 8'h01; 
                                        47: byte <= 8'h01;
                
                                        48: byte <= 8'h01; 
                                        49: byte <= 8'h01; 
                                        50: byte <= 8'h01; 
                                        51: byte <= 8'h01; 
                                        52: byte <= 8'h01; 
                                        53: byte <= 8'h01; 
                                        54: byte <= 8'h01; 
                                        55: byte <= 8'h01;

                                        56: byte <= 8'h01; 
                                        57: byte <= 8'h01; 
                                        58: byte <= 8'h01; 
                                        59: byte <= 8'h01;
                                        
                                        // The CRC32 control sum (checked in Matlab programm)
                                        60: byte <= 8'he3;
                                        61: byte <= 8'h8e;
                                        62: byte <= 8'hdf;
                                        63: byte <= 8'h1f;
                        
                                        default: byte <= 0; // Pause 
                                endcase
                endcase
          end   
        end        
endmodule
