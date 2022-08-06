//IkariWarriorsCore_CPU_A_B.sv
//Author: @RndMnkIII
//Date:   20/06/2022
`default_nettype none
`timescale 1ns/100ps

module IkariWarriorsCore_CPU_A_B
(
    input  wire VIDEO_RSTn,
    input  wire clk, //53.6MHz
    input  wire pause_cpu,
    input  wire H0,
	input  wire CK1,
    input  wire Cen_p,
    input  wire Cen_n,
    input wire clk_13p4b_cen,
    input  wire RESETn,
    input wire [15:0] PLAYER1,
    input wire [15:0] PLAYER2,
    input wire [7:0] GAME,
	input wire [15:0] DSW,
    input  wire VBL,
    input  wire BWA,
    input  wire A_B,
    input  wire RLA,
    input  wire RLB,
    input  wire WBA,
    input  wire WBB,
    input  wire VDG,
    output logic VRDn,
    output logic AE, //cpuA Enable
    output logic BE, //cpuB Enable
    //CPU A data bus
    output logic [7:0] CPUAD, //Cpu A data bus  
    output logic CPUA_RD,
    output logic CPUA_WR,

    //common address bus
    output logic [11:0] VA,
    //common data bus
    output logic [7:0] V_out,
    input  wire  [7:0] V_in,

    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire         ioctl_wr,
    
    //IO devices
    input  wire  SND_BUSY,
    output logic COIN,
    output logic P1,
    output logic P2,
    output logic P1_P2,
    output logic MCODE,
    output logic DIP1,
    output logic DIP2,

    //video devices
    output logic FRONT1_VIDEO_CSn,
    output logic FRONT2_VIDEO_CSn,
    output logic BACK1_VRAM_CSn,
    output logic SIDE_VRAM_CSn,
    output logic DISC,
    output logic SSET, //side bank and side color bank
    output logic BSET, //Video Attribs.
    output logic F1SX, //Front video scroll X sp16
    output logic F1SY, //Front video scroll Y sp16
    output logic F2SX, //Front video scroll X sp32
    output logic F2SY, //Front video scroll Y sp32
    output logic B1SX, //Back1 video scroll X bg
    output logic B1SY,  //Back1 video scroll Y bg
    output logic XSET,
    output logic YSET,
    output logic MSET,
    output logic F2INS,
    output logic REG0,
    output logic REG1
);
    logic VD_to_cpuAdbus; //LS32
    logic VD_to_cpuBdbus; //LS32


    //rom download selector
    logic P1_4E_cs, P2_4F_cs, P3_4H_cs;     //16KbytesX3 Main  CPU EPROMs 
    logic P4_2E_cs, P5_2F_cs, P6_2H_cs;     //16KbytesX3 Sub   CPU EPROMs
    selector_cpuAB_rom selector
    (
        .ioctl_addr(ioctl_addr),
        .P1_8D_cs(P1_4E_cs), .P2_7D_cs(P2_4F_cs), .P3_5D_cs(P3_4H_cs),
        .P4_3D_cs(P4_2E_cs), .P5_2D_cs(P5_2F_cs), .P6_1D_cs(P6_2H_cs)
    );

    //sync H0 and Cen_p, Cen_n signals by adding two clock periods delay to Cen_p, Cen_n
    logic Cen_pr1, Cen_pr2;
    logic Cen_nr1, Cen_nr2;

    always @(posedge clk) begin
        Cen_pr1 <= Cen_p;
        Cen_nr1 <= Cen_n;
    end

    // ----------------- Z80A Cpu -----------------
    //output
    logic cpuA_nM1;
    logic cpuA_nMR;
    logic cpuA_nIO /* synthesis syn_keep = 1 */;
    logic cpuA_nRD;
    logic cpuA_nWR;
    logic cpuA_nRFSH;
    logic cpuA_nHALT;
    logic cpuA_nBUSACK;
    //input
    logic cpuA_nINT;
    logic cpuA_nNMI;
    logic [15:0] cpuA_A; //AA
    logic [7:0] cpuA_Vin, cpuB_Vin;

    logic E4_1_Qn;
    DFF_pseudoAsyncClrPre2 #(.W(1)) e4_1 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(),
        .qn(cpuA_nINT),
        .set(1'b0),    // active high
        .clr(~cpuA_nIO),    // active high
        .cen(VBL) // signal whose edge will trigger the FF
    );

    reg [7:0] cpuA_Din;
    reg [7:0] cpuA_Dout;

    // local reset
    reg reset_n=1'b0;
    reg [5:0] rst_cnt;

    always @(posedge clk)
        if( ~RESETn ) begin
            rst_cnt <= 'd0;
            reset_n <= 1'b0;
        end else begin
            if( rst_cnt != ~6'b0 ) begin
                reset_n <= 1'b0;
                rst_cnt <= rst_cnt + 6'd1;
            end else reset_n <= 1'b1;
        end

    //T80pa CLK x4 real CPU clock
        T80pa z80_E5 (
        .RESET_n(reset_n), //RESETn
        .CLK    (clk),
        .CEN_p  (Cen_pr1 & ~pause_cpu), //active high
        .CEN_n  (Cen_nr1 & ~pause_cpu), //active high
        .WAIT_n (1'b1),
        .INT_n  (cpuA_nINT),
        .NMI_n  (cpuA_nNMI),
        .RD_n   (cpuA_nRD),
        .WR_n   (cpuA_nWR),
        .A      (cpuA_A),
        .DI     (cpuA_Din),
        .DO     (cpuA_Dout),
        .IORQ_n (cpuA_nIO),
        .M1_n   (cpuA_nM1),
        .MREQ_n (cpuA_nMR),
        .BUSRQ_n(1'b1),
        .BUSAK_n(cpuA_nBUSACK),
        .OUT0   (1'b0),
        .RFSH_n (cpuA_nRFSH),
        .HALT_n (cpuA_nHALT)
    );

    assign CPUA_WR = cpuA_nWR;
    assign CPUA_RD = cpuA_nRD;
    
    //---------------------------------------------

    //------------ CPUA Memory Mapper -------------
     logic C5_1_Y3n;
     logic CS_ROM_P3n;
     logic CS_ROM_P2n;
     logic CS_ROM_P1n;
    //              1 1 1 1  1 | 1     |
    //Address:      5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'h0000-3FFF 0 0 x x  x | x x x | x x x x  x x x x CS_ROM_P1n R  
    //16'h4000-7FFF 0 1 x x  x | x x x | x x x x  x x x x CS_ROM_P2n R
    //16'h8000-BFFF 1 0 x x  x | x x x | x x x x  x x x x CS_ROM_P3n R 
    ttl_74139_nodly c5_1(.Enable_bar(1'b0), .A_2D(cpuA_A[15:14]), .Y_2D({C5_1_Y3n, CS_ROM_P3n, CS_ROM_P2n, CS_ROM_P1n}));

    logic C7_3_OR; //2-Input OR
    assign C7_3_OR = cpuA_nMR | C5_1_Y3n;  

    //--- AE logic ---
    //logic C7_1_OR;
    logic C6_1_NOR;
    logic AE_addr; //Used by AE logic and PAL16L6A_A1

    // assign C7_1_OR = |cpuA_A[13:12];
    // assign C6_1_NOR = ~(C7_1_OR | cpuA_A[11]);
    assign C6_1_NOR = ~(|cpuA_A[13:11]);
    //add one clock delay
    logic c6nor1_r;
    always @(posedge clk) begin
        c6nor1_r <= C6_1_NOR;
    end
    assign AE_addr = c6nor1_r | C5_1_Y3n;
    
    assign AE = ~(AE_addr | cpuA_nMR); //C6_2_NOR;


    logic cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL;
    logic C2_2_INV; //Inverter
    logic C7_4_OR; //2-Input OR


    assign C2_2_INV = ~cpuA_A[11];
    assign C7_4_OR = |cpuA_A[13:12];

    //         1 1 1 1  1 | 1     |
    //Address: 5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hC000 1 1 0 0  0 | 0 0 0 | x x x x  x x x x COIN                               R
    //16'hC100 1 1 0 0  0 | 0 0 1 | x x x x  x x x x P1                                 R
    //16'hC200 1 1 0 0  0 | 0 1 0 | x x x x  x x x x P2                                 R    
    //16'hC300 1 1 0 0  0 | 0 1 1 | x x x x  x x x x P1_P2 R,CCOUNTERS W
    //16'hC400 1 1 0 0  0 | 1 0 0 | x x x x  x x x x MCODE                              W
    //16'hC500 1 1 0 0  0 | 1 0 1 | x x x x  x x x x DIP1                               R
    //16'hC600 1 1 0 0  0 | 1 1 0 | x x x x  x x x x DIP2                               R
    //16'hC700 1 1 0 0  0 | 1 1 1 | x x x x  x x x x cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL RW
    ttl_74138_nodly c8 (.Enable1_bar(C7_4_OR), .Enable2_bar(C7_3_OR), .Enable3(C2_2_INV), .A(cpuA_A[10:8]), 
                  .Y({cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL, DIP2, DIP1, MCODE, P1_P2, P2, P1, COIN}));
    //---------------------------------------------

    always @(posedge clk) begin
        //CPUA_RD <= cpuA_nRD;
        //CPUA_WR <= cpuA_nWR;
        if(!cpuA_nMR && !C5_1_Y3n) CPUAD <= cpuA_Dout;
        else CPUAD <= 8'hff;
    end
    //--- 27128 16Kx8 CPUA ROMS 250ns ---
    logic [7:0] data_P3_4H;
    logic [7:0] data_P2_4F;
    logic [7:0] data_P1_4E;
    
    eprom_16K P3_4H
    (
        .ADDR(cpuA_A[13:0]),
        .CLK(clk),
        .DATA(data_P3_4H),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P3_4H_cs),
        .WR(ioctl_wr)
    );
    
    eprom_16K P2_4F
    (
        .ADDR(cpuA_A[13:0]),
        .CLK(clk),
        .DATA(data_P2_4F),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P2_4F_cs),
        .WR(ioctl_wr)
    );
    
    eprom_16K P1_4E
    (
        .ADDR(cpuA_A[13:0]),
        .CLK(clk),
        .DATA(data_P1_4E),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P1_4E_cs),
        .WR(ioctl_wr)
    );
    //---------------------------------

    //CPU A data input MUX
    always @(posedge clk) begin
             if(!CS_ROM_P3n && !cpuA_nMR)              cpuA_Din <= data_P3_4H;
        else if(!CS_ROM_P2n && !cpuA_nMR)              cpuA_Din <= data_P2_4F; 
        else if(!CS_ROM_P1n && !cpuA_nMR)              cpuA_Din <= data_P1_4E;
        //IO input 
        //Ikari Warriors JP inputs  (ikaria)
        else if(!COIN && (GAME == 8'h06))              cpuA_Din <= {2'b11,SND_BUSY,PLAYER2[1],PLAYER1[1],(PLAYER1[9] & PLAYER2[9]),PLAYER2[0],PLAYER1[0]}; //{TEST,UNK,SND_BUSY,START2,START1,SERVICE,COIN_2,COIN_1}  
  //Ikari Warriors Inputs, Victory Road, Dogou Souken
        else if(!COIN)              cpuA_Din <= {PLAYER1[1],PLAYER2[1],PLAYER1[0],PLAYER2[0],2'b11,(PLAYER1[9] & PLAYER2[9]),SND_BUSY}; //{START1,START2,COIN_1,COIN_2,UNK,UNK,SERVICE,SND_BUSY}

        else if(!P1 && (GAME == 8'h08))                cpuA_Din <= {PLAYER1[10],PLAYER1[12],PLAYER1[13],PLAYER1[11],PLAYER1[11],PLAYER1[10],PLAYER1[12],PLAYER1[13]}; //Rambo 3 Player1 inputs:{LEFT1,DOWN1,UP1,RIGHT1,RIGHT1,LEFT1,DOWN1,UP1}
        else if(!P1)                                   cpuA_Din <= {PLAYER1[7:4],PLAYER1[11],PLAYER1[10],PLAYER1[12],PLAYER1[13]}; //Player1 inputs:{ROTARY1,RIGHT1,LEFT1,DOWN1,UP1}
        else if(!P2 && (GAME == 8'h08))                cpuA_Din <= {PLAYER2[10],PLAYER2[12],PLAYER2[13],PLAYER2[11],PLAYER2[11],PLAYER2[10],PLAYER2[12],PLAYER2[13]}; //Rambo 3 Player2 inputs:{{LEFT2,DOWN1,UP2,RIGHT2,RIGHT2,LEFT2,DOWN2,UP2}
        else if(!P2)                                   cpuA_Din <= {PLAYER2[7:4],PLAYER2[11],PLAYER2[10],PLAYER2[12],PLAYER2[13]}; //Player2 inputs:{ROTARY2,RIGHT2,LEFT2,DOWN2,UP2}
        else if(!P1_P2 && ((GAME == 8'h05) || (GAME == 8'h06) || (GAME == 8'h10) || (GAME == 8'h11)))              cpuA_Din <= {3'b111,PLAYER2[3],PLAYER2[2],1'b1,PLAYER1[3],PLAYER1[2]};  // P1/P2 Buttons:{UNK,UNK,UNK,P2BTN2,P2BTN1,UNK,P1BTN2,P1BTN1}

        else if(!DIP1)                                 cpuA_Din <= {DSW[7:0]}; //DIP1 Switches 
        else if(!DIP2)                                 cpuA_Din <= {DSW[15:8]}; //DIP2 Switches
        else if(!cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL)  cpuA_Din <= 8'hFF; //C700 Read
        //VIDEO RAM & Regs.      
        else if(!VD_to_cpuAdbus)                       cpuA_Din <= cpuA_Vin;
        else                                           cpuA_Din <= 8'hFF;          
    end

    // ----------------- Z80B Cpu -----------------
    //output
    logic cpuB_nM1;
    logic cpuB_nMR;
    logic cpuB_nIO;
    logic cpuB_nRD;
    logic cpuB_nWR;
    logic cpuB_nRFSH;
    logic cpuB_nHALT;
    logic cpuB_nBUSACK;
    //input
    logic cpuB_nINT;
    logic cpuB_nNMI;
    logic cpuB_nBR = 1'b1;
    logic [15:0] cpuB_A; //BA

    logic E4_2_Qn;
    DFF_pseudoAsyncClrPre #(.W(1)) e4_2 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(),
        .qn(cpuB_nINT),
        .set(1'b0),    // active high
        .clr(~cpuB_nIO),    // active high
        .cen(VBL) // signal whose edge will trigger the FF
    );

    logic  [7:0] cpuB_Din;
    logic  [7:0] cpuB_Dout;

    //T80pa CLK x4 real CPU clock
        T80pa z80_E1 (
        .RESET_n(reset_n), //RESETn
        .CLK    (clk),
        .CEN_p  (Cen_pr1 & ~pause_cpu & BWA), //active high
        .CEN_n  (Cen_nr1 & ~pause_cpu & BWA), //active high
        //.WAIT_n (BWA),
        .WAIT_n(1'b1),
        .INT_n  (cpuB_nINT),
        .NMI_n  (cpuB_nNMI),
        .RD_n   (cpuB_nRD),
        .WR_n   (cpuB_nWR),
        
        .A      (cpuB_A),
        .DI     (cpuB_Din),
        .DO     (cpuB_Dout),
        .IORQ_n (cpuB_nIO),
        .M1_n   (cpuB_nM1),
        .MREQ_n (cpuB_nMR),
        .BUSRQ_n(1'b1),
        .BUSAK_n(cpuB_nBUSACK),
        .OUT0   (1'b0),
        .RFSH_n (cpuB_nRFSH),
        .HALT_n (cpuB_nHALT)
    );

    //---------------------------------------------
    //------------ CPUB Memory Mapper -------------
    logic C5_2_Y3n;
    logic CS_ROM_P6n;
    logic CS_ROM_P5n;
    logic CS_ROM_P4n;
    //              1 1 1 1  1 | 1     |
    //Address:      5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'h0000-3FFF 0 0 x x  x | x x x | x x x x  x x x x CS_ROM_P4n  
    //16'h4000-7FFF 0 1 x x  x | x x x | x x x x  x x x x CS_ROM_P5n
    //16'h8000-BFFF 1 0 x x  x | x x x | x x x x  x x x x CS_ROM_P6n
    ttl_74139_nodly c5_2(.Enable_bar(1'b0), .A_2D(cpuB_A[15:14]), .Y_2D({C5_2_Y3n, CS_ROM_P6n, CS_ROM_P5n, CS_ROM_P4n}));
    
    //--- BE logic ---
    //logic C4_1_OR;
    logic C6_4_NOR;
    logic BE_addr; ////C4_2_OR Used by BE logic, PAL16L6A_A1 and B6 LS373
    logic cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL;

    // assign C4_1_OR = |cpuB_A[13:12];
    // assign C6_4_NOR = ~(C4_1_OR | cpuB_A[11]);
    assign C6_4_NOR = ~(|cpuB_A[13:11]);
    //add one clock delay
    logic c6nor4_r;
    always @(posedge clk) begin
        c6nor4_r <= C6_4_NOR;
    end
    assign BE_addr = c6nor4_r | C5_2_Y3n; 
    assign BE = ~(BE_addr | cpuB_nMR); //C6_3_NOR;
    //-----------------

    //---------------------------------------------
    //--- 27128 16Kx8 CPUB ROMS 250ns ---
    logic [7:0] data_P6_2H;
    logic [7:0] data_P5_2F;
    logic [7:0] data_P4_2E;

    eprom_16K P6_2H
    (
        .ADDR(cpuB_A[13:0]),
        .CLK(clk),
        .DATA(data_P6_2H),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P6_2H_cs),
        .WR(ioctl_wr)
    );

    eprom_16K P5_2F
    (
        .ADDR(cpuB_A[13:0]),
        .CLK(clk),
        .DATA(data_P5_2F),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P5_2F_cs),
        .WR(ioctl_wr)
    );

    eprom_16K P4_2E
    (
        .ADDR(cpuB_A[13:0]),
        .CLK(clk),
        .DATA(data_P4_2E),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P4_2E_cs),
        .WR(ioctl_wr)
    );

    //---------------------------------
    //CPU B data input
    always @(posedge clk) begin
        if(!CS_ROM_P6n && !cpuB_nMR)                          cpuB_Din <= data_P6_2H;
        else if(!CS_ROM_P5n && !cpuB_nMR)                          cpuB_Din <= data_P5_2F; 
        else if(!CS_ROM_P4n && !cpuB_nMR)                          cpuB_Din <= data_P4_2E;
        //hack to assign 0xFF value to data bus when reads addresses 0xC000.
        else if(!cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL && !cpuB_nRD) cpuB_Din <= 8'hFF;    
        //VIDEO RAM & Regs     
        else if(!VD_to_cpuBdbus)                                   cpuB_Din <= cpuB_Vin;
        else                                                       cpuB_Din <= 8'hFF; 
    end

    //--- cpuA and cpuB interrupt logic ---
    logic cpuB_NMI_TRIG_R; //B3_4_OR;
    logic cpuA_NMI_ACK_W;  //B3_3_OR;
    
    assign cpuB_NMI_TRIG_R = cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL | cpuA_nRD; //R
    assign cpuA_NMI_ACK_W  = cpuB_NMI_TRIG_R_cpuA_NMI_ACK_W_CTRL | cpuA_nWR;  //W

    logic C4_4_OR;
    logic C3_2_3NOR;
    logic C3_1_3NOR;
    logic C3_3_3NOR;

    //         1 1 1 1  1 | 1     |
    //Address: 5 4 3 2  1 | 0 9 8 | 7 6 5 4  3 2 1 0
    //16'hC000 1 1 0 0  0 | 0 0 0 | x x x x  x x x x cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL RW
    assign C4_4_OR                               = cpuB_A[12] | cpuB_A[11];  //|cpuB_A[12:11];
    assign C3_2_3NOR                             = ~(C4_4_OR | cpuB_A[13] | C5_2_Y3n);
    assign cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL   = ~C3_2_3NOR; //C2_1_INV
    
    assign C3_3_3NOR = ~(cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL | cpuB_nMR | cpuB_nRD); //R
    assign C3_1_3NOR = ~(cpuA_NMI_TRIG_R_cpuB_NMI_ACK_W_CTRL | cpuB_nMR | cpuB_nWR); //W

    logic cpuB_NMI_ACK_W;  //C2_4_INV
    logic cpuA_NMI_TRIG_R; //C2_6_INV

    assign cpuA_NMI_TRIG_R = ~C3_3_3NOR; //C2_6_INV
    assign cpuB_NMI_ACK_W  = ~C3_1_3NOR;  //C2_4_INV

    DFF_pseudoAsyncClrPre #(.W(1)) c1_1 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(),
        .qn(cpuA_nNMI),
        .set(1'b0),    // active high
        .clr(~cpuA_NMI_ACK_W),    // active high
        .cen(cpuA_NMI_TRIG_R) // signal whose edge will trigger the FF
    );

    DFF_pseudoAsyncClrPre #(.W(1)) c1_2 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(),
        .qn(cpuB_nNMI),
        .set(1'b0),    // active high
        .clr(~cpuB_NMI_ACK_W),    // active high
        .cen(cpuB_NMI_TRIG_R) // signal whose edge will trigger the FF
    );
    //------------------------------------


    A5004_2 C4(
        //inputs
        .AMRn(cpuA_nMR), //1
        .AE_addr(AE_addr), //2 
        .A_addr13(cpuA_A[13]), //3
        .A_addr12(cpuA_A[12]),  //4
        .A_addr11(cpuA_A[11]), //5
        .BMRn(cpuB_nMR),     //6
        .BE_addr(BE_addr), //7
        .B_addr13(cpuB_A[13]), //8
        .B_addr12(cpuB_A[12]), //9 
        .B_addr11(cpuB_A[11]), //10
        .ARDn(cpuA_nRD), //11
        .BRDn(cpuB_nRD), //13
        .AB_Sel(A_B), //22
        //outputs
        .FRONT1_VIDEO_CSn(FRONT1_VIDEO_CSn), //21 F1C
        .FRONT2_VIDEO_CSn(FRONT2_VIDEO_CSn), //16 F2C
        .VRDn(VRDn), //18
        .SIDE_VRAM_CSn(SIDE_VRAM_CSn), //19 SC
        .DISC(DISC), //20 DISC
        .BACK1_VRAM_CSn(BACK1_VRAM_CSn) //17 B1C
    );  

    assign VD_to_cpuAdbus = cpuA_nRD | AE_addr;
    assign VD_to_cpuBdbus = cpuB_nRD | BE_addr;
    //-----------------------------------------

    //ttl_74157 A_2D({B3,A3,B2,A2,B1,A1,B0,A0})
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) A4 (.Enable_bar(1'b0), .Select(A_B),
                .A_2D({cpuB_A[3],cpuA_A[3],cpuB_A[2],cpuA_A[2],cpuB_A[1],cpuA_A[1],cpuB_A[0],cpuA_A[0]}), .Y(VA[3:0]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) B4 (.Enable_bar(1'b0), .Select(A_B),
                .A_2D({cpuB_A[7],cpuA_A[7],cpuB_A[6],cpuA_A[6],cpuB_A[5],cpuA_A[5],cpuB_A[4],cpuA_A[4]}), .Y(VA[7:4]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) A3 (.Enable_bar(1'b0), .Select(A_B),
                .A_2D({cpuB_A[11],cpuA_A[11],cpuB_A[10],cpuA_A[10],cpuB_A[9],cpuA_A[9],cpuB_A[8],cpuA_A[8]}), .Y(VA[11:8]));

    //ONLY WRITABLE VIDEO RELATED REGISTERS (Ikari Warriors) C800-CB80
    //              1 1 1 1 1 | 1    
    //Address:      5 4 3 2 1 | 0 9 8 7 | 6 5 4  3 2 1 0
    //16'hC800      1 1 0 0 1 | 0 0 0 0 | x x x  x x x x B1SX
    //16'hC880      1 1 0 0 1 | 0 0 0 1 | x x x  x x x x B1SY
    //16'hC900      1 1 0 0 1 | 0 0 1 0 | x x x  x x x x BSET
    //16'hC980      1 1 0 0 1 | 0 0 1 1 | x x x  x x x x SSET SIDE LAYER ROM BANKING AND COLOR BANKING
    //16'hCA00      1 1 0 0 1 | 0 1 0 0 | x x x  x x x x F1SX
    //16'hCA80      1 1 0 0 1 | 0 1 0 1 | x x x  x x x x F1SY
    //16'hCB00      1 1 0 0 1 | 0 1 1 0 | x x x  x x x x F2SX
    //16'hCB80      1 1 0 0 1 | 0 1 1 1 | x x x  x x x x F2SY
    ttl_74138_nodly P7(
        .Enable1_bar(DISC), //4 G2An
        .Enable2_bar(VDG), //5 G2Bn
        .Enable3(~VA[10]), //6 G1
        .A(VA[9:7]), //3,2,1 C,B,A
        .Y({F2SY,F2SX,F1SY,F1SX,SSET,BSET,B1SY,B1SX}) //7,9,10,11,12,13,14,15 Y[7:0]
    );

    //ONLY WRITABLE VIDEO RELATED REGISTERS (Ikari Warriors) CC00-CD80
    //              1 1 1 1  1 1    
    //Address:      5 4 3 2  1 0 9 8  7 6 5 4  3 2 1 0
    //16'hCC00      1 1 0 0  1 1 0 0  0 x x x  x x x x XSET (W)
    //16'hCC80      1 1 0 0  1 1 0 0  1 x x x  x x x x YSET (W)
    //16'hCD00      1 1 0 0  1 1 0 1  0 x x x  x x x x MSET (W): set MSB Front Y's: F1Y8 (VD5), F2Y8 (VD4)
    //16'hCD80      1 1 0 0  1 1 0 1  1 x x x  x x x x F2INS(W): set FN's: H8 (FN[7]) (VD7), V8 (FN[6]) (VD6), FN[5:0] (VD5~0)

    //ONLY READABLE VIDEO RELATED REGISTERS (Ikari Warriors) CE00-CEE0
    //16'hCE00      1 1 0 0  1 1 1 0  0 0 0 X  x x x x REG0 Addr. 00 (R):
    //16'hCE20      1 1 0 0  1 1 1 0  0 0 1 X  x x x x REG0 Addr. 01 (R): 
    //16'hCE40      1 1 0 0  1 1 1 0  0 1 0 X  x x x x REG0 Addr. 10 (R):
    //16'hCE60      1 1 0 0  1 1 1 0  0 1 1 X  x x x x REG0 Addr. 11 (R):

    //16'hCE80      1 1 0 0  1 1 1 0  1 0 0 x  x x x x REG1 Addr. 00 (R):
    //16'hCEA0      1 1 0 0  1 1 1 0  1 0 1 x  x x x x REG1 Addr. 01 (R):
    //16'hCEC0      1 1 0 0  1 1 1 0  1 1 0 x  x x x x REG1 Addr. 10 (R):
    //16'hCEE0      1 1 0 0  1 1 1 0  1 1 1 x  x x x x REG1 Addr. 11 (R):
    logic P6_Y7, P6_Y6;
    ttl_74138_nodly P6(
        .Enable1_bar(DISC), //4 G2An
        .Enable2_bar(VDG), //5 G2Bn
        .Enable3(VA[10]), //6 G1
        .A(VA[9:7]), //3,2,1 C,B,A
        .Y({P6_Y7,P6_Y6,REG1,REG0,F2INS,MSET,YSET,XSET}) //7,9,10,11,12,13,14,15 Y[7:0]
    );


    //------------------------------------------

    //--- VD common data bus RW control ---
    // Data out
    // Vout <- WBB or WBA
    assign V_out = ((!WBA) ? CPUAD : ( 
                    (!WBB) ? cpuB_Dout : 8'hff ));

    logic [7:0] cpuA_Vin_r, cpuB_Vin_r;
    // data in (modeled as a latch with independent output enabled control)
    always @(posedge clk) begin
        if(!VIDEO_RSTn) begin
            cpuA_Vin_r <= 0;
            cpuB_Vin_r <= 0;
        end
        else begin
            if (RLA) //transparent latch (sync with clk)
                cpuA_Vin_r <= V_in;
            else
                cpuA_Vin_r <= cpuA_Vin; 

            if (RLB) //transparent latch (sync with clk)
                cpuB_Vin_r <= V_in;
            else
                cpuB_Vin_r <= cpuB_Vin;
        end
    end
    assign cpuA_Vin = (!VD_to_cpuAdbus) ? cpuA_Vin_r : 8'hff;
    assign cpuB_Vin = (!VD_to_cpuBdbus) ? cpuB_Vin_r : 8'hff;
endmodule
