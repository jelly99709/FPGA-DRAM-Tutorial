//behavior tb
`timescale 1ns/10ps
`define CYCLE	   10.00
`define End_CYCLE  10000000            // Modify cycle times once your design need more cycle times!
`define PATIN       "./in.dat" 
`define PATOUT      "./out.dat"


module tb_dram;
	parameter NUM_OF_PAT = 1024;
	parameter DDR_DATA_WIDTH   = 64;
	parameter DDR_ADDR_WIDTH   = 32;
	
    reg  		 	clk;
	reg  		 	reset;
    reg  [127:0]  	data_in;
    reg  		 	valid_in;
	wire			valid_out;
    wire [127:0]  	data_out;
	reg 			ready;

	reg local_init_done;
	wire amm_wait;
	wire [DDR_ADDR_WIDTH-1:0] amm_addr;
	wire amm_rvalid;
	wire [DDR_DATA_WIDTH-1:0] amm_rdata;
	wire [DDR_DATA_WIDTH-1:0] amm_wdata;
	wire amm_ren;
	wire amm_wen;
	wire [5:0] amm_burstcount;
	
	reg  [127:0]  	golden_in    [0:NUM_OF_PAT-1];
	reg  [127:0]  	golden_out   [0:NUM_OF_PAT-1];
	
	reg  [31:0]		in_index, out_index;
	
	wire [19:0]		numData = NUM_OF_PAT;
	
	initial begin
		$display("--------------------------- [ Simulation Starts !! ] ---------------------------");	
		$readmemh(`PATIN,  golden_in);
		$readmemh(`PATOUT, golden_out);
	end
        
	
    dram_wrapper dut(
		.clk(clk), 
		.rst(reset), 
		.data_in(data_in), 
		.valid_in(valid_in), 
		.numData(numData),
		.data_out(data_out), 
		.valid_out(valid_out), 
		.ready(ready),
		// DDR interface
		.local_init_done(local_init_done),
		.amm_wait(amm_wait),
		.amm_addr(amm_addr),
		.amm_rvalid(amm_rvalid),
		.amm_rdata(amm_rdata),
		.amm_wdata(amm_wdata),
		.amm_ren(amm_ren),
		.amm_wen(amm_wen),
		.amm_burstcount(amm_burstcount)
	);

	amm_slave amm_s0(
		.clk(clk),
		.rst(reset),
		.local_init_done(local_init_done),
		.amm_wait(amm_wait),
		.amm_addr(amm_addr),
		.amm_rvalid(amm_rvalid),
		.amm_rdata(amm_rdata),
		.amm_wdata(amm_wdata),
		.amm_ren(amm_ren),
		.amm_wen(amm_wen),
		.amm_burstcount(amm_burstcount)
	);
	
    // waveform dump
    initial begin
        $fsdbDumpfile( "dram_wrapper.fsdb" );
        $fsdbDumpvars(0, tb_dram, "+mda");
    end
	
    // clock
    initial begin
        clk = 1'b0;
		//#(20*`CYCLE)
        forever #(`CYCLE/2) clk = ~clk;
    end
	
	wire stop_all = (out_index==NUM_OF_PAT);
	integer err_cnt, i, k, iters, last_valid;
	reg [DDR_DATA_WIDTH-1:0] gold, out;
	
    initial begin
        reset = 1'b0; valid_in = 1'b0; in_index = 0; out_index = 0; err_cnt = 0; ready = 1'b0; iters = 0; last_valid=1;
        #(`CYCLE)
		@(posedge clk); 
		#(1.0) reset = 1'b1;
		#(10*`CYCLE) reset = 1'b0;
		#(5*`CYCLE)
		while(!stop_all) begin
			@(posedge clk);
			iters = iters+1;
			k = $random(iters)%20;
			if(in_index<=(NUM_OF_PAT-1)) begin	//send LDUX
				#(1.0)
				valid_in = (k>=10);
				data_in = golden_in[in_index];
				in_index = (valid_in)?in_index+1:in_index;
			end
			else begin
				if(last_valid==1) begin
					#(1.0)
					valid_in = 1'b0;
					last_valid = 0;
				end
				if(valid_out && ready) begin
					gold = {golden_out[out_index][111:96], golden_out[out_index][79:64], golden_out[out_index][47:32], golden_out[out_index][15:0]};
					out = {data_out[111:96], data_out[79:64], data_out[47:32], data_out[15:0]};
					if (!(gold === out)) begin
						$display(" Pattern %d failed !. Expected candidate = %h, but the Response candidate = %h !! ", out_index, golden_out[out_index], data_out);
						err_cnt = err_cnt + 1;
					end /*else begin
						$display("Pattern %d is passed !. Expected candidate = %h, Response candidate = %h !! ", out_index, golden_out[out_index], data_out);
					end*/
					out_index = out_index+1;
				end
				if(valid_out) begin
					#(1.0)
					ready = (k>=10);//
				end
			end
        end
				
		#(`CYCLE*2); 
		$display("--------------------------- Simulation Stops !!---------------------------");
		if (err_cnt) begin 
			$display("============================================================================");
			$display("\n (T_T) ERROR found!! There are %d errors in total.\n", err_cnt);
			$display("============================================================================");
		end
		 else begin 
			$display("============================================================================");
			$display("\n");
			$display("        ****************************              ");
			$display("        **                        **        /|__/|");
			$display("        **  Congratulations !!    **      / O,O  |");
			$display("        **                        **    /_____   |");
			$display("        **  Simulation Complete!! **   /^ ^ ^ \\  |");
			$display("        **                        **  |^ ^ ^ ^ |w|");
			$display("        *************** ************   \\m___m__|_|");
			$display("\n");
			$display("============================================================================");
			$finish;
		end
		$finish;
    end
	

	always@(err_cnt) begin
		if (err_cnt >= 10) begin
			$display("============================================================================");
			$display("\n (>_<) ERROR!! There are more than 10 errors during the simulation! Please check your code @@ \n");
			$display("============================================================================");
			$finish;
		end
	end
	
	initial begin 
		#`End_CYCLE;
		$display("================================================================================================================");
		$display("(/`n`)/ ~#  There is something wrong with your code!!"); 
		$display("Time out!! The simulation didn't finish after %d cycles!!, Please check it!!!", `End_CYCLE); 
		$display("================================================================================================================");
		$finish;
	end
endmodule
