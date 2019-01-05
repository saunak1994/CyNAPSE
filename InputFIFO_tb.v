`timescale 1ns/1ns
module InputFIFO_tb();

localparam NEURON_WIDTH = 11;
localparam BT_WIDTH = 36;
localparam FIFO_WIDTH = 11;

localparam sf = 2.0 **- 4.0;



reg Clock, Reset, QueueEnable, Dequeue, Enqueue;

reg [(BT_WIDTH-1):0] BTIn;
reg [(NEURON_WIDTH-1):0] NIDIn;

wire [(BT_WIDTH-1):0] BTOut;
wire [(NEURON_WIDTH-1):0] NIDOut;

wire IsQueueEmpty, IsQueueFull;
wire [(BT_WIDTH-1):0] BT_Head;

integer i;
integer outFile;

initial begin 

	Clock = 0;
	Reset = 1;
	QueueEnable = 0;
	Dequeue = 0;
	Enqueue = 0;

	#15
	Reset = 0; 
	QueueEnable = 1;

	#10
	Enqueue = 1;
	Dequeue = 0;

	for (i = 0; i< 2**FIFO_WIDTH; i=i+1) begin
		BTIn = {{32{i}},4'b1000};
		NIDIn = {11{i}};
		#10;
	end

	
	
	$fclose(outFile);
	#20
	Enqueue = 0;
	Dequeue = 1;
	
 	#20480
	Dequeue = 0;

	for (i = 0; i< 20; i= i+1) begin 
		if(~IsQueueFull) Enqueue = 1;
		

		BTIn = {{32{i+17}},4'b1000};
		NIDIn = {11{i+17}};
		#10
		if(~IsQueueEmpty) Dequeue = 1;

		#10;
	end

	Enqueue = 0;
	Dequeue = 0;

	QueueEnable = 0;
	
	outFile = $fopen("FIFODump.mem","w");
	for (i = 0; i< 2**FIFO_WIDTH; i=i+1) begin
		
		$fwrite(outFile,"%f %d\n",$itor(FIFO1.FIFO_BT[i])*sf,FIFO1.FIFO_NID[i]);
		
	end


end

	
	
always begin 
	
	#5 Clock =~ Clock;
end


InputFIFO #(BT_WIDTH, FIFO_WIDTH, NEURON_WIDTH) FIFO1
(
	.Clock(Clock),
	.Reset(Reset),
	.QueueEnable(QueueEnable),
	.Dequeue(Dequeue),
	.Enqueue(Enqueue),

	.BTIn(BTIn),	
	.NIDIn(NIDIn),

	.BTOut(BTOut),
	.NIDOut(NIDOut),

	.BT_Head(BT_Head),
	.IsQueueEmpty(IsQueueEmpty),
	.IsQueueFull(IsQueueFull)

);
	 



endmodule 
