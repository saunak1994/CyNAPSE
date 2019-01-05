/*
-----------------------------------------------------
| Created on: 12.21.2018		            							
| Author: Saunak Saha				    
|                                                   
| Department of Electrical and Computer Engineering  
| Iowa State University                             
-----------------------------------------------------
*/




`timescale 1ns/1ns
module Top_tb();

	//Global Timer resolution and limits
	localparam DELTAT_WIDTH = 4;																			//Resolution upto 0.1 ms can be supported 
	localparam BT_WIDTH_INT = 32;																			//2^32 supports 4,000M BT Units (ms) so for 500 ms exposure per example it can support 8M examples
	localparam BT_WIDTH_FRAC = DELTAT_WIDTH;																//BT Follows resolution 
	localparam BT_WIDTH = BT_WIDTH_INT + BT_WIDTH_FRAC;	

	//Data precision 
	localparam INTEGER_WIDTH = 16;																			//All Integer localparams should lie between +/- 2048
	localparam DATA_WIDTH_FRAC = 32;																		//Selected fractional precision for all status data
	localparam DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC;
	localparam TREF_WIDTH = 5;																				//Refractory periods should lie between +/- 16 (integer)
	localparam EXTEND_WIDTH = (TREF_WIDTH+3)*2;																//For Refractory Value Arithmetic

	//Neuron counts and restrictions
	localparam NEURON_WIDTH_LOGICAL = 11;																	//For 2^11 = 2048 supported logical neurons
	localparam NEURON_WIDTH = NEURON_WIDTH_LOGICAL;
	localparam NEURON_WIDTH_INPUT = NEURON_WIDTH_LOGICAL;													//For 2^11 = 2048 supported input neurons
	localparam NEURON_WIDTH_MAX_LAYER = 11;																	//Maximum supported layer size ofone layer in the network
	localparam NEURON_WIDTH_PHYSICAL = 3;																	//For 2^6 = 64 physical neurons on-chip
	localparam TDMPOWER = NEURON_WIDTH_LOGICAL - NEURON_WIDTH_PHYSICAL;										//The degree of Time division multiplexing of logical to physical neurons
	localparam INPUT_NEURON_START = 0;																		//Input neurons in Weight table starts from index: 0 
	localparam LOGICAL_NEURON_START = 2**NEURON_WIDTH_INPUT;												//Logical neurons in Weight Table starts from index: 2048

	//On-chip Neuron status SRAMs
	localparam SPNR_WORD_WIDTH = ((DATA_WIDTH*6)+(TREF_WIDTH+3)+ NEURON_WIDTH_LOGICAL + 1 + 1);				//Format : |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth| 
	localparam SPNR_ADDR_WIDTH = TDMPOWER;																	//This many entries in each On-chip SRAM 
	
	//Off-Chip Weight RAM
	localparam WRAM_WORD_WIDTH = DATA_WIDTH;																//Weight bit-width is same as all status data bit-width
	localparam WRAM_ROW_WIDTH = NEURON_WIDTH_INPUT + 1;
	localparam WRAM_COLUMN_WIDTH = NEURON_WIDTH_LOGICAL;  
	localparam WRAM_ADDR_WIDTH = WRAM_ROW_WIDTH + WRAM_COLUMN_WIDTH;										//ADDR_WIDTH = 2* NEURON_WIDTH + 1 (2*X^2 Synapses for X logical neurons and X input neurons) ?? Not Exactly but works in the present Configuration
	
	//Off-Chip Theta RAM
	localparam TRAM_WORD_WIDTH = DATA_WIDTH;																//Vth bit-width = status bit-wdth
	localparam TRAM_ADDR_WIDTH = NEURON_WIDTH_LOGICAL;														//Adaptive thresholds supported for all logical neurons
	
	//Queues
	localparam FIFO_WIDTH = NEURON_WIDTH_LOGICAL;															//2048 FIFO Queue Entries 

	//Memory initialization binaries
	localparam WEIGHTFILE = "weights_bin.mem";																//Binaries for Weights 
	localparam THETAFILE = "theta_bin.mem";	
	
	//Real datatype conversion
	localparam sfDATA = 2.0 **- 32.0;
	localparam sfBT = 2.0 **- 4.0;


	//Control Inputs
	reg  Clock;
	reg  Reset;
	reg  Initialize;
	reg  ExternalEnqueue;
	reg  ExternalDequeue;
	reg  Run;

	//AER Inputs
	reg  [(BT_WIDTH-1):0] InFIFOBTIn;
	reg  [(NEURON_WIDTH-1):0] InFIFONIDIn;

	//Global Inputs
	reg  [(DELTAT_WIDTH-1):0] DeltaT = 4'b1000;																//DeltaT = 0.5ms  


	//Network Information 
	reg  [(NEURON_WIDTH-1):0] ExRangeLOWER = 784;							
	reg  [(NEURON_WIDTH-1):0] ExRangeUPPER = (784 + 400 -1);							
	reg  [(NEURON_WIDTH-1):0] InRangeLOWER = (784 + 400);							 	
	reg  [(NEURON_WIDTH-1):0] InRangeUPPER = (784 + 400 + 400 -1);							
	reg  [(NEURON_WIDTH-1):0] IPRangeLOWER = 0;							
	reg  [(NEURON_WIDTH-1):0] IPRangeUPPER = 783;							
	reg  [(NEURON_WIDTH-1):0] OutRangeLOWER = 784;							
	reg  [(NEURON_WIDTH-1):0] OutRangeUPPER = (784 + 400 - 1);							
	reg  [(NEURON_WIDTH-1):0] NeuStart = 784;							 
	reg  [(NEURON_WIDTH-1):0] NeuEnd = 1583;								 

	
	//Status register initialization values
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_EX = {-16'd105, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_EX = {48'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_EX = {48'd0};
	
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_IN = {-16'd100, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_IN = {48'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_IN = {48'd0};


	//Neuron-specific characteristics	
	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_EX = {-16'd65}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_EX = {16'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_EX = {16'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_EX = {-16'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_EX = {16'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_EX = {16'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_EX = {5'd5};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_EX = {-16'd65};	
	reg signed [(DATA_WIDTH-1):0] Threshold_EX = {-16'd52,32'd0};

	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_IN = {-16'd60}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_IN = {16'd10}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_IN = {16'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_IN = {-16'd85}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_IN = {16'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_IN = {16'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_IN = {5'd2};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_IN = {-16'd45};	
	reg signed [(DATA_WIDTH-1):0] Threshold_IN = {-16'd40, 32'd0};

	//AER Outputs
	wire [(BT_WIDTH-1):0] OutFIFOBTOut;
	wire [(NEURON_WIDTH-1):0] OutFIFONIDOut;

	//Control Outputs 
	wire InitializationComplete;
	wire WChipEnable;
	wire ThetaChipEnable;

	//Off-Chip RAM I/O
	wire [(WRAM_ADDR_WIDTH-1):0] WRAMAddress;
	wire [(WRAM_WORD_WIDTH-1):0] WeightData;
	wire [(TRAM_ADDR_WIDTH-1):0] ThetaAddress;
	wire [(TRAM_WORD_WIDTH-1):0] ThetaData;




	//I/O Files
	integer i,j;
	
	integer BTFile, NIDFile, ScanBT, ScanNID;
	integer outFile1, outFile2, outFile3, outFile4, outFile5, outFile6, outFile7;
	
	reg signed [(DATA_WIDTH-1):0] IDVmemEx;
	reg signed [(DATA_WIDTH-1):0] IDVmemIn; 
	reg signed [(DATA_WIDTH-1):0] IDGexEx; 
	reg signed [(DATA_WIDTH-1):0] IDGexIn;
	reg signed [(DATA_WIDTH-1):0] IDGinEx; 
	reg signed [(DATA_WIDTH-1):0] IDGinIn;









	//State Monitor
	localparam Monitor = 0;	//Change this 
	localparam MonitorIn = (Monitor+400);
	localparam ExPhysical = Monitor%(2**NEURON_WIDTH_PHYSICAL);
	localparam ExRow = Monitor>>(NEURON_WIDTH_PHYSICAL);
	localparam InPhysical = MonitorIn%(2**NEURON_WIDTH_PHYSICAL);
	localparam InRow = MonitorIn>>(NEURON_WIDTH_PHYSICAL);

	
	
	
	
	

	

	initial begin 


		IDVmemEx = 0;
		IDVmemIn = 0;
		IDGexEx = 0;
		IDGexIn = 0;
		IDGinEx = 0;
		IDGinIn = 0;
		
		//File Handling : Use for Bad Pointer Accesses and Open file issues  
	
		/*
		outFile1 = $fopen("OneExampleTestDump_EX.mem","w");
		outFile2 = $fopen("OneExampleTestDump_IN.mem","w");
		BTFile = $fopen("BTIn.mem","r");
		NIDFile = $fopen("NIDIn.mem","r");
		$fclose(BTFile);
		$fclose(NIDFile);
		$fclose(outFile1);
		$fclose(outFile2);

		$finish;
		*/

		//File Handling and Initialization : Use if no aforementioned Issues
		
		
		outFile1 = $fopen("OneExampleTestDump_EX_Vmem.mem","w");
		outFile2 = $fopen("OneExampleTestDump_EX_gex.mem","w");
		outFile3 = $fopen("OneExampleTestDump_EX_gin.mem","w");

		outFile4 = $fopen("OneExampleTestDump_IN_Vmem.mem","w");
		outFile5 = $fopen("OneExampleTestDump_IN_gex.mem","w");
		outFile6 = $fopen("OneExampleTestDump_IN_gin.mem","w");

		outFile7 = $fopen("OneExampleTestDump_OUTFIFO.mem","w");

		BTFile = $fopen("BTIn.mem","r");
		NIDFile = $fopen("NIDIn.mem","r");
		
		
		
		//Global Reset
		Clock = 0;
		Reset = 1;	
		Initialize = 0;
		ExternalEnqueue = 0;
		ExternalDequeue = 0;
		Run = 0;

		
		//Global Initialize 
		#15
		Reset = 0;
		Initialize = 1;
		
		#9000
		if (InitializationComplete) begin 
			Initialize = 0;
			ExternalEnqueue = 1;
		end
		

		
		//Ten Event Test : A small manual custom events test
		
	
		/*		
		InFIFOBTIn = 36'd0;
		InFIFONIDIn = 11'd400;

		#10
		InFIFOBTIn = 36'd0;
		InFIFONIDIn = 11'd163;

		#10
		InFIFOBTIn = {32'd0,4'b1000};
		InFIFONIDIn = 11'd218;

		#10
		InFIFOBTIn = {32'd0,4'b1000};
		InFIFONIDIn = 11'd237;

		#10
		InFIFOBTIn = {32'd0,4'b1000};
		InFIFONIDIn = 11'd734;

		#10
		InFIFOBTIn = {32'd1,4'b0000};
		InFIFONIDIn = 11'd110;

		#10
		InFIFOBTIn = {32'd1,4'b1000};
		InFIFONIDIn = 11'd219;

		#10
		InFIFOBTIn = {32'd1,4'b1000};
		InFIFONIDIn = 11'd120;

		#10
		InFIFOBTIn = {32'd1,4'b1000};
		InFIFONIDIn = 11'd300;

		#10
		InFIFOBTIn = {32'd2,4'b0000};
		InFIFONIDIn = 11'd22;

		#10
		ExternalEnqueue = 0;
		Run = 1;

		*/
		
		

		//One Example Test: Test against imported AER files that are one examples long

		
		for (i = 0; i<2**FIFO_WIDTH; i=i+1) begin 
			if(!$feof(BTFile) && !$feof(NIDFile)) begin 
				ScanBT = $fscanf(BTFile, "%b\n", InFIFOBTIn);
				ScanNID = $fscanf(NIDFile, "%b\n", InFIFONIDIn);
				#10;
			end
			else begin 
			ExternalEnqueue = 0;
			end
			
		end
				

		$fclose(BTFile);
		$fclose(NIDFile);
		
		
		//Start Run
		#10
		ExternalEnqueue = 0;
		Run = 1;	
		
	end

	always begin 

		#5 Clock = ~Clock;
	
	end

	
	always @(posedge CyNAPSE.CLIFNU.UpdateComplete) begin
		if(Run) begin
			$display("Update Done");
			IDVmemEx = (CyNAPSE.CLIFNU.genblk3[ExPhysical].SPNR_x.OnChipRam[ExRow][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGexEx = (CyNAPSE.CLIFNU.genblk3[ExPhysical].SPNR_x.OnChipRam[ExRow][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGinEx = (CyNAPSE.CLIFNU.genblk3[ExPhysical].SPNR_x.OnChipRam[ExRow][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)]);

			IDVmemIn = (CyNAPSE.CLIFNU.genblk3[InPhysical].SPNR_x.OnChipRam[InRow][(6*DATA_WIDTH+TREF_WIDTH+3-1):(5*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGexIn = (CyNAPSE.CLIFNU.genblk3[InPhysical].SPNR_x.OnChipRam[InRow][(5*DATA_WIDTH+TREF_WIDTH+3-1):(4*DATA_WIDTH+TREF_WIDTH+3)]);
			IDGinIn = (CyNAPSE.CLIFNU.genblk3[InPhysical].SPNR_x.OnChipRam[InRow][(4*DATA_WIDTH+TREF_WIDTH+3-1):(3*DATA_WIDTH+TREF_WIDTH+3)]);

			$fwrite(outFile1,"%f\n",$itor(IDVmemEx)*sfDATA);
			$fwrite(outFile2,"%f\n",$itor(IDGexEx)*sfDATA);
			$fwrite(outFile3,"%f\n",$itor(IDGinEx)*sfDATA);

			$fwrite(outFile4,"%f\n",$itor(IDVmemIn)*sfDATA);
			$fwrite(outFile5,"%f\n",$itor(IDGexIn)*sfDATA);
			$fwrite(outFile6,"%f\n",$itor(IDGinIn)*sfDATA);
			
		end
			
	end

	
	always @(CyNAPSE.SysCtrl.Current_BT) begin 
		$display("Current_BT = %f", $itor(CyNAPSE.SysCtrl.Current_BT)*sfBT);
		if(CyNAPSE.SysCtrl.Current_BT == 36'd5616) begin 								//Set BT Limit. For one example BT Limit = 351*16 = 5616
			Run = 0;
			
			for (j = 0; j< 2**FIFO_WIDTH; j=j+1) begin
		
				$fwrite(outFile7,"%f %d\n",$itor(CyNAPSE.OutFIFO.FIFO_BT[j])*sfBT,CyNAPSE.OutFIFO.FIFO_NID[j]);
		
			end

			$fclose(outFile1);
			$fclose(outFile2);
			$fclose(outFile3);
			$fclose(outFile4);
			$fclose(outFile5);
			$fclose(outFile6);
			$fclose(outFile7);
			$finish;
		end
	end
	
	
	Top #(DELTAT_WIDTH, BT_WIDTH_INT, BT_WIDTH_FRAC, BT_WIDTH, INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, TREF_WIDTH, EXTEND_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, NEURON_WIDTH_INPUT, NEURON_WIDTH_MAX_LAYER, NEURON_WIDTH_PHYSICAL, TDMPOWER, INPUT_NEURON_START, LOGICAL_NEURON_START, SPNR_WORD_WIDTH, SPNR_ADDR_WIDTH, WRAM_WORD_WIDTH, WRAM_ROW_WIDTH, WRAM_COLUMN_WIDTH, WRAM_ADDR_WIDTH, TRAM_WORD_WIDTH, TRAM_ADDR_WIDTH, FIFO_WIDTH, WEIGHTFILE, THETAFILE) CyNAPSE
	(
		//Control Inputs
		.Clock(Clock),
		.Reset(Reset),
		.Initialize(Initialize),
		.ExternalEnqueue(ExternalEnqueue),
		.ExternalDequeue(ExternalDequeue),
		.Run(Run),

		//AER Inputs
		.InFIFOBTIn(InFIFOBTIn),
		.InFIFONIDIn(InFIFONIDIn),
	
		//Global Inputs 
		.DeltaT(DeltaT),
		
		//Network Information
		.ExRangeLOWER(ExRangeLOWER),			
		.ExRangeUPPER(ExRangeUPPER),			
		.InRangeLOWER(InRangeLOWER),					
		.InRangeUPPER(InRangeUPPER),			
		.IPRangeLOWER(IPRangeLOWER),			
		.IPRangeUPPER(IPRangeUPPER),
		.OutRangeLOWER(OutRangeLOWER),
		.OutRangeUPPER(OutRangeUPPER),			
		.NeuStart(NeuStart),			
		.NeuEnd(NeuEnd),

		//Status register initialization values 
		.Vmem_Initial_EX(Vmem_Initial_EX),
		.gex_Initial_EX(gex_Initial_EX),
		.gin_Initial_EX(gin_Initial_EX),
	
		.Vmem_Initial_IN(Vmem_Initial_IN),
		.gex_Initial_IN(gex_Initial_IN),
		.gin_Initial_IN(gin_Initial_IN),

		//Neuron-specific characteristics
		.RestVoltage_EX(RestVoltage_EX), 	
		.Taumembrane_EX(Taumembrane_EX), 	
		.ExReversal_EX(ExReversal_EX),	
		.InReversal_EX(InReversal_EX), 	
		.TauExCon_EX(TauExCon_EX),	
		.TauInCon_EX(TauInCon_EX),	
		.Refractory_EX(Refractory_EX),		
		.ResetVoltage_EX(ResetVoltage_EX),	
		.Threshold_EX(Threshold_EX),
	
		.RestVoltage_IN(RestVoltage_IN), 	
		.Taumembrane_IN(Taumembrane_IN), 	
		.ExReversal_IN(ExReversal_IN),	
		.InReversal_IN(InReversal_IN), 	
		.TauExCon_IN(TauExCon_IN),	
		.TauInCon_IN(TauInCon_IN),	
		.Refractory_IN(Refractory_IN),		
		.ResetVoltage_IN(ResetVoltage_IN),	
		.Threshold_IN(Threshold_IN),

		//AEROutputs
		.OutFIFOBTOut(OutFIFOBTOut),
		.OutFIFONIDOut(OutFIFONIDOut),

		//Control Outputs
		.InitializationComplete(InitializationComplete),
		.WChipEnable(WChipEnable),
		.ThetaChipEnable(ThetaChipEnable),

		//Off-Chip RAM I/O
		.WRAMAddress(WRAMAddress),
		.WeightData(WeightData),
		.ThetaAddress(ThetaAddress),
		.ThetaData(ThetaData)


	);

	/***************************************************************
		WEIGHT RAM 	
	***************************************************************/
	SinglePortOffChipRAM #(WRAM_WORD_WIDTH, WRAM_ADDR_WIDTH, WEIGHTFILE) WeightRAM
	(
		//Controls Signals
		.Clock(Clock),	
		.Reset(InternalRouteReset),
		.ChipEnable(WChipEnable),
		.WriteEnable(1'b0),

		//Inputs from Router		
		.InputData({WRAM_WORD_WIDTH{1'b0}}),
		.InputAddress(WRAMAddress),

		//Outputs to Router 
		.OutputData(WeightData)

	);

	
	
	/***************************************************************
		THETA RAM 	
	***************************************************************/
	
	SinglePortOffChipRAM #(TRAM_WORD_WIDTH, TRAM_ADDR_WIDTH, THETAFILE) ThetaRAM
	(
		//Controls Signals
		.Clock(Clock),	
		.Reset(Reset),
		.ChipEnable(ThetaChipEnable),			
		.WriteEnable(1'b0),			

		//Inputs from Router		
		.InputData({TRAM_WORD_WIDTH{1'b0}}),		
		.InputAddress(ThetaAddress),	

		//Outputs to Router 
		.OutputData(ThetaData)		

	);

endmodule
