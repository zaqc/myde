module calc_crc32(
	input 				rst_n,
	input 				clk,
	input		[7:0]		i_data,
	input					i_vl,
	input					i_calc,
	output	[31:0]	o_crc32
);

//******************************************************************************
//input data width is 8bit, and the first bit is bit[0]
function	[31:0]		NextCRC;
input		[7:0]			D;
input		[31:0]		C;
reg		[31:0]		NewCRC;
	begin
		NewCRC[0]=C[24]^C[30]^D[1]^D[7];
		NewCRC[1]=C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
		NewCRC[2]=C[26]^D[5]^C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
		NewCRC[3]=C[27]^D[4]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
		NewCRC[4]=C[28]^D[3]^C[27]^D[4]^C[26]^D[5]^C[24]^C[30]^D[1]^D[7];
		NewCRC[5]=C[29]^D[2]^C[28]^D[3]^C[27]^D[4]^C[25]^C[31]^D[0]^D[6]^C[24]^C[30]^D[1]^D[7];
		NewCRC[6]=C[30]^D[1]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
		NewCRC[7]=C[31]^D[0]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[24]^D[7];
		NewCRC[8]=C[0]^C[28]^D[3]^C[27]^D[4]^C[25]^D[6]^C[24]^D[7];
		NewCRC[9]=C[1]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^D[6];
		NewCRC[10]=C[2]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[24]^D[7];
		NewCRC[11]=C[3]^C[28]^D[3]^C[27]^D[4]^C[25]^D[6]^C[24]^D[7];
		NewCRC[12]=C[4]^C[29]^D[2]^C[28]^D[3]^C[26]^D[5]^C[25]^D[6]^C[24]^C[30]^D[1]^D[7];
		NewCRC[13]=C[5]^C[30]^D[1]^C[29]^D[2]^C[27]^D[4]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
		NewCRC[14]=C[6]^C[31]^D[0]^C[30]^D[1]^C[28]^D[3]^C[27]^D[4]^C[26]^D[5];
		NewCRC[15]=C[7]^C[31]^D[0]^C[29]^D[2]^C[28]^D[3]^C[27]^D[4];
		NewCRC[16]=C[8]^C[29]^D[2]^C[28]^D[3]^C[24]^D[7];
		NewCRC[17]=C[9]^C[30]^D[1]^C[29]^D[2]^C[25]^D[6];
		NewCRC[18]=C[10]^C[31]^D[0]^C[30]^D[1]^C[26]^D[5];
		NewCRC[19]=C[11]^C[31]^D[0]^C[27]^D[4];
		NewCRC[20]=C[12]^C[28]^D[3];
		NewCRC[21]=C[13]^C[29]^D[2];
		NewCRC[22]=C[14]^C[24]^D[7];
		NewCRC[23]=C[15]^C[25]^D[6]^C[24]^C[30]^D[1]^D[7];
		NewCRC[24]=C[16]^C[26]^D[5]^C[25]^C[31]^D[0]^D[6];
		NewCRC[25]=C[17]^C[27]^D[4]^C[26]^D[5];
		NewCRC[26]=C[18]^C[28]^D[3]^C[27]^D[4]^C[24]^C[30]^D[1]^D[7];
		NewCRC[27]=C[19]^C[29]^D[2]^C[28]^D[3]^C[25]^C[31]^D[0]^D[6];
		NewCRC[28]=C[20]^C[30]^D[1]^C[29]^D[2]^C[26]^D[5];
		NewCRC[29]=C[21]^C[31]^D[0]^C[30]^D[1]^C[27]^D[4];
		NewCRC[30]=C[22]^C[31]^D[0]^C[28]^D[3];
		NewCRC[31]=C[23]^C[29]^D[2];
		NextCRC=NewCRC;
	end
endfunction
//******************************************************************************


reg		[31:0]	crc;
assign o_crc32 = ~{
	crc[0], crc[1], crc[2], crc[3], crc[4], crc[5], crc[6], crc[7], 
	crc[8], crc[9], crc[10], crc[11], crc[12], crc[13], crc[14], crc[15],
	crc[16], crc[17], crc[18], crc[19], crc[20], crc[21], crc[22], crc[23], 
	crc[24], crc[25], crc[26], crc[27], crc[28], crc[29], crc[30], crc[31],
};

reg	[1:0]		cntr;

always @ (posedge clk or negedge rst_n) begin
	if(1'b0 == rst_n) begin
		crc <= 32'hFFFFFFFF;
		cntr <= 2'd0;
	end
	else begin
		if(1'b1 == i_calc) begin
			if(i_vl == 1'b1)
				crc <= NextCRC(i_data , crc);
			cntr <= 2'd0;
		end
		else begin
			if(cntr != 2'h3) begin
				if(i_vl == 1'b1) begin
					crc <= {crc[23:0], 8'hFF};
					cntr <= cntr + 2'd1;
				end
			end 
			else 
				crc <= 32'hFFFFFFFF;
		end
	end
end

endmodule
