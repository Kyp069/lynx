//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module dprf
//-------------------------------------------------------------------------------------------------
#
(
	parameter KB = 0,
	parameter DW = 8,
	parameter FN = ""
)
(
	input  wire                      clock1,
//	input  wire                      ce1,
	input  wire                      we1,
	input  wire[             DW-1:0] d1,
	output reg [             DW-1:0] q1,
	input  wire[$clog2(KB*1024)-1:0] a1,
	input  wire                      clock2,
//	input  wire                      ce2,
	input  wire                      we2,
	input  wire[             DW-1:0] d2,
	output reg [             DW-1:0] q2,
	input  wire[$clog2(KB*1024)-1:0] a2
);
//-------------------------------------------------------------------------------------------------

reg[DW-1:0] dpr[(KB*1024)-1:0];
initial if(FN != "") $readmemh(FN, dpr, 0);

always @(posedge clock1) begin q1 <= dpr[a1]; if(we1) dpr[a1] <= d1; end
always @(posedge clock2) begin q2 <= dpr[a2]; if(we2) dpr[a2] <= d2; end

/*
module true_dual_port_ram_single_clock
#(parameter DATA_WIDTH=8, parameter ADDR_WIDTH=6)
(
input [(DATA_WIDTH-1):0] data_a, data_b,
input [(ADDR_WIDTH-1):0] addr_a, addr_b,
input we_a, we_b, clk,
output reg [(DATA_WIDTH-1):0] q_a, q_b
);

// Declare the RAM variable

reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];

// Port A
always @ (posedge clk)
begin
	if (we_a)
	begin
		ram[addr_a] = data_a;
	end
	q_a <= ram[addr_a];
end

// Port B
always @ (posedge clk)
begin
	if (we_b)
	begin
		ram[addr_b] = data_b;
	end
	q_b <= ram[addr_b];
end

endmodule
*/
//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
