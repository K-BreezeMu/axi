class axi_monitor extends uvm_monitor;
	`uvm_component_utils(axi_monitor)

	virtual axi_interface vif;
	uvm_analysis_port #(axi_transaction) mon_port;
	
	function new(string name = "axi_monitor",uvm_component parent);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_port = new("mon_port",this);
		if(!uvm_config_db#(virtual axi_interface)::get(this,"","vif",vif)) begin
			`uvm_fatal("axi_monitor","no vif")
		end
	endfunction

	virtual task run_phase(uvm_phase phase);
		axi_transaction tr;
		super.run_phase(phase);
		fork
			monitor_read();
			monitor_write();
		join

		end
	endtask
		
	virtual task monitor_read();
		tr = axi_transaction::type_id::create("tr");
		tr.is_write = 0;
		forever begin
			do @(posedge vif.clk); while(!(vif.arvalid && vif.arready));
			tr.araddr = vif.araddr;
			tr.arlen = vif.arlen;
			tr.arsize = vif.arsize;
			tr.arburst = vif.arburst;
			tr.id = vif.arid;
			tr.rdata.delete();
			for(int i=0;i<(vif.arlen+1);i++) begin
				do @(posedge vif.clk); while(!(vif.rvalid && vif.rready));
				tr.rdata.push_back(vif.rdata);
				tr.rresp = vif.rresp;
			end
			mon_port.write(tr);
		end
		endtask

	virtual task monitor_write();
		axi_transaction tr;
		forever begin
			tr = axi_transaction::type_id::create("tr");
			tr.is_write = 1;
			 // 1. 等写地址握手
            		do @(posedge vif.clk); while(!(vif.awvalid && vif.awready));
            		tr.awaddr = vif.awaddr;
            		tr.awlen  = vif.awlen;
           		tr.awsize = vif.awsize;
            		tr.awburst= vif.awburst;
            		tr.id     = vif.awid;
            		tr.wdata.delete();
            		tr.wstrb.delete();

            		// 2. 收写数据
            		for(int i=0; i <= tr.awlen; i++) begin
                	do @(posedge vif.clk); while(!(vif.wvalid && vif.wready));
                	tr.wdata.push_back(vif.wdata);
                	tr.wstrb.push_back(vif.wstrb);
                	if (i == tr.awlen && vif.wlast !== 1'b1) 
                    	`uvm_error("MON", "Missing WLAST!")
            		end

            		// 3. 等写响应
            		do @(posedge vif.clk); while(!(vif.bvalid && vif.bready));
            		tr.bresp = vif.bresp;

            		// 发给 Scoreboard
            		mon_port.write(tr);
        		end
    	endtask
endclass
		
		


