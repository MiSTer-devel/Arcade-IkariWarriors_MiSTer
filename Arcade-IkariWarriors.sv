//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//USER_OUT
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`default_nettype none

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
//assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = status[14];
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

//assign LED_DISK = 0;
//assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
wire [1:0] ar = status[9:8];
wire orientation = ~status[10];
wire [2:0] scan_lines = status[6:4];
wire        direct_video;
wire forced_scandoubler;
wire [21:0] gamma_bus;

assign VIDEO_ARX = (!ar) ? (orientation  ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (orientation  ? 8'd3 : 8'd4) : 12'd0;


// Status Bit Map:
//             Upper                             Lower              
// 0         1         2         3          4         5         6   
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
// X   XXX XXXX  XXXXXX
	// "P4O[28:25],B1Voffset,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;",
	// "P4O[24],Swap B1V Nibbles,Off,On;",
`include "build_id.v" 
localparam CONF_STR = {
	"Ikari Warriors;;",
	"-;",
    "P1,Screen Settings;",
    "P1-;",
    "P1O[9:8],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[10],Orientation,Horz.,Vert.;",
	"P1O[11],Rotate CCW,Off,On;",
	"P1O[6:4],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"-;",
	"P2,Other Video Settings;",
	"P2-;",
	"P2O[14],VGA Scaler,Off,On;",
	"P2O[15],Flip,Off,On;",
	"P2-;",
	"P3,SNAC & GRS Super JoyStick;",
	"P3-;",
	"P3O[21:20],DB15 Devices,Off,OnlyP1,OnlyP2,P1&P2;",
	"P3O[23:22],Native LS-30 Adapter,Off,OnlyP1,OnlyP2,P1&P2;",
	"P3O[24],Use GRS Super JoyStick (Keystroke Mode), Off, On;",
	"P3-;",
	"P4,Debug;",
	"P4-;",
	"P4O[16],Side Layer,On,Off;",
	"P4O[17],Back Layer,On,Off;",
	"P4O[18],Front1 Layer,On,Off;",
	"P4O[19],Front2 Layer,On,Off;",
	"P4-;",
	"H1O[30:29],Rotary Speed,Normal,Slow,Fast,Very Fast;",
	"DIP;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Shot,Grenade,Start1,Coin1,Rotate Left,Rotate Right,Pause,Service;",
	"jn,A,B,Start,Select,L,R,X,Y;",
	"DEFMRA,IkariWarriors_JP.mra;",
	"V,v",`BUILD_DATE 
};

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;
wire        rom_download = ioctl_download && (ioctl_index  == 0);

//Debug enable/disable Graphics layers
reg   [3:0] layer_ena_dbg = 4'b1111;
always @(posedge clk_53p6) begin
	layer_ena_dbg[0] <= ~status[16]; //SIDE
	layer_ena_dbg[1] <= ~status[17]; //BACK1
	layer_ena_dbg[2] <= ~status[18]; //FRONT1
	layer_ena_dbg[3] <= ~status[19]; //FRONT2
end

// wire [3:0] dbg_B1Voffset = status[28:25];
//This fixed background offset by 1 pixel
wire [3:0] dbg_B1Voffset = 4'b0011;
//wire swap_px = status[24];
wire swap_px = 1'b1;
//wire forced_scandoubler;

wire  [1:0] buttons;
wire [127:0] status;
wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;

//SNAC joysticks
wire [1:0] SNAC_dev /* synthesis keep */;	
wire [1:0] SNAC_LS30 /* synthesis keep */;
wire USE_GRS_SJOY;
assign SNAC_dev =  status[21:20];
assign SNAC_LS30 = status[23:22];
assign USE_GRS_SJOY = status[24];

wire         JOY_CLK, JOY_LOAD;
wire         JOY_DATA  = USER_IN[5];

always_comb begin
	USER_OUT[0] = JOY_LOAD;
	USER_OUT[1] = JOY_CLK;
	USER_OUT[2] = 1'b1;
	USER_OUT[3] = 1'b1;
	USER_OUT[4] = 1'b1;
	USER_OUT[5] = 1'b1;
	USER_OUT[6] = 1'b1;
end

wire [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( clk_53p6  ), //53.6MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);

wire [15:0] JOY_DB1;
wire [15:0] JOY_DB2;
always_comb begin
	if ((SNAC_dev[0] == 1'b1) || (SNAC_LS30[0] == 1'b1)) begin
		JOY_DB1 = JOYDB15_1;
	end else begin
		JOY_DB1 = 16'hff;
	end

	if ((SNAC_dev[1] == 1'b1) || (SNAC_LS30[1] == 1'b1)) begin
		JOY_DB2 = JOYDB15_2;
	end else begin
		JOY_DB2 = 16'hff;
	end
end

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_53p6),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(),
	.forced_scandoubler(),
	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.direct_video(direct_video),
   .forced_scandoubler(forced_scandoubler),
   .gamma_bus(gamma_bus),
	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_upload_req(ioctl_upload_req),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),
	
	.ps2_key(ps2_key),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1)
);



////////////////////   SDRAM   ////////////////////

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_107p2),
	.clk_shifted(clk_107p2s),

	.addr0(rom_read_addr[23:0]),
	.din0({ioctl_dout[7:0], ioctl_dout[7:0]}),
	.dout0(),
	.wrl0((ioctl_addr[0] == 1'b1)),
	.wrh0((ioctl_addr[0] == 1'b0)),

	// //odd data for BACK1, B0,B2 for FRONT2
	// .wrl0((ioctl_addr >= 24'h40000 & ioctl_addr < 24'h60000 & ioctl_addr[0] == 1'b1) | 
	// 	  (ioctl_addr >= 24'h90000 & ioctl_addr < 24'hA0000)                         |
	// 	  (ioctl_addr >= 24'hB0000 & ioctl_addr < 24'hC0000)),

	// //even data for BACK1, B1 for FRONT2
	// .wrh0((ioctl_addr >= 24'h40000 & ioctl_addr < 24'h60000 & ioctl_addr[0] == 1'b0) | 
	// 	   ioctl_addr >= 24'hA0000 & ioctl_addr < 24'hB0000	),

	.req0(rom_wr),
	.ack0(sdram_wrack),

	.addr1(rom_addr[23:0]),
	.din1(0),
	.dout1(sdram_data),
	.wrl1(0),
	.wrh1(0),
	.req1(rom_req),
	.ack1(sdram_rdack),

	.addr2(0),
	.din2(0),
	.dout2(),
	.wrl2(0),
	.wrh2(0),
	.req2(0),
	.ack2()
);

// wire [23:0] rom_read_addr = ioctl_addr[23:0] < 24'h40000 ? ioctl_addr[23:0] - 24'h20000:
//                             ioctl_addr[23:0] < 24'h60000 ? ioctl_addr[23:0] - 24'h40000:
//                             ioctl_addr[23:0] < 24'h80000 ? ioctl_addr[23:0] - 24'h50000:
//                             ioctl_addr[23:0] - 24'h70000;

wire [23:0] SDRAM_BASE_ADDR_BACK1__ROM = 24'h0;
wire [23:0] SDRAM_BASE_ADDR_FRONT2_ROM = 24'h20000;
wire [23:0] IOCTL_BASE_ADDR_FRONT2_D0  = 24'h90000;
wire [23:0] IOCTL_BASE_ADDR_FRONT2_D1  = 24'hA0000;
wire [23:0] IOCTL_BASE_ADDR_FRONT2_D2  = 24'hB0000;


// wire [23:0] rom_read_addr2 = ioctl_addr[23:0] < 24'hD0000 ? ioctl_addr[23:0] - 24'h90000; //B0,B1,B2,X
// {rom_read_addr2[23:1]}


// wire [23:0] SDRAM_FRONT2_D2 = ioctl_addr[23:0] - 24'h8FFFF; //B2 -90000+1
wire [23:0] rom_read_addr;
wire dummy_bit;
assign {rom_read_addr[22:0],dummy_bit} =  ioctl_addr[23:0] - 24'h40000;
                              
//wire [23:0] rom_read_addr = 
wire [23:0] rom_addr;
wire [15:0] sdram_data;
wire rom_req, sdram_rdack;

reg rom_wr = 0;
wire sdram_wrack;

// wire rom_download_SDRAM = ((ioctl_addr >= 24'h40000) & (ioctl_addr < 24'h60000)) |
//                           ((ioctl_addr >= 24'h90000) & (ioctl_addr < 24'hD0000)) & ioctl_download;
wire rom_download_SDRAM = ((ioctl_addr >= 24'h40000) & (ioctl_addr < 24'h60000)) & ioctl_download;

always @(posedge clk_53p6) begin
	if(rom_download_SDRAM & ioctl_wr) begin
		ioctl_wait <= 1;
		rom_wr <= ~rom_wr;
	end
	else if(ioctl_wait && (rom_wr == sdram_wrack))
		ioctl_wait <= 0;
end

// PAUSE SYSTEM
wire pause_cpu;

wire [23:0] rgb_out;

pause #(8,8,8,536) pause (
 .*,
 //.OSD_STATUS(1'b0), //pause only on user defined button
 .clk_sys(clk_53p6),
 .reset(reset),
 .user_button((m_pause1 | m_pause2)),
 .r(R8B),
 .g(G8B),
 .b(B8B),
 .pause_cpu(pause_cpu),
 .pause_request(),
 .options(~status[22:21])
);

// Video rotation 
wire rotate_ccw = status[11];
wire no_rotate = orientation | direct_video;
wire video_rotated;
wire flip = status[15];

screen_rotate screen_rotate (.*);

arcade_video #(288,24) arcade_video
(
        .*,

        .clk_video(clk_53p6),
        .ce_pix(ce_pix),

        .RGB_in(rgb_out),
	    //.RGB_in({R8B,G8B,B8B}),
        .HBlank(HBlank),
        .VBlank(VBlank),
        .HSync(HSync),
        .VSync(VSync),

        .fx(scan_lines)
);

///////////////////////   CLOCKS and POR  ///////////////////////////////

wire clk_sys;
wire clk_53p6;
wire clk_107p2;
wire clk_107p2s;
wire locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_53p6),
	.outclk_1(clk_107p2),
	.outclk_2(clk_107p2s),
	.locked(locked)
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;
	
// <<< Start of Integration on Alpha Mission Core on MiSTer >>>
wire HBlank;
wire HSync;
wire VBlank;
wire VSync;
wire ce_pix;
wire [3:0] R,G,B;
wire [15:0] snd1, snd2;
logic [15:0] PLAYER1, PLAYER2;

IkariWarriorsCore IK_Core
(
	.RESETn(~reset),
	.VIDEO_RSTn(~reset),
	.pause_cpu(pause_cpu),
	//.pause_cpu(1'b0),
	.i_clk(clk_53p6), //53.6MHz
	.DSW({dsw2,dsw1}),
	.PLAYER1(PLAYER1),
	.PLAYER2(PLAYER2),
	.GAME(game), //default ASO (ASO,Alpha Mission, Arian Mission)
	//hps_io rom interface
	.ioctl_addr(ioctl_addr[24:0]),
	.ioctl_wr(ioctl_wr && rom_download),
	.ioctl_data(ioctl_dout),
	.layer_ena_dbg(layer_ena_dbg),
	.dbg_B1Voffset(dbg_B1Voffset),
	.swap_px(swap_px),
	//SDRAM interface
	.rom_addr(rom_addr),
	.rom_data(sdram_data),
	.rom_req(rom_req),
	.rom_ack(sdram_rdack),
	//output
	.R(R),
	.G(G),
	.B(B),
	.HBLANK(HBlank),
	.VBLANK(VBlank),
	.HSYNC(HSync),
	.VSYNC(VSync),
	.CE_PIXEL(ce_pix),
	.snd1(snd1),
	.snd2(snd2)
);

//color LUT for 4bit component to 8bit non-linear scale conversion (from LT Spice calculated values)
logic [7:0] R8B, G8B, B8B;
RGB4bit_LUT R_LUT( .COL_4BIT(R), .COL_8BIT(R8B));
RGB4bit_LUT G_LUT( .COL_4BIT(G), .COL_8BIT(G8B));
RGB4bit_LUT B_LUT( .COL_4BIT(B), .COL_8BIT(B8B));
// >>> End of Integration on Alpha Mission Core on MiSTer <<<

// assign CLK_VIDEO = clk_sys;
assign CLK_VIDEO = clk_53p6;

//Audio
assign AUDIO_S = 1'b1; //Signed audio samples
assign AUDIO_MIX = 2'b11; //0 No Mix, 1 25%, 2 50%, 3 100% mono

//synchronize audio
reg [15:0] snd1_r, snd2_r;
always @(posedge CLK_AUDIO) begin
	snd1_r <= snd1;
	snd2_r <= snd2;
	AUDIO_L <= snd1_r;
	AUDIO_R <= snd2_r;
end


//////// Game inputs, the same controls are used for two player alternate gameplay ////////
//Dip Switches
// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge clk_53p6) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

//Added support for multigame core.
reg [7:0] game;
always @(posedge clk_53p6) begin
	if((ioctl_index == 1) && (ioctl_addr == 0)) begin
		game <= ioctl_dout;
	end
end

logic [7:0] dsw1, dsw2;
assign dsw1 = sw[0];
assign dsw2 = sw[1];

///////////////////         Keyboard           //////////////////
reg btn_left_1     = 0 /* synthesis preserve */;
reg btn_right_1    = 0 /* synthesis preserve */;
reg btn_left_2     = 0 /* synthesis preserve */;
reg btn_right_2    = 0 /* synthesis preserve */;

wire pressed = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
always @(posedge clk_53p6) begin
	reg old_state;
	old_state <= ps2_key[10];
	if(old_state != ps2_key[10]) begin

		if(USE_GRS_SJOY) begin
			case(code)
				'h6B: btn_left_1    <= pressed; // left
				'h74: btn_right_1   <= pressed; // right
				'h21: btn_left_2    <= pressed; // C as left
				'h2A: btn_right_2   <= pressed; // V as right
			endcase
		end else begin
				btn_left_1    <= 1'b0; // left
				btn_right_1   <= 1'b0; // right
				btn_left_2    <= 1'b0; // C as left
				btn_right_2   <= 1'b0; // V as right
		end
	end
end

//Joysticks
//Player 1
wire m_up1;
wire m_down1;
wire m_left1;
wire m_right1;
wire m_shot1;
wire m_grenade1;
wire m_service1;
wire m_start1;
wire m_coin1;
wire m_pause1; //active high
wire m_rot_left1, m_rot_right1;

//Player 2
wire m_up2;
wire m_down2;
wire m_left2;
wire m_right2;
wire m_shot2;
wire m_grenade2;
wire m_service2;
wire m_start2;
wire m_coin2;
wire m_pause2; //active high
wire m_rot_left2, m_rot_right2;

//custom_joy1:13 UP,12 DOWN,11 RIGHT,10 LEFT,9 H,8 G,7 F,6 E,5 D,4 C,3 B,2 A,1 START1,0 COIN
//db15:        //    11 L, 10 S, 9 F, 8 E, 7 D, 6 C, 5 B, 4 A, 3 U, 2 D, 1 L, 0 R
//    10 9876543210
//----LS FEDCBAUDLR
//JOY_DB1 = (SNAC_dev == 2'd1)
	assign m_up1       = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[3]  : ~joystick_0[3];
	assign m_down1     = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[2]  : ~joystick_0[2];
	assign m_left1     = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[1]  : ~joystick_0[1];
	assign m_right1    = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[0]  : ~joystick_0[0];
	assign m_shot1     = (SNAC_dev[0]) ? ~JOY_DB1[5]  : (SNAC_LS30[0] ? ~JOY_DB1[4] : ~joystick_0[4]); //DB15 (NeoGeo): B , LS30 (Custom) A
	assign m_grenade1  = (SNAC_dev[0]) ? ~JOY_DB1[6]  : (SNAC_LS30[0] ? ~JOY_DB1[5] : ~joystick_0[5]); //DB15 (NeoGeo): C , LS30 (Custom) B
	assign m_start1    = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[10] : ~joystick_0[6]; //DB15 (NeoGeo): Start
	assign m_coin1     = (SNAC_dev[0] || SNAC_LS30[0]) ? ~JOY_DB1[11] : ~joystick_0[7]; //DB15 (NeoGeo): Select 
	assign m_rot_left1 = (SNAC_dev[0] || SNAC_LS30[0]) ?  JOY_DB1[4]  :  joystick_0[8]; //DB15 (NeoGeo): A, LS30 (Custom) not used
	assign m_rot_right1= (SNAC_dev[0] || SNAC_LS30[0]) ?  JOY_DB1[7]  :  joystick_0[9]; //DB15 (NeoGeo): D LS30 (Custom) not used
	assign m_service1  = (SNAC_dev[0] || SNAC_LS30[0]) ?  ~(JOY_DB1[5] & JOY_DB1[11]) : ~joystick_0[10]; //DB15 (NeoGeo): Select+B
	assign m_pause1    = (SNAC_dev[0] || SNAC_LS30[0]) ?   (JOY_DB1[4] & JOY_DB1[11]) :  joystick_0[11]; //DB15 (NeoGeo): Select+A
	
	assign m_up2       = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[3]  : ~joystick_1[3];
	assign m_down2     = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[2]  : ~joystick_1[2];
	assign m_left2     = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[1]  : ~joystick_1[1];
	assign m_right2    = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[0]  : ~joystick_1[0];
	assign m_shot2     = (SNAC_dev[1]) ? ~JOY_DB2[5]  : (SNAC_LS30[1] ? ~JOY_DB2[4] : ~joystick_1[4]); //DB15 (NeoGeo): B , LS30 (Custom) A
	assign m_grenade2  = (SNAC_dev[1]) ? ~JOY_DB2[6]  : (SNAC_LS30[1] ? ~JOY_DB2[5] : ~joystick_1[5]); //DB15 (NeoGeo): C , LS30 (Custom) B
	assign m_start2    = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[10] : ~joystick_1[6]; //DB15 (NeoGeo): Start
	assign m_coin2     = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[11] : ~joystick_1[7]; //DB15 (NeoGeo): Select 
	assign m_rot_left2 = (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[4]  :  joystick_1[8]; //DB15 (NeoGeo): A, LS30 (Custom) not used
	assign m_rot_right2= (SNAC_dev[1] || SNAC_LS30[1]) ? ~JOY_DB2[7]  :  joystick_1[9]; //DB15 (NeoGeo): D LS30 (Custom) not used
	assign m_service2  = (SNAC_dev[1] || SNAC_LS30[1]) ?  ~(JOY_DB2[5] & JOY_DB2[11]) : ~joystick_1[10]; //DB15 (NeoGeo): Select+B
	assign m_pause2    = (SNAC_dev[1] || SNAC_LS30[1]) ?   (JOY_DB2[4] & JOY_DB2[11]) :  joystick_1[11]; //DB15 (NeoGeo): Select+A
	
//Rotary controls based on https://github.com/MiSTer-devel/Arcade-Jackal_MiSTer
//for gamepad or button based game controllers
reg [22:0] rotary_div = 23'd0;
reg [3:0] rotary1 = 4'd11;
reg [3:0] rotary2 = 4'd11;
wire [1:0] rot_speed =status[30:29];
logic rotary_en;

always_comb begin
	if (USE_GRS_SJOY) rotary_en = !rotary_div[20:0];
	else begin
		case(rot_speed)
			2'b00: rotary_en = !rotary_div[22:0]; //Normal
			2'b01: rotary_en = !rotary_div;       //Slow
			2'b10: rotary_en = !rotary_div[21:0]; //Fast
			2'b11: rotary_en = !rotary_div[20:0]; //Very Fast
		endcase
	end
end
always_ff @(posedge clk_53p6) begin
	rotary_div <= rotary_div + 23'd1;
	if(rotary_en) begin
		if(m_rot_left1 || btn_left_1) begin
			if(rotary1 != 4'd11)
				rotary1 <= rotary1 + 4'd1;
			else
				rotary1 <= 4'd0;
		end
		else if(m_rot_right1 || btn_right_1) begin
			if(rotary1 != 4'd0)
				rotary1 <= rotary1 - 4'd1;
			else
				rotary1 <= 4'd11;
		end
		else
			rotary1 <= rotary1;
		if(m_rot_left2 || btn_left_2) begin
			if(rotary2 != 4'd11)
				rotary2 <= rotary2 + 4'd1;
			else
				rotary2 <= 4'd0;
		end
		else if(m_rot_right2 || btn_right_2) begin
			if(rotary2 != 4'd0)
				rotary2 <= rotary2 - 4'd1;
			else
				rotary2 <= 4'd11;
		end
		else
			rotary2 <= rotary2;
	end
end



//LS-30 Custom SNAC controller
logic [3:0] rot1_ls30 = 4'd11;
logic [3:0] rot2_ls30 = 4'd11;

logic [3:0] last_port1 /* synthesis preserve */;
logic [3:0] last_port2 /* synthesis preserve */;
logic [3:0] port1;
logic [3:0] port2;
logic [1:0] wait_read = 1'b1;

assign port1 = {JOY_DB1[9],JOY_DB1[8],JOY_DB1[7],JOY_DB1[6]}; //buttons FEDC have the LS30 encoded rotating data
assign port2 = {JOY_DB2[9],JOY_DB2[8],JOY_DB2[7],JOY_DB2[6]}; //buttons FEDC have the LS30 encoded rotating data

ls30rot_decoder dec1 (.clk(clk_53p6), .wait_data(wait_read), .curr_data(port1), .last_data(last_port1), .pos(rot1_ls30));
ls30rot_decoder dec2 (.clk(clk_53p6), .wait_data(wait_read), .curr_data(port2), .last_data(last_port2), .pos(rot2_ls30));

always_ff @(posedge clk_53p6) begin
	last_port1 <= port1;
	last_port2 <= port2;

	if (wait_read) wait_read <= 1'b0;
end


wire [3:0] rot1, rot2;
assign rot1 = SNAC_LS30[0] ? rot1_ls30 : rotary1;
assign rot2 = SNAC_LS30[1] ? rot2_ls30 : rotary2;
//                15 14 13       12       11      10       9       8   7654       3          2        1        0 
assign PLAYER1 = {2'b11,m_up1,m_down1,m_right1,m_left1,m_service1,1'b1,rot1,m_grenade1,m_shot1,m_start1,m_coin1};
assign PLAYER2 = {2'b11,m_up2,m_down2,m_right2,m_left2,m_service2,1'b1,rot2,m_grenade2,m_shot2,m_start2,m_coin2};
endmodule
