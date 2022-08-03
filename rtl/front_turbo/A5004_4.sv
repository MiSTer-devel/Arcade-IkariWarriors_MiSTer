//A5004_4.sv
//Author: @RndMnkIII
//Date: 22/06/2022
`default_nettype none
`timescale 1ns/1ps

module A5004_4(
	input wire YC, //1
	input wire Y7, //2
	input wire Y6, //3
	input wire Y5, //4
	input wire XC, //6
	input wire X7, //7
	input wire X6, //8
	input wire X5, //9
	input wire H8, //13
	input wire Y8, //14
	input wire V8, //17
	input wire X8, //18
	output logic D1, //12
	output logic D0 //19
);
	logic F15, F16;
	
	assign D1 = ~((~XC & ~X7 & ~X6 & ~X5 & ~F15) |
		          ( XC &  X7 &  X6 &  X5 & ~F15) |
		          ( XC & ~X7 & ~X6 & ~X5 &  F15) |
		          (~XC &  X7 &  X6 &  X5 &  F15));

	assign F15 = ~((~V8 & ~X8) | (V8 & X8));

	assign F16 = ~((~H8 & ~Y8) | (H8 & Y8));

	assign D0 = ~((~YC & ~Y7 & ~Y6 & ~Y5 & ~F16) |
		          ( YC &  Y7 &  Y6 &  Y5 & ~F16) |
		          ( YC & ~Y7 & ~Y6 & ~Y5 &  F16) |
		          (~YC &  Y7 &  Y6 &  Y5 &  F16));
endmodule