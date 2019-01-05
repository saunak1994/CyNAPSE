`timescale 1ns/1ns
module InternalRouter_tb();

localparam NEURON_WIDTH = 11;
localparam BT_WIDTH = 36;
localparam DELTAT_WIDTH = 4;
localparam FIFO_WIDTH = 11;

localparam sf = 2.0 **- 4.0;

reg Clock, Reset, RouteEnable, QueueEnable, Dequeue;

reg [(NEURON_WIDTH-1):0] OutRangeLOWER = 0;
reg [(NEURON_WIDTH-1):0] OutRangeUPPER = 399;

reg [(BT_WIDTH-1):0] Current_BT = {32'd5,4'b0000};
reg [(DELTAT_WIDTH-1):0] DeltaT = 4'b1000;

reg [(2**NEURON_WIDTH-1):0] SpikeBuffer;

wire AuxEnqueueOut, OutEnqueueOut;
wire [(BT_WIDTH-1):0] AuxBTOut, OutBTOut;
wire [(NEURON_WIDTH-1):0] AuxNIDOut, OutNIDOut;

wire AuxIsQueueEmpty, AuxIsQueueFull;
wire OutIsQueueEmpty, OutIsQueueFull;

wire [(BT_WIDTH-1):0] AuxFIFOBTOut, OutFIFOBTOut;
wire [(NEURON_WIDTH-1):0] AuxFIFONIDOut, OutFIFONIDOut;

wire [(BT_WIDTH-1):0] AuxBT_Head, OutBT_Head;

wire RoutingComplete;

integer i, outFile;

initial begin 
	
	Clock = 0;
	Reset = 1;
	RouteEnable = 0;
	SpikeBuffer = 2048'd0;

	Dequeue = 0;
	QueueEnable = 0;
	
	#15
	Reset = 0;
	RouteEnable = 1;
	SpikeBuffer[0] = 1'b1;
	SpikeBuffer[8] = 1'b1;
	SpikeBuffer[15] = 1'b1;
	SpikeBuffer[20] = 1'b1;
	SpikeBuffer[77] = 1'b1;
	SpikeBuffer[155] = 1'b1;
	SpikeBuffer[267] = 1'b1;
	SpikeBuffer[367] = 1'b1;
	SpikeBuffer[418] = 1'b1;
	SpikeBuffer[460] = 1'b1;
	SpikeBuffer[526] = 1'b1;
	SpikeBuffer[575] = 1'b1;
	SpikeBuffer[620] = 1'b1;
	SpikeBuffer[687] = 1'b1;
	SpikeBuffer[783] = 1'b1;

	QueueEnable = 1;
	
	/*
	outFile = $fopen("AuxFIFODump.mem","w");
	for (i = 0; i< 2**FIFO_WIDTH; i=i+1) begin
		
		$fwrite(outFile,"%f %d\n",$itor(Aux1.FIFO_BT[i])*sf,Aux1.FIFO_NID[i]);
		
	end
	
	$fclose(outFile);
	*/

	

end

always begin 
	#5 Clock = ~Clock;
end

always @ (posedge RoutingComplete) begin 
	RouteEnable = 0;
end



InternalRouter #(NEURON_WIDTH,BT_WIDTH,DELTAT_WIDTH) InR1(

	.Clock(Clock),
	.Reset(Reset),
	.RouteEnable(RouteEnable),
	.Current_BT(Current_BT),

	.OutRangeLOWER(OutRangeLOWER),
	.OutRangeUPPER(OutRangeUPPER),

	.DeltaT(DeltaT),
	
	.SpikeBuffer(SpikeBuffer),
	
	.ToAuxEnqueueOut(AuxEnqueueOut),
	.ToAuxBTOut(AuxBTOut),
	.ToAuxNIDOut(AuxNIDOut),

	.ToOutEnqueueOut(OutEnqueueOut),
	.ToOutBTOut(OutBTOut),
	.ToOutNIDOut(OutNIDOut),
	

	.RoutingComplete(RoutingComplete)
); 


InputFIFO Aux1(

	.Clock(Clock),
	.Reset(Reset),
	.QueueEnable(QueueEnable),
	.Dequeue(Dequeue),
	.Enqueue(AuxEnqueueOut),

	.BTIn(AuxBTOut),
	.NIDIn(AuxNIDOut),

	.BTOut(AuxFIFOBTOut),
	.NIDOut(AuxFIFONIDOut),

	.BT_Head(AuxBT_Head),
	.IsQueueEmpty(AuxIsQueueEmpty),
	.IsQueueFull(AuxIsQueueFull)
);

InputFIFO Out1(

	.Clock(Clock),
	.Reset(Reset),
	.QueueEnable(QueueEnable),
	.Dequeue(Dequeue),
	.Enqueue(OutEnqueueOut),

	.BTIn(OutBTOut),
	.NIDIn(OutNIDOut),

	.BTOut(OutFIFOBTOut),
	.NIDOut(OutFIFONIDOut),

	.BT_Head(OutBT_Head),
	.IsQueueEmpty(OutIsQueueEmpty),
	.IsQueueFull(OutsIsQueueFull)
);





endmodule



