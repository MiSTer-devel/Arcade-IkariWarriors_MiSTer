//Dual_YM3526_Sound.sv
//Author: @RndMnkIII
//Date: 26/05/2022
//sound output frequency 55.556KHz
`default_nettype none
`timescale 1ns/10ps

module Dual_YM3526_Sound
(
    input  wire VIDEO_RSTn,
    input  wire clk, //53.6MHz
    input wire pause_cpu,
    input  wire CEN_p, //4MHz
    input  wire CEN_n, ////4MHz shifted 180 degrees
    input  wire RESETn, //same RESETn signal as CPUA, CPUB
    input  wire [7:0] data_in,
    //hps_io rom interface
	input wire         [24:0] ioctl_addr,
	input wire         [7:0] ioctl_data,
	input wire         ioctl_wr,
    input  wire MCODE,
    output logic MS,
    // combined output
    output  wire signed [15:0] snd1,
    output  wire signed [15:0] snd2,
    output  wire sample
);
    logic [7:0] latch_din;

    // ----------------- Z80A Cpu -----------------
    //output
    logic nM1;
    logic nMREQ;
    logic nIORQ;
    logic nRD;
    logic nWR;
    logic nRFSH;
    logic nHALT;
    logic nBUSACK;
    //input
    logic nWAIT = 1'b1;
    logic nINT;
    logic nNMI = 1'b1;
    logic nBUSRQ = 1'b1;
    logic [15:0] A;

    logic  [7:0] cpu_din;
    logic  [7:0] cpu_dout;

    // local reset
    reg reset_n=1'b0;
    reg [4:0] rst_cnt;

    always @(negedge clk) begin
        if( ~RESETn ) begin
            rst_cnt <= 'd0;
            reset_n <= 1'b0;
        end else begin
            if( rst_cnt != ~5'b0 ) begin
                reset_n <= 1'b0;
                rst_cnt <= rst_cnt + 5'd1;
            end else reset_n <= 1'b1;
        end
    end

    //T80pa CLK x2 real CPU clock
        T80pa z80_g2 (
        .RESET_n(RESETn),
        .CLK    (clk),
        .CEN_p  (CEN_p & ~pause_cpu), //active high
        .CEN_n  (CEN_n & ~pause_cpu), //active high
        //.WAIT_n (~pause_cpu),
        .WAIT_n (1'b1),
        .INT_n  (nINT),
        .NMI_n  (1'b1),
        .RD_n   (nRD),
        .WR_n   (nWR),
        .A      (A),
        .DI     (cpu_din),
        .DO     (cpu_dout),
        .IORQ_n (nIORQ),
        .M1_n   (nM1),
        .MREQ_n (nMREQ),
        .BUSRQ_n(1'b1),
        .BUSAK_n(nBUSACK),
        .OUT0   (1'b0),
        .RFSH_n (nRFSH),
        .HALT_n (nHALT)
    );
    //---------------------------------------------

    //---- YM3526 ----
    logic YM3526_IRQn1;
    logic YM3526_IRQn2;
    logic YM3526_CSn1, YM3526_RDn1, YM3526_WRn1;
    logic YM3526_CSn2, YM3526_RDn2, YM3526_WRn2;
    logic YM3526_RW1, YM3526_RW2;

    assign YM3526_CSn1 = YM3526_RW1;
    assign YM3526_RDn1 = YM3526_RW1 | nRD;
    assign YM3526_WRn1 = YM3526_RW1 | nWR;

    assign YM3526_CSn2 = YM3526_RW2;
    assign YM3526_RDn2 = YM3526_RW2 | nRD;
    assign YM3526_WRn2 = YM3526_RW2 | nWR;

    logic [7:0] ym3526_dout1;
    logic [7:0] ym3526_dout2;
    jtopl  YM3526_1
    (
        .rst(~RESETn),        // rst should be at least 6 clk&cen cycles long
        .clk(clk),        // CPU clock
        .cen(CEN_p & ~pause_cpu), //active high
        .din(cpu_dout),
        .addr(A[10]),
        .cs_n(YM3526_CSn1),
        .wr_n(YM3526_WRn1),
        .dout(ym3526_dout1),
        .irq_n(YM3526_IRQn1),
        // combined output
        .snd(snd1),
        .sample(sample)
    );

    jtopl  YM3526_2
    (
        .rst(~RESETn),        // rst should be at least 6 clk&cen cycles long
        .clk(clk),        // CPU clock
        .cen(CEN_p & ~pause_cpu), //active high
        .din(cpu_dout),
        .addr(A[10]),
        .cs_n(YM3526_CSn2),
        .wr_n(YM3526_WRn2),
        .dout(ym3526_dout2),
        .irq_n(YM3526_IRQn2),
        // combined output
        .snd(snd2),
        .sample()
    );
    //----------------

    logic CS_ROM_0n, CS_ROM_1n, CS_ROM_2n, CS_RAMn;

  
    logic F4_2_Y3n;
    ttl_74139_nodly F4_2(.Enable_bar(1'b0), .A_2D(A[15:14]), .Y_2D({F4_2_Y3n, CS_ROM_2n, CS_ROM_1n, CS_ROM_0n}));

    // logic ROM256_CE;
    // assign ROM256_CE = CS_ROM_2n & CS_ROM_1n;

    logic SOUND_STATUS, LATCH_MCODEn;
    logic F4_1_Gn;
    assign F4_1_Gn = F4_2_Y3n | (~A[13]);
    ttl_74139_nodly F4_1(.Enable_bar(F4_1_Gn), .A_2D(A[12:11]), .Y_2D({SOUND_STATUS,YM3526_RW2,YM3526_RW1,LATCH_MCODEn}));

    //--- 27128 16Kx8, 27256 32Kx8 MAIN CPU ROMS ---
    logic ROM0_cs, ROM1_cs, ROM2_cs;

    selector_dualYM3526_cpu_snd_rom ROM_Sel
    (.ioctl_addr(ioctl_addr), .ROM0_cs(ROM0_cs), .ROM1_cs(ROM1_cs), .ROM2_cs(ROM2_cs)); //recheck

    logic [7:0] data_ROM0;
    logic [7:0] data_ROM1;
    logic [7:0] data_ROM2;

    eprom_16K ROM0
    (
        .ADDR(A[13:0]),
        .CLK(clk),
        .DATA(data_ROM0),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(ROM0_cs),
        .WR(ioctl_wr)
    );
    
    //In Athena PCB there are one 16Kb EPROM and one 32Kb EPROM
    eprom_16K ROM1
    (
        .ADDR({A[13:0]}),
        .CLK(clk),
        .DATA(data_ROM1),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(ROM1_cs),
        .WR(ioctl_wr)
    );

    eprom_16K ROM2
    (
        .ADDR({A[13:0]}),
        .CLK(clk),
        .DATA(data_ROM2),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(ROM2_cs),
        .WR(ioctl_wr)
    );
    //---------------------------------

    //--- HM6116-4 2Kx8 200ns SRAM ---
    assign CS_RAMn = A[13] | F4_2_Y3n;
    logic [7:0] RAM_dout;
    SRAM_sync_noinit #(.ADDR_WIDTH(11)) f1(.ADDR(A[10:0]), .clk(clk), .cen(~CS_RAMn), .we(~nWR), .DATA(cpu_dout), .Q(RAM_dout));
    //--------------------------------

    //Sound CPU data input MUX
    logic SOUND_STATUS_R, SOUND_STATUS_W;

    assign SOUND_STATUS_R = nRD | SOUND_STATUS;
    assign SOUND_STATUS_W = nWR | SOUND_STATUS;

    always @(posedge clk) begin
                 if(!CS_ROM_0n        && !nRD)                  cpu_din <= data_ROM0;    //0x0000-0x3fff
            else if(!CS_ROM_1n        && !nRD)                  cpu_din <= data_ROM1;    //0x4000-0x7fff
            else if(!CS_ROM_2n        && !nRD)                  cpu_din <= data_ROM2;    //0x8000-0xbfff
            else if(!CS_RAMn          && !nRD)                  cpu_din <= RAM_dout;     //0xc000-0xcfff
            else if(!LATCH_MCODEn     && !nRD)                  cpu_din <= latch_din;    //0xE000                                  
            else if(!YM3526_CSn1      && !YM3526_RDn1)          cpu_din <= ym3526_dout1; //0xE800
            else if(!YM3526_CSn2      && !YM3526_RDn2)          cpu_din <= ym3526_dout2; //0xF000
            else if(!SOUND_STATUS_R)                            cpu_din <= {4'hf,STATUS_r};     //0xF800 //LSB FOUR BITS, remaing all 0
            else                                                cpu_din <= 8'hFF;        
        //end
    end
    //--------------------------------


    //--- Z80 CPU interrupt logic ---
    logic JK_YM1_ACK, JK_YM2_ACK;
    logic JK_YM3526_IRQ1_STATUS, JK_YM3526_IRQ1, JK_YM3526_IRQ2_STATUS, JK_YM3526_IRQ2;
    ttl_74107a_sync #(.BLOCKS(1)) JK_YM3526_IRQ1ic (.Reset_n(VIDEO_RSTn), .CLRn(JK_YM1_ACK), .J(1'b1), .K(1'b0), .Clk(clk), .Cen(YM3526_IRQn1), .Q(JK_YM3526_IRQ1_STATUS), .Qn(JK_YM3526_IRQ1));
    ttl_74107a_sync #(.BLOCKS(1)) JK_YM3526_IRQ2ic (.Reset_n(VIDEO_RSTn), .CLRn(JK_YM2_ACK), .J(1'b1), .K(1'b0), .Clk(clk), .Cen(YM3526_IRQn2), .Q(JK_YM3526_IRQ2_STATUS), .Qn(JK_YM3526_IRQ2));
    
    logic DFF_CPU_BUSY_ACK;
    logic DFF_CMD_IRQ_ACK;
    logic CPU_BUSY, CMD_IRQ;
    logic CPU_BUSY_STATUS, CMD_IRQ_STATUS;

    DFF_pseudoAsyncClrPre2 #(.W(1)) CPU_BUSY_IRQic (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(CPU_BUSY_STATUS),
        .qn(CPU_BUSY),
        .set(1'b0),
        .clr(~DFF_CPU_BUSY_ACK),
        .cen(MCODE) 
    );

     DFF_pseudoAsyncClrPre2 #(.W(1)) CMD_IRQic (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(CMD_IRQ_STATUS),
        .qn(CMD_IRQ),
        .set(1'b0),
        .clr(~DFF_CMD_IRQ_ACK),
        .cen(MCODE) 
    );

    assign nINT = (JK_YM3526_IRQ1 & JK_YM3526_IRQ2 & CPU_BUSY & CMD_IRQ);

    assign {DFF_CMD_IRQ_ACK,DFF_CPU_BUSY_ACK,JK_YM2_ACK,JK_YM1_ACK} = (!SOUND_STATUS_W) ? cpu_dout[7:4] : 4'hf;

    assign MS = CPU_BUSY_STATUS;

    //Read Status
    logic [3:0] STATUS_r;
    always @(posedge clk) begin
        if (!SOUND_STATUS_R) STATUS_r <= {CMD_IRQ_STATUS, CPU_BUSY_STATUS, JK_YM3526_IRQ2_STATUS, JK_YM3526_IRQ1_STATUS};
        else                 STATUS_r <= 4'hf;      
    end

    //-------------------------------

    //--- Data latch interface ---
    reg [7:0] vdin_r;
    always @(posedge clk) begin
        if(!VIDEO_RSTn) vdin_r <= 8'b0;
        else vdin_r <= data_in;
    end

    logic [7:0] F8_Q;
    ttl_74273_sync f8 (.RESETn(VIDEO_RSTn), .CLRn(DFF_CMD_IRQ_ACK), .Clk(clk), .Cen(MCODE), .D(vdin_r), .Q(F8_Q));
   
    always @(posedge clk) begin
        if(!LATCH_MCODEn) latch_din <= F8_Q;
        else              latch_din <= 8'hFF;
    end     
    //----------------------------
endmodule
