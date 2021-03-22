//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module video
//-------------------------------------------------------------------------------------------------
(
	input  wire      clock,
	input  wire      hSync,
	input  wire      ce,
	input  wire      de,
	input  wire      altg,
	input  wire[7:0] d,
	output wire      r,
	output wire      g,
	output wire      b,
	output wire[1:0] bank
);
//-------------------------------------------------------------------------------------------------

reg[2:0] hCount;
always @(posedge clock) if(hSync) hCount <= 1'd0; else if(ce) hCount <= hCount+1'd1;

reg[7:0] redInput;
wire redInputLoad = hCount == 3 && de;
always @(posedge clock) if(ce) if(redInputLoad) redInput <= d;

reg[7:0] blueInput;
wire blueInputLoad = hCount == 1 & de;
always @(posedge clock) if(ce) if(blueInputLoad) blueInput <= d;

reg[7:0] greenInput;
wire greenInputLoad = hCount == 5 & de;
always @(posedge clock) if(ce) if(greenInputLoad) greenInput <= d;

reg[7:0] redOutput;
reg[7:0] blueOutput;
reg[7:0] greenOutput;
wire dataOutputLoad = hCount == 7 && de;

always @(posedge clock) if(ce)
if(dataOutputLoad)
begin
	redOutput <= redInput;
	blueOutput <= blueInput;
	greenOutput <= greenInput;
end
else
begin
	redOutput <= { redOutput[6:0], 1'b0 };
	blueOutput <= { blueOutput[6:0], 1'b0 };
	greenOutput <= { greenOutput[6:0], 1'b0 };
end

//-------------------------------------------------------------------------------------------------

assign r = redOutput[7];
assign g = greenOutput[7];
assign b = blueOutput[7];
assign bank = { hCount[2], hCount[1]|(hCount[2]&~altg) };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
