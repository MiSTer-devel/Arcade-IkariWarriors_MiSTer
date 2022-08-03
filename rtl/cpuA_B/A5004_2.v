//Author: @RndMnkIII
//Date: 18/06/2022
//Derived from IKARI A5004-2 PAL20L8A
`default_nettype none
`timescale 1ns/10ps

module A5004_2 (
    //inputs
    input  wire  AMRn, //1
    input  wire  AE_addr, //2 
    input  wire  A_addr13, //3
    input  wire  A_addr12,  //4
    input  wire  A_addr11, //5
    input  wire  BMRn,     //6
    input  wire  BE_addr, //7
    input  wire  B_addr13, //8
    input  wire  B_addr12, //9 
    input  wire  B_addr11, //10
    input  wire  ARDn, //11
    input  wire  BRDn, //13
    input  wire  AB_Sel, //23
    output wire  FRONT1_VIDEO_CSn, //21 F1C
    output wire  DISC, //20
    output wire  SIDE_VRAM_CSn, //19 SC
    output wire  VRDn, //18
    output wire  BACK1_VRAM_CSn, //17 B1C
    output wire  FRONT2_VIDEO_CSn //16 F2C
);  
    //                1 1 1 1  1 | 1     |
    //Address:        5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hE800-EFFF   1 1 1 0  1 | x x x | x x x x  x x x x cpuA SHARED FRONT1 VIDEO RAM 2Kbytes
    //16'hF000-F7FF   1 1 1 1  0 | x x x | x x x x  x x x x cpuA SHARED FRONT1 VIDEO RAM 2Kbytes
    //16'hE800-EFFF   1 1 1 0  1 | x x x | x x x x  x x x x cpuB SHARED FRONT1 VIDEO RAM 2Kbytes
    //16'hF000-F7FF   1 1 1 1  0 | x x x | x x x x  x x x x cpuB SHARED FRONT1 VIDEO RAM 2Kbytes
    assign  FRONT1_VIDEO_CSn = ~((~AMRn & ~AE_addr &  A_addr13 &  A_addr12 &  ~A_addr11 & ~AB_Sel ) |
                                 (~AMRn & ~AE_addr &  A_addr13 & ~A_addr12 &   A_addr11 & ~AB_Sel ) |
                                 (~BMRn & ~BE_addr &  B_addr13 &  B_addr12 &  ~B_addr11 &  AB_Sel ) |
                                 (~BMRn & ~BE_addr &  B_addr13 & ~B_addr12 &   B_addr11 &  AB_Sel ));

    assign  VRDn = ~((~ARDn & ~AB_Sel ) | (~BRDn &  AB_Sel ));

    //                1 1 1 1  1 | 1     |
    //Address:        5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hF800-CFFF   1 1 1 1  1 | x x x | x x x x  x x x x cpuA SHARED SIDE VIDEO RAM 2Kbytes
    //16'hF800-CFFF   1 1 1 1  1 | x x x | x x x x  x x x x cpuB SHARED SIDE VIDEO RAM 2Kbytes
    assign  SIDE_VRAM_CSn = ~((~AMRn & ~AE_addr & A_addr13 & A_addr12 & A_addr11 & ~AB_Sel ) |
                              (~BMRn & ~BE_addr & B_addr13 & B_addr12 & B_addr11 &  AB_Sel ));

    //                1 1 1 1  1 | 1     |
    //Address:        5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hC800-CFFF   1 1 0 0  1 | x x x | x x x x  x x x x cpuA VIDEO REGISTERS
    //16'hC800-CFFF   1 1 0 0  1 | x x x | x x x x  x x x x cpuB VIDEO REGISTERS   
    assign  DISC = ~((~AMRn & ~AE_addr & ~A_addr13 & ~A_addr12 &  A_addr11 & ~AB_Sel ) |
                     (~BMRn & ~BE_addr & ~B_addr13 & ~B_addr12 &  B_addr11 &  AB_Sel ));

    //                1 1 1 1  1 | 1     |
    //Address:        5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hD000-DFFF   1 1 0 1  x | x x x | x x x x  x x x x cpuA SHARED BACK1 VIDEO RAM 4Kbytes MIRROR D800-DFFF
    //16'hD000-DFFF   1 1 0 1  x | x x x | x x x x  x x x x cpuB SHARED BACK1 VIDEO RAM 4Kbytes MIRROR D800-DFFF
    assign  BACK1_VRAM_CSn = ~((~AMRn & ~AE_addr & ~A_addr13 &  A_addr12 & ~AB_Sel ) |
                               (~BMRn & ~BE_addr & ~B_addr13 &  B_addr12 &  AB_Sel ));

    //                1 1 1 1  1 | 1     |
    //Address:        5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hE000-E7FF   1 1 1 0  0 | x x x | x x x x  x x x x cpuA SHARED FRONT2 VIDEO RAM 2Kbytes
    //16'hE000-E7FF   1 1 1 0  0 | x x x | x x x x  x x x x cpuB SHARED FRONT2 VIDEO RAM 2Kbytes
    assign  FRONT2_VIDEO_CSn = ~((~AMRn & ~AE_addr &  A_addr13 & ~A_addr12 & ~A_addr11 & ~AB_Sel ) |
                                 (~BMRn & ~BE_addr &  B_addr13 & ~B_addr12 & ~B_addr11 &  AB_Sel ));
endmodule