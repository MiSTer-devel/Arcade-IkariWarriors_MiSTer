module IkariWarriorsCore_FrontTurbo(
    //clocks
    input  wire VIDEO_RSTn,
    input  wire clk,
	input  wire H2n,
	input  wire H6,
	input  wire H7,
	input  wire XSET,
	input  wire YSET,
	input  wire F2INS,
    input  wire  [7:0] VD_in,
    output logic [7:0] VD_out,

	 input  wire [8:0] SPR_1Y,
	 input  wire [8:0] SPR_1X,
	input  wire [1:0] VA, //VA6~5
	 input  wire  WR0,
	 input  wire  WR1,
	 input  wire REG0n,
	 input  wire REG1n,
	 output wire [5:0] FN 
);
	reg [7:0] vdin_r;
    always @(posedge clk) begin
        vdin_r <= VD_in;
    end

	 logic [7:0] XSETr;
	 logic [7:0] YSETr;
	 logic [7:0] FNr;

	//*** X ***
	ttl_74273_sync T5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(XSET), .D(vdin_r), .Q(XSETr));

    logic u8_cout;
     logic [2:0] t8_sum;
	logic t8_dum;
	 logic XC;
	ttl_74283_nodly U8(.A(XSETr[3:0]), .B(SPR_1X[3:0]), .C_in(1'b1),     .Sum(),      .C_out(u8_cout));
	ttl_74283_nodly T8(.A(XSETr[7:4]), .B(SPR_1X[7:4]), .C_in(u8_cout),  .Sum({t8_sum,t8_dum}), .C_out(XC));

	//*** Y ***
	ttl_74273_sync R5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(YSET), .D(vdin_r), .Q(YSETr));

	logic r8_cout;
     logic [2:0] p8_sum;
	logic p8_dum;
	 logic YC;
	logic [8:0] SPR_1Yn;
	
	assign SPR_1Yn = ~SPR_1Y;
	
	ttl_74283_nodly R8(.A(YSETr[3:0]), .B(SPR_1Yn[3:0]), .C_in(1'b1),     .Sum(),      .C_out(r8_cout));
	ttl_74283_nodly P8(.A(YSETr[7:4]), .B(SPR_1Yn[7:4]), .C_in(r8_cout),  .Sum({p8_sum,p8_dum}), .C_out(YC));


	ttl_74273_sync N5(.RESETn(VIDEO_RSTn), .CLRn(1'b1), .Clk(clk), .Cen(F2INS), .D(vdin_r), .Q(FNr));

	 logic D1out, D0out;
	//logic D1r, D0r; //for register D1,D0 outputs
	A5004_4 S8(
		.YC(YC), //1
		.Y7(p8_sum[2]), //2
		.Y6(p8_sum[1]), //3
		.Y5(p8_sum[0]), //4
		.XC(XC), //6
		.X7(t8_sum[2]), //7
		.X6(t8_sum[1]), //8
		.X5(t8_sum[0]), //9
		.H8(FNr[7]), //13
		.Y8(SPR_1Yn[8]), //14
		.V8(FNr[6]), //17
		.X8(SPR_1X[8]), //18
		.D1(D1out), //12
		.D0(D0out) //19
	);

	//Register D1,D0 values
	// always @(posedge clk) begin
	// 	D1r <= D1out;
	// 	D0r <= D0out;
	// end

	logic [7:0] b2r ;
	ttl_74164_sync u7(
		.A(~D0out), 
		.B(~D1out), //serial input data
		.Reset_n(VIDEO_RSTn),
		.clk(clk),
		.Cen(H2n),
		.MRn(1'b1), //Master Reset (async)
		.Q0(b2r[7]), .Q1(b2r[6]), .Q2(b2r[5]), .Q3(b2r[4]), .Q4(b2r[3]), .Q5(b2r[2]), .Q6(b2r[1]), .Q7(b2r[0]) //fix
	);

	//Register file: in hardware implemented using four 74LS670 4bitx4 Latch registers dual ported
	//Implemented using 8bit registersx4
	 logic [7:0] FT_RegFile_REG0 [0:3];
	 logic [7:0] FT_RegFile_REG1 [0:3];
	 logic [7:0] REG0_VDout;
	 logic [7:0] REG1_VDout;

	always @(posedge clk) begin
		//The writing process is controlled by horizontal counter
		if(!WR0) begin
			 FT_RegFile_REG0[{H7,H6}] <= b2r;
		end
		if(!WR1) begin
			 FT_RegFile_REG1[{H7,H6}] <= b2r;
		end

		//The read process is video address controlled
		REG0_VDout <= FT_RegFile_REG0[VA];
		REG1_VDout <= FT_RegFile_REG1[VA];
	end

	//in real hardware, if not enabled REG0n or REG1n, the output remains in high impedance state
	//in the FPGA the 8'hff output values is used
	assign VD_out = (!REG0n) ? REG0_VDout : ((!REG1n) ? REG1_VDout : 8'hff ); 

	assign FN = FNr[5:0];
endmodule