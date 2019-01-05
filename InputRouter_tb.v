`timescale 1ns/1ns
module InputRouter_tb();

localparam NEURON_WIDTH = 11;
localparam DATA_WIDTH = 44;
localparam ADDR_WIDTH = 22;

localparam sf = 2.0 **- 32.0;  

//Control Inputs
reg Clock, Reset, RouteEnable, Initialize;

//Network Information
reg [(NEURON_WIDTH-1):0] ExRangeLOWER = 784;		
reg [(NEURON_WIDTH-1):0] ExRangeUPPER = (784 + 400 - 1);		
reg [(NEURON_WIDTH-1):0] InRangeLOWER = (784 + 400);			
reg [(NEURON_WIDTH-1):0] InRangeUPPER = (784 + 400 + 400 -1 );		
reg [(NEURON_WIDTH-1):0] IPRangeLOWER = 0;		
reg [(NEURON_WIDTH-1):0] IPRangeUPPER = 783;		
reg [(NEURON_WIDTH-1):0] NeuStart = 784;
reg [(NEURON_WIDTH-1):0] NeuEnd = 1583;		

//Queue Inputs
reg [(NEURON_WIDTH-1):0] NeuronID = 400;			
	
//Inputs from Memory
wire signed [(DATA_WIDTH-1):0] WeightData;	

//Outputs to Memory						
wire WChipEnable;										
wire WWriteEnable;									
wire [(ADDR_WIDTH-1):0] WRAMAddress;				

//Inputs from Crossbar			
wire  signed [(DATA_WIDTH-1):0] ExWeightSum;	
wire  signed [(DATA_WIDTH-1):0] InWeightSum;

//Outputs to Crossbar
wire  EXChipEnable;			
wire  INChipEnable;			
wire  EXWriteEnable;			
wire  INWriteEnable;			
wire  [(NEURON_WIDTH-1):0] EXAddress;	
wire  [(NEURON_WIDTH-1):0] INAddress;	
wire  signed [(DATA_WIDTH-1):0] NewExWeightSum;				
wire  signed [(DATA_WIDTH-1):0] NewInWeightSum;	

//Outputs to SysControl
wire RoutingComplete;

integer i;
integer outFile;

initial begin 
	
	Clock = 0;
	Reset = 1;
	RouteEnable = 0;
	Initialize = 0;

	#15
	Reset = 0;
	Initialize = 1; 

	#35
	Initialize = 0;
	RouteEnable = 1;

	#65000
	outFile = $fopen("ExDendriticDump.mem","w");
	for (i=0; i< (NeuEnd-NeuStart+1) ; i = i + 1) begin
		$fwrite(outFile,"%f \n", $itor(EXRAM.OnChipRam[i])*sf);
	end
	#10
	$fclose(outFile);

	
end					


		
always begin

	#5 Clock = ~Clock;

end

always @ (posedge RoutingComplete) begin 
	
	RouteEnable = 0;
	

end

InputRouter IR1(

	.Clock(Clock),
	.Reset(Reset),
	.RouteEnable(RouteEnable),
	.Initialize(Initialize),

	
	.ExRangeLOWER(ExRangeLOWER),			
	.ExRangeUPPER(ExRangeUPPER),			
	.InRangeLOWER(InRangeLOWER),					
	.InRangeUPPER(InRangeUPPER),			
	.IPRangeLOWER(IPRangeLOWER),			
	.IPRangeUPPER(IPRangeUPPER),			
	.NeuStart(NeuStart),
	.NeuEnd(NeuEnd),						
	
	
	.NeuronID(NeuronID),			
	
										
	.WeightData(WeightData),		

						
	.WChipEnable(WChipEnable),											
	.WWriteEnable(WWriteEnable),									
	.WRAMAddress(WRAMAddress),				

						
	.ExWeightSum(ExWeightSum),			
	.InWeightSum(InWeightSum),		
	
	
	.EXChipEnable(EXChipEnable),				
	.INChipEnable(INChipEnable),				
	.EXWriteEnable(EXWriteEnable),				
	.INWriteEnable(INWriteEnable),				
	.EXAddress(EXAddress),		
	.INAddress(INAddress),		
	.NewExWeightSum(NewExWeightSum),					
	.NewInWeightSum(NewInWeightSum),		

	
	.RoutingComplete(RoutingComplete)						

		
);


	SinglePortOnChipRAM #(44,22,"weights_bin.mem") WRAM(
	
		.Clock(Clock),
		.Reset(Reset),
		.ChipEnable(WChipEnable),
		.WriteEnable(WWriteEnable),

		.InputData(44'd0),
		.InputAddress(WRAMAddress),
	
		.OutputData(WeightData)
	
	);

	SinglePortNeuronRAM #(44, 11) EXRAM(

		.Clock(Clock),
		.Reset(Reset),
		.ChipEnable(EXChipEnable),
		.WriteEnable(EXWriteEnable),
	
		.InputData(NewExWeightSum),
		.InputAddress(EXAddress),

		.OutputData(ExWeightSum)

	);

	SinglePortNeuronRAM #(44, 11) INRAM(

		.Clock(Clock),
		.Reset(Reset),
		.ChipEnable(INChipEnable),
		.WriteEnable(INWriteEnable),
	
		.InputData(NewInWeightSum),
		.InputAddress(INAddress),

		.OutputData(InWeightSum)
	

	);
	



endmodule



