typedef enum bit [2:0] {wrrdfixed=0,wrrdincr=1,wrrdwrap=2,wrrderror=3,rstdut=4}operation;
class axi_transaction extends uvm_sequence_item;

	operation op;

	function new(string name = "axi_transaction");
		super.new(name);
	endfunction

	int len = 0;
	rand bit [3:0] id;

	bit clk,resetn;
	bit awvaild;
	bit awready;
	bit [3:0] awid;
	bit [3:0] awlen;
	rand bit [2:0] awsize;
	rand bit [31:0] awaddr;
	rand bit [1:0] awburst;

	bit	wvalid;
	bit	wready;
	bit [3:0] wid;
	rand bit [31:0] wdata;
	rand bit [3:0]  wstrb;
	bit	wlast;

	bit	bready;
	bit	bvalid;
	bit [3:0] bid;
	bit [1:0] bresp;
	
	bit		arready;
	bit [3:0] 	arid;
	rand bit [31:0] araddr;
	rand bit [3:0]  arlen;
	bit [2:0]	arsize;
	bit [1:0]	arburst;
	bit		arvalid;

	bit [3:0]	rid;
	bit [31:0]	rdata;
	bit [1:0]	rresp;
	rand bit [3:0]  rstrb;
	bit		rlast;
	bit		rvalid;
	bit		rready;
	
	bit [31:0]	next_addrwr;
	bit [31:0]	next_addrrd;

        `uvm_object_utils_begin(axi_transaction)
        `uvm_field_int(awaddr,   UVM_ALL_ON) 
        `uvm_field_int(araddr,   UVM_ALL_ON) 
        `uvm_field_int(wdata,  UVM_ALL_ON)
        `uvm_field_int(rdata,  UVM_ALL_ON)
        `uvm_field_int(arsize,  UVM_ALL_ON)
        `uvm_field_int(arburst,    UVM_ALL_ON)
        `uvm_field_int(awburst,   UVM_ALL_ON)
        `uvm_field_int(awlen,   UVM_ALL_ON)
        `uvm_field_int(arlen,   UVM_ALL_ON)
        `uvm_object_utils_end	

endclass
