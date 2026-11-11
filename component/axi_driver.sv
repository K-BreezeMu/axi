class axi_driver extends uvm_driver #(axi_transaction);
	
	`uvm_component_utils(axi_driver)
	virtual axi_interface vif;
	axi_transaction tr;

	function new(string name = "axi_driver",uvm_component parent);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		tr = axi_transaction::type_id::create("tr");
	endfunction

	virtual task run_phase(uvm_phase phase);
		init_bus();
		forever begin
			seq_item_port.get_next_item(tr);
			`uvm_info("DRV",$sformatf("awaddr=%0h",tr.awaddr),UVM_MEDIUM)
			run();
			seq_item_port.item_done(tr);
		end
	endtask

	virtual task run();
		if(tr.op == rstdut)
			reset_dut();
		else if(tr.op == wrrdfixed) begin
			`uvm_info("DRV",$sformatf("Fixed Mode Write read wlen=%0d wsize=%0d",tr.awlen+1,tr.awsize),UVM_MEDIUM)
			fixed_wr();
			fixed_rd();
		end
		else if(tr.op == wrrdincr) begin
			`uvm_info("DRV",$sformatf("increament Mode Write read wlen=%0d wsize=%0d",tr.awlen+1,tr.awsize),UVM_MEDIUM)
			incr_wr();
			incr_rd();
		end
	  endtask

	virtual task init_bus();
        	vif.awvalid <= 1'b0;
        	vif.wvalid  <= 1'b0;
       	 	vif.bready  <= 1'b0;
        	vif.arvalid <= 1'b0;
        	vif.rready  <= 1'b0;
        endtask

	virtual task reset_dut();
		`uvm_info("DRV", "Resetting DUT...", UVM_LOW)
		init_bus();
    		vif.resetn <= 1'b1;
      		repeat(5) @(posedge vif.clk);
   		vif.resetn <= 1'b0;
		@(posedge vif.clk);
		endtask

	virtual task fixed_wr();
		`uvm_info("DRV","fixed_mode write transaction is started",UVM_LOW)

		@(posedge vif.clk);
		vif.awid   <= tr.id;
		vif.awlen  <= tr.awlen;
		vif.awsize <= tr.awsize;
		vif.awaddr <= tr.awaddr;
		vif.awburst <= 2'b00;
		vif.wvalid <= 1'b0;
		vif.bready <= 1'b0;
		vif.awvalid <= 1'b1;
		vif.wlast   <= 1'b0;
		//写地址通道握手
		do @(posedge vif.clk); while(!(vif.awvalid && vif.awready));
		vif.awvalid <= 1'b0;

		for(int i=0;i<(vif.awlen+1);i++) begin
			vif.wdata <= tr.wdata[i];
			vif.wstrb <= tr.wstrb[i];
			vif.wlast <= (i == tr.awlen);
			vif.wvalid <= 1'b1;
		//写通道握手
		do @(posedge vif.clk); while(!(vif.wvalid && vif.wready));
	end
		vif.wvalid <= 1'b0;
		vif.wlast <= 1'b0;
		vif.bready <= 1'b1;
		//写响应通道握手
		do @(posedge vif.clk); while(!(vif.bvalid && vif.bready));
		vif.bready <= 0;
		if(vif.bid != tr.id) begin
		`uvm_error("[DRV]",$sformatf("bid =%0d,id=%0d",vif.bid,tr.id))
	end
		`uvm_info("[DRV]",$sformatf("bresp = %0d",vif.bresp),UVM_MEDIUM)
		
		`uvm_info("[DRV]","Fixed_mode write transaction is completed",UVM_LOW)
 	endtask
	
	virtual task fixed_rd();
		`uvm_info("DRV","fixed_mode read transaction is started",UVM_LOW)

		@(posedge vif.clk);
		vif.arvalid <= 1'b1;
		vif.arid <= tr.id;
		vif.arlen <= tr.arlen;
		vif.arsize <=tr.arsize;
		vif.araddr <= tr.araddr;
		vif.arburst <= 2'b00;
		//读地址通道握手
		do @(posedge vif.clk); while (!(vif.arvalid && vif.arready));
		vif.arvalid <= 1'b0;
		vif.rready <= 1'b1;
		for(int i=0;i<(vif.arlen+1);i++) begin
			//读通道握手
			do @(posedge vif.clk) ; while (!(vif.rvalid && vif.rready));			
			if (i == tr.arlen && vif.rlast !== 1'b1) 
			`uvm_error("DRV", "Missing RLAST!")
			if (i < tr.arlen && vif.rlast === 1'b1)  
			`uvm_error("DRV", "Unexpected RLAST!")
		end
		
		vif.rready <= 1'b0;
		`uvm_info("DRV","FIXED_MODE read complete",UVM_LOW)
	endtask

	virtual task incr_wr();
		`uvm_info("DRV","INCR_mode write transaction is started",UVM_MEDIUM)
		
		@(posedge vif.clk);
		vif.awid <= tr.id;
		vif.awlen <= tr.awlen;
		vif.awsize <= tr.awsize;
		vif.awaddr <= tr.awaddr;
		vif.awburst <= 2'b01;

		vif.wvalid <= 1'b0;
		vif.bready <= 1'b0;
		vif.awvalid <= 1'b1;
		//写地址握手
		do @(posedge vif.clk); while (!(vif.awvalid == 1'b1 && vif.awready == 1'b1));
		vif.awvalid <= 1'b0;
		vif.wlast <= 1'b0;

		for(int i=0;i<(vif.awlen+1);i++) begin
			vif.wvalid <= 1'b1;
			vif.wstrb <= tr.wstrb[i];
			vif.wdata <= tr.wdata[i];
			vif.wlast <= (i == tr.awlen);
			do @(posedge vif.clk); while(!(vif.wvalid == 1'b1 && vif.wready == 1'b1));
		end

		vif.wvalid <= 1'b0;
		vif.bready <=1'b1;
		do @(posedge vif.clk); while(!(vif.bready == 1'b1 && vif.bvalid == 1'b1));
		if(vif.bid != tr.id)
			`uvm_error("[DRV]",$sformatf("bid =%0d,id=%0d",vif.bid,tr.id))
		`uvm_info("[DRV]","INCR_mode write transaction is completed",UVM_LOW)
 
   endtask
	
	  virtual task incr_rd();
		`uvm_info("[DRV]","INCR_mode read transaction is started",UVM_MEDIUM)
		vif.arid <= tr.id;
		vif.araddr <= tr.araddr;
		vif.arlen <= tr.arlen;
		vif.arsize <= tr.arsize;
		vif.arburst <= 2'b01;
		vif.arvalid <= 1'b1;
		do @(posedge vif.clk); while(!(vif.arvalid == 1'b1 && vif.arready == 1'b1));
		vif.arvalid <= 1'b0;
		vif.rready <= 1'b1;

		for(int i=0;i<vif.arlen+1;i++) begin
			do @(posedge vif.clk); while(!(vif.rvalid == 1'b1 && vif.rready == 1'b1));
			if (i == tr.arlen && vif.rlast !== 1'b1) 
			`uvm_error("DRV", "Missing RLAST!")
			if (i < tr.arlen && vif.rlast === 1'b1)  
			`uvm_error("DRV", "Unexpected RLAST!")
		end
		vif.rready <= 1'b0;
		`uvm_info("[DRV]","INCR_MODE read complete",UVM_MEDIUM)
	endtask

endclass
   		
	
		




