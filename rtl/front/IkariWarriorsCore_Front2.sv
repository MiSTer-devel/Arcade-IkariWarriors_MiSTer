//IkariWarriorsCore_Front2.sv
//32x32px Sprite Generator Layer
//Author: @RndMnkIII
//Date: 20/06/2022
`default_nettype none
`timescale 1ns/1ps


module IkariWarriorsCore_Front2(
    input  wire VIDEO_RSTn,
    input wire clk,
     input wire CK1,
    //Side SRAM address selector V/C
     input wire V_C,
    //B address
    input wire FRONT2_VIDEO_CSn,
    input wire [10:0] VA,
    input wire [7:0] VD_in,
    output logic [7:0] VD_out,
    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire               ioctl_wr,
    //A address
     input wire VCKn,
    //front SRAM control
    input wire VRD,
    input wire VDG,
    input wire VOE,
    input wire VWE,
    //clocking
     input wire [4:0] FH, //FH8,FH7,FH6,FH5,FH4
     input wire [8:0] F2V,
     input wire LC,
     input wire VLK,
    //The Front2 Sprite layer uses the two FCK clocks
     input wire F1CK,
     input wire F2CK,
     input wire H3,
     input wire LD,
     input wire CK0,
    //front data output
    output logic [7:0] F2D,
	 output logic [8:0] SPR_2Y
);
    logic [7:0] D0_in, D1_in;
    logic [7:0] Q0, Q1;
    logic [7:0] D0_out, D1_out;
    logic [7:0] Dreg0, Dreg1 ;

    logic F2B1, F2B0;
	logic f2dum2,f2dum3;
    ttl_74139_nodly b2_cpu_pcb(.Enable_bar(FRONT2_VIDEO_CSn), .A_2D({1'b0,VA[0]}), .Y_2D({f2dum3, f2dum2, F2B1, F2B0}));
    
    //bus multiplexers between video data common bus and front SRAM ICs.
    logic R5_EN; //F10 LS32 UnitA
    logic S5_EN; //F10 LS32 UnitB

    assign R5_EN =~(F2B0 | VDG);
    assign S5_EN =~(F2B1 | VDG);

    assign D0_in = (R5_EN && VRD) ? VD_in : 8'hFF;
    assign D1_in = (S5_EN && VRD) ? VD_in : 8'hFF;

    // DIR=L B->A, DIR=H A->B
    // A (VD) -> B(Dx)
    logic [9:0] A;
    logic B1CSn, B0CSn;
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) P8 (.Enable_bar(1'b0), .Select(V_C), .A_2D({F2B1,VCKn,F2B0,VCKn,VA[10],1'b0,VA[9],1'b0}), .Y({B1CSn, B0CSn, A[9:8]}));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) R8 (.Enable_bar(1'b0), .Select(V_C), .A_2D({VA[8],1'b0,VA[7],1'b0,VA[6],FH[4],VA[5],FH[3]}), .Y(A[7:4]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) T7 (.Enable_bar(1'b0), .Select(V_C), .A_2D({VA[4],FH[2],VA[3],FH[1],VA[2],FH[0],VA[1],H3}), .Y(A[3:0]));

    //--- TMM2016BP-100 100ns, only used per IC: WORKRAM (1Kbyte), SPRITE RAM (64 bytes) ---
    //Ikari Warriors uses VA[10:0] 1Kbytesx2 FRONT2 RAM space

    //add one clock delay to VCKn
    logic VCKn_reg;
    always @(posedge clk) begin
        VCKn_reg <= VCKn;
    end
    SRAM_dual_sync #(.ADDR_WIDTH(10)) P7_byte0
    (
        .ADDR0({VA[10:1]}), 
        .clk0(clk), 
        .cen0(~F2B0), 
        .we0(~VWE), 
        .DATA0(D0_in), 
        .Q0(Q0),
        .ADDR1({4'b0000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg0)
    );

    SRAM_dual_sync #(.ADDR_WIDTH(10)) S7_byte1
    (
        .ADDR0({VA[10:1]}), 
        .clk0(clk), 
        .cen0(~F2B1), 
        .we0(~VWE), 
        .DATA0(D1_in), 
        .Q0(Q1),
        .ADDR1({4'b0000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg1)
    );

    assign D0_out = (!VOE) ? Q0 : 8'hff;
    assign D1_out = (!VOE) ? Q1 : 8'hff;


    assign VD_out = ( (!VRD && R5_EN) ? D0_out : (
                      (!VRD && S5_EN) ? D1_out : 8'hff
                    ));

	logic LOW_SPR_DATA_CLK ;
	logic HI_SPR_DATA_CLK ;

	assign LOW_SPR_DATA_CLK = VLK | H3;
	assign HI_SPR_DATA_CLK  = VLK | ~H3;

     logic [7:0] N5_Q;
    //Sprite X offset
    ttl_74273_sync g2(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(LOW_SPR_DATA_CLK), .D(Dreg0), .Q(N5_Q));
     logic [7:0] Tile_num;
    //Sprite Tile Number
    ttl_74273_sync g3(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(LOW_SPR_DATA_CLK), .D((!VCKn_reg ? Dreg1 : 8'hff)), .Q(Tile_num));
     logic [7:0] Y_offset;
    //Sprite Y offset
    ttl_74273_sync g4(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(HI_SPR_DATA_CLK), .D(Dreg0), .Q(Y_offset));
     logic [7:0] S2_Q;
    //Sprite attributes
    ttl_74273_sync g5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(HI_SPR_DATA_CLK), .D((!VCKn_reg ? Dreg1 : 8'hff)), .Q(S2_Q));

	assign SPR_2Y[8] = S2_Q[7];
	assign SPR_2Y[7:0] = Y_offset;

    //HACK
    // logic [7:0] SYNC_SPR_Q;
    // ttl_74273_sync sync_spr(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F2CK), .D(Y_offset), .Q(SYNC_SPR_Q));
    //assign SPR_2Y[7:0] = SYNC_SPR_Q;
    
     logic [3:0] Spr_Color_Bank;
     logic X_offset_MSB;
     logic Spr_Bank_Sel; //Ikari warriors 1024 tiles
     logic Spr_XFlip; //Ikari Warriors Front2 32x32 sprites
     logic Y_offset_MSB;

    assign  Spr_XFlip = S2_Q[5];
    assign  X_offset_MSB = ~S2_Q[4];

    logic [7:0] X_offset;
    
    // generate
    //     for(i=0; i<8; i++) begin : x_offset_gen
    //         assign X_offset[i] = ~N5_Q[i];
    //     end
    // endgenerate
    assign X_offset = ~N5_Q;

    logic t2_dum;
    ttl_74174_sync T2(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(F2CK), .Clr_n(1'b1), .D({1'b1,S2_Q[6],S2_Q[3:0]}),.Q({t2_dum,Spr_Bank_Sel,Spr_Color_Bank}));
    //ttl_74174_sync T2(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(F2CK), .Clr_n(1'b1), .D({S2_Q[7],S2_Q[6],S2_Q[3:0]}),.Q({SPR_2Y[8],Spr_Bank_Sel,Spr_Color_Bank}));

    logic [7:0] S3_Q;
    ttl_74273_sync G5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F2CK), .D(Tile_num), .Q(S3_Q));

    logic [1:0] t3_dum;
    ttl_74174_sync T3(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(LC), .Clr_n(1'b1), .D({Spr_Color_Bank,2'b11}), .Q({F2D[6:3],t3_dum}));
    assign F2D[7] = 1'b0;



    // logic X8OFFr, F2V8r, M7COUTr ;
    // logic [3:0] M7SUMr, L8SUMr ;

    // always @(posedge clk) begin
    //     X8OFFr  <= X_offset_MSB;
    //     F2V8r    <= F2V[8];
    //     M7COUTr <= M7_cout;
    //     M7SUMr  <= M7_sum;
    //     L8SUMr  <= L8_sum;
    // end

     logic N7;
    // assign N7 = F2V8r ^ X8OFFr ^ M7COUTr;
    assign N7 = F2V[8] ^ X_offset_MSB ^ M7_cout;

    logic [3:0] M7_sum;
    logic M7_cout;
    ttl_74283_nodly M7 (.A(F2V[7:4]), .B(X_offset[7:4]), .C_in(L8_cout),  .Sum(M7_sum), .C_out(M7_cout));

    logic [3:0] L8_sum;
    logic L8_cout;
    ttl_74283_nodly L8 (.A(F2V[3:0]), .B(X_offset[3:0]), .C_in(1'b1), .Sum(L8_sum), .C_out(L8_cout));

    //Sprite 32x32 X-Flip, Ikari Warriors
    logic [4:0] Xsum_Flip;
    genvar i;
    generate
        for(i=0; i<4; i++) begin : x_flip_gen
            assign Xsum_Flip[i] = L8_sum[i] ^ Spr_XFlip;
        end
    endgenerate
    assign Xsum_Flip[4] = M7_sum[0] ^ Spr_XFlip;

     logic L7;
	 assign L7 = ~(&M7_sum[3:1] & N7);

    logic [5:0] L4_Q;
    ttl_74174_sync L4(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(F2CK), .Clr_n(1'b1), .D({L7,Xsum_Flip}), .Q(L4_Q));

     logic [1:0] ROM_Bank_CS;

    always_comb begin : Rom_bank_Selector
        casex ({Spr_Bank_Sel,L4_Q[5]})
            2'bx1: ROM_Bank_CS = 2'b00; //NONE ROM Selected
            2'b00: ROM_Bank_CS = 2'b01; //ROM0 Side Selected
            2'b10: ROM_Bank_CS = 2'b10; //ROM1 Side Selected
        endcase
    end

    //HN27256G-30 300ns 32Kx8 x2 x3 FRONT ROMS ---
    wire P11_cs = (ioctl_addr >= 25'h90_000) & (ioctl_addr < 25'h98_000); //ROM0
	wire P14_cs = (ioctl_addr >= 25'h98_000) & (ioctl_addr < 25'hA0_000); //ROM1
    wire P12_cs = (ioctl_addr >= 25'hA0_000) & (ioctl_addr < 25'hA8_000); //ROM0
	wire P15_cs = (ioctl_addr >= 25'hA8_000) & (ioctl_addr < 25'hB0_000); //ROM1
    wire P13_cs = (ioctl_addr >= 25'hB0_000) & (ioctl_addr < 25'hB8_000); //ROM0
	wire P16_cs = (ioctl_addr >= 25'hB8_000) & (ioctl_addr < 25'hC0_000); //ROM1

    logic [7:0] P11_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    //logic P11_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    eprom_32K P11_4M //ROM0
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P11_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P11_cs),
        .WR(ioctl_wr)
    );

    logic [7:0] P14_Dout;
    //logic  P14_Dout;
    eprom_32K P14_2M //ROM1
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P14_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P14_cs),
        .WR(ioctl_wr)
    );

	logic [7:0] F2D0_Byte;
    assign F2D0_Byte = (~L4_Q[5]) ? ((Spr_Bank_Sel == 1'b0) ? P11_Dout : P14_Dout) : 8'hff;
    //assign F2D0_Byte = (ROM_Bank_CS == 2'b01) ? P11_Dout : ((ROM_Bank_CS == 2'b10) ? P14_Dout : 8'hFF);
    PLSO_shift M1 (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(F2D0_Byte), .SO(F2D[0]));

    logic [7:0] P12_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    //logic P12_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    eprom_32K P12_4P //ROM0
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P12_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P12_cs),
        .WR(ioctl_wr)
    );

    logic [7:0] P15_Dout;
    //logic P15_Dout;
    eprom_32K P15_2P //ROM1
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P15_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P15_cs),
        .WR(ioctl_wr)
    );

	logic [7:0] F2D1_Byte; 
    assign F2D1_Byte = (~L4_Q[5]) ? ((Spr_Bank_Sel == 1'b0) ? P12_Dout : P15_Dout) : 8'hff;
    //assign F2D1_Byte = (ROM_Bank_CS == 2'b01) ? P12_Dout : ((ROM_Bank_CS == 2'b10) ? P15_Dout : 8'hFF);
    PLSO_shift P1 (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(F2D1_Byte), .SO(F2D[1]));

    logic [7:0] P13_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    //logic P13_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    eprom_32K P13_4R //ROM0
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P13_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P13_cs),
        .WR(ioctl_wr)
    );

    logic [7:0] P16_Dout;
    //logic P16_Dout;
    eprom_32K P16_2R //ROM1
    (
        .ADDR({S3_Q,L4_Q[4:0],F2CK,F1CK}),
        .CLK(clk),
        .DATA(P16_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P16_cs),
        .WR(ioctl_wr)
    );

	logic [7:0] F2D2_Byte;
    assign F2D2_Byte = (~L4_Q[5]) ? ((Spr_Bank_Sel == 1'b0) ? P13_Dout : P16_Dout) : 8'hff;
    //assign F2D2_Byte = (ROM_Bank_CS == 2'b01) ? P13_Dout : ((ROM_Bank_CS == 2'b10) ? P16_Dout : 8'hFF);
    PLSO_shift R1 (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(F2D2_Byte), .SO(F2D[2]));
endmodule

