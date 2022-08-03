//TNKIIICore_Sound_sync.sv
//Author: @RndMnkIII
//sound output frequency 55.556KHz
`default_nettype none
`timescale 1ns/10ps

module TNKIIICore_Sound_sync
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
    output logic SND_BUSY,
    // combined output
    output  wire signed [15:0] snd,
    output  wire sample,
    input wire [15:0] FRM_CNT
);
    logic [7:0] latch_din;

    //logic P7_F4_cs, P8_F3_cs, P9_F2_cs;
    logic P10_F6_cs, P11_D6_cs;
    // selector_cpu_snd_rom selector
    // (.ioctl_addr(ioctl_addr), .P7_F4_cs(P7_F4_cs), .P8_F3_cs(P8_F3_cs), .P9_F2_cs(P9_F2_cs));
    selector_tnkiii_cpu_snd_rom selector_tnkiii
    (.ioctl_addr(ioctl_addr), .P10_F6_cs(P10_F6_cs), .P11_D6_cs(P11_D6_cs));

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
        .RESET_n(reset_n),
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
    logic YM3526_IRQn;
    logic YM3526_IRQ;
    logic YM3526_CSn, YM3526_RDn, YM3526_WRn;
    logic YM3526_RW;

    assign YM3526_CSn = YM3526_RW;
    assign YM3526_RDn = YM3526_RW | nRD;
    assign YM3526_WRn = YM3526_RW | nWR;
    assign YM3526_IRQ = ~YM3526_IRQn;

    logic [7:0] ym3526_dout;
    jtopl  YM3526
    (
        .rst(~RESETn),        // rst should be at least 6 clk&cen cycles long
        .clk(clk),        // CPU clock
        .cen(CEN_p & ~pause_cpu), //active high
        .din(cpu_dout),
        .addr(A[0]),
        .cs_n(YM3526_CSn),
        .wr_n(YM3526_WRn),
        .dout(ym3526_dout),
        .irq_n(YM3526_IRQn),
        // combined output
        .snd(snd),
        .sample(sample)
    );
    //----------------

    logic CS_ROM_P10n, CS_ROM_P11n;
    assign CS_ROM_P10n = ~(~A[14] & ~A[15]); //0x0000-0x3fff
    assign CS_ROM_P11n = ~( A[14] & ~A[15]); //0x4000-0x7fff
  
    logic D8_2_Y3, BUSY_CLEARn, LATCH_MCODEn, CS_RAMn;
    ttl_74139_nodly d8_2(.Enable_bar((~A[15] | nMREQ)), .A_2D(A[14:13]), .Y_2D({D8_2_Y3, BUSY_CLEARn, LATCH_MCODEn, CS_RAMn}));

    logic YM3526_IRQ_ACK, MCODE_IRQ_ACK, D8_1_Y1;
    ttl_74139_nodly d8_1(.Enable_bar(D8_2_Y3), .A_2D(A[2:1]), .Y_2D({YM3526_IRQ_ACK, MCODE_IRQ_ACK, D8_1_Y1, YM3526_RW}));

    //--- 27128 16Kx8 MAIN CPU ROMS ---
    logic [7:0] data_P10_F6;
    logic [7:0] data_P11_D6;

    eprom_16K P10_F6
    (
        .ADDR(A[13:0]),
        .CLK(clk),
        .DATA(data_P10_F6),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P10_F6_cs),
        .WR(ioctl_wr)
    );
    
    eprom_16K P11_D6
    (
        .ADDR(A[13:0]),
        .CLK(clk),
        .DATA(data_P11_D6),
        .ADDR_DL(ioctl_addr),
        .CLK_DL(clk),
        .DATA_IN(ioctl_data),
        .CS_DL(P11_D6_cs),
        .WR(ioctl_wr)
    );
    //---------------------------------

    //--- HM6116-4 2Kx8 200ns SRAM ---
    logic [7:0] RAM_dout;
    SRAM_sync_noinit #(.ADDR_WIDTH(11)) f1(.ADDR(A[10:0]), .clk(clk), .cen(~CS_RAMn), .we(~nWR), .DATA(cpu_dout), .Q(RAM_dout));
    //--------------------------------

    //Sounc CPU data input MUX
    logic LATCH_MCODEn_reg, BUSY_CLEARn_reg, YM3526_CSn_reg, G6_2_Y1_reg, MCODE_IRQ_ACK_reg, YM3526_IRQ_ACK_reg;
    logic YM3526_RDn_reg, YM3526_WRn_reg;

    always @(posedge clk) begin
                 if(!CS_ROM_P10n      && !nRD)                  cpu_din <= data_P10_F6;   //0x0000-0x3fff
            else if(!CS_ROM_P11n      && !nRD)                  cpu_din <= data_P11_D6;   //0x4000-0x7fff
            else if(!CS_RAMn          && !nRD)                  cpu_din <= RAM_dout;     //0x8000-0x87ff
            else if(!LATCH_MCODEn     && !nRD)                  cpu_din <= latch_din;    //0xA000                                  
            else if(!BUSY_CLEARn      && !nRD)                  cpu_din <= 8'hFF;        //0xC000
            else if(!YM3526_CSn       && !YM3526_RDn)           cpu_din <= ym3526_dout;  //0xE000-0xE001 YM3526_CSn <-> YM3526_RW
            else if(!D8_1_Y1          && !nRD)                  cpu_din <= 8'h00;        //0xE002
            else if(!MCODE_IRQ_ACK    && !nRD)                  cpu_din <= 8'hFF;        //0xE004
            else if(!YM3526_IRQ_ACK   && !nRD)                  cpu_din <= 8'hFF;        //0xE006
            else                                                cpu_din <= 8'hFF;        
        //end
    end
    //--------------------------------

    //--- Z80 CPU interrupt logic ---
    logic G7_2_Q;
    DFF_pseudoAsyncClrPre #(.W(1)) g7_2 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(G7_2_Q),
        .qn(),
        .set(1'b0),    // active high
        .clr(~YM3526_IRQ_ACK),    // active high
        .cen(YM3526_IRQ) // signal whose edge will trigger the FF
    );

    logic G7_1_Q;
    DFF_pseudoAsyncClrPre #(.W(1)) g7_1 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(G7_1_Q),
        .qn(),
        .set(1'b0),    // active high
        .clr(~MCODE_IRQ_ACK),    // active high
        .cen(MCODE) // signal whose edge will trigger the FF
    );

    logic G5_3;
    logic H5_3;
    assign G5_3 = G7_2_Q | G7_1_Q;
    assign H5_3 = ~G5_3;
    assign nINT = H5_3;

    DFF_pseudoAsyncClrPre #(.W(1)) h6_1 (
        .clk(clk),
        .rst(~VIDEO_RSTn),
        .din(1'b1),
        .q(SND_BUSY),
        .qn(),
        .set(1'b0),    // active high
        .clr(~BUSY_CLEARn),    // active high
        .cen(MCODE) // signal whose edge will trigger the FF
    );
    //-------------------------------

    //--- Data latch interface ---
    reg [7:0] vdin_r;
    always @(posedge clk) begin
        if(!VIDEO_RSTn) vdin_r <= 8'b0;
        else vdin_r <= data_in;
    end

    logic [7:0] F8_Q;
    ttl_74273_sync f8 (.RESETn(VIDEO_RSTn), .CLRn(BUSY_CLEARn), .Clk(clk), .Cen(MCODE), .D(vdin_r), .Q(F8_Q));

    reg [7:0] F8_Q_r;
    always @(posedge clk) begin
        if(!VIDEO_RSTn) F8_Q_r <= 8'b0;
        else F8_Q_r <= F8_Q;
    end
   
    always @(posedge clk) begin
        if(!LATCH_MCODEn) latch_din <= F8_Q_r;
        else              latch_din <= 8'hFF;
    end     
    //assign latch_din = ((!LATCH_MCODEn) ? F8_Q : 8'hFF);
    //----------------------------
endmodule
