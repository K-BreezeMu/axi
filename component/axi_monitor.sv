class axi_monitor extends uvm_monitor;

	`uvm_component_utils(axi_monitor)
	virtual axi_interface vif;
	axi_transaction tr;
	uvm_analysis_port #(axi_transaction) mon_port;
	
	function new(string name = "axi_monitor",uvm_component parent);
		super.new(name,parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		mon_port = new("mon_port",this);
		tr = axi_transaction::type_id::create("tr");
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		forever begin
			@(posedge vif.clk);
			run();
		end
	endtask

	virtual task run();
	begin
		if(vif.resetn == 1'b0) begin
			`uvm_info("mon","reset task started",UVM_MEDIUM)
			reset_dut();
		end
		else if((vif.resetn == 1'b1) && (vif.awaddr <= 128) || (vif.araddr <= 128)) begin
			wr_rd_transaction();
		end

		else if((vif.resetn == 1'b1) &&(vif.awaddr > 127)|| (vif.araddr > 127)) begin
			wrrderror();
		end
	end
	endtask

	virtual task reset_dut();
		tr.awid = vif.awid;
		tr.awlen = vif.awlen;
		tr.awsize = vif.awsize;
		tr.awaddr = vif.awaddr;
		tr.awburst = vif.awburst;
		tr.awvalid = vif.awvalid;
		tr.awready = vif.awready;

		tr.wdata = vif.wdata;
		tr.wvalid = vif.wvalid;
		tr.wready = vif.wready;
		tr.wstrb = vif.wstrb;
		tr.wlast = vif.wlast;
		tr.wid = vif.wid;

		tr.bresp = vif.bresp;
		tr.bid = vif.bid;
		tr.bvalid = vif.bvalid;
		tr.bready = vif.bready;

		tr.arid = vif.arid;
		tr.arlen = vif.arlen;
		tr.arsize = vif.arsize;
		tr.araddr = vif.araddr;
		tr.arburst = vif.arburst;
		tr.arvalid = vif.arvalid;
		tr.arready = vif.arready;

		tr.rid = vif.rid;
		tr.rdata = vif.rdata;
		tr.rstrb = vif.rstrb;
		tr.rresp = vif.rresp;
		tr.rlast = vif.rlast;
		tr.rvalid = vif.rvalid;
		tr.rready = vif.rready;

		mon_port.write(tr);
	endtask

	virtual task wr_rd_transaction();
		`uvm_info("MON","write read transaction",UVM_MEDIUM)

		tr.awburst= vif.awburst;
		tr.awaddr = vif.next_addrwr;
		tr.id	= vif.awid;
		tr.awsize = vif.awsize;
		tr.awlen = vif.awlen;
		tr.awvalid = vif.awvalid;
		tr.awready = vif.awready;

		case(vif.awburst)
			0:tr.op = wrrdfixed;
			1:tr.op = wrrdincr;
			2:tr.op = wrrdwrap;
			default: tr.op = wrrdfixed;
		endcase

		if((vif.wvalid == 1'b1) && (vif.wready == 1'b1)) begin
			tr.wdata = vif.wdata;
			tr.wvalid = vif.wvalid;
			tr.wready = vif.wready;
			tr.wstrb = vif.wstrb;
			tr.wlast = vif.wlast;
			tr.id = vif.wid;
		end

		if((vif.bvalid == 1'b1) && (vif.bready == 1'b1)) begin
			tr.bresp = vif.bresp;
			tr.id = vif.bid;
			tr.bvalid = vif.bvalid;
			tr.bready = vif.bready;
		end

		tr.id	= vif.arid;
		tr.arlen = vif.arlen;
		tr.arsize = vif.arsize;
		tr.araddr = vif.next_addrrd;
		tr.arburst = vif.arburst;
		tr.arvalid = vif.arvalid;
		tr.arready = vif.arready;

		if((vif.rvalid == 1)&&(vif.rready==1)) begin
			tr.id = vif.rid;
			tr.rdata = vif.rdata;
			tr.rstrb = vif.rstrb;
			tr.rresp = vif.rresp;
			tr.rlast = vif.rlast;
			tr.rvalid =vif.rvalid;
			tr.ready = vif.ready;
		end

		mon_port.write(tr);
		`uvm_info("MON",$sformatf("awaddr=%0d wdata=%0d araddr=%0d rdata=%0d",tr.awaddr,tr.wdata,tr.araddr,tr.rdata),UVM_MEDIUM)  
	endtask

	virtual task wrrderror();
		`uvm_info("mon","write read transaction",UVM_MEDIUM)
		tr.awburst = vif.awburst;
		tr.awaddr = vif.awaddr;
		tr.id = vif.awid;
		tr.awlen = vif.awlen;
		tr.awsize = vif.awsize;
		tr.awvalid = vif.awvalid;
		tr.awready = vif.awready;

		case(vif.awburst)
			0:tr.op = wrrdfixed;
			1:tr.op = wrrdincr;
			2:tr.op = wrrdwrap;
			default: tr.op = wrrdfixed;
		endcase

		if((vif.wvalid == 1'b1)&&(vif.wready == 1'b1)) begin
			tr.wdata = vif.wdata;
			tr.wvalid = vif.wvalid;
			tr.wready = vif.wready;
			tr.wstrb = vif.wstrb;
			tr.wlast = vif.wlast;
			tr.id = vif.id;
		end

		if((vif.bvalid==1'b1) && (vif.bready == 1'b1)) begin
			tr.bresp = vif.bresp;
			tr.id	= vif.bid;
			tr.bvalid = vif.bvalid;
			tr.bready = vif.bready;
		end

		tr.id = vif.arid;
		tr.arlen = vif.arlen;
		tr.arsize = vif.arsize;
		tr.araddr = vif.araddr;
		tr.arburst = vif.arburst;
		tr.arvalid = vif.arvalid;
		tr.arready = vif.arready;

		if((vif.rvalid == 1) && (vif.rready == 1)) begin
			tr.id = rid;
			tr.rdata = vif.rdata;
			tr.rstrb = vif.rstrb;
			tr.rresp = vif.rresp;
			tr.rlast = vif.rlast;
			tr.rvalid = vif.rvalid;
			tr.ready = vif.ready;
			$display("RRESP = %0b",tr.rresp);
			end
			mon_port.write(tr);
			`uvm_info("MON",$sformatf("awaddr=%0d wdata=%0d araddr=%0d rdata=%0d",tr.awaddr,tr.wdata,tr.araddr,tr.rdata),UVM_MEDIUM)
		endtask
	endclass

		



