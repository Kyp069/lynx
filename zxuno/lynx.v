//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for ZX-Uno board by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module lynx
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire       led,

	output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 8:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	input  wire[ 1:0] ps2,
	input  wire[ 5:0] joy,

	output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.i      (clock50), // 50 MHz
	.o      (clock  )  // 24 MHz
);

//-------------------------------------------------------------------------------------------------

wire[7:0] keyCode;

ctrl Ctrl
(
	.clock  (clock  ),
	.ce     (ce     ),
	.ps2    (ps2    ),
	.keyPrss(keyPrss),
	.keyStrb(keyStrb),
	.keyCode(keyCode),
	.reset  (ctrlRs ),
	.boot   (ctrlMb ),
	.f12    (f12    ),
	.f11    (f11    ),
	.f8     (f8     ),
	.f7     (f7     ),
	.f6     (f6     )
);

//-------------------------------------------------------------------------------------------------

reg[3:0] pw;
wire power = pw[3];
always @(posedge clock) if(ce) if(!power) pw <= pw+1'd1; else if(!f6 || !f7) pw <= 1'd0;

//-------------------------------------------------------------------------------------------------

reg f6d, ramX;
always @(posedge clock) if(ce) begin f6d <= f6; if(!f6 && f6d) ramX <= ~ramX; end

reg f7d, romS;
always @(posedge clock) if(ce) begin f7d <= f7; if(!f7 && f7d) romS <= ~romS; end

reg f8d, casM;
always @(posedge clock) if(ce) begin f8d <= f8; if(!f8 && f8d) casM <= ~casM; end

//-------------------------------------------------------------------------------------------------

wire reset = f12 & ctrlRs;
wire boot = f11 & ctrlMb;
wire tape = ~ear;

main Main
(
	.clock  (clock  ),
	.power  (power  ),
	.reset  (reset  ),
	.ce     (ce     ),
	.ramX   (ramX   ),
	.romS   (romS   ),
	.casM   (casM   ),
	.hSync  (hSync  ),
	.vSync  (vSync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.tape   (tape   ),
	.sound  (sound  ),
	.keyPrss(keyPrss),
	.keyStrb(keyStrb),
	.keyCode(keyCode),
	.joy    (joy    ),
	.ramWe  (ramWe  ),
	.ramDQ  (ramDQ  ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

reg mb;
always @(posedge clock) mb <= ~mb;

BUFG bufgMB(.I(mb), .O(clockmb));

multiboot Multiboot
(
	.clock  (clockmb),
	.boot   (boot   )
);

//-------------------------------------------------------------------------------------------------

assign led = tape;

assign audio = {2{sound}};

assign stdn = 2'b01; // PAL
assign sync = { 1'b1, ~(hSync^vSync) };
assign rgb = { {3{r}}, {3{g}}, {3{b}} };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
