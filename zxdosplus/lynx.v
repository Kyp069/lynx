//-------------------------------------------------------------------------------------------------
// Lynx: Lynx 48K/96K/96Kscorpion implementation for ZX-Uno board by Kyp
// https://github.com/Kyp069/lynx
//-------------------------------------------------------------------------------------------------
module lynx
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock50,

	output wire       led,

	//output wire[ 1:0] stdn,
	output wire[ 1:0] sync,
	output wire[ 17:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	input  wire[ 1:0] ps2,
	//input  wire[ 5:0] joy,
   input  wire joyD,  //data
   output wire joyLd, //load
   output wire joyCk, //clock
   input  wire joySl, //select

	output wire       ramUb,
   output wire       ramLb,
   output wire       ramWe,
	inout  wire[ 7:0] ramDQ,
	output wire[20:0] ramA
);
//-------------------------------------------------------------------------------------------------
wire clock, clock16;

clock Clock
(
	.i      (clock50), // 50 MHz
	.o      (clock  ), // 24 MHz
   .o16    (clock16)  // 16,66MHz for zxdos joystick
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
   .video  (videokey),
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

reg f6d, ramX = 1'b1;
always @(posedge clock) if(ce) begin f6d <= f6; if(!f6 && f6d) ramX <= ~ramX; end

reg f7d, romS = 1'b0;
always @(posedge clock) if(ce) begin f7d <= f7; if(!f7 && f7d) romS <= ~romS; end

reg f8d, casM = 1'b0;
always @(posedge clock) if(ce) begin f8d <= f8; if(!f8 && f8d) casM <= ~casM; end

//-------------------------------------------------------------------------------------------------

wire reset = f12 & ctrlRs;
wire boot = f11 & ctrlMb;
wire tape = ~ear;
wire [20:0] ramA_aux;
wire [7:0]  ramDQ_aux;
wire [5:0] joy, joy2;

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
   .joy2   (joy2   ),
	.ramWe  (ramWe_aux ),
	.ramDQ  (ramDQ_aux  ),
	.ramA   (ramA_aux   )
);

reg[3:0] por_r = 4'd0;
wire por_n = por_r[3];
always @(posedge clock) if(!por_n) por_r <= por_r+1'd1;

assign ramA  = (por_n) ? ramA_aux
                : 21'h08FD5 ; //magic place where the scandoubler settings have been stored
assign ramWe = (por_n) ? ramWe_aux : 1'b1;
assign ramDQ = ramDQ_aux;
// Select always lower memory bus
assign ramUb = 1'b1;
assign ramLb = 1'b0;

//-------------------------------------------------------------------------------------------------

reg mb;
always @(posedge clock) mb <= ~mb;

BUFG bufgMB(.I(mb), .O(clockmb));

multiboot Multiboot
(
	.clk_icap  (clockmb),
	.REBOOT    (~boot   )
);



//-------------------------------------------------------------------------------------------------

assign led = tape;

assign audio = {2{sound}};

////assign stdn = 2'b01; // PAL
//wire hsyncaux;
//assign hsyncaux = ~(hSync^vSync);
////assign sync = { 1'b1, ~(hSync^vSync) };
//assign sync = { 1'b1, hsyncaux };
//assign rgb = { {6{r}}, {6{g}}, {6{b}} };

wire hsyncaux;
wire [17:0] vduRGB, rgbSD;
assign vduRGB = { {6{r}}, {6{g}}, {6{b}} };
assign rgb = rgbSD;

reg scndbl_disable = 1'b0;
reg videokey_prev = 1'b1;
always @(posedge clock) begin
   videokey_prev <= videokey;
   if (!por_n) scndbl_disable <= ~ramDQ_aux[0];
   else if (videokey_prev == 1'b0 && videokey == 1'b1) 
      scndbl_disable <= ~scndbl_disable;
end

zxuno_video zxunoVideo
(
	.clk_sys     (clock    ),
	.scanlines   (2'b00),
	.ce_divider  (1'b0       ),
	.R           (vduRGB[17:12]),
	.G           (vduRGB[11: 6]),
	.B           (vduRGB[ 5: 0]),
	.HSync       (~vduHs     ),
	.VSync       (~vduVs     ),
	.VGA_R       (rgbSD[17:12] ),
	.VGA_G       (rgbSD[11: 6] ),
	.VGA_B       (rgbSD[ 5: 0] ),
	.VGA_VS      (sync[1]    ),
	.VGA_HS      (hsyncaux    ),
	.scandoubler_disable(scndbl_disable)
);
assign vduHs = hSync;
assign vduVs = vSync;

assign sync[0] = hsyncaux;

//-Joysticks---------------------------------------------------------------------------------------
  wire [11:0] joy1_aux; //lx25
  wire [11:0] joy2_aux; //lx25
   
  joydecoder joysticks (
      .clk(clock16),
      .joy_data(joyD),
      .joy_clk(joyCk),
      .joy_load_n(joyLd),
      .reset(~reset),
		.hsync_n_s(hsyncaux),
      .joy1_o(joy1_aux), // -- MXYZ SACB RLDU  Negative Logic
      .joy2_o(joy2_aux)  // -- MXYZ SACB RLDU  Negative Logic
   );
assign joySl = hsyncaux;
assign joy = {joy1_aux[4] , joy1_aux[5] , joy1_aux[3:0]};
assign joy2 = {joy2_aux[4] , joy2_aux[5] , joy2_aux[3:0]};

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
