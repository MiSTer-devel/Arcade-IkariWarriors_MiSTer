//IkariWarriorsCore.sv
//Author: @RndMnkIII
//Date: 08/06/2022
`default_nettype none
`timescale 1ns/1ps

module IkariWarriorsCore
(
    input wire RESETn,
    input wire VIDEO_RSTn,
    input wire pause_cpu,
    input wire i_clk, //53.6MHz
    input wire [15:0] PLAYER1,
    input wire [15:0] PLAYER2,
    input wire [7:0] GAME,
    input wire [15:0] DSW,
    output wire player_ctrl_clk,
    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire               ioctl_wr,

    //SDRAM interface
	output        [23:0] rom_addr,
	input         [15:0] rom_data,
	output logic         rom_req,
	input                rom_ack,

    //layer dbg interfacee
    input wire [3:0] layer_ena_dbg, //0x4 Front layer enabled, 0x2 Back1 layer enabled, 0x1 Side layer enabled
    input wire [3:0] dbg_B1Voffset,
    input wire swap_px,    
    //output video signals
    output logic [3:0] R,
    output logic [3:0] G,
    output logic [3:0] B,
	output logic HBLANK,
	output logic VBLANK,
	output logic HSYNC,
	output logic VSYNC,
    output logic [8:0] SCR_Y,
    output logic [8:0] SCR_X,
    output logic VBL,
    output logic SYNC,
    output logic VS,
    output logic HS,
    output logic DISP,
    output logic PIX_CLK,
	output logic CE_PIXEL,

    //sound output
    output wire signed [15:0] snd1,
    output wire signed [15:0] snd2,
    output wire sample
);
    logic VRD, AE, BE;
    
    logic CK0, CK0n, CK1, CK1n, LDn;
    logic HLDn;
     logic [8:0] H;
     logic [2:0] Hn;
    logic [8:0] FH;
    logic F1CK;
    logic F2CK;
    logic [7:0] Y;
    logic [7:0] X;
    logic [8:0] F1V;
    logic [8:0] F2V;
    logic VCKn;
    logic LT;
    logic VLK;
    logic VFLGn;
    logic VDG, V_C;
    logic VWE, VOE;
    logic BWA, A_B, RLA, RLB, WBA, WBB;
    logic LA, LC, LD, HD8;
    logic WR0, WR1;

    //CPU A data bus (tri-state)
    logic  [7:0] AD;
    
    //common buses
    logic [7:0] VD_out, VD_in;
    logic [11:0] VA;

    //Video Registers and CS 
    logic FRONT1_VIDEO_CSn;
    logic FRONT2_VIDEO_CSn;
    logic BACK1_VRAM_CSn;
    logic SIDE_VRAM_CSn;
    logic DISC;
    logic F1SX; //Front video scroll X
    logic F1SY; //Fraont video scroll Y
    logic F2SX; //Front video scroll X
    logic F2SY; //Fraont video scroll Y
    logic B1SX; //Back1 video scroll X
    logic B1SY; //Back1 video scroll Y
    logic SSET; //side bank and side color bank
    logic BSET; //Video Attribs.
    logic XSET;
    logic YSET;
    logic MSET;
    logic F2INS;
    logic [5:0] FN;
    logic REG0n;
    logic REG1n;

    //Video Attributes
    logic INV;  //Flip screen (invert)
    logic INVn; //Negated flip screen
    logic B1X8; //BACK1 tile layer scroll X MSB
    logic B1Y8; //BACK1 tile layer scroll Y MSB
    logic F1X8;  //FRONT1 tile layer scroll X MSB
    logic F1Y8;  //FRONT1 tile layer scroll Y MSB
	logic F2X8;  //FRONT2 tile layer scroll X MSB
    logic F2Y8;  //FRONT2 tile layer scroll Y MSB
    
    //IO devices
    logic COIN;
    logic P1;
    logic P2;
    logic P1_P2;
    logic MCODE;
    logic DIP1;
    logic DIP2;

     logic clk_13p4_cen;
     logic clk_13p4;
     logic clk_13p4b_cen;
     logic clk_13p4b;
     logic clk_6p7_cen;
     logic clk_6p7b_cen;
     logic clk_3p35_cen;
     logic clk_3p35b_cen;
     logic clk_4_cen;
     logic clk_4b_cen;

    IkariWarriorsCoreClocks_Cen IK_clk_cen(
        .i_clk(i_clk),
        .clk_13p4_cen(clk_13p4_cen),
        .clk_13p4(clk_13p4),
        .clk_13p4b_cen(clk_13p4b_cen),
        .clk_13p4b(clk_13p4b),
        .clk_6p7_cen(clk_6p7_cen),
        .clk_6p7b_cen(clk_6p7b_cen),
        .clk_3p35_cen(clk_3p35_cen),
        .clk_3p35b_cen(clk_3p35b_cen),
        .clk_4_cen(clk_4_cen),
        .clk_4b_cen(clk_4b_cen)
    );
    
    assign player_ctrl_clk = clk_3p35_cen;
	assign CE_PIXEL = clk_6p7_cen; 

IkariWarriorsCore_Clocks IK_clocks(
    .clk(i_clk), //53.6
    .clk_13p4_cen(clk_13p4_cen), //CK0
    .clk_13p4(clk_13p4),
    .clk_13p4b_cen(clk_13p4b_cen), //CK0n
    .clk_13p4b(clk_13p4b),
    .clk_6p7_cen(clk_6p7_cen),
    .clk_6p7b_cen(clk_6p7b_cen),
    .reset(VIDEO_RSTn),
    .VIDEO_RSTn(VIDEO_RSTn),
    .INVn(INVn), 
    .F1SX(F1SX),
    .F1X8(F1X8),
    .F2SX(F2SX),
    .F2X8(F2X8),
    .VD_in(VD_in),
    .VRD(VRD), //replace for VRD
    .AE(AE), //replace for AE
    .BE(BE), //replace for BE
    //output
    .CK0(CK0),
    .CK0n(CK0n),
    .HLDn(HLDn),
    .CK1(CK1),
    .CK1n(CK1n),
    .H(H),
    .Hn(Hn),
    .FH(FH),
    .F1CK(F1CK),
    .F2CK(F2CK),
    .Y(Y),
    .X(X),
    .F1V(F1V),
    .F2V(F2V),
    .VCKn(VCKn),
    .VBL(VBL),
    .DISP(DISP),
    .SYNC(SYNC),
	.HBLANK(HBLANK),
	.VBLANK(VBLANK),
    .HSYNC(HSYNC),
    .VSYNC(VSYNC),
    .LT(LT),
    //
    .VWE(VWE),
    .VOE(VOE),
    .BWA(BWA),
    .A_B(A_B),
    .RLA(RLA),
    .RLB(RLB),
    .WBA(WBA),
    .WBB(WBB),
    .VDG(VDG),
    .VLK(VLK),
    .V_C(V_C),
    .VFLGn(VFLGn),
    .HD8(HD8),
    .LC(LC),
    .LD(LD),
    .LA(LA),
    .WR0(WR0),
    .WR1(WR1)
	);

    logic SND_BUSY;
    logic CPUA_WR;
    logic CPUA_RD;
    logic [7:0] CPUAD;

//    assign SND_BUSY = SND_BUSY_MUSIC & SND_BUSY_FX; //hack, duplicate sound hardware

    IkariWarriorsCore_CPU_A_B IK_cpuA_B
    (
        //inputs
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .pause_cpu(pause_cpu),
        .H0(H[0]),
        .Cen_p(clk_3p35_cen),
        .Cen_n(clk_3p35b_cen),
        .RESETn(VIDEO_RSTn),
        .PLAYER1(PLAYER1),
        .PLAYER2(PLAYER2),
        .DSW(DSW),
        .VBL(VBL),
        .BWA(BWA),
        .A_B(A_B),
        .RLA(RLA),
        .RLB(RLB),
        .WBA(WBA),
        .WBB(WBB),
        .VDG(VDG),
        //outputs
        .VRDn(VRD),
        .AE(AE), //cpuA Enable
        .BE(BE), //cpuB Enable
        
        //CPU A data bus
        .CPUAD(CPUAD),
        .CPUA_RD(CPUA_RD),
        .CPUA_WR(CPUA_WR),

        //common address bus
        .VA(VA),
        //common data bus
        .V_out(VD_in), //exchange buses
        .V_in(VD_out),
        
        //GAME
        .GAME(GAME),
        //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),
        
        //IO devices
        .SND_BUSY(SND_BUSY),
        .COIN(COIN),
        .P1(P1),
        .P2(P2),
        .P1_P2(P1_P2),
        .MCODE(MCODE),
        .DIP1(DIP1),
        .DIP2(DIP2),

        //video devices
        .FRONT1_VIDEO_CSn(FRONT1_VIDEO_CSn),
        .FRONT2_VIDEO_CSn(FRONT2_VIDEO_CSn),
        .BACK1_VRAM_CSn(BACK1_VRAM_CSn),
        .SIDE_VRAM_CSn(SIDE_VRAM_CSn),
        .DISC(DISC),
        .SSET(SSET), //side bank and side color bank
        .BSET(BSET), //Video Attribs.
        .F1SX(F1SX), //Front1 video scroll X
        .F1SY(F1SY), //Front1 video scroll Y
        .F2SX(F2SX), //Front2 video scroll X
        .F2SY(F2SY), //Front2 video scroll Y
        .B1SX(B1SX), //Back1 video scroll X
        .B1SY(B1SY), //Back1 video scroll Y
        .XSET(XSET),
        .YSET(YSET),
        .MSET(MSET),
        .F2INS(F2INS),
        .REG0(REG0n),
        .REG1(REG1n)
    );

    Dual_YM3526_Sound IK_snd
    (
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .pause_cpu(pause_cpu),
        .CEN_p(clk_4_cen),
        .CEN_n(clk_4b_cen),
        .RESETn(VIDEO_RSTn),
        .data_in(CPUAD),
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),
        .MCODE(MCODE),
        .MS(SND_BUSY),
        .snd1(snd1),
        .snd2(snd2),
        .sample(sample)
    );

    //Video Attributes
    //logic [1:0] BACK1_TILE_BANK; //For Side ROM bank selector
    //logic [3:0] BACK1_COLOR_BANK; //For Final Video Color Index bank selector
    //SIDE color BANK
    //logic [2:0] SIDE_COL_BANK; //for Final Video
    // logic COIN1_CNT, COIN2_CNT;
    // logic SIDE_ROM_BK;
    logic [7:0] F1Y;
    logic [7:0] F2Y;
    logic [1:0] SBK;
    logic [2:0] SD_COLOR_BANK;

    IkariWarriorsCore_Registers IK_registers(
        .VIDEO_RSTn(VIDEO_RSTn),
        .reset(VIDEO_RSTn),
        .clk(i_clk),
        .VD_in(VD_in), //VD data bus

        //Register BSET: B1X, B1Y MSBs, INV signal
        .BSET(BSET),
        .INV(INV), //Flip screen
        .INVn(INVn), //in real PCB use LS368 not buffer
        .B1X8(B1X8),
        .B1Y8(B1Y8),

        //Register SSET: side layer rom banks, side layer color palette bank
        .SSET(SSET),
        .SBK(SBK),
        .SD_COLOR_BANK(SD_COLOR_BANK), //SD6~4

        //Register MSET: front layers X, Y scroll MSBs
        .MSET(MSET),
        .F2Y8(F2Y8),
        .F2X8(F2X8),
        .F1Y8(F1Y8),
        .F1X8(F1X8),

        //Register F1SY: Front1 Y Scroll LSB
        .F1SY(F1SY),
        .F1Y(F1Y),

        //Register F2SY: Front2 Y Scroll LSB
        .F2SY(F2SY),
        .F2Y(F2Y)
    );

    //Side Layer hardware
    logic [6:0] SD;
    assign SD[6:4] = SD_COLOR_BANK;
    logic [7:0] side_vout;

    IkariWarriorsCore_Side IK_side(
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .CK1(CK1),
    //Flip screen control
        .INV(INV),
        .INVn(INVn),

    //common video data bus
        .VD_in(VD_in),
        .VD_out(side_vout),
     //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),
    //Side SRAM address selector
        .V_C(V_C),
    //A address
        .SIDE_VRAM_CSn(SIDE_VRAM_CSn),
        .VA(VA[10:0]),
    //B address
        .VFLGn(VFLGn),
        .H8(H[8]),
        .Y(Y[7:3]), //Y[7:3] in schematics
        .X(X), 

    //side SRAM control
        .VRD(VRD),
        .VDG(VDG),
        .VOE(VOE),
        .VWE(VWE),

    //clocking
        .VLK(VLK),
        .H2n(Hn[2]),
        .H1n(Hn[1]),
        .H0n(Hn[0]),

    //side palette index color
        .SBK(SBK),
        .SD(SD[3:0])
    );

    logic [7:0] B1D;
    //assign B1D[7:4] = BACK1_COLOR_BANK;
    logic [7:0] back1_vout;
    IkariWarriorsCore_Back1 IK_back1(
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .CK1(CK1),
        .RESET(VIDEO_RSTn),
        //Flip screen control
        .INV(INV), //Flip screen, in real pcb two LS368 chained gates
        .INVn(INVn),
        //common video data bus
        .VD_in(VD_in),
        .VD_out(back1_vout),
        //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),

        //dbg interface
        .dbg_B1Voffset(dbg_B1Voffset),
        .swap_px(swap_px),
        
    	  //SDRAM interface
        .rom_addr(rom_addr),
	     .rom_data(rom_data),
	     .rom_req(rom_req),
	     .rom_ack(rom_ack),
        //Registers
        .B1SY(B1SY),
        .B1SX(B1SX),
        //MSBs
        .B1Y8(B1Y8),
        .B1X8(B1X8),
        //VIDEO/CPU Selector
        .V_C(V_C),
        //B address
        .H8(H[8]),
        .Y(Y[7:4]), //Y[7:4] in schematics
        .H3(H[3]),
        .H2(H[2]),
        .H1(H[1]),
        .H0(H[0]),
        .X(X), 
        .VA(VA[10:0]),
        .BACK1_VRAM_CSn(BACK1_VRAM_CSn),
        
        //A address
        .VFLGn(VFLGn),

        //side SRAM control
        .VRD(VRD),
        .VDG(VDG),
        .VOE(VOE),
        .VWE(VWE),

        //clocking
        .CK1n(CK1n),
        .LA(LA),
        .VLK(VLK),
        //input wire H3

        .B1D(B1D[7:0])
    );
    
    logic [7:0] F1D;
    logic [8:0] FL_1Y;
    logic [8:0] SPR_1Y;
    logic [8:0] SPR_1X;
    logic [7:0] front1_vout;

    IkariWarriorsCore_Front1 IK_front1(
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .CK1(CK1),
        //common video data bus
        .VD_in(VD_in),
        .VD_out(front1_vout),
        //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),
        //Side SRAM address selector V/C
        .V_C(V_C),
        //B address
        .FRONT1_VIDEO_CSn(FRONT1_VIDEO_CSn),
        .VA(VA[11:0]), //VA[10:0] 2Kbytes Space for TNKIII
        //A address
        .VCKn(VCKn),
        //front SRAM control
        .VRD(VRD),
        .VDG(VDG),
        .VOE(VOE),
        .VWE(VWE),
        //clocking
        .FH(FH[8:4]),
        .F1V(F1V),
        .FN(FN[5:0]),
        .LC(LC),
        .VLK(VLK),
        .F1CK(F1CK),
        .H3(H[3]),
        .LD(LD),
        .CK0(CK0),
        //front data output
        .F1D(F1D),
        .SPR_1Y(SPR_1Y),
        .SPR_1X(SPR_1X),
        .FL_1Y(FL_1Y)
    );

    logic [7:0] F2D;
    logic [8:0] SPR_2Y;
    logic [7:0] front2_vout;

    IkariWarriorsCore_Front2 IK_front2(
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .CK1(CK1),
        //Side SRAM address selector V/C
        .V_C(V_C),
        //B address
        .FRONT2_VIDEO_CSn(FRONT2_VIDEO_CSn),
        .VA(VA[10:0]), 
        .VD_in(VD_in),
        .VD_out(front2_vout),
        //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),
        //A address
        .VCKn(VCKn),
        //front SRAM control
        .VRD(VRD),
        .VDG(VDG),
        .VOE(VOE),
        .VWE(VWE),
        //clocking
        .FH(FH[8:4]), //FH8,FH7,FH6,FH5,FH4
        .F2V(F2V),
        .LC(LC),
        .VLK(VLK),
        //The Front2 Sprite layer uses the two FCK clocks
        .F1CK(F1CK),
        .F2CK(F2CK),
        .H3(H[3]),
        .LD(LD),
        .CK0(CK0),
        //front data output
        .F2D(F2D),
        .SPR_2Y(SPR_2Y)
    );


    logic [7:0] L1D_BUF;
    logic FYocho1;
    assign FYocho1 = F1Y8;
    IkariWarriorsCore_LineBuffer IK_linebuf1(
        //inputs:
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .RESETn(VIDEO_RSTn),
        .FD(F1D),
        .LT(LT),
        .VCKn(VCKn),
        .CK1(CK1),
        .CK1n(CK1n),
        .CK0(CK0),
        .CK0n(CK0n),
        .FCK_LDn(~(F1CK & ~LD)),
        .FLY(FL_1Y), //comes from FRONT1 output
        .HLD(HLDn),
        .FY8(FYocho1),
        .FY(F1Y),
        .INVn(INVn),
        //output:
        .LD_BUF(L1D_BUF)
    );


    logic [7:0] L2D_BUF;
    logic FYocho2;
    assign FYocho2 = F2Y8;
    IkariWarriorsCore_LineBuffer IK_linebuf2(
        //inputs:
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .RESETn(VIDEO_RSTn),
        .FD(F2D),
        .LT(LT),
        .VCKn(VCKn),
        .CK1(CK1),
        .CK1n(CK1n),
        .CK0(CK0),
        .CK0n(CK0n),
        .FCK_LDn(~(F2CK & F1CK & ~LD)),
        .FLY(SPR_2Y), //comes from FRONT2 output
        .HLD(HLDn),
        .FY8(FYocho2),
        .FY(F2Y),
        .INVn(INVn),
        //output:
        .LD_BUF(L2D_BUF)
    );

    logic [7:0] FT_VD_out;

    IkariWarriorsCore_FrontTurbo IK_FrontTurbo(
        //clocks
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .H2n(Hn[2]),
        .H6(H[6]),
        .H7(H[7]),
        .XSET(XSET),
        .YSET(YSET),
        .F2INS(F2INS),
        .VD_in(VD_in),
        .VD_out(FT_VD_out),
        .SPR_1Y(SPR_1Y),
        .SPR_1X(SPR_1X),
        .VA(VA[6:5]), //VA6~5
        .WR0(WR0),
        .WR1(WR1),
        .REG0n(REG0n),
        .REG1n(REG1n),
        .FN(FN[5:0])
    );
    
    //Video out multiplexer
        assign VD_out = ( (!VDG && !SIDE_VRAM_CSn)     ? side_vout   : (
                          (!VDG && !BACK1_VRAM_CSn)    ? back1_vout  : (
                          (!VDG && !FRONT1_VIDEO_CSn)  ? front1_vout : (  
                          (!VDG && !FRONT2_VIDEO_CSn)  ? front2_vout : ( 
                          ((!REG0n || !REG1n)) ? FT_VD_out   : 8'hff ))))); //default bus data works as tri-state pulled up data bus

    IkariWarriorsCore_FinalVideo IK_video_mixer(
    //clocks
        .VIDEO_RSTn(VIDEO_RSTn),
        .clk(i_clk),
        .HD8(HD8),
        .H1(H[1]),
        .CK1(CK1),
        .CK1n(CK1n),
        //hps_io rom interface
        .ioctl_addr(ioctl_addr[19:0]),
        .ioctl_wr(ioctl_wr),
        .ioctl_data(ioctl_data),

        //dbg layer en/disable interface
        .layer_ena_dbg(layer_ena_dbg),
        //Graphics layers
        .L1D(L1D_BUF), //Line buffer1
        .L2D(L2D_BUF[6:0]), //Line buffer2
        .SD(SD), //Side layer
        .B1D(B1D), //Background layer
        //.B1D(8'hff), //Background layer

        //Final pixel color RGB triplet
        .DISP(DISP), //enable/disable pixel color
        //Final pixel color RGB triplet,
        .R(R),
        .G(G),
        .B(B)
    );

    assign SCR_X = X;
    assign SCR_Y = {H[8],Y[7:3],H[2:0]};
    assign PIX_CLK = CK1;
endmodule
