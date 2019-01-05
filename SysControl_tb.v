`timescale 1ns/1ns
module SysControl_tb();

localparam BT_WIDTH = 36;
localparam DELTAT_WIDTH = 4;

//External Inputs
reg Clock, Reset, Initialize, ExternalEnqueue, ExternalDequeue, Run;

//Global Inputs
reg [(DELTAT_WIDTH-1):0] DeltaT = 4'b1000;

//Input FIFO, Aux FIFO, Out FIFO
reg IsInputQueueFull, IsInputQueueEmpty, IsAuxQueueFull, IsAuxQueueEmpty, IsOutQueueFull, IsOutQueueEmpty;
reg [(BT_WIDTH-1):0] InputBT_Head, AuxBT_Head, OutBT_Head;

wire InputReset, InputQueueEnable, InputEnqueue, InputDequeue;
wire AuxReset, AuxQueueEnable, AuxDequeue;
wire OutReset, OutQueueEnable, OutDequeue;

//IRIS
wire InputRouteInputSelect;

//Input Router, Iternal Router 
reg InputRoutingComplete, InternalRoutingComplete;

wire InputRouteReset, InputRouteInitialize, InputRouteEnable;
wire InternalRouteReset, InternalRouteEnable;
wire [(BT_WIDTH-1):0] InternalCurrent_BT;

//Neuron Unit
reg MappingComplete, UpdateComplete;
wire NeuronUnitReset, NeuronUnitInitialize, MapNeurons, UpdateEnable;

//Top-level Outputs
wire InitializationComplete; 



initial begin 
	
	Clock = 0;
	Reset = 1;
	Initialize = 0;
	ExternalEnqueue = 0;
	ExternalDequeue = 0;
	Run = 0;
	IsInputQueueFull = 0;
	IsInputQueueEmpty = 0;
	IsAuxQueueFull = 0;
	IsAuxQueueEmpty = 0;
	IsOutQueueFull = 0;
	IsOutQueueEmpty = 0;
	InputRoutingComplete = 0;
	InternalRoutingComplete = 0;
	MappingComplete = 0;
	UpdateComplete = 0;

	#15
	Reset = 0;
	Initialize  = 1;
	

	#1000
	MappingComplete = 1;
	Initialize = 0;																							//This is done by the Top Level 
	Run = 1;
	ExternalEnqueue = 1;
	ExternalDequeue = 0;
	IsInputQueueFull = 0;
	IsInputQueueEmpty = 1;
	IsAuxQueueFull = 0;
	IsAuxQueueEmpty = 1;
	IsOutQueueFull = 0;
	IsOutQueueEmpty = 1;
	InputBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}};	//0
	AuxBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}};	//0
	OutBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}};	//0  							//All are empty and BT Heads are zero, nothing happens here
	InputRoutingComplete = 0;													 
	InternalRoutingComplete = 0;
	UpdateComplete = 0;
	

	//Current BT should be 0 here

	#10
	IsInputQueueEmpty = 0;																					// First enqueue has occured from external (and subsequent)	
	InputBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}};  								//Still 0
	
	#200																									//One route has completed 
	InputRoutingComplete = 1;
	#10
	InputRoutingComplete = 0;													

	#200																									//Two routes have completed
	InputRoutingComplete = 1;
	#10
	InputRoutingComplete = 0;

	InputBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}+DeltaT}; 							//Now 0.5, so It should now check Aux but Aux empty so should go to Update and IRIS should go to (1 or 0) = 1

	#1000
	UpdateComplete = 1;																						//Update should finish here and go to Internal Route
	#10
	UpdateComplete = 0;

	#200
	InternalRoutingComplete = 1;																			//Internal ROute completes

	IsAuxQueueEmpty = 0;																					//Aux not empty, IRIS is still (1 or 1) = 1
	AuxBT_Head = {{BT_WIDTH - DELTAT_WIDTH{1'b0}},{DELTAT_WIDTH{1'b0}}+DeltaT}; 							//Now 0.5 next BT 
	#10
	InternalRoutingComplete = 0;

	//Now Current BT should be 0.5																			//IRIS is still (0 or 1) = 1 						

	#200																									//First Aux is Routed because IRIS is 1  
	InputRoutingComplete = 1;
	#10
	InputRoutingComplete = 0;
	IsAuxQueueEmpty = 1;																					//IRIS is now (0 or 0) = 0, so will route the Input Router 							
	
	#200																									//One Route completes from Input Queue
	InputRoutingComplete = 1;
	#10
	InputRoutingComplete = 0;

	#200																									//Two routes complete from Input Queue
	InputRoutingComplete = 1;
	#10
	InputRoutingComplete = 0;

	InputBT_Head = {32'd1,{DELTAT_WIDTH{1'b0}}}; 															//Now 1.0 , IRIS is now (1 or 0) = 1 Should go to AUx which empty, So Update

	
	#1000
	UpdateComplete = 1;																						//Update should finish here and go to Internal Route
	#10
	UpdateComplete = 0;									

	#200 																									//Internal Route completes
	InternalRoutingComplete = 1;				
	#10
	InternalRoutingComplete = 0; 								
	
	
	IsInputQueueEmpty = 1;																					//Stop here (Because no Internal event generated and no more input events to be routed)																				
	IsAuxQueueEmpty = 1;
	Run = 0;




	//THIS TEST WAS SUCCESSFUL (?)

	
	
end

always begin 
	
	#5 Clock = ~Clock;

end




SysControl #(BT_WIDTH, DELTAT_WIDTH) SC1(

	.Clock(Clock),
	.Reset(Reset),
	.Initialize(Initialize),
	.ExternalEnqueue(ExternalEnqueue),
	.ExternalDequeue(ExternalDequeue),
	.Run(Run),


	.DeltaT(DeltaT),
	

	.IsInputQueueFull(IsInputQueueFull),
	.IsInputQueueEmpty(IsInputQueueEmpty),
	.InputBT_Head(InputBT_Head),

	.InputReset(InputReset),
	.InputQueueEnable(InputQueueEnable),
	.InputEnqueue(InputEnqueue),
	.InputDequeue(InputDequeue),


	.IsAuxQueueFull(IsAuxQueueFull),
	.IsAuxQueueEmpty(IsAuxQueueEmpty),
	.AuxBT_Head(AuxBT_Head),

	.AuxReset(AuxReset),
	.AuxQueueEnable(AuxQueueEnable),
	.AuxDequeue(AuxDequeue),


	.IsOutQueueFull(IsOutQueueFull),
	.IsOutQueueEmpty(IsOutQueueEmpty),
	.OutBT_Head(OutBT_Head),

	.OutReset(OutReset),
	.OutQueueEnable(OutQueueEnable),
	.OutDequeue(OutDequeue),


	.InputRouteInputSelect(InputRouteInputSelect),
	

	.InputRoutingComplete(InputRoutingComplete),
	
	.InputRouteReset(InputRouteReset),
	.InputRouteInitialize(InputRouteInitialize),
	.InputRouteEnable(InputRouteEnable),

	
	.InternalRoutingComplete(InternalRoutingComplete),
	
	.InternalRouteReset(InternalRouteReset),
	.InternalCurrent_BT(InternalCurrent_BT),
	.InternalRouteEnable(InternalRouteEnable),
	
	
	.MappingComplete(MappingComplete),
	.UpdateComplete(UpdateComplete),

	.NeuronUnitReset(NeuronUnitReset),
	.NeuronUnitInitialize(NeuronUnitInitialize),
	.MapNeurons(MapNeurons),
	.UpdateEnable(UpdateEnable),



	.InitializationComplete(InitializationComplete)

);
	





endmodule
