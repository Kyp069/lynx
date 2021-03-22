//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for SiDi board by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module lynx
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock27,

	output wire       led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBa,
	output wire[12:0] ramA,

	input  wire       cfgD0,
	input  wire       spiCk,
	input  wire       spiS2,
	input  wire       spiS3,
	input  wire       spiDi,
	output wire       spiDo
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.inclk0 (clock27), // 27 MHz
	.c0     (clock48), // 48 MHz
	.c1     (clock24)  // 24 MHz
);

//-------------------------------------------------------------------------------------------------

wire ramX = status[1];
wire romS = status[2];
wire casM = status[3];

reg rxd, rxp;
always @(posedge clock24) if(ce) begin rxd <= ramX; rxp <= ramX != rxd; end

reg rsd, rsp;
always @(posedge clock24) if(ce) begin rsd <= romS; rsp <= romS != rsd; end

//-------------------------------------------------------------------------------------------------

reg[3:0] pw;
wire power = pw[3];
always @(posedge clock24) if(ce) if(!power) pw <= pw+1'd1;

//-------------------------------------------------------------------------------------------------

reg[4:0] rs;
wire reset = rs[4];
always @(posedge clock24) if(ce) if(!reset) rs <= rs+1'd1; else if(status[0] || rxp || rsp) rs <= 1'd0;

//-------------------------------------------------------------------------------------------------

wire tape = ~ear;

main Main
(
	.clock  (clock24),
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
	.keyPrss(~keyPrss),
	.keyStrb(keyStrb),
	.keyCode(keyCode),
	.joy    (joy    ),
	.ramCs  (ramCs  ),
	.ramWe  (ramWe  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBa  (ramBa  ),
	.ramA   (ramA   )
);

assign ramCk = clock48;
assign ramCe = 1'b1;

//-------------------------------------------------------------------------------------------------

assign led = tape;

assign audio = {2{sound}};

//-------------------------------------------------------------------------------------------------

//reg scandoubler_toggle;
//reg bootd;
//always @(posedge clock) begin bootd <= boot; if(!boot && bootd) scandoubler_toggle <= ~scandoubler_toggle; end

localparam CONF_STR = {
	"Lynx;;",
	"T0,Reset;",
	"O1,RAM,48K,96K;",
	"O2,ROM,Standard,Scorpion;",
	"O3,Bank 2 CAS enable,Off,On;",
	"O45,Scanlines,None,25%,50%,75%;",
	"V,v1.1"
};

wire[31:0] status;
wire[ 7:0] keyCode;

user_io #(.STRLEN(($size(CONF_STR)>>3))) userIo
( 
	.conf_str    (CONF_STR ),
	.clk_sys     (clock24  ),
	.SPI_CLK     (spiCk    ),
	.SPI_SS_IO   (cfgD0    ),
	.SPI_MISO    (spiDo    ),
	.SPI_MOSI    (spiDi    ),
	.status      (status   ),
	.key_pressed (keyPrss  ),
	.key_strobe  (keyStrb  ),
	.key_code    (keyCode  ),
	.scandoubler_disable(scandoubler_disable)
);

mist_video mistVideo
(
	.clk_sys   (clock24    ),
	.SPI_SCK   (spiCk      ),
	.SPI_DI    (spiDi      ),
	.SPI_SS3   (spiS3      ),
	.ce_divider(1'b0       ),
	.no_csync  (1'b0       ),
	.ypbpr     (1'b0       ),
	.rotate    (2'b00      ),
	.blend     (1'b0       ),
	.HSync     (~hSync     ),
	.VSync     (~vSync     ),
	.R         ({6{r}}     ),
	.G         ({6{g}}     ),
	.B         ({6{b}}     ),
	.VGA_VS    (sync[1]    ),
	.VGA_HS    (sync[0]    ),
	.VGA_R     (rgb[17:12] ),
	.VGA_G     (rgb[11: 6] ),
	.VGA_B     (rgb[ 5: 0] ),
	.scanlines (status[5:4]),
	.scandoubler_disable(scandoubler_disable)
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
