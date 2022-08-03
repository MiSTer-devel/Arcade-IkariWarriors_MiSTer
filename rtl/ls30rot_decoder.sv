//ls30rot_decoder.sv
//Author: @RndMnkIII
//Date: 31/07/2022
//Description: this module decodes the LS-30 joystick rotation position.
//Convert from two position data captures the relative rotation direction.
//and convert it to absolute rotation value. 
//The LS-30 operation is based on a 12 switches arranged in a circunference.
//The switches are normally open and when closed are connected directly to ground.
//Because this is necessary to use in the adapter pull-up resistors to get a high value.
//Also the 12 wires coming from the LS-30 connector are combined in such a way that 
//they are reduced to use only 4 with the adapter. So I don't know the absolute value
//of rotation, only the relative change between groups of four consecutive wires. 
//4 groups of 3 cables are created by grouping them like this: (12,8,4), (11,7,3),
//(10,6,2),(9,5,1).
//Normally there is only one switch closed at a time, but there is an overlap between 
//one position and the adjacent ones, causing two switches to be active for a short time.
//This feature has been used to create a data table in which the current position is 
//compared with the previous one and based on the combination of both values, a delta 
//value is obtained that can indicate that it was rotated clockwise, counterclockwise 
//or no change has occurred. Combinations where the aforementioned overlap occurs at 
//the current position are also ignored. This delta value is used to update the absolute
//position of rotation in [11-0] interval.
`timescale 1ns / 1ps
 
module ls30rot_decoder (
  input wire clk,
  input wire wait_data,
  input wire [3:0] curr_data,
  input wire [3:0] last_data,
  output logic [3:0] pos
);
	logic [3:0] r_curr_data;
	logic [3:0] r_last_data;
	logic signed [1:0] delta_value;
	logic [7:0] data_changed;
	
	logic [3:0] r_pos = 4'd11; //simulate the absolute rotation value from a relative one.	
	assign data_changed = {r_last_data,r_curr_data} ^ {last_data,curr_data};
	
	//Uses positive logic for data decoding.
	always_comb begin
		case ({last_data,curr_data})
		8'b1001_0001: delta_value = 1;
		8'b0011_0010: delta_value = 1;
		8'b0110_0100: delta_value = 1;
		8'b1100_1000: delta_value = 1;
		8'b1001_1000: delta_value = -1;
		8'b1100_0100: delta_value = -1;
		8'b0110_0010: delta_value = -1;
		8'b0011_0001: delta_value = -1;
		default:      delta_value = 0;
		endcase
	end
  
  always_ff @(posedge clk) begin
	r_curr_data <= curr_data;
	r_last_data <= last_data;
    if(data_changed && !wait_data) begin
		if (r_pos == 4'd11) begin
		if(delta_value > 0) r_pos = 4'd0;
		else if(delta_value < 0) r_pos = r_pos - 4'd1;
		end
		else if (r_pos == 4'd0) begin
		if(delta_value < 0) r_pos = 4'd11;
		else if(delta_value > 0) r_pos = r_pos + 4'd1;
		end
		else begin
		if(delta_value < 0) r_pos = r_pos - 4'd1;
		else if(delta_value > 0) r_pos = r_pos + 4'd1;
		end
	end
  end
  
  assign pos = r_pos;
endmodule