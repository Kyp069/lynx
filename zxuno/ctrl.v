//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for ZX-Uno by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module ctrl
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      ce,
	input  wire[1:0] ps2,
	output wire      keyPrss,
	output reg       keyStrb,
	output reg [7:0] keyCode,
	output wire      reset,
	output wire      boot,
	output reg       f12,
	output reg       f11,
	output reg       f8,
	output reg       f7,
	output reg       f6
);
//-------------------------------------------------------------------------------------------------

reg      ps2c;
reg      ps2d;
reg      ps2e;
reg[7:0] ps2f;

always @(posedge clock) if(ce)
begin
	ps2d <= ps2[1];
	ps2e <= 1'b0;
	ps2f <= { ps2[0], ps2f[7:1] };

	if(ps2f == 8'hFF) ps2c <= 1'b1;
	else if(ps2f == 8'h00)
	begin
		ps2c <= 1'b0;
		if(ps2c) ps2e <= 1'b1;
	end
end

//-------------------------------------------------------------------------------------------------

reg parity;

reg[8:0] data;
reg[3:0] count;

always @(posedge clock) if(ce)
begin
	keyStrb <= 1'b0;

	if(ps2e) begin
		if(count == 4'd0) begin
			parity <= 1'b0;
			if(!ps2d) count <= count+4'd1;
		end
		else begin
			if(count < 4'd10) begin
				data <= { ps2d, data[8:1] };
				count <= count+4'd1;
				parity <= parity ^ ps2d;
			end
			else if(ps2d) begin
				count <= 4'd0;
				if(parity) begin
					keyCode <= data[7:0];
					keyStrb <= 1'b1;
				end
			end
			else count <= 0;
		end
	end
end

//-------------------------------------------------------------------------------------------------
initial begin
	f12 = 1'b1;
	f11 = 1'b1;
	f8 = 1'b1;
	f7 = 1'b1;
	f6 = 1'b1;
end
	
reg alt = 1'b1;
reg del = 1'b1;
reg ctrl = 1'b1;
reg backspace = 1'b1;

reg pressed;

always @(posedge clock) if(ce)
if(keyStrb)
	if(keyCode == 8'hF0) pressed <= 1'b1;
	else
	begin
		pressed <= 1'b0;

		case(keyCode)
			8'h0B: f6        <= pressed;
			8'h83: f7        <= pressed;
			8'h0A: f8        <= pressed;
			8'h78: f11       <= pressed;
			8'h07: f12       <= pressed;

			8'h11: alt       <= pressed;
			8'h71: del       <= pressed;
			8'h14: ctrl      <= pressed;
			8'h66: backspace <= pressed;
		endcase
	end

//-------------------------------------------------------------------------------------------------

assign keyPrss = pressed;
assign reset = ctrl | alt | backspace;
assign boot  = ctrl | alt | del;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
