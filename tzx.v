//-------------------------------------------------------------------------------------------------
// tzx_sd - reproductor de cintas TZX/CDT leídas directamente de la SD, por sectores
// Shaeon (Carlos Palmero) y Kyp (Kyp069). Libre para cualquier core.
//
// Para cualquier ordenador que use cintas TZX (o CDT, que es el mismo formato): Spectrum, Amstrad
// CPC, Enterprise, Lynx, MSX... El fichero se monta como una imagen de disco (en MiST/SiDi/Calypso
// "S<n>U,TZXCDT,Mount tape;", en MiSTer igual con hps_io) y no se carga en memoria: el módulo pide
// al firmware los sectores de 512 bytes que necesita y los guarda en una caché de 2 sectores
// (1 KB de BRAM). Mientras se reproduce un sector, pide por adelantado el siguiente, así que la
// cinta no espera a la SD salvo al volver atrás en un bucle.
//
// Necesita tzxplayer.vhd (György Szombathelyi), que convierte los bloques TZX en la señal de la
// cinta. Las duraciones de los bloques TZX están en T-estados de 3,5 MHz para todas las máquinas;
// tzxplayer los convierte al reloj del core con TZX_MS (pulsos de ce por milisegundo).
//
// Mandos (pulsos de un ciclo, o niveles: se detecta el flanco de subida):
//   play    arranca o sigue desde donde se paró (si la cinta había llegado al final, desde el
//           principio)
//   stop    pausa (al pulsar play sigue desde ahí)
//   rewind  para y vuelve al principio
//   motor   control remoto del motor del ordenador (CPC, MSX, Enterprise...): con motor = 0 la
//           cinta no avanza aunque esté en play. Los cores sin control de motor lo ponen a 1.
//   stop48  1: el bloque 0x2A ("parar si es un 48K") para la cinta; solo tiene sentido en Spectrum.
// Los bloques 0x20 con pausa 0 ("parar la cinta") la paran; al pulsar play sigue.
//
// Conexión con el firmware:
//   - MiST/SiDi/Calypso (user_io): sd_ack debe ser el ack de ESTA imagen (sd_ack_x[n]), y la
//     multiplexación de sd_lba / sd_rd con las demás imágenes la hace el core.
//   - MiSTer (hps_io): sd_lba[n], sd_rd[n], sd_ack[n] de esta unidad, con BLKSZ de 512 bytes.
//   El último sector de casi todos los TZX está incompleto: hace falta un firmware que lo lea
//   (mist-firmware desde el commit 002146a, calypso-firmware desde la versión que lo incluye).
//-------------------------------------------------------------------------------------------------
module tzx
#(
	parameter TZX_MS = 56000,             // pulsos de ce por milisegundo (reloj en kHz si ce = 1).
	                                      // Si pasa de 65535, el módulo divide ce internamente

	// duraciones del bloque estándar 0x10 (en T-estados de 3,5 MHz). Por defecto, las de la ROM
	// del Spectrum. Para Amstrad CPC: 2000, 855, 855, 855, 1710, 4095, 4095.
	parameter NORMAL_PILOT_LEN    = 2168,
	parameter NORMAL_SYNC1_LEN    = 667,
	parameter NORMAL_SYNC2_LEN    = 735,
	parameter NORMAL_ZERO_LEN     = 855,
	parameter NORMAL_ONE_LEN      = 1710,
	parameter HEADER_PILOT_PULSES = 8063,
	parameter NORMAL_PILOT_PULSES = 3223
)
(
	input  wire       clock,
	input  wire       ce,                 // habilitación de reloj de tzxplayer (1 si no hace falta)

	// imagen montada (user_io / hps_io)
	input  wire       img_mounted,        // pulso al montar una imagen en esta unidad
	input  wire[31:0] img_size,           // válido en el ciclo de img_mounted
	output reg [31:0] sd_lba = 32'd0,
	output reg        sd_rd = 1'b0,
	input  wire       sd_ack,             // ack de esta imagen
	input  wire[ 8:0] sd_buff_addr,
	input  wire[ 7:0] sd_buff_dout,
	input  wire       sd_buff_wr,

	// mandos
	input  wire       play,
	input  wire       stop,
	input  wire       rewind,
	input  wire       motor,
	input  wire       stop48,

	// estado
	output wire       tape,               // señal de la cinta (nivel EAR / datos de casete)
	output wire       busy,               // la cinta está girando
	output reg        playing = 1'b0,     // play pulsado (aunque el motor del ordenador esté parado)
	output reg        valid = 1'b0,       // hay montado un TZX/CDT válido
	output wire[31:0] pos,                // byte del fichero por el que va (para una barra de progreso)
	output wire[31:0] size,
	output wire       loading             // leyendo un sector de la SD (para un LED)
);
//--- flancos de los mandos -----------------------------------------------------------------------

	reg playP = 1'b0, stopP = 1'b0, rewP = 1'b0;
	always @(posedge clock) begin playP <= play; stopP <= stop; rewP <= rewind; end
	wire playE = play && !playP;
	wire stopE = stop && !stopP;
	wire rewE  = rewind && !rewP;

//--- caché de 2 sectores -------------------------------------------------------------------------

	reg [7:0] cache[0:1023];              // slot 0: 0-511, slot 1: 512-1023
	reg [9:0] cRa;
	reg [7:0] cQ;
	reg       wSlot;                      // slot que se está llenando
	always @(posedge clock) begin
		if(sd_ack && sd_buff_wr) cache[{ wSlot, sd_buff_addr }] <= sd_buff_dout;
		cQ <= cache[cRa];
	end

	reg [22:0] tag[0:1];                  // sector guardado en cada slot (ficheros de hasta 4 GB)
	reg  [1:0] valid_s = 2'b00;
	reg [31:0] fsize = 32'd0;
	reg        mounted = 1'b0;
	reg        ld = 1'b0;                 // lectura de un sector en curso
	reg        ackP = 1'b0;
	reg        sigOk = 1'b0;

	assign loading = ld;
	assign size = fsize;

	wire[22:0] lastSec = fsize[31:9] - { 22'd0, fsize[8:0] == 9'd0 };

	function [7:0] tzxSig(input [2:0] i);   // "ZXTape!" + 0x1A (TZX y CDT)
		case(i)
			0: tzxSig = "Z"; 1: tzxSig = "X"; 2: tzxSig = "T"; 3: tzxSig = "a";
			4: tzxSig = "p"; 5: tzxSig = "e"; 6: tzxSig = "!"; default: tzxSig = 8'h1A;
		endcase
	endfunction

//--- servidor de bytes ---------------------------------------------------------------------------

	// petición de un byte: rReq != rAck; dirección rA; dato en rQ
	reg        rReq = 1'b0, rAck = 1'b0;
	reg [31:0] rA;
	reg  [7:0] rQ;
	reg  [1:0] rLat = 2'd0;
	reg        rBusy = 1'b0;
	reg [22:0] curSec = 23'd0;            // último sector servido (para la lectura adelantada)

	wire[22:0] reqSec = rA[31:9];
	wire       hit0 = valid_s[0] && tag[0] == reqSec;
	wire       hit1 = valid_s[1] && tag[1] == reqSec;
	wire       nxtCached = (valid_s[0] && tag[0] == curSec+1'd1) || (valid_s[1] && tag[1] == curSec+1'd1);
	wire       freeSlot = (valid_s[0] && tag[0] == curSec) ? 1'b1 : 1'b0;   // el que no tiene el actual

	task load(input [22:0] sec, input slot);
		begin
			sd_lba <= { 9'd0, sec };
			sd_rd <= 1'b1;
			wSlot <= slot;
			valid_s[slot] <= 1'b0;
			tag[slot] <= sec;
			ld <= 1'b1;
		end
	endtask

	always @(posedge clock) begin
		ackP <= sd_ack;

		if(img_mounted) begin
			// imagen nueva (o desmontada, con tamaño 0): vacía la caché y lee el sector 0
			fsize <= img_size;
			mounted <= img_size != 0;
			valid_s <= 2'b00;
			sd_rd <= 1'b0;
			ld <= 1'b0;
			curSec <= 23'd0;
			valid <= 1'b0;
			if(img_size != 0) begin sigOk <= 1'b1; load(23'd0, 1'b0); end
		end
		else begin
			if(ld) begin
				if(sd_ack) sd_rd <= 1'b0;
				// formato: los 8 primeros bytes del sector 0
				if(sd_ack && sd_buff_wr && tag[wSlot] == 0 && sd_buff_addr < 8 && sd_buff_dout != tzxSig(sd_buff_addr[2:0]))
					sigOk <= 1'b0;
				if(ackP && !sd_ack) begin
					valid_s[wSlot] <= 1'b1;
					ld <= 1'b0;
					if(tag[wSlot] == 0) valid <= sigOk && fsize >= 10;
				end
			end

			if(rReq != rAck && !rBusy) begin
				if(hit0 || hit1) begin
					cRa <= { hit1, rA[8:0] };
					curSec <= reqSec;
					rLat <= 2'd2;
					rBusy <= 1'b1;
				end
				else if(!ld) load(reqSec, freeSlot);
			end
			else if(rBusy) begin
				if(rLat != 2'd0) rLat <= rLat-1'd1;
				else begin rQ <= cQ; rAck <= rReq; rBusy <= 1'b0; end
			end
			else if(!ld && mounted && curSec < lastSec && !nxtCached)
				load(curSec+1'd1, freeSlot);
		end
	end

//--- tzxplayer -----------------------------------------------------------------------------------

	wire       req;
	reg        ack = 1'b0;
	reg        restart = 1'b0;
	reg  [7:0] data;
	reg [31:0] a = 32'd0, loopA = 32'd0;
	reg        fetch = 1'b0;
	reg        ended = 1'b0;              // la cinta ha llegado al final del fichero
	wire       eot, eot48, loopStart, loopNext;

	assign pos = a;

	// tzxplayer cuenta los milisegundos con 16 bits: con TZX_MS > 65535 (relojes de más de 65 MHz
	// con ce = 1) se le da un ce dividido entre 2, 4 u 8
	localparam integer CEDIV = TZX_MS > 262140 ? 8 : TZX_MS > 131070 ? 4 : TZX_MS > 65535 ? 2 : 1;
	reg [2:0] ceCnt = 3'd0;
	localparam [2:0] CEMAX = CEDIV-1;
	always @(posedge clock) if(ce) ceCnt <= ceCnt == CEMAX ? 3'd0 : ceCnt+1'd1;
	wire tzxCe = ce && ceCnt == 3'd0;

	tzxplayer
	#(
		.TZX_MS             (TZX_MS / CEDIV     ),
		.NORMAL_PILOT_LEN   (NORMAL_PILOT_LEN   ),
		.NORMAL_SYNC1_LEN   (NORMAL_SYNC1_LEN   ),
		.NORMAL_SYNC2_LEN   (NORMAL_SYNC2_LEN   ),
		.NORMAL_ZERO_LEN    (NORMAL_ZERO_LEN    ),
		.NORMAL_ONE_LEN     (NORMAL_ONE_LEN     ),
		.HEADER_PILOT_PULSES(HEADER_PILOT_PULSES),
		.NORMAL_PILOT_PULSES(NORMAL_PILOT_PULSES)
	)
	tzxplayer
	(
		.clk         (clock             ),
		.ce          (tzxCe             ),
		.restart_tape(restart           ),
		.host_tap_in (data              ),
		.tzx_req     (req               ),
		.tzx_ack     (ack               ),
		.loop_start  (loopStart         ),
		.loop_next   (loopNext          ),
		.stop        (eot               ),
		.stop48k     (eot48             ),
		.cass_read   (tape              ),
		.cass_motor  (playing && motor  ),
		.cass_running(busy              )
	);

	always @(posedge clock) begin
		restart <= 1'b0;

		// byte servido
		if(fetch && rReq == rAck) begin data <= rQ; ack <= req; a <= a+1'd1; fetch <= 1'b0; end

		// tzxplayer pide un byte: solo se le da en play, así la cinta se para en el acto (en el
		// límite de un byte) con stop o con un bloque de parada, aunque tzxplayer simule la inercia
		// del motor durante 50 ms (que se mantiene para el control remoto del motor)
		if(playing && !fetch && rReq == rAck && req != ack && !loopStart && !loopNext && !restart) begin
			if(a < fsize) begin rA <= a; rReq <= ~rReq; fetch <= 1'b1; end
			else begin playing <= 1'b0; ended <= 1'b1; end   // final del fichero
		end

		if(img_mounted || rewE) begin
			// imagen nueva o rebobinar: al principio y parada
			a <= 32'd0;
			restart <= 1'b1;
			playing <= 1'b0;
			ended <= 1'b0;
			fetch <= 1'b0;
		end
		else if(playE && valid && mounted) begin
			playing <= 1'b1;
			if(ended) begin a <= 32'd0; restart <= 1'b1; ended <= 1'b0; fetch <= 1'b0; end
		end
		else if(stopE || eot || (eot48 && stop48)) playing <= 1'b0;
		else if(loopStart) loopA <= a;
		else if(loopNext)  a <= loopA;
	end

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
