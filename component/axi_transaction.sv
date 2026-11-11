typedef enum bit [2:0] {wrrdfixed=0,wrrdincr=1,wrrdwrap=2,wrrderror=3,rstdut=4}operation;
class axi_transaction extends uvm_sequence_item;

	operation op;
	bit is_write;

	function new(string name = "axi_transaction");
		super.new(name);
	endfunction

	rand bit [7:0] id;

	bit clk,resetn;
	bit awvalid;
	bit awready;
	bit [7:0] awid;
	bit [7:0] awlen;
	rand bit [2:0] awsize;
	rand bit [15:0] awaddr;
	rand bit [1:0] awburst;

	bit	wvalid;
	bit	wready;
	rand bit [31:0] wdata[$];
	rand bit [3:0]  wstrb[$];
	bit	wlast;

	bit	bready;
	bit	bvalid;
	bit [7:0] bid;
	bit [1:0] bresp;
	
	bit		arready;
	bit [7:0] 	arid;
	rand bit [15:0] araddr;
	rand bit [7:0]  arlen;
	rand bit [2:0]	arsize;
	rand bit [1:0]	arburst;
	bit		arvalid;

	bit [7:0]	rid;
	bit [31:0]	rdata[$];
	bit [1:0]	rresp;
	bit		rlast;
	bit		rvalid;
	bit		rready;
	

endclass
