class axi_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(axi_scoreboard)

	uvm_analysis_imp #(axi_transaction,axi_scoreboard) analysis_export;

	axi_refmodel refmodel;

	int pass;
	int fail;
	int total;
	bit [31:0] exp[$];
	bit [15:0] addr_count;
	bit [7:0] exp_byte;
	bit [7:0] act_byte;
	int start_lane;
	int lane;
	int num_byte;

	function new(string name = "axi_scoreboard",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		analysis_export = new("analysis_export",this);
		refmodel = new();
	endfunction

	virtual function void write(axi_transaction tr);
		exp.delete();
		if(tr.is_write == 1'b1) begin
			`uvm_info("SCB",$sformatf("write mode:addr = 0x%h, len=%0d",tr.awaddr,tr.awlen),UVM_MEDIUM)
			refmodel.write(tr.awaddr,tr.awlen,tr.awsize,tr.awburst,tr.wstrb,tr.wdata);
		end else begin
			`uvm_info("SCB",$sformatf("read mode:addr = 0x%0h,len = %0d",tr.araddr,tr.arlen),UVM_MEDIUM)
			exp = refmodel.read(tr.araddr,tr.arlen,tr.arsize,tr.arburst);
			for(int i=0;i<(tr.arlen+1);i++) begin
				if(tr.arburst == 2'b00) begin
					addr_count = tr.araddr;
				end else begin
					addr_count = tr.araddr + (i*(1<<tr.arsize));
				end
					start_lane = addr_count % 4;
					num_byte = 1 << tr.arsize;					
					for(int j=0;j < num_byte;j++) begin
						total++;
						lane = start_lane + j;
						if(lane < 4) begin
							act_byte = tr.rdata[i][lane*8 +: 8];
							exp_byte = exp[i][lane*8 +: 8];

							if(act_byte !== exp_byte) begin
								fail++;
								`uvm_error("SCB",$sformatf("Mismatch at addr 0x%h (lane %0d): exp = 0x%h,act = 0x%0h",addr_count + j,lane,exp_byte,act_byte))
							end else begin
							pass++;
							end
						end
					end
			end
		end
	endfunction
	
	virtual function void report_phase(uvm_phase phase);
		super.report_phase(phase);
		`uvm_info("SCB","-------------------------------------------------",UVM_MEDIUM)
		`uvm_info("SCB","-----------------Report SCB----------------------",UVM_MEDIUM)
		`uvm_info("SCB",$sformatf("total : %5d			",total),UVM_MEDIUM)
		`uvm_info("SCB",$sformatf("PASS  : %5d			",pass),UVM_MEDIUM)
		`uvm_info("SCB",$sformatf("FALL  : %5d			",fail),UVM_MEDIUM)
		`uvm_info("SCB","-------------------------------------------------",UVM_MEDIUM)
	endfunction
endclass		

		
