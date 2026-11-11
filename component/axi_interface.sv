interface axi_interface;

	logic clk;
	logic resetn;

	logic awvalid;
	logic awready;
	logic [7:0] awid;
	logic [7:0] awlen;
	logic [2:0] awsize;
	logic [15:0] awaddr;
	logic [1:0] awburst;
	logic awlock;
	logic [3:0] awcache;
	logic [2:0] awprot;

	logic wvalid;
	logic wready;
	logic [31:0] wdata;
	logic [3:0] wstrb;
	logic wlast;

	logic bready;
	logic bvalid;
	logic [7:0] bid;
	logic [1:0] bresp;

	logic arready;
	logic [7:0] arid;
	logic [15:0] araddr;
	logic [7:0] arlen;
	logic [2:0] arsize;
	logic [1:0] arburst;
	logic arvalid;
	logic arlock;
	logic arcache;
	logic arprot;

	logic [7:0] rid;
	logic [31:0] rdata;
	logic [1:0] rresp;
	logic rlast;
	logic rvalid;
	logic rready;


endinterface
