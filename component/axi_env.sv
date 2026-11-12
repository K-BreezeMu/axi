class axi_env extends uvm_env;
	`uvm_component_utils(axi_env)

	axi_agent agent;
	axi_scoreboard scoreboard;
	axi_subscriber subscriber;

	function new(string name = "axi_env",uvm_component parent);
		super.new(name,parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		agent = axi_agent::type_id::create("agent",this);
		scoreboard = axi_scoreboard::type_id::create("scoreboard",this);
		subscriber = axi_subscriber::type_id::create("subscriber",this);
	endfunction

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		agent.monitor.mon_port.connect(scoreboard.analysis_export);
		agent.monitor.mon_port.connect(subscriber.analysis_export);
	endfunction
endclass
