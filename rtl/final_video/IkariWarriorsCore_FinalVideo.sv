//IkariWarriorsCore_FinalVideo.sv
//Author: @RndMnkIII
//Date: 22/06/2022
`default_nettype none
`timescale 1ns/1ps

module IkariWarriorsCore_FinalVideo(
    //clocks
    input  wire VIDEO_RSTn,
    input wire clk,
    input wire HD8,
    input wire H1,
    input wire CK1,
    input wire CK1n,
    //hps_io rom interface
    input wire         [24:0] ioctl_addr,
    input wire         [7:0] ioctl_data,
    input wire               ioctl_wr,
    //Graphics layers
    input wire [3:0] layer_ena_dbg, //dbg interface to enable/disable layers
    input wire [7:0] L1D, //Line buffer1 8bits in Ikari Warriors
    input wire [6:0] L2D, //Line buffer2 7bits in Ikari Warriors
    input wire [6:0] SD, //Side layer 7bits in Ikari Warriors
    input wire [6:0] B1D, //Background layer, 7bits in Ikari Warriors

    //Final pixel color RGB triplet
    input wire DISP, //enable/disable pixel color
    output logic [3:0] R,
    output logic [3:0] G,
    output logic [3:0] B
);
    logic G4_Qn;

    DFF_pseudoAsyncClrPre #(.W(1)) G4 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(HD8),
        .q(),
        .qn(G4_Qn),
        .set(1'b0),    // active high
        .clr(1'b0),    // active high
        .cen(H1) // signal whose edge will trigger the FF
    );

    logic [6:0] SD_ena;
    assign SD_ena = (layer_ena_dbg[0]) ? SD : 7'h7f;
        
    logic [6:0] B1D_ena;
    assign B1D_ena = (layer_ena_dbg[1]) ? B1D : 7'h7f; 

    logic [7:0] L1D_ena;
    assign L1D_ena = (layer_ena_dbg[2]) ? L1D : {1'b0,7'h7f};

    logic [6:0] L2D_ena;
    assign L2D_ena = (layer_ena_dbg[3]) ? L2D : 7'h7f;



    logic G3n;
    assign G3n = ~(G4_Qn & SD_ena[3] & SD_ena[2] & SD_ena[1]);

    logic [7:0] SLD;
    logic [7:0] SLBD;

    ttl_74298_sync P1 (.VIDEO_RSTn(VIDEO_RSTn), .clk(clk), .Cen(CK1n), .WS(G3n), .A(L1D_ena[3:0]), .B(SD_ena[3:0]), .Q(SLD[3:0]));
    ttl_74298_sync P2 (.VIDEO_RSTn(VIDEO_RSTn), .clk(clk), .Cen(CK1n), .WS(G3n), .A(L1D_ena[7:4]), .B({1'b0,SD_ena[6:4]}), .Q(SLD[7:4]));

	 logic SD30AND;
    logic SD30AND_r; //input
    logic SD31_r; //input
    logic COLBANK3, COLBANK4, COLBANK5, LAYER_SELA, LAYER_SELB;
    A5004_3 N2(
    .SD31(G3n), //1
    .SD0(SD_ena[0]), //2
    .SLD7(SLD[7]), //3
    .SLD0(SLD[0]), //4
    .SLD1(SLD[1]), //5
    .SLD2(SLD[2]), //6
    .L2D0(L2D_ena[0]), //7
    .L2D1(L2D_ena[1]), //8
    .L2D2(L2D_ena[2]), //9
    .i11(1'b1), //11 VCC
    .SD31_r(SD31_r), //13
    .SD30_ANDr(SD30AND_r), //14
    //outputs
    .COLBANK5(COLBANK5), //12
    .LAYER_SELA(LAYER_SELA), //15
    .LAYER_SELB(LAYER_SELB), //16
    .COLBANK3(COLBANK3), //17
    .COLBANK4(COLBANK4), //18
    .SD30_AND(SD30AND) //19
    );
	 
    logic COLBANK5n, LAYER_SELAn;
    assign COLBANK5n = ~COLBANK5;
    assign LAYER_SELAn = ~LAYER_SELA;

    //Block1 = A
    //Block2 = B
    //A = {Block2, Block1};
    ttl_74153 #(.DELAY_RISE(0), .DELAY_FALL(0)) N1
    (
        .Enable_bar({2{1'b0}}),
        .Select({LAYER_SELB,LAYER_SELAn}),
        .A_2D({{L2D_ena[1], SLD[1], B1D_ena[1], B1D_ena[1]},{L2D_ena[0], SLD[0], B1D_ena[0], B1D_ena[0]}}),
        .Y(SLBD[1:0])
    );
    ttl_74153 #(.DELAY_RISE(0), .DELAY_FALL(0)) M1
    (
        .Enable_bar({2{1'b0}}),
        .Select({LAYER_SELB,LAYER_SELAn}),
        .A_2D({{L2D_ena[3], SLD[3], B1D_ena[3], B1D_ena[3]},{L2D_ena[2], SLD[2], B1D_ena[2], B1D_ena[2]}}),
        .Y(SLBD[3:2])
    );
    ttl_74153 #(.DELAY_RISE(0), .DELAY_FALL(0)) L2
    (
        .Enable_bar({2{1'b0}}),
        .Select({LAYER_SELB,LAYER_SELAn}),
        .A_2D({{L2D_ena[5], SLD[5], B1D_ena[5], B1D_ena[5]},{L2D_ena[4], SLD[4], B1D_ena[4], B1D_ena[4]}}),
        .Y(SLBD[5:4])
    );
    ttl_74153 #(.DELAY_RISE(0), .DELAY_FALL(0)) L1
    (
        .Enable_bar({2{1'b0}}),
        .Select({LAYER_SELB,LAYER_SELAn}),
        .A_2D({{4'b1111},{L2D_ena[6], SLD[6], B1D_ena[6], B1D_ena[6]}}),
        .Y(SLBD[7:6])
    );

    logic [9:0] COLOR_IDX;
    ttl_74174_sync K1
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1),
        .Clr_n(1'b1),
        .D(SLBD[5:0]),
        .Q(COLOR_IDX[5:0])
    );

    ttl_74174_sync K2
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1),
        .Clr_n(1'b1),
        .D({G3n,     SD30AND, COLBANK5n, COLBANK4, COLBANK3, SLBD[6]}),
        .Q({SD31_r, SD30AND_r, COLOR_IDX[9:6]})
    );

    //PROMS MB7122E x 3 See IkariWarriors_JP_interleave.mra
    wire H1_R_cs = (ioctl_addr >= 25'hD0_000) & (ioctl_addr < 25'hD0_400);
    wire J2_G_cs = (ioctl_addr >= 25'hD0_400) & (ioctl_addr < 25'hD0_800); 
    wire J1_B_cs = (ioctl_addr >= 25'hD0_800) & (ioctl_addr < 25'hD0_C00);     // 1KbytesX3 Color     PROMs
    
    //tAA (address change time): 25ns(typ) 45ns(max), tEN,tDIS (output enable/disable time): 30ns (max)
    logic [3:0] R4_D;
    logic [3:0] G4_D;
    logic [3:0] B4_D;

    prom_1K_4bit H1_R
    (
        .ADDR(COLOR_IDX),
        .CLK(clk),
        .DATA(R4_D),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data[3:0]),
        .CS_DL(H1_R_cs),
        .WR(ioctl_wr)
    );

    prom_1K_4bit J2_G
    (
        .ADDR(COLOR_IDX),
        .CLK(clk),
        .DATA(G4_D),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data[3:0]),
        .CS_DL(J2_G_cs),
        .WR(ioctl_wr)
    );

    prom_1K_4bit J1_B
    (
        .ADDR(COLOR_IDX),
        .CLK(clk),
        .DATA(B4_D),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data[3:0]),
        .CS_DL(J1_B_cs),
        .WR(ioctl_wr)
    );

  //Final stage RGB color output,the lines are NOT scrambled
    ttl_74174_sync G2
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1),
        .Clr_n(DISP),
        .D({R4_D[3:0],G4_D[1:0]}),
        .Q({R[3:0], G[1:0]})
    );

    ttl_74174_sync H2
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1),
        .Clr_n(DISP),
        .D({G4_D[3:2],B4_D[3:0]}),
        .Q({G[3:2], B[3:0]})
    );
endmodule
