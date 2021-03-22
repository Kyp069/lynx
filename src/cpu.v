//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       reset,
	input  wire       clock,
	input  wire       pe,
	input  wire       ne,
	input  wire       mi,
	output wire       rfsh,
	output wire       mreq,
	output wire       iorq,
	output wire       rd,
	output wire       wr,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	output wire[15:0] a
);

T80pa Cpu
(
	.CLK    (clock),
	.CEN_p  (pe   ),
	.CEN_n  (ne   ),
	.RESET_n(reset),
	.BUSRQ_n(1'b1 ),
	.WAIT_n (1'b1 ),
	.BUSAK_n(     ),
	.HALT_n (     ),
	.RFSH_n (rfsh ),
	.MREQ_n (mreq ),
	.IORQ_n (iorq ),
	.NMI_n  (1'b1 ),
	.INT_n  (mi   ),
	.M1_n   (     ),
	.RD_n   (rd   ),
	.WR_n   (wr   ),
	.A      (a    ),
	.DI     (d    ),
	.DO     (q    ),
	.OUT0   (1'b0 ),
	.REG    (     ),
	.DIRSet (1'b0 ),
	.DIR    (212'd0)
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
