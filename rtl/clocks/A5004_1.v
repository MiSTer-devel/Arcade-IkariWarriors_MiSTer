//Ikari Warriors A5004-1 PAL16R6 (same as Athena A6001-1 PAL16R6)
//Author: @RndMnkIII
//Date: 15/06/2022
//Converted from Ikari-A5004-1-GAL.jed using MAME's jedutil tool
//Many thanks to @Porchy and pldarchive.co.uk for the JED files.
`default_nettype none
`timescale 1ns/1ps

module A5004_1 (
    Reset_n,
    clk, //1
    //(*direct_enable*) Cen, //Clock enable
    Cen, //Clock enable
    F15_BE_Qn, //2 
    C3A_Q, //3
    F15_AE_Qn,  //4
    C3A_Qn, //5
    A15_QA, //6
    A15_QB, //7
    A15_QC, //8
    PLOAD_RSHIFTn, //12 
    VDG, //14
    RL_Sel, //15
    VLK, //16
    AB_Sel, //17
    V_C, //18
    G15_CE //19
);
    input wire Reset_n;
    input wire clk;
    input wire Cen;
    input wire F15_BE_Qn;
    input wire C3A_Q;
    input wire F15_AE_Qn;
    input wire C3A_Qn;
    input wire A15_QA;
    input wire A15_QB;
    input wire A15_QC;
    output wire PLOAD_RSHIFTn;
    output wire VDG;
    output wire RL_Sel;
    output wire VLK;
    output wire AB_Sel;
    output wire V_C;
    output wire G15_CE;

    reg rVDG, rRL_Sel, rVLK, rAB_Sel, rV_C;
    wire rVDGn, rRL_Seln, rVLKn, rAB_Seln, rV_Cn;
    wire rVDGneg, rRL_Selneg, rVLKneg, rAB_Selneg, rV_Cneg;
    wire VDGterm, RL_Selterm, VLKterm, AB_SELterm, V_Cterm;
    wire A15_QCn, A15_QBn;
    wire F15_AE_Q;
	
    assign  A15_QCn = ~A15_QC;
    assign  A15_QBn = ~A15_QB;
    assign  F15_AE_Q = ~F15_AE_Qn; //fix temporal, check and delete this

    assign  PLOAD_RSHIFTn = ~((                                       A15_QCn & rV_Cn) |
                              (F15_BE_Qn &      F15_AE_Qn &           C3A_Q          ) |
                              (F15_BE_Qn &      F15_AE_Qn &           A15_QCn        ) |
                              (F15_BE_Qn &      F15_AE_Qn & C3A_Q   & C3A_Q   & rV_Cn));

    //------------------------------------------------------
    assign  VDGterm = A15_QBn & rV_Cn;
    
    reg last_cen;
    always @(posedge clk) begin
        if (!Reset_n) begin
            rVDG     <= 1'b0;
            rRL_Sel  <= 1'b0;
            rVLK     <= 1'b0;
            rAB_Sel  <= 1'b0;
            rV_C     <= 1'b0;
            last_cen <= 1'b1;
        end
        else begin
            last_cen <= Cen;
            if(Cen && !last_cen)  begin //trigger on positive edge change
                rVDG    <= VDGterm;
                rRL_Sel <= RL_Selterm;
                rVLK    <= VLKterm;
                rAB_Sel <= AB_SELterm;
                rV_C    <= V_Cterm;
            end
        end
    end

    assign  rVDGn = ~rVDG;
    assign  rVDGneg = ~rVDGn;
    assign  VDG = ~rVDG;
    //------------------------------------------------------

    assign  RL_Selterm = A15_QA & A15_QBn & rV_Cn; //FIXED

    assign  rRL_Seln = ~rRL_Sel;
    assign  rRL_Selneg = ~rRL_Seln;
    assign  RL_Sel = ~rRL_Sel;

    //------------------------------------------------------
    assign  VLKterm = C3A_Qn & A15_QA & A15_QBn & rV_Cneg; //FIXED

    assign  rVLKn = ~rVLK;
    assign  rVLKneg = ~rVLKn;
    assign  VLK = ~rVLK;
    //------------------------------------------------------
    assign  AB_SELterm = F15_AE_Q; //negated of F15_AE_Qn
    
    assign  rAB_Seln = ~rAB_Sel;
    assign  rAB_Selneg = ~rAB_Seln;
    assign  AB_Sel = ~rAB_Sel;

    //------------------------------------------------------
    assign  V_Cterm = F15_BE_Qn & F15_AE_Qn;

    assign  rV_Cn = ~rV_C;
    assign  rV_Cneg = ~rV_Cn;
    assign  V_C = ~rV_C;

    //------------------------------------------------------
    assign  G15_CE = ~(rV_Cneg | A15_QB); //FIXED: infered from logic analyzer capture

endmodule