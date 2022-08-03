//IkariWarriorsCore_LineBuffer.sv
//Author: @RndMnkIII
//Date: 21/06/2022
`default_nettype none
`timescale 1ns/1ps

module IkariWarriorsCore_LineBuffer(
    //inputs:
    input  wire VIDEO_RSTn,
    input wire clk,
    input wire RESETn,
    input wire [7:0] FD,
    input wire LT,
    input wire VCKn,
    input wire CK1,
    input wire CK1n,
    input wire CK0,
    input wire CK0n,
    input wire FCK_LDn,
    input wire [8:0] FLY, //comes from FRONT1 output
    input wire HLD,
    input wire FY8,
    input wire [7:0] FY,
    input wire INVn,
    //output:
    output logic [7:0] LD_BUF
);
    logic LTn;
    logic VCK;

    assign LTn = ~LT;
    assign VCK = ~VCKn;

    logic [8:0] W1A;
    logic A11_RCO;
    ttl_74163a_sync a11
    (
        .Clk(clk), //2
        .Rst_n(VIDEO_RSTn),
        .Clear_bar(1'b1), //1
        .Load_bar(FCK_LDn), //HACK
        .ENT(1'b1), //7
        .ENP(1'b1), //10
        .D(FLY[3:0]), //D 6, C 5, B 4, A 3
        .Cen(CK0),
        .RCO(A11_RCO), //15
        .Q(W1A[3:0]) //QD 11, QC 12, QB 13, QA 14
    );

    logic A12_RCO;
    ttl_74163a_sync a12
    (
        .Clk(clk), //2
        .Rst_n(VIDEO_RSTn),
        .Clear_bar(1'b1), //1
        .Load_bar(FCK_LDn), //HACK
        .ENT(A11_RCO), //7
        .ENP(1'b1), //10
        .D(FLY[7:4]), //D 6, C 5, B 4, A 3
        .Cen(CK0),
        .RCO(A12_RCO), //15
        .Q(W1A[7:4]) //QD 11, QC 12, QB 13, QA 14
    );

    logic [2:0] a13_dum;
    ttl_74163a_sync a13
    (
        .Clk(clk), //2
        .Rst_n(VIDEO_RSTn),
        .Clear_bar(1'b1), //1
        .Load_bar(FCK_LDn), //HACK
        .ENT(A12_RCO), //7
        .ENP(1'b1), //10
        .D({3'b111,FLY[8]}), //D 6, C 5, B 4, A 3
        .Cen(CK0),
        .RCO(), //15
        .Q({a13_dum,W1A[8]}) //QD 11, QC 12, QB 13, QA 14
    );

    //HACK: delay HLD signal to trigger load 
    logic HLDr;
    // logic FCK_LDnr;
    always @(posedge clk) begin
        HLDr <= HLD;
        //FCK_LDnr <= FCK_LDn;
    end

    logic [8:0] R1A;
    n9bit_counter ra_counter
    (
        .Reset_n(VIDEO_RSTn),
        .clk(clk), 
        .cen(CK1),
        .direction(INVn), // 1 = Up, 0 = Down
        .load_n(HLDr), //Use delayed signal for trigger with rising edge of CK1
        .ent_n(1'b0),
        .enp_n(1'b0),
        .P({FY8,FY}),
        .Q(R1A)   // 4-bit output
    );

    logic a14_A; //74LS20 4-input NAND gate
    assign a14_A = ~(&FD[2:0]);

    logic A8_B_Qn;
    DFF_pseudoAsyncClrPre #(.W(1)) a8_A (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(a14_A),
        .q(),
        .qn(A8_B_Qn),
        .set(1'b0),    // active high
        .clr(1'b0),    // active high
        .cen(CK0n) // signal whose edge will trigger the FF
    );

    logic D9_A_Q, D9_A_Qn;
    DFF_pseudoAsyncClrPre #(.W(1)) d9_A (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(D9_A_Qn),
        .q(D9_A_Q),
        .qn(D9_A_Qn),
        .set(1'b0),    // active high
        .clr(~LTn),    // active high
        .cen(VCK) // signal whose edge will trigger the FF
    );

    logic [8:0] L0A;
    logic L0OE, L0WE, L0CE;
    //ttl_74157 A_2D({B3,A3,B2,A2,B1,A1,B0,A0})
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b9 (.Enable_bar(1'b0), .Select(D9_A_Q),
                .A_2D({R1A[3],W1A[3],R1A[2],W1A[2],R1A[1],W1A[1],R1A[0],W1A[0]}), .Y(L0A[3:0]));
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b11 (.Enable_bar(1'b0), .Select(D9_A_Q),
                .A_2D({R1A[7],W1A[7],R1A[6],W1A[6],R1A[5],W1A[5],R1A[4],W1A[4]}), .Y(L0A[7:4]));
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b13 (.Enable_bar(1'b0), .Select(D9_A_Q),
                .A_2D({D9_A_Qn,1'b1, CK1,CK0, 1'b0,A8_B_Qn, R1A[8],W1A[8]}), .Y({L0OE,L0WE,L0CE,L0A[8]}));

    logic [8:0] L1A;
    logic L1OE, L1WE, L1CE;
    //ttl_74157 A_2D({B3,A3,B2,A2,B1,A1,B0,A0})
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b10 (.Enable_bar(1'b0), .Select(D9_A_Qn),
                .A_2D({R1A[3],W1A[3],R1A[2],W1A[2],R1A[1],W1A[1],R1A[0],W1A[0]}), .Y(L1A[3:0]));
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b12 (.Enable_bar(1'b0), .Select(D9_A_Qn),
                .A_2D({R1A[7],W1A[7],R1A[6],W1A[6],R1A[5],W1A[5],R1A[4],W1A[4]}), .Y(L1A[7:4]));
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) b14 (.Enable_bar(1'b0), .Select(D9_A_Qn),
                .A_2D({D9_A_Q,1'b1, CK1,CK0, 1'b0,A8_B_Qn, R1A[8],W1A[8]}), .Y({L1OE,L1WE,L1CE,L1A[8]}));


    //now dont use tristate bus for FPGA code
    logic [7:0] DL1_in, DL0_in;
    logic [7:0] DL1_out, DL0_out;

    ttl_74374_sync d14 (.RESETn(VIDEO_RSTn), .OCn(D9_A_Qn), .Clk(clk), .Cen(CK0n), .D(FD[7:0]), .Q(DL1_in));
    ttl_74374_sync d13 (.RESETn(VIDEO_RSTn), .OCn(D9_A_Q), .Clk(clk), .Cen(CK0n), .D(FD[7:0]), .Q(DL0_in));

    //TMM2018D-45 2K x 8bits NMOS Static RAM, only used 512 bytes per IC
    SRAM_sync_noinit #(.ADDR_WIDTH(9)) c13(.ADDR({L0A}), .clk(clk), .cen(~L0CE), .we(~L0WE), .DATA(DL0_in), .Q(DL0_out) );
    SRAM_sync_noinit #(.ADDR_WIDTH(9)) c14(.ADDR({L1A}), .clk(clk), .cen(~L1CE), .we(~L1WE), .DATA(DL1_in), .Q(DL1_out) );
    
    logic [7:0] DL0, DL1;
    assign DL0 = ((!L0OE && !L0CE) ? DL0_out : 8'hff); //simulate a tri state bus when the bus is tied to High value in the case of that nothing is connected to it.
    assign DL1 = ((!L1OE && !L1CE) ? DL1_out : 8'hff); //simulate a tri state bus when the bus is tied to High value in the case of that nothing is connected to it.

	ttl_74298_sync J2 (.VIDEO_RSTn(VIDEO_RSTn), .clk(clk), .Cen(CK1), .WS(D9_A_Qn), .A(DL0[7:4]), .B(DL1[7:4]), .Q(LD_BUF[7:4]));
	ttl_74298_sync H2 (.VIDEO_RSTn(VIDEO_RSTn), .clk(clk), .Cen(CK1), .WS(D9_A_Qn), .A(DL0[3:0]), .B(DL1[3:0]), .Q(LD_BUF[3:0]));
endmodule