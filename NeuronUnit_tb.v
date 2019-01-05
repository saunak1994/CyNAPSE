`timescale 1ns/1ns
module NeuronUnit_tb();

	//Design Parameters
	localparam INTEGER_WIDTH = 12; 
	localparam DATA_WIDTH_FRAC = 32;
	localparam DATA_WIDTH = INTEGER_WIDTH + DATA_WIDTH_FRAC;
	localparam DELTAT_WIDTH = 4;
	localparam TREF_WIDTH = 5;
	localparam NEURON_WIDTH_LOGICAL = 11;
	localparam NEURON_WIDTH_PHYSICAL = 6;
	localparam NEURON_WIDTH = NEURON_WIDTH_LOGICAL;
	localparam NEURON_WIDTH_INPUT = 11;
	localparam NEURON_WIDTH_MAX_LAYER = 11;
	localparam ROW_WIDTH = NEURON_WIDTH_INPUT + 1;
	localparam COLUMN_WIDTH = NEURON_WIDTH_LOGICAL;
	localparam ADDR_WIDTH = ROW_WIDTH + COLUMN_WIDTH;
	localparam INPUT_NEURON_START = 0;
	localparam LOGICAL_NEURON_START = 2**NEURON_WIDTH_INPUT;
	localparam TDMPOWER = NEURON_WIDTH_LOGICAL - NEURON_WIDTH_PHYSICAL;
	localparam NEU_DATA_WIDTH = (DATA_WIDTH*6)+(TREF_WIDTH+3)+ NEURON_WIDTH_LOGICAL + 1 + 1;			//Format : |NID|Valid|Ntype|Vmem|Gex|Gin|RefVal|ExWeight|InWeight|Vth| 
	localparam NEU_ADDR_WIDTH = TDMPOWER;
	localparam EXTEND_WIDTH = (TREF_WIDTH+3)*2;
	localparam THETAFILE = "theta_bin.mem";
	localparam WEIGHTFILE = "weights_bin.mem";

	//Test-specific parameters
	localparam sf = 2.0 ** -32.0;
	localparam monitor = 574;
	localparam physical = monitor%2**NEURON_WIDTH_PHYSICAL;
	localparam row = monitor>>NEURON_WIDTH_PHYSICAL;
	
	//Control Signals
	reg Clock;
	reg Reset;
	reg UpdateEnable;
	reg RouteEnable;
	reg Initialize;
	reg MapNeurons; 
	wire MappingComplete;
	wire UpdateComplete;
	wire RoutingComplete;
	
	//Status register initialization values
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_EX = {-12'd105, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_EX = {44'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_EX = {44'd0};
	
	reg signed [(DATA_WIDTH-1):0] Vmem_Initial_IN = {-12'd100, 32'd0};
	reg signed [(DATA_WIDTH-1):0] gex_Initial_IN = {44'd0};
	reg signed [(DATA_WIDTH-1):0] gin_Initial_IN = {44'd0};

	//Neuron-specific characteristics
	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_EX = {-12'd65}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_EX = {12'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_EX = {12'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_EX = {-12'd100}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_EX = {12'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_EX = {12'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_EX = {5'd5};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_EX = {-12'd65};	
	reg signed [(DATA_WIDTH-1):0] Threshold_EX = {-12'd52,32'd0};

	reg signed [(INTEGER_WIDTH-1):0] RestVoltage_IN = {-12'd60}; 	
	reg signed [(INTEGER_WIDTH-1):0] Taumembrane_IN = {12'd10}; 	
	reg signed [(INTEGER_WIDTH-1):0] ExReversal_IN = {12'd0};	
	reg signed [(INTEGER_WIDTH-1):0] InReversal_IN = {-12'd85}; 	
	reg signed [(INTEGER_WIDTH-1):0] TauExCon_IN = {12'd1};	
	reg signed [(INTEGER_WIDTH-1):0] TauInCon_IN = {12'd2};	
	reg signed [(TREF_WIDTH-1):0] Refractory_IN = {5'd2};		
	reg signed [(INTEGER_WIDTH-1):0] ResetVoltage_IN = {-12'd45};	
	reg signed [(DATA_WIDTH-1):0] Threshold_IN = {-12'd40, 32'd0};

	//Network Information
	reg [(NEURON_WIDTH-1):0] ExRangeLOWER = 784;			
	reg [(NEURON_WIDTH-1):0] ExRangeUPPER = (784 + 400 -1);		
	reg [(NEURON_WIDTH-1):0] InRangeLOWER = (784 + 400);					
	reg [(NEURON_WIDTH-1):0] InRangeUPPER = (784 + 400 + 400 -1);			
	reg [(NEURON_WIDTH-1):0] IPRangeLOWER = 0;			
	reg [(NEURON_WIDTH-1):0] IPRangeUPPER = 783;			
	reg [(NEURON_WIDTH-1):0] NeuStart = 784;			
	reg [(NEURON_WIDTH-1):0] NeuEnd = 1583;

	//Global Inputs
	reg [(DELTAT_WIDTH-1):0] DeltaT = {4'b1000};

	//From Router to NeuronUnit
	wire FromRouterEXChipEnable;
	wire FromRouterINChipEnable;
	wire FromRouterEXWriteEnable;
	wire FromRouterINWriteEnable;
	wire [(NEURON_WIDTH-1):0] FromRouterEXAddress;
	wire [(NEURON_WIDTH-1):0] FromRouterINAddress;
	wire signed [(DATA_WIDTH-1):0] FromRouterNewExWeightSum;
	wire signed [(DATA_WIDTH-1):0] FromRouterNewInWeightSum;

	//From NeuronUnit to Router
	wire signed [(DATA_WIDTH-1):0] ToRouterExWeightSum;
	wire signed [(DATA_WIDTH-1):0] ToRouterInWeightSum;

	//From Theta RAM to NeuronUnit
	wire [(DATA_WIDTH-1):0] ThetaData;

	//From Neuron Unit to Theta RAM
	wire ThetaChipEnable;
	wire [(NEURON_WIDTH-1):0] ThetaAddress;
	
	//Outputs to INternal Router
	wire [(2**NEURON_WIDTH-1):0] SpikeBufferOut;

	//Queue Inputs 
	reg [(NEURON_WIDTH -1):0] NeuronID = 784;

	//Inputs from Synaptic RAM
	wire [(DATA_WIDTH-1):0] WeightData;

	//Outputs to Synaptic RAM
	wire WChipEnable;								
	wire WWriteEnable;									
	wire [(ADDR_WIDTH-1):0] WRAMAddress;

	
	
	

	integer i,j;
	localparam k = 16;
	integer outFile1, outFile2, outFile3;

	
	reg [(NEURON_WIDTH_LOGICAL-1):0] IDNID;
	reg IDValid;
	reg IDNtype;
	reg signed [(DATA_WIDTH-1):0] IDVmem;
	reg signed [(DATA_WIDTH-1):0] IDGex;
	reg signed [(DATA_WIDTH-1):0] IDGin;	
	reg [(TREF_WIDTH+3-1):0] IDRefVal;
	reg signed [(DATA_WIDTH-1):0] IDExWeight;
	reg signed [(DATA_WIDTH-1):0] IDInWeight;
	reg signed [(DATA_WIDTH-1):0] IDVth;
	

	initial begin 
	
		outFile1 = $fopen("ExDendriticDump.mem","w");
		outFile2 = $fopen("IntegTestVmemDump_EXNeurons.mem","w");
		outFile3 = $fopen("IntegTestVmemDump_INNeurons.mem","w");

		
		Clock = 0;
		Reset = 1;
		UpdateEnable = 0;
		RouteEnable = 0;
		Initialize = 0;
		MapNeurons = 0;

		
		//Initialize 
		#15 
		Reset = 0;
		Initialize = 1;
		MapNeurons = 1;


		#9000;
		if(Initialize == 0) RouteEnable = 1;
		
		

			
				
		

	end


	always begin 
		#5 Clock = ~ Clock;
	end

	always @(posedge RoutingComplete) begin 

		RouteEnable = 0;
		$display("Routing Done");
		#50;//HIATUS : Compulsory	

		for (i=0; i<2**TDMPOWER; i = i+1) begin
			IDExWeight = NU1.genblk3[k].SPNR_x.OnChipRam[i][(3*DATA_WIDTH-1):2*DATA_WIDTH];
			$fwrite(outFile1,"%f \n", $itor(IDExWeight)*sf);
		end

		UpdateEnable = 1;		

	end

	always @(posedge UpdateComplete) begin 

		UpdateEnable = 0;
		$display("Update Done");
		#50 															//HIATUS : Optional
		$fclose(outFile1);
		$fclose(outFile2);
		$fclose(outFile2);
		$finish;
	

	end

	always @(posedge MappingComplete) begin 
	
		MapNeurons = 0;
		Initialize = 0;

	end
 
		



	//NEURON UNIT 
	NeuronUnit #(INTEGER_WIDTH, DATA_WIDTH_FRAC, DATA_WIDTH, DELTAT_WIDTH, TREF_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH_PHYSICAL, NEURON_WIDTH, TDMPOWER, NEU_DATA_WIDTH, NEU_ADDR_WIDTH, EXTEND_WIDTH) NU1
	(
		//Control Signals
		.Clock(Clock),
		.Reset(Reset),
		.UpdateEnable(UpdateEnable),
		.RouteEnable(RouteEnable),
		.Initialize(Initialize),
		.MapNeurons(MapNeurons),


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

	
		//Network Information
		.ExRangeLOWER(ExRangeLOWER),			
		.ExRangeUPPER(ExRangeUPPER),			
		.InRangeLOWER(InRangeLOWER),					
		.InRangeUPPER(InRangeUPPER),			
		.IPRangeLOWER(IPRangeLOWER),			
		.IPRangeUPPER(IPRangeUPPER),			
		.NeuStart(NeuStart),			
		.NeuEnd(NeuEnd),

	
		//Global Inputs
		.DeltaT(DeltaT),


		//Inputs from Router 
		.FromRouterEXChipEnable(FromRouterEXChipEnable),
		.FromRouterINChipEnable(FromRouterINChipEnable),
		.FromRouterEXWriteEnable(FromRouterEXWriteEnable),
		.FromRouterINWriteEnable(FromRouterINWriteEnable),
		.FromRouterEXAddress(FromRouterEXAddress),
		.FromRouterINAddress(FromRouterINAddress),
		.FromRouterNewExWeightSum(FromRouterNewExWeightSum),					
		.FromRouterNewInWeightSum(FromRouterNewInWeightSum),

		//Inputs from Theta RAM
		.ThetaData(ThetaData),

	
		//Outputs to Router 
		.ToRouterExWeightSum(ToRouterExWeightSum),
		.ToRouterInWeightSum(ToRouterInWeightSum),

		
		//Outputs to Theta RAM
		.ThetaChipEnable(ThetaChipEnable),
		.ThetaAddress(ThetaAddress),
		
		

		//Outputs to Spike Route
		.SpikeBufferOut(SpikeBufferOut),

		//Control Outputs
		.MappingComplete(MappingComplete),	
		.UpdateComplete(UpdateComplete)
		);



	InputRouter #(DATA_WIDTH, NEURON_WIDTH_LOGICAL, NEURON_WIDTH, NEURON_WIDTH_INPUT, NEURON_WIDTH_MAX_LAYER, ROW_WIDTH, COLUMN_WIDTH, ADDR_WIDTH, INPUT_NEURON_START, LOGICAL_NEURON_START) IR1
	(
		//Control Inputs
		.Clock(Clock),
		.Reset(Reset),
		.RouteEnable(RouteEnable),
		.Initialize(Initialize),

		//Network Information: Neuron Ranges
		.ExRangeLOWER(ExRangeLOWER),
		.ExRangeUPPER(ExRangeUPPER),
		.InRangeLOWER(InRangeLOWER),
		.InRangeUPPER(InRangeUPPER),
		.IPRangeLOWER(IPRangeLOWER),
		.IPRangeUPPER(IPRangeUPPER),
		.NeuStart(NeuStart),
		.NeuEnd(NeuEnd),

		//Queue Inputs
		.NeuronID(NeuronID),

		//Inputs from Synaptic RAM
		.WeightData(WeightData),

		//Outputs to Synaptic RAM
		.WChipEnable(WChipEnable),
		.WWriteEnable(WWriteEnable),
		.WRAMAddress(WRAMAddress),

		//Inputs from Dendritic RAM (via Neuron Unit)
		.ExWeightSum(ToRouterExWeightSum),
		.InWeightSum(ToRouterInWeightSum),

		//Outputs to Dendritic RAM (via Neuron Unit)
		.EXChipEnable(FromRouterEXChipEnable),
		.INChipEnable(FromRouterINChipEnable),
		.EXWriteEnable(FromRouterEXWriteEnable),
		.INWriteEnable(FromRouterINWriteEnable),
		.EXAddress(FromRouterEXAddress),
		.INAddress(FromRouterINAddress),
		.NewExWeightSum(FromRouterNewExWeightSum),
		.NewInWeightSum(FromRouterNewInWeightSum),

		//Control Outputs
		.RoutingComplete(RoutingComplete)


	);


	SinglePortOnChipRAM #(DATA_WIDTH,ADDR_WIDTH,WEIGHTFILE) WRAM
	(
	
		.Clock(Clock),
		.Reset(Reset),
		.ChipEnable(WChipEnable),
		.WriteEnable(WWriteEnable),

		.InputData(44'd0),
		.InputAddress(WRAMAddress),
	
		.OutputData(WeightData)
	
	);


	SinglePortOnChipRAM #(DATA_WIDTH, NEURON_WIDTH_LOGICAL, THETAFILE) ThetaRAM
	(
		//Control Signals
		.Clock(Clock),
		.Reset(Reset),
		.ChipEnable(ThetaChipEnable),
		.WriteEnable(1'b0),

		//Inputs from NeuronUnit
		.InputData(44'd0),
		.InputAddress(ThetaAddress),
		
		//Outputs to NeuronUnit
		.OutputData(ThetaData)
	);


			

endmodule
