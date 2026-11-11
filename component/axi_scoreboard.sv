class axi_scoreboard extends uvm_scoreboard;
	`uvm_component_utils(axi_scoreboard)

	uvm_analysis_imp #(axi_transaction,axi_scoreboard) analysis_export;

	axi_refmodel refmodel;

	int pass;
	int fail;
	int total;

	function new(string name = "axi_scoreboard",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		analysis_export = new("analysis_export",this);
		refmodel = new();
	endfunction

	virtual function void write(axi_transaction tr);
		
