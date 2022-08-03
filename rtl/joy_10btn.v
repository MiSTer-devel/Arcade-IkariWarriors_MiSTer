module joy_10btn
(
 input  wire clk,      //Reloj de Entrada sobre 48-50Mhz
 output  wire JOY_CLK,
 output  wire JOY_LOAD,  
 input   wire JOY_DATA, 
 output  wire [15:0] JOYSTICK1
);
//Gestion de Joystick
reg [15:0] JCLOCKS;
always @(posedge clk) begin 
   JCLOCKS <= JCLOCKS +8'd1;
end

reg [15:0] joy1  = 16'hFFFF;
reg joy_renew = 1'b1;
reg [4:0]joy_count = 5'd0;
   
assign JOY_CLK = JCLOCKS[4]; //con 3 Funciona = 3Mhz
assign JOY_LOAD = joy_renew;
always @(posedge JOY_CLK) begin 
    if (joy_count == 5'd0) begin
       joy_renew = 1'b0;
    end else begin
       joy_renew = 1'b1;
    end
    if (joy_count == 5'd17) begin
      joy_count = 5'd0;
    end else begin
      joy_count = joy_count + 1'd1;
    end      
end
always @(posedge JOY_CLK) begin
    case (joy_count)
        5'd4  : joy1[0] <= JOY_DATA;   //COIN
        5'd5  : joy1[1]  <= JOY_DATA;  //START
        5'd6  : joy1[2]  <= JOY_DATA;  //A 
        5'd7  : joy1[3]  <= JOY_DATA;  //B
        5'd8  : joy1[4]  <= JOY_DATA;  //C
        5'd9  : joy1[5]  <= JOY_DATA;  //D
        5'd10 : joy1[6]  <= JOY_DATA;  //E
        5'd11 : joy1[7]  <= JOY_DATA;  //F
        5'd12 : joy1[8]  <= JOY_DATA;  //G
        5'd13 : joy1[9]  <= JOY_DATA;  //H
        5'd14 : joy1[10]  <= JOY_DATA;  //LEFT 
        5'd15 : joy1[11]  <= JOY_DATA;  //RIGHT 
        5'd16 : joy1[12] <= JOY_DATA;  //DOWN
        5'd17 : joy1[13] <= JOY_DATA;  //UP
    endcase              
end
//----LS FEDCBAUDLR
assign JOYSTICK1[15:0] = joy1; //ASO uses active low signals for game inputs

endmodule