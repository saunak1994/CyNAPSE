/*
-----------------------------------------------------
| Created on: 12.15.2018		            						
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering  
| Iowa State University                             
-----------------------------------------------------
*/



`timescale 1ns/1ns
module SinglePortOffChipRAM
#(
	parameter WORD_WIDTH = 16+32,
	parameter ADDR_WIDTH = 23, 									
	parameter FILENAME = "weights_bin.mem"
)
(
	input Clock,
	input Reset,
	input ChipEnable,
	input WriteEnable,
	
	input [(WORD_WIDTH-1):0] InputData,
	input [(ADDR_WIDTH-1):0] InputAddress,

	output [(WORD_WIDTH-1):0] OutputData
);



	reg [(WORD_WIDTH - 1):0] OnChipRam [(2**ADDR_WIDTH - 1):0];
	reg [(ADDR_WIDTH - 1):0] RamAddress;

	
	initial begin 
	
		$display("Loading Data into On-Chip RAM");
		$readmemb(FILENAME, OnChipRam);
		$display("Finished Loading");
		

	end
	

	assign OutputData = OnChipRam[RamAddress]; 

	always @ (posedge Clock) begin
		if (Reset) begin 
			RamAddress <= 0;	
		end	
		
		else if(ChipEnable) begin 		
			if(WriteEnable) begin 
				OnChipRam[InputAddress] <= InputData;
			end
	 
			RamAddress <= InputAddress;
			
		end
		
		else begin 
			RamAddress <= RamAddress;
		end
				 
	end
	
endmodule
