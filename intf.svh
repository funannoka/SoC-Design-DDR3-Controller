
//interface to connect memory and controller

interface intf;
   //`include "sg187.v"
  // `include "1024Mb_ddr3_parameters.vh"
   `include "sg093.v"
 //  `include "defs.svh"
   logic                		rst_n;
   logic                		ck;
   logic                		ck_n;
   logic                		cke;
   logic                		cs_n;
   logic                		ras_n;
   logic                		cas_n;
   logic                		we_n;
   logic		[BA_BITS-1:0] 	ba;
   logic    [ADDR_BITS-1:0] addr;
   logic       							odt;
   logic    [DM_BITS-1:0]		dm;
   logic    [DQ_BITS-1:0] 	dq; //data from controller to memory
   logic    [DQS_BITS-1:0] 	dqs; //data control signal: dq will be written or read at dqs edge
   logic    [DQS_BITS-1:0] 	dqs_n;
   logic    [DQ_BITS-1:0] 	dq0; //data from memory to controller
   logic   	[DQS_BITS-1:0] 	dqs0; //dq0 control signal 
   logic   	[DQS_BITS-1:0] 	dqs0_n;  
   logic    [DQS_BITS-1:0]	tdqs_n;
   integer                  tzqcs;
   integer                  tzqinit;
   integer                  tzqoper;


modport cntrl(
   output	rst_n,
   input	ck,
   output ck_n,
   output cke,
   output cs_n,
   output ras_n,
   output	cas_n,
   output we_n,
   output ba,
   output addr,
   output odt,
   output dm,
   output dq, 
   output dqs,   
   output dqs_n,  
   input  dq0, 
   input  dqs0,  
   input  dqs0_n,  
   input  tdqs_n,
   input  tzqcs,
   input  tzqinit,
   input  tzqoper
);

modport mem(
    input   rst_n,
    input   ck,
    input   ck_n,
    input   cke,
    input   cs_n,
    input   ras_n,
    input   cas_n,
    input   we_n,
    input   dm, 
    input   ba,
    input   addr,
    input   odt,
    input   dq, 
    input   dqs,  
    input   dqs_n, 
    output  dq0, 
    output  dqs0, 
    output  dqs0_n,  
    output  tdqs_n,
    output  tzqcs,
    output  tzqinit,
    output  tzqoper
   );//

 
endinterface


interface iftb;
//`include "defs.svh"
 //  `include "sg187.v"
// `include "st_defs.svh"
 // `include "1024Mb_ddr3_parameters.vh" 
  `include "sg093.v"
  /*THIS IS THE INTERFACE BETWEEN TESTBENCH AND CONTROLLER*/ 
	reg [BA_BITS-1:0]  ba;
  reg [COL_BITS-1:0] col;
  reg [ROW_BITS-1:0] row;
  reg [ADDR_BITS-1:0] addr;
	logic [4:0] prev_cmd;
	logic [4:0] cmd;
	logic [1:0] wr_cmd; //
	logic [1:0] rd_cmd;
  parameter ap_on = 1'b1;  //enable autoprecharge
  parameter ap_off = 1'b0; //disable auto precharge
  parameter bc_on = 1'b1; 
  parameter bc_off = 1'b0; 
  reg [31:0] t,rlen;     //t = desired time for nop //rlen desired number of incremental busrts for wrapping
  logic cmd_en;
  reg [8*DM_BITS-1:0] dm;  //data mask must be kept low except dq data is to be ignored by mem
  reg [8*DQ_BITS-1:0] dq; //data from testbench to controller which will be sent to 
  logic ap;											//mem by controller.
  logic clk,rst;
  int next_state;											
	//enum integer {wr_mrs,wr_bc4,wr_bl8}write_cmd; //choose between burst length 8(fixed mode),burst lenght 4(chop mode)or set in mr0
	//enum integer {rd_mrs,rd_bc4,rd_bl8}read_cmd;//choose between burst lenght 8(fixed mode),burst lenght 4(chop mode)or set in mr0
	//enum integer {pwr_up,desel,nops,reset,zqcs,zqcl,act,rd,wr,r_ap,w_ap,rd_wrap,rd_ap_wrap,pre,prea,refr,sre,srx,mrs,pde,pdx,mpr}ddr3_cmd;
	//ddr3_cmd prev_cmd;
	//ddr3_cmd cmd;
	//write_cmd wr_cmd;
	//read_cmd rd_cmd;
	 // modport tb(input ba,input col, input dq, input dm,input row,input addr,input t,input rlen,input cmd,input prev_cmd,input rd_cmd,input wr_cmd,output cmd_en);
  modport cntrl(input ba,input col, input clk, input rst,input dq, input dm,input row,input addr,
  input t,input rlen,input cmd,input prev_cmd,input rd_cmd,input wr_cmd,input ap,output cmd_en,input next_state);
endinterface

interface AHBIF;
    logic mHBUSREQ,mHGRANT,HREADY,mHREADY;
    logic [1:0] HRESP,mHRESP;
    logic HRESET;
    logic HCLK;
    logic [31:0] HRDATA,mHRDATA;
    logic [31:0] HWDATA,mHWDATA;
    logic HLOCK;        // Not used
    logic [1:0] HTRANS,mHTRANS;
    logic [31:0] HADDR,mHADDR;
    logic HWRITE,mHWRITE;
    logic [2:0] HSIZE,mHSIZE;
    logic [2:0] HBURST,mHBURST;
    logic [3:0] HPROT;  // Not used
    logic HSEL;         // slave select
    logic [3:0] HMASTER; // Not used
    logic HMASTLOCK;    // not used


    
    clocking cb @(posedge(HCLK));
       
    endclocking : cb

    modport AHBM( input mHGRANT, output mHBUSREQ, 
        input mHREADY,input mHRESP,
        input mHRDATA,output mHTRANS, output mHADDR,
        output mHWRITE, output mHSIZE, output mHBURST);
    
    modport AHBS( input HSEL, input HADDR,
        input HWRITE, input HTRANS,
        input HSIZE, input HBURST, input HWDATA, 
        output HREADY,
        output HRESP, output HRDATA);
        
        
    modport AHBCLKS( input HCLK, input HRESET);
    
        
endinterface : AHBIF

