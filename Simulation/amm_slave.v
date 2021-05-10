`timescale 1ns/10ps
module amm_slave #(
	parameter DDR_DATA_WIDTH   = 64,
	parameter DDR_ADDR_WIDTH   = 32
)
(
	input clk,
	input rst,
	output reg local_init_done,
	output reg amm_wait,
	input [DDR_ADDR_WIDTH-1:0] amm_addr,
	output amm_rvalid,
	output reg [DDR_DATA_WIDTH-1:0] amm_rdata,
	input [DDR_DATA_WIDTH-1:0] amm_wdata,
	input amm_ren,
	input amm_wen,
	input [5:0] amm_burstcount
);

	parameter NUM_OF_PAT = 65536/4;
	parameter MEM_ADDR_WIDTH = $clog2(NUM_OF_PAT);

	reg r_en, w_en;
	reg [DDR_ADDR_WIDTH-1:0] mem_addr;
	reg [DDR_DATA_WIDTH-1:0] data_in;
	wire [DDR_DATA_WIDTH-1:0] data_out;

	reg rvalid, rvalid_nxt;
	reg ren, wen, ren_nxt, wen_nxt;
	reg [DDR_ADDR_WIDTH-1:0] addr, addr_nxt;
	assign amm_rvalid = rvalid;

	ddr_mem #(DDR_DATA_WIDTH, MEM_ADDR_WIDTH) ddr_a_mem (
		.CLK(clk), 
		.r_en       (r_en), 
		.w_en       (w_en), 
		.mem_addr   (mem_addr), 
		.mem_in     (data_in), 
		.mem_out    (data_out)
	);

	reg [1:0] STATE, STATE_N;
	localparam IDLE = 0;
	localparam WAIT = 1;
	localparam FREE = 2;
	//localparam READ = 2;
	//localparam WRITE = 3;

	integer i, j;
	reg [31:0] iter1, iter2, iter1_nxt, iter2_nxt;

	always@(*) begin

		STATE_N = STATE;
		ren_nxt = ren;
		wen_nxt = wen;
		addr_nxt = addr;
		rvalid_nxt = 0;

		local_init_done = 1;
		mem_addr = 0;
		amm_wait = 0;
		r_en = 0;
		w_en = 0;
		data_in = 0;
		amm_rdata = 0;

		iter1_nxt = iter1 + 1;
		i = $abs($random())%20;
		iter2_nxt = iter2 + 1;
		j = $abs($random())%20;

		case(STATE)
			IDLE: begin
				local_init_done = i >= 2;
				ren_nxt = amm_ren;
				addr_nxt = amm_addr;
				wen_nxt = amm_wen;
				if(amm_ren && amm_wen) begin 
					$display("ERROR!!! Simultaneous amm_ren and amm_wen!");
					#50;
					$finish;
				end
				else if(amm_ren) begin
					if(j >= 10 || !local_init_done) begin
						STATE_N = WAIT;
						amm_wait = 1'b1;
					end
					else begin
						STATE_N = FREE;
						rvalid_nxt = 1;
						amm_wait = 1'b1;
					end
					mem_addr = amm_addr;
					r_en = 1;
				end
				else if(amm_wen) begin
					if(j >= 10 || !local_init_done) begin
						STATE_N = WAIT;
						amm_wait = 1'b1;
					end
					else begin
						STATE_N = FREE;
						amm_wait = 1'b1;
					end
					mem_addr = amm_addr;
					w_en = 1;
					data_in = amm_wdata;
				end
				else begin
					STATE_N = IDLE;
					amm_wait = 0;
				end
			end
			WAIT: begin
				local_init_done = 1;
				amm_wait = 1'b1;
				ren_nxt = amm_ren;
				addr_nxt = amm_addr;
				wen_nxt = amm_wen;
				if(amm_ren && amm_wen) begin 
					$display("ERROR!!! Simultaneous amm_ren and amm_wen!");
					#50;
					$finish;
				end
				else if(amm_ren) begin
					if(amm_ren != ren || amm_addr != addr) begin
						$display("ERROR!!! Singals amm_ren and amm_addr should hold in wait state!");
						#50;
						$finish;
					end
					if(j >= 10 || !local_init_done) begin
						STATE_N = WAIT;
					end
					else begin
						STATE_N = FREE;
						rvalid_nxt = 1;
					end
					mem_addr = amm_addr;
					r_en = 1;
				end
				else if(amm_wen) begin
					if(amm_wen != wen || amm_addr != addr) begin
						$display("ERROR!!! Singals amm_wen and amm_addr should hold in wait state!");
						#50;
						$finish;
					end
					if(j >= 10 || !local_init_done) begin
						STATE_N = WAIT;
					end
					else begin
						STATE_N = FREE;
					end
				end
				else begin
					$display("ERROR!!! Signals amm_ren or amm_wen should hold in wait state!");
					#50;
					$finish;
				end
			end
			FREE: begin
				STATE_N = IDLE;
				amm_wait = 0;
				mem_addr = addr;
				local_init_done = 1;
				if(amm_ren && amm_wen) begin 
					$display("ERROR!!! Simultaneous amm_ren and amm_wen!");
					//#50;
					$finish;
				end
				else if(ren) begin
					if(amm_ren != ren || amm_addr != addr) begin
						$display("ERROR!!! Singals amm_ren and amm_addr should hold in wait state!");
						#50;
						$finish;
					end
				end
				else if(wen) begin
					if(amm_wen != wen || amm_addr != addr) begin
						$display("ERROR!!! Singals amm_wen and amm_addr should hold in wait state!");
						#50;
						$finish;
					end
				end
				else begin
					$display("ERROR!!! Signals amm_ren or amm_wen should hold in wait state!");
					#50;
					$finish;
				end
				if(rvalid) begin
					amm_rdata = data_out;
				end
			end
		endcase
	end

	always@(posedge clk or posedge rst) begin
		if(rst) begin
			STATE <= IDLE;
			ren <= 0;
			wen <= 0;
			addr <= 0;
			rvalid <= 0;
			iter1 <= 31'd33;
			iter2 <= 31'd10000;
		end
		else begin
			STATE <= STATE_N;
			ren <= ren_nxt;
			wen <= wen_nxt;
			addr <= addr_nxt;
			rvalid <= rvalid_nxt;
			iter1 <= iter1_nxt;
			iter2 <= iter2_nxt;
		end
	end

endmodule

module ddr_mem
#(parameter DATA_WIDTH=128, parameter ADDR_WIDTH=7)
(
	input [(DATA_WIDTH-1):0] mem_in,
	input [(ADDR_WIDTH-1):0] mem_addr,
	input w_en, r_en, CLK,
	output reg [(DATA_WIDTH-1):0] mem_out
);

	// Declare the RAM variable
	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

	// Port A 
	always @ (posedge CLK)
	begin
		if (w_en) begin
			ram[mem_addr] <= mem_in;
		end 
	end 

	// Port B 
	always @ (posedge CLK)
	begin
		if (r_en) begin
			mem_out <= ram[mem_addr];
		end 
	end

endmodule