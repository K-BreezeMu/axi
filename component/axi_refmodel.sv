class axi_refmodel;
	bit [7:0] ref_mem [bit [15:0]];
	function void write (bit [15:0] awaddr,bit [7:0] awlen,bit [2:0] awsize,bit [1:0] awburst,bit [3:0] wstrb[$],bit [31:0] wdata[$]);
		bit [15:0] addr;
		bit [15:0] addr_count;
		addr_count = awaddr;
		if(awburst == 2'b00) begin
			for(int i=0;i<(awlen+1);i++) begin
				addr = addr_count & 16'hFFFC;
				for(int j=0;j<4;j++) begin
				if(wstrb[i][j]) begin
				ref_mem[addr + j] =  wdata[i][j*8 +: 8];
				end
				end
			end
		end

		if(awburst == 2'b01) begin
			for(int i=0;i<(awlen+1);i++) begin
				addr = addr_count & 16'hFFFC;
				for(int j=0;j<4;j++) begin
				if(wstrb[i][j]) begin
				ref_mem[addr + j] = wdata[i][j*8 +: 8];
				end
				end
				addr_count = addr_count + (1<<awsize);
			end
		end
	endfunction

	function bit [31:0] read[$] (bit [15:0] araddr,bit [7:0] arlen,bit [2:0] arsize,bit [1:0] arburst);
		bit [15:0] addr;
		bit [31:0] rdata[$];
		bit [31:0] data;
		bit [15:0] addr_count;
		if(arburst == 2'b00) begin
			addr = araddr & 16'hFFFC;
			for(int i=0;i<(arlen+1);i++) begin
				for(int j=0;j<4;j++) begin
				data[j*8 +: 8] = ref_mem[addr + j];
				end
				rdata.push_back(data);
			end
		end
		if(arburst == 2'b01) begin
			addr_count = araddr;
				for(int i=0;i<(arlen+1);i++) begin
				addr = addr_count & 16'hFFFC;
				for(int j=0;j<4;j++) begin					
				data[j*8 +: 8] = ref_mem[addr + j];
				end
				rdata.push_back(data);
				addr_count = addr_count + (1<<arsize);
				end
		end
		return rdata;
	endfunction

endclass
							

				
	





