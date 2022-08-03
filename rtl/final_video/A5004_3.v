//A5004_3.v
//Author: @RndMnkIII
//Date: 22/06/2022
`default_nettype none
`timescale 1ns/1ps

module A5004_3 (
    //inputs
    input wire SD31, //1
    input wire SD0, //2
    input wire SLD7, //3
    input wire SLD0, //4
    input wire SLD1, //5
    input wire SLD2, //6
    input wire L2D0, //7
    input wire L2D1, //8
    input wire L2D2, //9
    input wire i11, //11 VCC
    input wire SD31_r, //13
    input wire SD30_ANDr, //14
    //outputs
    output wire COLBANK5, //12
    output wire LAYER_SELA, //15
    output wire LAYER_SELB, //16
    output wire COLBANK3, //17
    output wire COLBANK4, //18
    output wire SD30_AND //19
);
    wire SD31_r_neg;
    wire SD31_neg;
    wire SD30_ANDr_neg;
    wire SD0_neg;
    wire SLBD7_neg;
    wire SLD7_neg;
    wire SLD0_neg;
    wire SLD1_neg;
    wire SLD2_neg;
    wire L2D2_neg;
    wire L2D1_neg;
    wire L2D0_neg;
    wire i11_neg;

    assign  SD31_r_neg    = ~SD31_r;
    assign  SD30_ANDr_neg = ~SD30_ANDr;
    assign  SLD7_neg      = ~SLD7;
    assign  SLD0_neg      = ~SLD0;
    assign  SLD1_neg      = ~SLD1;
    assign  SLD2_neg      = ~SLD2;
    assign  L2D2_neg      = ~L2D2;
    assign  L2D1_neg      = ~L2D1;
    assign  L2D0_neg      = ~L2D0;
    assign  i11_neg       = ~i11;
    assign  SD31_neg      = ~SD31;
    assign  SD0_neg       = ~SD0;
     
    assign  COLBANK5   = ~((SD30_ANDr_neg                                                                               )|
                           (               SLD7_neg & SLD0_neg & SLD1 & SLD2 &                                SD31_r_neg)|
                           (                          SLD0_neg & SLD1 & SLD2 &            L2D1 & L2D2 & i11 & SD31_r_neg)|
                           (                                     SLD1 & SLD2 & L2D0_neg & L2D1 & L2D2 & i11 & SD31_r_neg));
                                               
    //------------------------------------------------------
    assign  LAYER_SELA = ~((SLD7 & L2D1_neg & SD31_r_neg)|
                           (SLD7 & L2D2_neg & SD31_r_neg)|
                           (SLD7 & i11_neg  & SD31_r_neg)|
                           (SLD1 & SLD2     & SD31_r_neg));  
    //------------------------------------------------------
    assign  LAYER_SELB = ~((SLD1 & SLD2 & L2D1 & L2D2 & i11 & SD31_r_neg));
    //------------------------------------------------------
    assign  COLBANK3   = ~((SLD1 & SLD2 & L2D1 & L2D2 & i11 & SD31_r_neg)|
                           (                     LAYER_SELA & SD31_r_neg));
    //------------------------------------------------------
    assign  COLBANK4   = ~((SLD1_neg & SD31_r_neg)|
                           (SLD2_neg & SD31_r_neg)|
                           (L2D1_neg & SD31_r_neg)|
                           (L2D2_neg & SD31_r_neg)|
                           (i11_neg  & SD31_r_neg));   

    assign  SD30_AND   = ~(SD31_neg & SD0_neg);
endmodule 