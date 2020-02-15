//============================================================================
//  Arcade: Spy Hunter
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

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

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = rom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd21;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd20;

`include "build_id.v" 
localparam CONF_STR = {
	"A.MCR3MONO;;",
	"H0O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"h1O6,Control,Mode 1,Mode 2;",
	"h1-;",
	"h2O6,Control 1P,Buttons,Spinner;",
	"h2O7,Control 2P,Buttons,Spinner;",
	"h2O8,Control 3P,Buttons,Spinner;",
	"h2O9,Control 4P,Buttons,Spinner;",
	"h2-;",
	"h3O6,Gas 1P,Buttons,Analog Y;",
	"h3O7,Steering 1P,Buttons,Analog X;",
	"h3O8,Gas 2P,Buttons,Analog Y;",
	"h3O9,Steering 2P,Buttons,Analog X;",
	"h3-;",
	"h4O6,Fire 1P,4Way,Fly+Fire;",
	"h4O7,Fire 2P,4Way,Fly+Fire;",
	"h4O8,Fire 3P,4Way,Fly+Fire;",
	"h4-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire A,Fire B,Fire C,Fire D,Start,Coin;",
	"jn,A,B,X,Y,Start,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_80M;
wire clk_mem = clk_80M;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 40M
	.outclk_1(clk_80M), // 80M
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_index;

wire [10:0] ps2_key;

wire [31:0] joy1, joy2, joy3, joy4;
wire [31:0] joy = joy1 | joy2 | joy3 | joy4;
wire [15:0] joy1a, joy2a, joy3a, joy4a;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({mod_stargrds, mod_maxrpm, mod_demderby, mod_sarge, direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),

	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a),
	.joystick_analog_2(joy3a),
	.joystick_analog_3(joy4a),

	.ps2_key(ps2_key)
);

reg mod_rampage    = 0;
reg mod_sarge      = 0;
reg mod_powerdrive = 0;
reg mod_maxrpm     = 0;
reg mod_demderby   = 0;
reg mod_stargrds   = 0;

always @(posedge clk_sys) begin
	reg [7:0] mod = 0;
	if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

	mod_rampage	   <= (mod == 0);
	mod_sarge	   <= (mod == 1);
	mod_powerdrive	<= (mod == 2);
	mod_maxrpm	   <= (mod == 3);
	mod_demderby   <= (mod == 4);
	mod_stargrds   <= (mod == 5);
end

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'h75: btn_up            <= pressed; // up
			'h72: btn_down          <= pressed; // down
			'h6B: btn_left          <= pressed; // left
			'h74: btn_right         <= pressed; // right
			'h76: btn_coin1         <= pressed; // ESC
			'h05: btn_start1        <= pressed; // F1
			'h06: btn_start2        <= pressed; // F2
			//'h04: btn_start3        <= pressed; // F3
			//'h0C: btn_start4        <= pressed; // F4
			'h14: btn_fireA         <= pressed; // l-ctrl
			'h11: btn_fireB         <= pressed; // l-alt
			'h29: btn_fireC         <= pressed; // Space
			'h12: btn_fireD         <= pressed; // l-shift
			// JPAC/IPAC/MAME Style Codes
			'h16: btn_start1        <= pressed; // 1
			'h1E: btn_start2        <= pressed; // 2
			//'h26: btn_start3        <= pressed; // 3
			//'h25: btn_start4        <= pressed; // 4
			'h2E: btn_coin1         <= pressed; // 5
			'h36: btn_coin2         <= pressed; // 6
			'h3D: btn_coin3         <= pressed; // 7
			//'h3E: btn_coin4         <= pressed; // 8
			'h2D: btn_up2           <= pressed; // R
			'h2B: btn_down2         <= pressed; // F
			'h23: btn_left2         <= pressed; // D
			'h34: btn_right2        <= pressed; // G
			'h1C: btn_fire2A        <= pressed; // A
			'h1B: btn_fire2B        <= pressed; // S
			'h21: btn_fire2C        <= pressed; // Q
			'h1D: btn_fire2D        <= pressed; // W
		endcase
	end
end

reg btn_left   = 0;
reg btn_right  = 0;
reg btn_down   = 0;
reg btn_up     = 0;
reg btn_fireA  = 0;
reg btn_fireB  = 0;
reg btn_fireC  = 0;
reg btn_fireD  = 0;
reg btn_coin1  = 0;
reg btn_coin2  = 0;
reg btn_coin3  = 0;
//reg btn_coin4  = 0;
reg btn_start1 = 0;
reg btn_start2 = 0;
//reg btn_start3 = 0;
//reg btn_start4 = 0;
reg btn_up2    = 0;
reg btn_down2  = 0;
reg btn_left2  = 0;
reg btn_right2 = 0;
reg btn_fire2A = 0;
reg btn_fire2B = 0;
reg btn_fire2C = 0;
reg btn_fire2D = 0;

// Generic controls - make a module from this?
wire m_coin1   = (mod_powerdrive | mod_stargrds) ? (btn_coin1 | joy1[9]) : (btn_coin1 | btn_coin2 | btn_coin3 | joy[9]);
wire m_start1  = btn_start1 | joy1[8];
wire m_up1     = btn_up     | joy1[3];
wire m_down1   = btn_down   | joy1[2];
wire m_left1   = btn_left   | joy1[1];
wire m_right1  = btn_right  | joy1[0];
wire m_fire1a  = btn_fireA  | joy1[4];
wire m_fire1b  = btn_fireB  | joy1[5];
wire m_fire1c  = btn_fireC  | joy1[6];
wire m_fire1d  = btn_fireD  | joy1[7];
wire m_spccw1  =              joy1[30];
wire m_spcw1   =              joy1[31];

wire m_coin2   = (mod_powerdrive | mod_stargrds)  & (btn_coin2 | joy2[9]);
wire m_start2  = btn_start2 | joy2[8];
wire m_left2   = btn_left2  | joy2[1];
wire m_right2  = btn_right2 | joy2[0];
wire m_up2     = btn_up2    | joy2[3];
wire m_down2   = btn_down2  | joy2[2];
wire m_fire2a  = btn_fire2A | joy2[4];
wire m_fire2b  = btn_fire2B | joy2[5];
wire m_fire2c  = btn_fire2C | joy2[6];
wire m_fire2d  = btn_fire2D | joy2[7];
wire m_spccw2  =              joy2[30];
wire m_spcw2   =              joy2[31];

wire m_coin3   = (mod_powerdrive | mod_stargrds) & joy3[9];
wire m_start3  = joy3[8];
wire m_left3   = joy3[1];
wire m_right3  = joy3[0];
wire m_up3     = joy3[3];
wire m_down3   = joy3[2];
wire m_fire3a  = joy3[4];
wire m_fire3b  = joy3[5];
wire m_fire3c  = joy3[6];
wire m_fire3d  = joy3[7];
wire m_spccw3  = joy3[30];
wire m_spcw3   = joy3[31];

wire m_coin4   = 0;
wire m_start4  = joy4[8];
wire m_left4   = joy4[1];
wire m_right4  = joy4[0];
//wire m_up4     = joy4[3];
//wire m_down4   = joy4[2];
wire m_fire4a  = joy4[4];
wire m_fire4b  = joy4[5];
//wire m_fire4c  = joy4[6];
//wire m_fire4d  = joy4[7];
wire m_spccw4  = joy4[30];
wire m_spcw4   = joy4[31];

reg       sg; // Sounds Good board
reg [7:0] input0;
reg [7:0] input1;
reg [7:0] input2;
reg [7:0] input3;
reg [7:0] input4;
reg [7:0] output5;
reg [7:0] output6;

reg inp_mux;
always @(posedge clk_sys) begin
	if(output6[7]) inp_mux <= 0;
	if(output6[6]) inp_mux <= 1;
end

// Game specific sound board/DIP/input settings
always @(*) begin
	sg = mod_rampage | mod_powerdrive | mod_stargrds;

	input0 = 8'hff;
	input1 = 8'hff;
	input2 = 8'hff;
	input3 = sw[0];
	input4 = 8'hff;

	if (mod_sarge) begin
		input0 = ~{2'b00, sw[1][0], 1'b0, m_start2, m_start1, m_coin2, m_coin1};
		input1 = ~{m_fire1d, m_fire1d, m_fire1a, m_fire1a, s_rd1, s_ru1, s_ld1, s_lu1};
		input2 = ~{m_fire2d, m_fire2d, m_fire2a, m_fire2a, s_rd2, s_ru2, s_ld2, s_lu2};
	end
	else if (mod_demderby) begin
		input0 = ~{2'b00, sw[1][0], 1'b0, m_start2, m_start1, m_coin2, m_coin1};
		input1 = ~{inp_mux ? ddwh3 : ddwh1, m_fire1b, m_fire1a};
		input2 = ~{inp_mux ? ddwh4 : ddwh2, m_fire2b, m_fire2a};
		input4 = ~{m_fire4b, m_fire4a, m_fire3b, m_fire3a, m_start4, m_start3, m_coin4, m_coin3};
	end
	else if (mod_maxrpm) begin
		input0 = ~{sw[1][0], 3'b000, m_start1, m_start2, m_coin1, m_coin2};
		input1 = maxrpm_adc_data;
		input2 = ~{maxrpm_gear1, maxrpm_gear2};
	end
	else if (mod_rampage) begin
		// normal controls for 3 players
		input0 = ~{2'b00, sw[1][0], 1'b0, 2'b00, m_coin2, m_coin1};
		input1 = ~{2'b00, m_fire1b, m_fire1a, m_left1, m_down1, m_right1, m_up1};
		input2 = ~{2'b00, m_fire2b, m_fire2a, m_left2, m_down2, m_right2, m_up2};
		input4 = ~{sndstat[0],1'b0, m_fire3b, m_fire3a, m_left3, m_down3, m_right3, m_up3};
	end
	else if (mod_powerdrive) begin
		// Controls for 3 players using 4 buttons/joystick
		input0 = ~{2'b00, sw[1][0], 1'b0, 1'b0, m_coin3, m_coin2, m_coin1};
		input1 = ~{m_fire2b, m_fire2a, powerdrv_gear[1], m_fire2c, m_fire1b, m_fire1a, powerdrv_gear[0], m_fire1c};
		input2 = ~{sndstat[0], 3'b000, m_fire3b, m_fire3a, powerdrv_gear[2], m_fire3c};
	end
	else if (mod_stargrds) begin
		// normal controls for 3 players
		input0 = ~{sw[1][0], 2'b00, sndstat[0], output5[1] ? m_start3 : m_start2, m_start1, output5[1] ? m_coin3 : m_coin2, m_coin1};
		input1 = ~{m_right1, m_left1, m_down1, m_up1, status[6] ? ((m_fire1a|m_fire1d|m_fire1b|m_fire1c) ? {m_right1, m_left1, m_down1, m_up1} : 4'b0000) : {m_fire1a, m_fire1d, m_fire1b, m_fire1c}};
		input2 = ~{m_right2, m_left2, m_down2, m_up2, status[7] ? ((m_fire2a|m_fire2d|m_fire2b|m_fire2c) ? {m_right2, m_left2, m_down2, m_up2} : 4'b0000) : {m_fire2a, m_fire2d, m_fire2b, m_fire2c}};
		input4 = ~{m_right3, m_left3, m_down3, m_up3, status[8] ? ((m_fire3a|m_fire3d|m_fire3b|m_fire3c) ? {m_right3, m_left3, m_down3, m_up3} : 4'b0000) : {m_fire3a, m_fire3d, m_fire3b, m_fire3c}};
	end
end

wire rom_download = ioctl_download && !ioctl_index;

wire [15:0] rom_addr;
wire  [7:0] rom_do;
wire [17:0] snd_addr;
wire [15:0] snd_do;
wire [15:0] sp_addr;
wire [31:0] sp_do;
wire [24:0] sp_ioctl_addr = ioctl_addr - 17'h10000;
wire [24:0] snd_ioctl_addr = ioctl_addr - snd_offset;
reg         port1_req, port2_req;
reg  [23:0] port1_a;
reg  [23:0] port2_a;
reg  [19:0] snd_offset;
reg  [19:0] gfx1_offset;

always @(*) begin
	if (sg) begin
		snd_offset  = 20'h60000;
		gfx1_offset = 20'h50000;
		port1_a = ioctl_addr[23:0];
		port1_a = (ioctl_addr < snd_offset) ? ioctl_addr[23:0] : // 8 bit main ROM
		snd_offset + {snd_ioctl_addr[17], snd_ioctl_addr[15:0], snd_ioctl_addr[16]}; // 16 bit Sounds Good ROM

		// merge sprite roms (4x64k) into 32-bit wide words
		port2_a     = {sp_ioctl_addr[23:18], sp_ioctl_addr[15:0], sp_ioctl_addr[17:16]};
	end else begin
		snd_offset  = 20'h40000;
		gfx1_offset = 20'h30000;
		port1_a = ioctl_addr[23:0];
		// merge sprite roms (4x32k) into 32-bit wide words
		port2_a     = {sp_ioctl_addr[23:17], sp_ioctl_addr[14:0], sp_ioctl_addr[16:15]};
	end
end

sdram sdram(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_mem      ),

	// port1 used for main + sound CPU
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( port1_a[23:1] ),
	.port1_ds      ( {port1_a[0], ~port1_a[0]} ),
	.port1_we      ( rom_download ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       ( ),

	.cpu1_addr     ( cpu1_addr ),
	.cpu1_q        ( snd_do ),
	.cpu2_addr     ( ),
	.cpu2_q        ( ),
	.cpu3_addr     ( ),
	.cpu3_q        ( ),

	// port2 for sprite graphics
	.port2_req     ( port2_req ),
	.port2_ack     ( ),
	.port2_a       ( port2_a[23:1] ),
	.port2_ds      ( {port2_a[0], ~port2_a[0]} ),
	.port2_we      ( rom_download ),
	.port2_d       ( {ioctl_dout, ioctl_dout} ),
	.port2_q       ( ),

	.sp_addr       ( rom_download ? 16'hffff : sp_addr ),
	.sp_q          ( sp_do )
);

dpram #(8,16) cpu_rom
(
	.clk_a(clk_sys),
	.we_a(ioctl_wr && rom_download && !ioctl_addr[24:16]),
	.addr_a(ioctl_addr[15:0]),
	.d_a(ioctl_dout),

	.clk_b(clk_sys),
	.addr_b(rom_addr),
	.q_b(rom_do)
);

reg [19:1] cpu1_addr;

// ROM download controller
always @(posedge clk_sys) begin
	if (rom_download) begin
		if (ioctl_wr & rom_download) begin
			port1_req <= ~port1_req;
			port2_req <= ~port2_req;
		end
	end
	// register for better timings
	cpu1_addr <= rom_download ? 19'h7ffff : (snd_offset[19:1] + snd_addr[17:1]);
end

// reset signal generation
reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk_sys) begin
	reg ioctl_downlD;
	reg [15:0] reset_count;
	ioctl_downlD <= rom_download;

	// generate a second reset signal - needed for some reason
	if (status[0] | buttons[1] | ~rom_loaded) reset_count <= 16'hffff;
	else if (reset_count != 0) reset_count <= reset_count - 1'd1;

	if (ioctl_downlD & ~rom_download) rom_loaded <= 1;
	reset <= status[0] | buttons[1] | rom_download | ~rom_loaded | (reset_count == 16'h0001);
end

wire [1:0] sndstat;
mcr3mono mcr3mono (
	.clock_40(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_blankn(),
	.video_hblank(HBlank),
	.video_vblank(VBlank),
	.video_hs(HSync),
	.video_vs(VSync),
	.video_csync(),
	.video_ce(ce_pix),
	.tv15Khz_mode(1),

	.mod_stargrds(mod_stargrds),

	.soundsgood(sg),
	.snd_stat(sndstat),
	.audio_out(audio),

	.input_0(input0),
	.input_1(input1),
	.input_2(input2),
	.input_3(input3),
	.input_4(input4),
	.output_5(output5),
	.output_6(output6),

	.cpu_rom_addr ( rom_addr ),
	.cpu_rom_do   ( rom_do   ),
	.snd_rom_addr ( snd_addr ),
	.snd_rom_do   ( snd_do   ),
	.sp_addr      ( sp_addr  ),
	.sp_graphx32_do ( sp_do  ),

	.dl_addr(ioctl_addr-gfx1_offset),
	.dl_data(ioctl_dout),
	.dl_wr(ioctl_wr && !ioctl_index)
);

wire ce_pix;
wire HBlank, VBlank;
wire HSync, VSync;
wire [2:0] r,g,b;

arcade_video #(512,240,9) arcade_video
(
	.*,
	.clk_video(clk_sys),
	.RGB_in({r,g,b}),

	.no_rotate(1),
	.rotate_ccw(0),
	.fx(status[5:3])
);

wire  [9:0] audio;
assign AUDIO_L = { audio, 6'd0 };
assign AUDIO_R = { audio, 6'd0 };
assign AUDIO_S = 0;

////////////////////  Game specific controls  /////////////////////////////

// Sarge
wire s_lu1, s_ld1, s_ru1, s_rd1, s_f1a, s_f1b;
twosticks twosticks1
(
	status[6],
	m_left1,  m_right1, m_up1, m_down1,
	m_fire1b, m_fire1c,
	s_lu1, s_ld1, s_ru1, s_rd1
);

wire s_lu2, s_ld2, s_ru2, s_rd2, s_f2a, s_f2b;
twosticks twosticks2
(
	status[6],
	m_left2, m_right2, m_up2, m_down2,
	m_fire2b, m_fire2c,
	s_lu2, s_ld2, s_ru2, s_rd2
);

// Power Drive gear
reg  [2:0] powerdrv_gear;
always @(posedge clk_sys) begin
	reg [2:0] gear_old;

	if (reset) powerdrv_gear <= 0;
	else begin
		gear_old <= {m_fire3d, m_fire2d, m_fire1d};
		if (~gear_old[0] & m_fire1d) powerdrv_gear[0] <= ~powerdrv_gear[0];
		if (~gear_old[1] & m_fire2d) powerdrv_gear[1] <= ~powerdrv_gear[1];
		if (~gear_old[2] & m_fire3d) powerdrv_gear[2] <= ~powerdrv_gear[2];
	end
end


// MaxRPM gearbox
wire [3:0] maxrpm_gear_bits[5] = '{ 4'h0, 4'h5, 4'h6, 4'h1, 4'h2 };
wire [3:0] maxrpm_gear1 = maxrpm_gear_bits[gear1];
wire [3:0] maxrpm_gear2 = maxrpm_gear_bits[gear2];
reg  [2:0] gear1;
reg  [2:0] gear2;
always @(posedge clk_sys) begin
	reg m_fire1a_last, m_fire1b_last;
	reg m_fire2a_last, m_fire2b_last;

	if (reset) begin
		gear1 <= 0;
		gear2 <= 0;
	end else begin
		m_fire1a_last <= m_fire1a;
		m_fire1b_last <= m_fire1b;
		m_fire2a_last <= m_fire2a;
		m_fire2b_last <= m_fire2b;

		if (m_start1) gear1 <= 0;
		else if (~m_fire1a_last && m_fire1a && gear1 != 3'd4) gear1 <= gear1 + 1'd1;
		else if (~m_fire1b_last && m_fire1b && gear1 != 3'd0) gear1 <= gear1 - 1'd1;

		if (m_start2) gear2 <= 0;
		else if (~m_fire2a_last && m_fire2a && gear2 != 3'd4) gear2 <= gear2 + 1'd1;
		else if (~m_fire2b_last && m_fire2b && gear2 != 3'd0) gear2 <= gear2 - 1'd1;
	end
end

//Pedals/Steering
reg [7:0] maxrpm_adc_data;
reg [3:0] maxrpm_adc_control;
always @(*) begin
	case (maxrpm_adc_control[1:0])
		2'b00: maxrpm_adc_data = status[8] ? gas2a : gas2;
		2'b01: maxrpm_adc_data = status[6] ? gas1a : gas1;
		2'b10: maxrpm_adc_data = status[9] ? steering2a : steering2;
		2'b11: maxrpm_adc_data = status[7] ? steering1a : steering1;
	endcase
end

always @(posedge clk_sys) if (~output6[6] & ~output6[5]) maxrpm_adc_control <= output5[4:1];

wire [7:0] gas1a = joy1a[15] ? {joy1a[14:8],1'b1} : 8'hFF;
wire [7:0] gas2a = joy2a[15] ? {joy2a[14:8],1'b1} : 8'hFF;

wire [7:0] steering1a = 8'h74 - {joy1a[7],joy1a[7:1]};
wire [7:0] steering2a = 8'h74 + {joy2a[7],joy2a[7:1]};

wire [7:0] gas1;
wire [7:0] steering1;
steering_control
#(
	.gas_reverse(1'b1)
)
maxrpm_pl1
(
	.clk(clk_sys),
	.reset(reset),
	.vsync(VSync),
	.gas_plus(m_up1),
	.gas_minus(~m_up1),
	.steering_minus(m_right1),
	.steering_plus(m_left1),
	.steering(steering1),
	.gas(gas1)
);

wire [7:0] gas2;
wire [7:0] steering2;
steering_control
#(
	.gas_reverse(1'b1)
)
maxrpm_pl2
(
	.clk(clk_sys),
	.reset(reset),
	.vsync(VSync),
	.gas_plus(m_up2),
	.gas_minus(~m_up2),
	.steering_plus(m_right2),
	.steering_minus(m_left2),
	.steering(steering2),
	.gas(gas2)
);


// Demolition Derby
wire [5:0] ddwh1;
spinner #(10) dd_wheel1
(
	.clk(clk_sys),
	.reset(reset),
	.minus(m_left1 | m_spccw1),
	.plus(m_right1 | m_spcw1),
	.strobe(VSync),
	.use_spinner(status[6] | m_spccw1 | m_spcw1),
	.spin_angle(ddwh1)
);

wire [5:0] ddwh2;
spinner #(10) dd_wheel2
(
	.clk(clk_sys),
	.reset(reset),
	.minus(m_left2 | m_spccw2),
	.plus(m_right2 | m_spcw2),
	.strobe(VSync),
	.use_spinner(status[7] | m_spccw2 | m_spcw2),
	.spin_angle(ddwh2)
);

wire [5:0] ddwh3;
spinner #(10) dd_wheel3
(
	.clk(clk_sys),
	.reset(reset),
	.minus(m_left3 | m_spccw3),
	.plus(m_right3 | m_spcw3),
	.strobe(VSync),
	.use_spinner(status[8] | m_spccw3 | m_spcw3),
	.spin_angle(ddwh3)
);

wire [5:0] ddwh4;
spinner #(10) dd_wheel4
(
	.clk(clk_sys),
	.reset(reset),
	.minus(m_left4 | m_spccw4),
	.plus(m_right4 | m_spcw4),
	.strobe(VSync),
	.use_spinner(status[9] | m_spccw4 | m_spcw4),
	.spin_angle(ddwh4)
);

endmodule

module twosticks
(
	input mode,
	input l,r,u,d,
	input bb,bc,

	output lu,ld,ru,rd
);

assign lu = mode ? (u | r) : u;
assign ld = mode ? (d | l) : d;
assign ru = mode ? (u | l) : bc;
assign rd = mode ? (d | r) : bb;

endmodule
