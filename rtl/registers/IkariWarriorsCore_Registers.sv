//IkariWarriorsCore_Registers.sv
//Author: @RndMnkIII
//Date: 20/06/2022
`default_nettype none
`timescale 1ns/1ps


module IkariWarriorsCore_Registers(
  input wire VIDEO_RSTn,
  input wire reset,
  input wire clk,
  input wire [7:0] VD_in, //VD_in data bus

  //Register BSET: B1X, B1Y MSBs, INV signal
  input wire BSET,
  output logic INV, //Flip screen
  output logic INVn, //in real PCB use LS368 not buffer
  output logic B1X8,
  output logic B1Y8,

  //Register SSET: side layer rom banks, side layer color palette bank
  input wire SSET,
  output logic [1:0] SBK,
  output logic [2:0] SD_COLOR_BANK, //SD6~4

  //Register MSET: front layers X, Y scroll MSBs
  input wire MSET,
  output logic F2Y8,
  output logic F2X8,
  output logic F1Y8,
  output logic F1X8,

  //Register F1SY: Front1 Y Scroll LSB
  input wire F1SY,
  output logic [7:0] F1Y,

//Register F2SY: Front2 Y Scroll LSB
  input wire F2SY,
  output logic [7:0] F2Y
);
    reg [7:0] vdin_r;

     always @(posedge clk) begin
        vdin_r <= VD_in;
    end

	//Register BSET: B1X, B1Y MSBs, INV signal
    logic j4_dum5, j4_dum3, j4_dum2;
    ttl_74174_sync J4 (.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(BSET), .Clr_n(1'b1), .D(vdin_r[5:0]), .Q({j4_dum5,INV,j4_dum3,j4_dum2,B1Y8,B1X8}));
    assign INVn = ~INV; //add delay for one inverter buffer LS368 gate

	//Register SSET: side layer rom banks, side layer color palette bank
    logic p3_dum3;
    ttl_74174_sync P3 (.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(SSET), .Clr_n(1'b1), .D(vdin_r[5:0]), .Q({SBK,p3_dum3,SD_COLOR_BANK}));

	//Register MSET: front layers X, Y scroll MSBs
    logic [1:0] m5_dum;
    ttl_74174_sync M5 (.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(MSET), .Clr_n(1'b1), .D(vdin_r[5:0]), .Q({F2Y8,F1Y8,F2X8,F1X8,m5_dum}));

	//Register F1SY: Front1 Y Scroll LSB
    ttl_74273_sync P5(.RESETn(reset), .CLRn(1'b1), .Clk(clk), .Cen(F1SY), .D(vdin_r), .Q(F1Y[7:0]));

	//Register F2SY: Front2 Y Scroll LSB
	ttl_74273_sync S5(.RESETn(reset), .CLRn(1'b1), .Clk(clk), .Cen(F2SY), .D(vdin_r), .Q(F2Y[7:0]));
endmodule