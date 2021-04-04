//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for ZX-Uno by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module clock
//-------------------------------------------------------------------------------------------------
(
	input  wire i, // 50.000 MHz
	output wire o, // 24.000 MHz
   output wire o16 // 16.666 MHz
);
//-------------------------------------------------------------------------------------------------


IBUFG IBufg(.I(i), .O(ci));

DCM_SP #
(
	.CLKIN_PERIOD          (20.000),
	.CLKDV_DIVIDE          ( 2.000),
	.CLKFX_DIVIDE          (25    ),
	.CLKFX_MULTIPLY        (12    )
)
Dcm0
(
	.RST                   (1'b0),
	.DSSEN                 (1'b0),
	.PSCLK                 (1'b0),
	.PSEN                  (1'b0),
	.PSINCDEC              (1'b0),
	.CLKIN                 (ci),
	.CLKFB                 (fb),
	.CLK0                  (c0),
	.CLK90                 (),
	.CLK180                (),
	.CLK270                (),
	.CLK2X                 (),
	.CLK2X180              (),
	.CLKFX                 (co),
	.CLKFX180              (),
	.CLKDV                 (),
	.PSDONE                (),
	.LOCKED                (),
	.STATUS                ()
);

BUFG bufgFb(.I(c0), .O(fb));
BUFG bufgO(.I(co), .O(o));

	// clock 16,66Mhz
	reg ce_16m;
	reg [1:0] div3 = 2'b0;

	always @(posedge ci) begin
		if (div3 == 2'b10) begin
			div3 <= 2'b0;
			ce_16m <= 1'b1;
		end
		else begin
			div3 <= div3 +1'b1;
			ce_16m <= 1'b0;
		end
	end

BUFG bufgO16(.I(ce_16m), .O(o16));

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
