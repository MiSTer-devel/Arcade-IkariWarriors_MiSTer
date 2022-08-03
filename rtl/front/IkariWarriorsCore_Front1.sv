//IkariWarriorsCore_Front1.sv
//Author: @RndMnkIII
//Date: 20/06/2022
`default_nettype none
`timescale 1ns/1ps


module IkariWarriorsCore_Front1(
    input  wire VIDEO_RSTn,
    input wire clk,
    input wire CK1,
    //Side SRAM address selector V/C
    input wire V_C ,
    //B address
    input wire FRONT1_VIDEO_CSn,
    input wire [11:0] VA,
    input wire [7:0] VD_in,
    output logic [7:0] VD_out,
    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire               ioctl_wr,
    //A address
    input wire VCKn ,
    //front SRAM control
    input wire VRD,
    input wire VDG,
    input wire VOE,
    input wire VWE,
    //clockiny
    input wire [4:0] FH , //FH8,FH7,FH6,FH5,FH4
    input wire [8:0] F1V ,
	input wire [5:0] FN ,
    input wire LC,
    input wire VLK ,
    input wire F1CK ,
    input wire H3 ,
    input wire LD,
    input wire CK0,
    //front data output
    output logic [7:0] F1D ,
	output logic [8:0] SPR_1Y ,
    output logic [8:0] SPR_1X ,
    output logic [8:0] FL_1Y 
);
    logic [7:0] D0_in, D1_in, D2_in, D3_in ;
    logic [7:0] Q0, Q1, Q2, Q3;
    logic [7:0] D0_out, D1_out, D2_out, D3_out;
    logic [7:0] Dreg0, Dreg1, Dreg2, Dreg3 ;

    logic F1B3, F1B2, F1B1, F1B0;
    ttl_74139_nodly b2_cpu_pcb(.Enable_bar(FRONT1_VIDEO_CSn), .A_2D(VA[1:0]), .Y_2D({F1B3, F1B2, F1B1, F1B0}));
    
    //bus multiplexers between video data common bus and front SRAM ICs.
    logic F2_EN; //F10 LS32 UnitA
    logic F3_EN; //F10 LS32 UnitB
    logic F4_EN; //F10 LS32 UnitC
    logic F5_EN; //F10 LS32 UnitD

    assign F2_EN =~(F1B0 | VDG);
    assign F3_EN =~(F1B1 | VDG);
    assign F4_EN =~(F1B2 | VDG);
    assign F5_EN =~(F1B3 | VDG);

    assign D0_in = (F2_EN && VRD) ? VD_in : 8'hFF;
    assign D1_in = (F3_EN && VRD) ? VD_in : 8'hFF;
    assign D2_in = (F4_EN && VRD) ? VD_in : 8'hFF;
    assign D3_in = (F5_EN && VRD) ? VD_in : 8'hFF;

    // DIR=L B->A, DIR=H A->B
    // A (VD) -> B(Dx)
    logic [10:0] A;
    logic B3CSn, B2CSn, B1CSn, B0CSn;
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) K6 (.Enable_bar(1'b0), .Select(V_C), .A_2D({F1B3,VCKn,F1B2,VCKn,F1B1,VCKn,F1B0,VCKn}), .Y({B3CSn, B2CSn, B1CSn, B0CSn}));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) J6 (.Enable_bar(1'b0), .Select(V_C), .A_2D({1'b0,1'b0, VA[11],1'b1,  VA[10],1'b0,  VA[9],1'b0}), .Y(A[10:7]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) K8 (.Enable_bar(1'b0), .Select(V_C), .A_2D({VA[8],1'b0,VA[7],FH[4],VA[6],FH[3],VA[5],FH[2]}), .Y(A[6:3]));
	
	logic j8_dum;
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) J8 (.Enable_bar(1'b0), .Select(V_C), .A_2D({VA[4],FH[1],VA[3],FH[0],VA[2],H3,1'b1,1'b1}), .Y({A[2:0],j8_dum}));


	//Compare if FN[5:0] > {FH[4:0],H3}
	//in the PCB are used two HD74LS85 4bit magnitude commparators chained to compare two 6bit values.
	logic FHltFN ;
	assign FHltFN = ({FH[4:0],H3} < FN[5:0]) ? 1'b1: 1'b0;

	logic p7reg;
	DFF_pseudoAsyncClrPre #(.W(1)) P7 (
        .clk(clk),
        .rst(1'b0),
        .din(FHltFN),
        .q(p7reg),
        .qn(),
        .set(1'b0),    // active high
        .clr(1'b0),    // active high
        .cen(VLK) // signal whose edge will trigger the FF
    );
	
    //add one clock delay to VCKn
    //logic VCKn_reg;
    // always @(posedge clk) begin
    //     VCKn_reg <= VCKn;
    // end

    //--- TMM2016BP-100 100ns, only used per IC: WORKRAM (1Kbyte), SPRITE RAM (64 bytes) ---
    //Ikari Warriors uses VA[11:0] 4Kbytes FRONT RAM space
    SRAM_dual_sync #(.ADDR_WIDTH(10)) h2_byte0
    (
        .ADDR0({VA[11:2]}), 
        .clk0(clk), 
        .cen0(~F1B0), 
        .we0(~VWE), 
        .DATA0(D0_in), 
        .Q0(Q0),
        .ADDR1({4'b1000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg0)
    );

    SRAM_dual_sync #(.ADDR_WIDTH(10)) h3_byte1
    (
        .ADDR0({VA[11:2]}), 
        .clk0(clk), 
        .cen0(~F1B1), 
        .we0(~VWE), 
        .DATA0(D1_in), 
        .Q0(Q1),
        .ADDR1({4'b1000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg1)
    );


    SRAM_dual_sync #(.ADDR_WIDTH(10)) h5_byte2
    (
        .ADDR0({VA[11:2]}), 
        .clk0(clk), 
        .cen0(~F1B2), 
        .we0(~VWE), 
        .DATA0(D2_in), 
        .Q0(Q2),
        .ADDR1({4'b1000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg2)
    );

    SRAM_dual_sync #(.ADDR_WIDTH(10)) h6_byte3
    (
        .ADDR0({VA[11:2]}), 
        .clk0(clk), 
        .cen0(~F1B3), 
        .we0(~VWE), 
        .DATA0(D3_in), 
        .Q0(Q3),
        .ADDR1({4'b1000,FH[4:0],H3}), 
        .clk1(clk), 
        .cen1(~VCKn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(Dreg3)
    );

    assign D0_out = (!VOE && !F1B0) ? Q0 : 8'hff;
    assign D1_out = (!VOE && !F1B1) ? Q1 : 8'hff;
    assign D2_out = (!VOE && !F1B2) ? Q2 : 8'hff;
    assign D3_out = (!VOE && !F1B3) ? Q3 : 8'hff; 

    assign VD_out = ( (!VRD && F2_EN) ? D0_out : (
                      (!VRD && F3_EN) ? D1_out : (
                      (!VRD && F4_EN) ? D2_out : (
                      (!VRD && F5_EN) ? D3_out : 8'hff
                    ))));

    logic [7:0] G2_Q;
    //Sprite X offset
    ttl_74273_sync g2(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D(Dreg0), .Q(G2_Q));
    logic [7:0] Tile_num;
    //Sprite Tile Number
    ttl_74273_sync g3(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D((!VCKn ? Dreg1 : 8'hff)), .Q(Tile_num));
    logic [7:0] Y_offset;
    //Sprite Y offset
    ttl_74273_sync g4(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D(Dreg2), .Q(Y_offset));
    logic [7:0] C6_Q;
    //Sprite attributes
    ttl_74273_sync g5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D((!VCKn ? Dreg3 : 8'hff)), .Q(C6_Q));

	assign SPR_1Y[8] = C6_Q[7];
	assign SPR_1Y[7:0] = Y_offset;
    
    logic [3:0] Spr_color_bank;
    logic X_offset_MSB;
    logic [1:0] Spr_bank; //Ikari warriors 1024 tiles
    logic Spr_XFlip; //TNKIII
    logic Y_offset_MSB;

    //C6_Q[6]
    //C6_Q[5]
    //assign  Spr_XFlip = C6_Q[5];
    assign  X_offset_MSB = ~C6_Q[4];


    logic [7:0] X_offset;
    genvar i;
    generate
        for(i=0; i<8; i++) begin : x_offset_gen
            assign X_offset[i] = ~G2_Q[i];
        end
    endgenerate

    assign SPR_1X[7:0] = X_offset;
    assign SPR_1X[8]   = X_offset_MSB;

    //Spr_bank have 2 bits
	logic f1d7_8reg;
	ttl_74273_sync C5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F1CK), .D({p7reg,C6_Q[7:5],C6_Q[3:0]}), .Q({f1d7_8reg,FL_1Y[8],Spr_bank,Spr_color_bank}));

   ttl_74273_sync D5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F1CK), .D(Y_offset), .Q(FL_1Y[7:0]));

   logic [7:0] G5_Q;
   ttl_74273_sync G5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F1CK), .D(Tile_num), .Q(G5_Q));

	 //logic e7_D;
	 logic e5_cout;
	 logic [3:0] e5_sum;

    //assign e7_D = F1V[8] ^ X_offset_MSB;

    logic e7_C;

    logic X8OFFr, F1V8r, E5COUTr;
    logic [3:0] E5SUMr, E4SUMr;

    always @(posedge clk) begin
        X8OFFr  <= X_offset_MSB;
        F1V8r    <= F1V[8];
        E5COUTr <= e5_cout;
        E5SUMr  <= e5_sum;
        E4SUMr  <= e4_sum;
    end
    //assign e7_C = e7_D ^ e5_cout;
    assign e7_C = F1V8r ^ X8OFFr ^ E5COUTr;

    logic e4_cout;
    ttl_74283_nodly e5 (.A(F1V[7:4]), .B(X_offset[7:4]), .C_in(e4_cout),  .Sum(e5_sum), .C_out(e5_cout));

    logic [3:0] e4_sum;
    ttl_74283_nodly e4 (.A(F1V[3:0]), .B(X_offset[3:0]), .C_in(1'b1), .Sum(e4_sum), .C_out(e4_cout));

    //Sprite X flip, TNKIII
    // logic [3:0] e4_flip;
    // generate
    //     for(i=0; i<4; i++) begin : x_flip_gen
    //         assign e4_flip[i] = e4_sum[i] ^ Spr_XFlip;
    //     end
    // endgenerate

    logic e6_B;
    assign e6_B = &E5SUMr;
    
    logic e8_C;
    assign e8_C = ~(e7_C & e6_B);

    logic [4:0] L5_Q;
    //logic E8_dummy;

    logic l5_dum;
    ttl_74174_sync L5
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(F1CK),
        .Clr_n(1'b1),
        .D({1'b1,e8_C,E4SUMr}), //Ikari Warriors
        .Q({l5_dum,L5_Q})
    );

    logic B5_dum;

    ttl_74174_sync B5
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(LC),
        .Clr_n(1'b1),
        .D({f1d7_8reg,Spr_color_bank,1'b1}),
        .Q({F1D[7:3],B5_dum})
    );

    //HN27256G-30 300ns 32Kx8x3 FRONT ROMS ---
    wire P8_3D_cs = (ioctl_addr >= 25'h60_000) & (ioctl_addr < 25'h68_000);
	wire P9_3F_cs  = (ioctl_addr >= 25'h70_000) & (ioctl_addr < 25'h78_000); 
	wire P10_3H_cs  = (ioctl_addr >= 25'h80_000) & (ioctl_addr < 25'h88_000);

    logic [7:0] P8_D, P8_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA7
    eprom_32K P8_3D
    (
        .ADDR({Spr_bank,G5_Q,L5_Q[3:0],F1CK}),
        .CLK(clk),
        .DATA(P8_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P8_3D_cs),
        .WR(ioctl_wr)
    );

    assign P8_D = (!L5_Q[4]) ? P8_Dout : 8'hFF;

    logic [7:0] P9_D, P9_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA6
    eprom_32K P9_3F
    (
        .ADDR({Spr_bank,G5_Q,L5_Q[3:0],F1CK}),
        .CLK(clk),
        .DATA(P9_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P9_3F_cs),
        .WR(ioctl_wr)
    );
    assign P9_D = (!L5_Q[4]) ? P9_Dout : 8'hFF;

    logic [7:0] P10_D,P10_Dout; //On PCB pulled to Vcc with 4.7Kx8 RA5
    eprom_32K P10_3H
    (
        .ADDR({Spr_bank,G5_Q,L5_Q[3:0],F1CK}),
        .CLK(clk),
        .DATA(P10_Dout),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P10_3H_cs),
        .WR(ioctl_wr)
    );
    assign P10_D = (!L5_Q[4]) ? P10_Dout : 8'hFF;

//    logic LD_reg;
//    always @(posedge clk) begin
//       LD_reg <= LD; 
//    end
    PLSO_shift g10 (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(P8_D), .SO(F1D[0]));
    PLSO_shift g9  (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(P9_D),  .SO(F1D[1]));
    PLSO_shift g8  (.RESETn(VIDEO_RSTn), .CLK(clk), .CEN(~CK0), .LOADn(LD), .SI(1'b1), .D(P10_D),  .SO(F1D[2]));
endmodule

module PLSO_shift (RESETn, CLK, CEN, LOADn, SI, D, SO); 
    input wire RESETn, CLK, CEN, SI, LOADn; 
    input wire [7:0] D; 
    output wire SO;

    reg [7:0] tmp; 
    reg last_cen;

    always @(posedge CLK) 
    begin 
        if (!RESETn) begin
            tmp <= 0;
            last_cen = 1'b1;
        end
        else begin
            last_cen <= CEN;

            if (CEN && !last_cen) begin
                if (!LOADn) tmp <= D; 
                else        tmp <= {tmp[6:0], SI};
            end 
        end
    end 

    assign SO = tmp[7]; 
endmodule 
