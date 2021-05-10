`timescale 1ns/10ps
module dram_wrapper #(
	parameter C_PCI_DATA_WIDTH = 9'd32,
	parameter DDR_DATA_WIDTH   = 64,
	parameter DDR_ADDR_WIDTH   = 32
)
(clk, rst, data_in, valid_in, numData, data_out, valid_out, ready,
 local_init_done,
 amm_wait,
 amm_addr,
 amm_rvalid,
 amm_rdata,
 amm_wdata,
 amm_ren,
 amm_wen,
 amm_burstcount
 );

  /* ============================================ */
    input           	clk;
    input           	rst;
    input  [127:0]		data_in;
    input   		  	valid_in;
	input  [19:0]		numData;
    input   		  	ready;

    output reg [127:0]	data_out;
	output reg 			valid_out;

	//DDR interface
	input  local_init_done;
	input  amm_wait;
	output reg [DDR_ADDR_WIDTH-1:0] amm_addr;
	input  amm_rvalid;
	input  [DDR_DATA_WIDTH-1:0] amm_rdata;
	output reg [DDR_DATA_WIDTH-1:0] amm_wdata;
	output reg amm_ren;
	output reg amm_wen;
	output [5:0] amm_burstcount;

	assign amm_burstcount = 1;
	  
	localparam NUM_OF_PAT = 65536/4;
	localparam MEM_ADDR_WIDTH = $clog2(NUM_OF_PAT);
	  
	localparam RECI = 0;
	localparam TRAN1 = 1;
	localparam TODDR = 2;
	localparam TORAM = 3;
	localparam TRAN2 = 4;
	localparam SEND = 5;
	  
	reg  						UX_r_en     [0:1];
	reg  [MEM_ADDR_WIDTH-1:0]	UX_in_addr  [0:1];	//write in
	reg  [MEM_ADDR_WIDTH-1:0]	UX_out_addr [0:1];	//read out
	reg  					 	UX_w_en     [0:1];
	reg  [127:0]  				UX_in       [0:1];
	wire [127:0]  				UX_out      [0:1];

    reg [2:0]	state, state_nxt;
	reg [MEM_ADDR_WIDTH+1:0]	counter1,  counter1_nxt;
	reg [MEM_ADDR_WIDTH+1:0]	counter2,  counter2_nxt;

	integer i;

  /* ============================================ */
    always@(*) begin
    	for(i = 0; i < 2; i = i + 1) begin
			UX_r_en[i] = 0;
			UX_in_addr[i] = 0;
			UX_out_addr[i] = 0;
			UX_w_en[i] = 0;
			UX_in[i] = 128'd0;
		end
		state_nxt = state;
		counter1_nxt = counter1;
		counter2_nxt = counter2;
		valid_out = 0;
		data_out  = 0;

		amm_addr = 0;
		amm_wdata = 0;
		amm_ren = 0;
		amm_wen = 0;

		case(state)
			RECI: begin
				if(valid_in) begin
					counter1_nxt = counter1 + 1;
					UX_w_en[0] = 1'b1;	//first (NUM_OF_PAT) data : a
					UX_in_addr[0] = counter1[MEM_ADDR_WIDTH-1:0];
					UX_in[0] = data_in;
					if(counter1 == (numData - 1)) begin
						state_nxt   = TRAN1;
						counter1_nxt = 0;
						//read from block RAM (for tran)
					end
				end
			end
			TRAN1: begin
				UX_r_en[0]     = 1;
				UX_out_addr[0] = counter1;
				state_nxt = TODDR;
			end
			TODDR: begin
				UX_r_en[0]     = 1;
				UX_out_addr[0] = counter1;
				amm_wdata = {UX_out[0][111:96], UX_out[0][79:64], UX_out[0][47:32], UX_out[0][15:0]};
				amm_wen = local_init_done ? 1'b1 : 1'b0;
				amm_addr = counter1;
				if(~amm_wait && local_init_done) begin
					counter1_nxt = counter1 + 1;
					UX_out_addr[0] = counter1_nxt;
					if(counter1 == (numData - 1)) begin
						state_nxt = TORAM;
						counter1_nxt = numData - 1;
					end
				end
				counter2_nxt = 0;
			end
			TORAM: begin
				amm_ren = local_init_done && counter1 < numData ? 1'b1 : 1'b0;
				amm_addr = counter1;
				if(~amm_wait && local_init_done) begin
					counter1_nxt = counter1 - 1;
				end
				if(amm_rvalid) begin
					counter2_nxt = counter2 + 1;
					UX_w_en[1] = 1'b1;	//first (NUM_OF_PAT) data : a
					UX_in_addr[1] = counter2[MEM_ADDR_WIDTH-1:0];
					UX_in[1] = {16'd0, amm_rdata[63:48], 16'd0, amm_rdata[47:32], 16'd0, amm_rdata[31:16], 16'd0, amm_rdata[15:0]};
					if(counter2 == (numData - 1)) begin
						state_nxt   = TRAN2;
						counter2_nxt = 0;
						//read from block RAM (for tran)
					end
				end
			end
			TRAN2: begin
				UX_r_en[1]     = 1;
				UX_out_addr[1] = 0;
				state_nxt = SEND;
			end
			SEND: begin
				valid_out = 1;
				data_out  = {UX_out[1][31:0], UX_out[1][63:32], UX_out[1][95:64], UX_out[1][127:96]};
				//read from block RAM (for send)
				UX_r_en[1]     = 1;
				UX_out_addr[1] = counter2[MEM_ADDR_WIDTH-1:0];
				if(ready) begin
					counter2_nxt = counter2 + 1;
					UX_out_addr[1] = counter2_nxt[MEM_ADDR_WIDTH-1:0];
				end
			end
        endcase
    end

  /* ============================================ */
    always@(posedge clk or posedge rst)
    begin
        if (rst) begin
			state 	<= RECI;
			counter1 <= 0;
			counter2 <= 0;
		end
        else begin
			state 	<= state_nxt;
			counter1 <= counter1_nxt;
			counter2 <= counter2_nxt;
        end
    end
  /* ============================================ */  
  
    data_mem #(128, MEM_ADDR_WIDTH) data_a_mem (
		.CLK(clk), 
		.w_en       (UX_w_en[0]), 
		.mem_in     (UX_in[0]), 
		.mem_addr_i (UX_in_addr[0]), 
		.r_en       (UX_r_en[0]), 
		.mem_out    (UX_out[0]),
		.mem_addr_o (UX_out_addr[0])
	);

	data_mem #(128, MEM_ADDR_WIDTH) data_b_mem (
		.CLK(clk), 
		.w_en       (UX_w_en[1]), 
		.mem_in     (UX_in[1]), 
		.mem_addr_i (UX_in_addr[1]), 
		.r_en       (UX_r_en[1]), 
		.mem_out    (UX_out[1]),
		.mem_addr_o (UX_out_addr[1])
	);

endmodule

//==============================================================================//

// Quartus II Verilog Template
// True Dual Port RAM with single clock
module data_mem
#(parameter DATA_WIDTH=128, parameter ADDR_WIDTH=7)
(
	input [(DATA_WIDTH-1):0] mem_in,
	// input [(DATA_WIDTH-1):0] data_b,
	input [(ADDR_WIDTH-1):0] mem_addr_i, mem_addr_o,
	input w_en, r_en, CLK,
	// output reg [(DATA_WIDTH-1):0] q_a,
	output reg [(DATA_WIDTH-1):0] mem_out
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	// Port A 
	always @ (posedge CLK)
	begin
		if (w_en) begin
			ram[mem_addr_i] <= mem_in;
		end 
	end 

	// Port B 
	always @ (posedge CLK)
	begin
		if (r_en) begin
			mem_out <= ram[mem_addr_o];
		end 
	end

endmodule
