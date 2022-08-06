//IkariWarriorsCore_Back1_sync.sv
//Author: @RndMnkIII
//Date: 08/06/2022
`default_nettype none
`timescale 1ns/1ps

module IkariWarriorsCore_Back1(
    input  wire VIDEO_RSTn,
    input wire clk,
    input wire CK1,
    input wire RESET,
    //Flip screen control
    input wire INV,
    input wire INVn,
    //common video data bus
    input wire [7:0] VD_in,
    output logic [7:0] VD_out,
    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire               ioctl_wr,
    //Debug interface
    input wire [3:0] dbg_B1Voffset, 
    input wire swap_px,
    //SDRAM interface
	output        [23:0] rom_addr,
	input         [15:0] rom_data,
	output reg           rom_req,
	input                rom_ack,
    //Registers
    input wire B1SY,
    input wire B1SX,

    //MSBs
    input wire B1Y8,
    input wire B1X8,

    //VIDEO/CPU Selector
    input wire V_C,

    //B address
    input wire H8,
    input wire [3:0] Y, //Y[7:4] in schematics
    input wire H3,
    input wire H2,
    input wire H1,
    input wire H0,
    input wire [7:0] X, 

    input wire [10:0] VA,
    input wire BACK1_VRAM_CSn,
    
    //A address
    input wire VFLGn,

    //side SRAM control
    input wire VRD,
    input wire VDG,
    input wire VOE,
    input wire VWE,

    //clocking
    input wire CK1n,
    input wire LA,
    input wire VLK,
    //input wire H3

    //Back1 data color
    output logic [7:0] B1D
);

    //RAM BANK Selection logic 
    logic B1B0,B1B1;
    assign B1B0 = (!VA[0] && !BACK1_VRAM_CSn) ? 1'b0 : 1'b1; //active low signal
    assign B1B1 = ( VA[0] && !BACK1_VRAM_CSn) ? 1'b0 : 1'b1; //active low signal

    //Y Scroll Register, Adder section, modified for Ikari Warriors, added XOR_YSR[3]
    logic [3:0] XOR_YSR;
    logic [7:0] B1Y;
    assign XOR_YSR[3] = VD_in[3] ^ INV;
    assign XOR_YSR[2] = VD_in[2] ^ INVn;
    assign XOR_YSR[1] = VD_in[1] ^ INVn;
    assign XOR_YSR[0] = VD_in[0] ^ INVn;

    //*** Synchronous Hack ***
    reg [7:0] vdin_r;
    always @(posedge clk) begin
        vdin_r <= {VD_in[7:4],XOR_YSR};
    end

    ttl_74273_sync L3(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(B1SY), .D(vdin_r), .Q(B1Y)); //HACK

    logic [8:0] B1H;
    logic [3:0] B1Hn;
    ttl_74283_nodly K1 (.A(B1Y[3:0]),    .B({H3,H2,H1,H0}), .C_in(1'b0),     .Sum(B1H[3:0]),           .C_out()       );
    logic K2_cout;
    ttl_74283_nodly K2 (.A(B1Y[7:4]),    .B(Y[3:0]),        .C_in(1'b0),     .Sum(B1H[7:4]),           .C_out(K2_cout));
    assign B1H[8] = (H8 ^ B1Y8) ^ K2_cout;

    //Specific for Ikari Warriors
    assign B1Hn[0] = ~B1H[0];
    assign B1Hn[1] = ~B1H[1];
    assign B1Hn[2] = ~B1H[2];
    assign B1Hn[3] = ~B1H[3];

    logic [8:0] B1HQ /* synthesis keep */;
    logic [5:0] h1_q;
    ttl_74174_sync icH1
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1n),
        .Clr_n(1'b1),
        .D({2'b11,B1Hn}),
        .Q(h1_q)
    );
    assign B1HQ[3:0] = h1_q[3:0];

    logic j2_dum;
    ttl_74174_sync J2
    (
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(CK1n),
        .Clr_n(1'b1),
        .D({1'b1,B1H[8:4]}),
        .Q({j2_dum,B1HQ[8:4]})
    );
    //assign B1HQ[8:4] = j2_q[4:0];

    //X Scroll Register, Adder section
    reg [7:0] vdinX_r;
     always @(posedge clk) begin
        vdinX_r <= VD_in;
    end

    logic [7:0] B1X;
    ttl_74273_sync b12(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(B1SX), .D(vdinX_r), .Q(B1X)); //*** SYNCHRONOUS HACK ***
    logic [8:0] B1V /* synthesis keep */;
    logic a12_cout;
    ttl_74283_nodly a12 (.A(B1X[3:0]),    .B(X[3:0]), .C_in(1'b0),         .Sum(B1V[3:0]), .C_out(a12_cout));
    logic a11_cout;
    ttl_74283_nodly a11 (.A(B1X[7:4]),    .B(X[7:4]), .C_in(a12_cout),     .Sum(B1V[7:4]), .C_out(a11_cout));
    assign B1V[8] = B1X8 ^ a11_cout;

    //2:1 Back1 SRAM bus addresses MUX
    //ttl_74157 A_2D({B3,A3,B2,A2,B1,A1,B0,A0})
    logic G4_CSn, E4_CSn; //SRAM chip select signal
    logic [9:0] A;

    //Switch between CPU/VIDEO access (V_C signal)

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) icH2 (.Enable_bar(1'b0), .Select(V_C),
                .A_2D({VA[10],B1HQ[8],VA[9],B1HQ[7],VA[8],B1HQ[6],VA[7],B1HQ[5]}), .Y(A[9:6]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) icH3 (.Enable_bar(1'b0), .Select(V_C),
                .A_2D({VA[6],B1HQ[4],VA[5],B1V[8],VA[4],B1V[7],VA[3],B1V[6]}), .Y(A[5:2]));

    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) icG3 (.Enable_bar(1'b0), .Select(V_C),
                .A_2D({VA[2],B1V[5],VA[1],B1V[4],B1B0,VFLGn,B1B1,VFLGn}), .Y({A[1:0],E4_CSn,G4_CSn}));

    logic BACK1_SEL0, BACK1_SEL1;
    assign BACK1_SEL0 = ~(B1B0 | VDG);
    assign BACK1_SEL1 = ~(B1B1 | VDG);

    //data bus multiplexer from VD_in  
    logic [7:0] D0, D1, Din0, Din1;
    assign Din0 = (BACK1_SEL0 && VRD) ?  VD_in : 8'hFF;
    assign Din1 = (BACK1_SEL1 && VRD) ?  VD_in : 8'hFF;

    //--- 2X HM6116P-3 2Kx8 300ns SRAM ---
    //ikari Warriors only uses 1Kbx2 in total, in the core the SRAM size is adjusted to the usage limit
    logic [7:0] back1_0_Q, back1_1_Q;
    logic [7:0] D0reg, D1reg;
    logic G4_CS, E4_CS;

    assign E4_CS = ~E4_CSn;
    assign G4_CS = ~G4_CSn;

    logic [9:0] h12_addr1;
    assign h12_addr1 = {B1HQ[8:4],B1V[8:4]};

    //LOW
    SRAM_dual_sync #(.ADDR_WIDTH(10)) E4
    (
        .ADDR0({VA[10:1]}), 
        .clk0(clk), 
        .cen0(E4_CS), 
        .we0(~VWE), 
        .DATA0(Din0), 
        .Q0(back1_0_Q),
        .ADDR1(h12_addr1), 
        .clk1(clk), 
        .cen1(~VFLGn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(D0reg)
    );
	 
    //HIGH
    SRAM_dual_sync #(.ADDR_WIDTH(10)) L4
    (
        .ADDR0({VA[10:1]}), 
        .clk0(clk), 
        .cen0(G4_CS), 
        .we0(~VWE), 
        .DATA0(Din1), 
        .Q0(back1_1_Q),
        .ADDR1(h12_addr1), 
        .clk1(clk), 
        .cen1(~VFLGn), 
        .we1(1'b0), 
        .DATA1(8'hff),
        .Q1(D1reg)
    );

    assign D0 = (!VOE) ? back1_0_Q : 8'hff;
    assign D1 = (!VOE) ? back1_1_Q : 8'hff;
    assign VD_out = (BACK1_SEL0 && !VRD) ? D0 : ((BACK1_SEL1 && !VRD) ? D1 : 8'hff);

    //added delay using FF
    //ttl_74273_sync Dreg_dly(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(CK1), .D(D), .Q(Dreg));

    //Background tile ROM address generator
    //LOW BYTE
    logic [7:0] D1_Q;
    ttl_74273_sync H2ic(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D(D0reg), .Q(D1_Q));
//    ttl_74273_sync H2ic(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(VLK), .D(back1_0_Q), .Q(D1_Q));

    logic [7:0] C1_Q;
    ttl_74273_sync G2ic(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(LA), .D(D1_Q), .Q(C1_Q));

    logic [7:0] B1_Q /* synthesis preserve */;
    ttl_74273_sync F2ic(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(B1HQ[3]), .D(C1_Q), .Q(B1_Q));

    //HIGH BYTE (only uses 6 bits)
    logic [5:0] G1_Q;
    ttl_74174_sync G1(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(VLK), .Clr_n(1'b1),.D({D1reg[7:4],D1reg[1:0]}), .Q(G1_Q));

    logic [5:0] G2_Q;
    ttl_74174_sync G2(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(LA), .Clr_n(1'b1),.D(G1_Q), .Q(G2_Q));

    logic [5:0] F2_Q;
    ttl_74174_sync F2(.Reset_n(VIDEO_RSTn), .Clk(clk), .Cen(B1HQ[3]), .Clr_n(1'b1),.D(G2_Q), .Q(F2_Q));


    logic CE3_A0 /* synthesis keep */;
    logic CE3_A1 /* synthesis keep */;
    logic CE3_A2 /* synthesis keep */;
    assign CE3_A0 = B1HQ[1] ^ INV; //IC 11D Unit B
    assign CE3_A1 = B1HQ[2] ^ INV; //IC 11D Unit A
    assign CE3_A2 = B1HQ[3] ^ INV;

    //HN27256G-30 300ns 4x32Kx8 BACK1 ROMs ---
    //hps_io rom load interface
    wire BACK1_ROM0_cs = (ioctl_addr >= 25'h40_000) && (ioctl_addr < 25'h48_000) /* synthesis keep */;
    wire BACK1_ROM1_cs = (ioctl_addr >= 25'h48_000) && (ioctl_addr < 25'h50_000) /* synthesis keep */;
    wire BACK1_ROM2_cs = (ioctl_addr >= 25'h50_000) && (ioctl_addr < 25'h58_000) /* synthesis keep */;
    wire BACK1_ROM3_cs = (ioctl_addr >= 25'h58_000) && (ioctl_addr < 25'h60_000) /* synthesis keep */;
    
    logic [7:0] ROM_DATA;

    //****** START OF ROM USES SDRAM ******
    //                    2     8       4       1      1
    //ROM address: {2_Q[1:0],B1_Q,B1V[3:0],CE3_A2,CE3_A1}

    logic [15:0] mask_rom_addr /* synthesis keep */;
    assign mask_rom_addr = {F2_Q[1:0],B1_Q,B1V[3:0],CE3_A2,CE3_A1};
    assign rom_addr = {8'h00, mask_rom_addr};

    reg [15:0] old_rom_addr;
    reg [15:0] back1_romdata;
    reg CE3_A0r;
    always_ff @(posedge clk) begin
        old_rom_addr <= mask_rom_addr;
        CE3_A0r <= CE3_A0;
        if(mask_rom_addr != old_rom_addr) begin
            rom_req <= ~rom_ack;
        end
        if(rom_req == rom_ack) begin
            back1_romdata <= rom_data;
        end
    end


    always_comb begin
        if (CE3_A0) begin
            ROM_DATA = back1_romdata[15:8]; 
        end
        else begin
            ROM_DATA = back1_romdata[7:0];
        end
    end
    //****** END OF ROM USES SDRAM ******

    //****** START OF ROM USES BRAM ******
    // logic [7:0] ROM_DATA3,ROM_DATA2,ROM_DATA1,ROM_DATA0 /* synthesis keep */;

    // eprom_32K BACK1_ROM0
    // (
    //     .ADDR({B1_Q, B1V[3:0], CE3_A2, CE3_A1, CE3_A0}),
    //     .CLK(clk),
    //     .DATA(ROM_DATA0),
    //     .ADDR_DL(ioctl_addr),
    //     .CLK_DL(clk),
    //     .DATA_IN(ioctl_data),
    //     .CS_DL(BACK1_ROM0_cs),
    //     .WR(ioctl_wr)
    // );
    // eprom_32K BACK1_ROM1
    // (
    //     .ADDR({B1_Q, B1V[3:0], CE3_A2, CE3_A1, CE3_A0}),
    //     .CLK(clk),
    //     .DATA(ROM_DATA1),
    //     .ADDR_DL(ioctl_addr),
    //     .CLK_DL(clk),
    //     .DATA_IN(ioctl_data),
    //     .CS_DL(BACK1_ROM1_cs),
    //     .WR(ioctl_wr)
    // );
    // eprom_32K BACK1_ROM2
    // (
    //     .ADDR({B1_Q, B1V[3:0], CE3_A2, CE3_A1, CE3_A0}),
    //     .CLK(clk),
    //     .DATA(ROM_DATA2),
    //     .ADDR_DL(ioctl_addr),
    //     .CLK_DL(clk),
    //     .DATA_IN(ioctl_data),
    //     .CS_DL(BACK1_ROM2_cs),
    //     .WR(ioctl_wr)
    // );
    // eprom_32K BACK1_ROM3
    // (
    //     .ADDR({B1_Q, B1V[3:0], CE3_A2, CE3_A1, CE3_A0}),
    //     .CLK(clk),
    //     .DATA(ROM_DATA3),
    //     .ADDR_DL(ioctl_addr),
    //     .CLK_DL(clk),
    //     .DATA_IN(ioctl_data),
    //     .CS_DL(BACK1_ROM3_cs),
    //     .WR(ioctl_wr)
    // );
    
    // always_comb begin : romdata_sel
    //     case (F2_Q[1:0])
    //         2'b00: ROM_DATA = ROM_DATA0;
    //         2'b01: ROM_DATA = ROM_DATA1;
    //         2'b10: ROM_DATA = ROM_DATA2;
    //         2'b11: ROM_DATA = ROM_DATA3;
    //     endcase
    // end
    //****** END OF ROM USES BRAM ******



    logic [1:0] a1_dummy;
    logic [3:0] A1_Q;
    ttl_74174_sync A1(
        .Reset_n(VIDEO_RSTn),
        .Clk(clk),
        .Cen(A2_S),
        .Clr_n(1'b1),
        .D({F2_Q[5:2],2'b11}),
        .Q({A1_Q,a1_dummy})
    );

     logic [3:0] A1bis_Q,A1bis2_Q,A1bis3_Q,A1bis4_Q,A1bis5_Q,A1bis6_Q,A1bis7_Q,A1bis8_Q,A1bis9_Q,A1bis10_Q,A1bis11_Q,A1bis12_Q,A1bis13_Q,A1bis14_Q,A1bis15_Q;

    always @(posedge clk) begin
        A1bis2_Q <= A1_Q;
        A1bis3_Q <= A1bis2_Q;
        A1bis4_Q <= A1bis3_Q;
        A1bis5_Q <= A1bis4_Q;
        A1bis6_Q <= A1bis5_Q;
        A1bis7_Q <= A1bis6_Q;
        A1bis8_Q <= A1bis7_Q;
        A1bis9_Q <= A1bis8_Q;
        A1bis10_Q <= A1bis9_Q;
        A1bis11_Q <= A1bis10_Q;
        A1bis12_Q <= A1bis11_Q;
        A1bis13_Q <= A1bis12_Q;
        A1bis14_Q <= A1bis13_Q;
        A1bis15_Q <= A1bis14_Q;
    end

    always_comb begin
        case (dbg_B1Voffset)
            4'b0000:  A1bis_Q = A1_Q;
            4'b0001:  A1bis_Q = A1bis2_Q;
            4'b0010:  A1bis_Q = A1bis3_Q;
            4'b0011:  A1bis_Q = A1bis4_Q;
            4'b0100:  A1bis_Q = A1bis5_Q;
            4'b0101:  A1bis_Q = A1bis6_Q;
            4'b0110:  A1bis_Q = A1bis7_Q;
            4'b0111:  A1bis_Q = A1bis8_Q;
            4'b1000:  A1bis_Q = A1bis9_Q;
            4'b1001:  A1bis_Q = A1bis10_Q;
            4'b1010:  A1bis_Q = A1bis11_Q;
            4'b1011:  A1bis_Q = A1bis12_Q;
            4'b1100:  A1bis_Q = A1bis13_Q;
            4'b1101:  A1bis_Q = A1bis14_Q;
            4'b1110:  A1bis_Q = A1bis15_Q;
            default: A1bis_Q = A1_Q;    
        endcase
    end

    assign B1D[7:4] = A1bis_Q;

    logic [7:0] A3_Q;
    ttl_74273_sync A3(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(B1HQ[0]), .D(ROM_DATA), .Q(A3_Q));

    logic [7:0] A3bis_Q,A3bis2_Q,A3bis3_Q,A3bis4_Q,A3bis5_Q,A3bis6_Q,A3bis7_Q,A3bis8_Q,A3bis9_Q,A3bis10_Q,A3bis11_Q,A3bis12_Q,A3bis13_Q,A3bis14_Q,A3bis15_Q;

    always @(posedge clk) begin
        A3bis2_Q <= A3_Q;
        A3bis3_Q <= A3bis2_Q;
        A3bis4_Q <= A3bis3_Q;
        A3bis5_Q <= A3bis4_Q;
        A3bis6_Q <= A3bis5_Q;
        A3bis7_Q <= A3bis6_Q;
        A3bis8_Q <= A3bis7_Q;
        A3bis9_Q <= A3bis8_Q;
        A3bis10_Q <= A3bis9_Q;
        A3bis11_Q <= A3bis10_Q;
        A3bis12_Q <= A3bis11_Q;
        A3bis13_Q <= A3bis12_Q;
        A3bis14_Q <= A3bis13_Q;
        A3bis15_Q <= A3bis14_Q;
    end

    always_comb begin
        case (dbg_B1Voffset)
            4'b0000:  A3bis_Q = A3_Q;
            4'b0001:  A3bis_Q = A3bis2_Q;
            4'b0010:  A3bis_Q = A3bis3_Q;
            4'b0011:  A3bis_Q = A3bis4_Q;
            4'b0100:  A3bis_Q = A3bis5_Q;
            4'b0101:  A3bis_Q = A3bis6_Q;
            4'b0110:  A3bis_Q = A3bis7_Q;
            4'b0111:  A3bis_Q = A3bis8_Q;
            4'b1000:  A3bis_Q = A3bis9_Q;
            4'b1001:  A3bis_Q = A3bis10_Q;
            4'b1010:  A3bis_Q = A3bis11_Q;
            4'b1011:  A3bis_Q = A3bis12_Q;
            4'b1100:  A3bis_Q = A3bis13_Q;
            4'b1101:  A3bis_Q = A3bis14_Q;
            4'b1110:  A3bis_Q = A3bis15_Q;
            default:  A3bis_Q = A3_Q;
        endcase
    end

    logic A2_S;
    assign A2_S = B1HQ[0] ^ INV;
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) A2 (.Enable_bar(1'b0), .Select((swap_px ? ~A2_S : A2_S)),
                .A_2D({A3bis_Q[7],A3bis_Q[3],A3bis_Q[6],A3bis_Q[2],A3bis_Q[5],A3bis_Q[1],A3bis_Q[4],A3bis_Q[0]}), .Y(B1D[3:0]));
endmodule