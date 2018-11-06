  //  `include "1024Mb_ddr3_parameters.svh"

// `include "sg187.v"
/*`include "defs.svh"
`ifdef den1024Mb
    `include "1024Mb_ddr3_parameters.vh"
`elsif den2048Mb
    `include "2048Mb_ddr3_parameters.vh"
`elsif den4096Mb
    `include "4096Mb_ddr3_parameters.vh"
`elsif den8192Mb
    `include "8192Mb_ddr3_parameters.vh"
`else
    // NOTE: Intentionally cause a compile fail here to force the users
    //       to select the correct component density before continuing
    ERROR: You must specify component density with +define+den____Mb.
`endif*/

`timescale 1ps / 1ps
//`include "intf.svh"
//`include "st_defs.svh"

module top();
`include "st_defs.svh"
`include "defs.svh"
 //`include "sg187.v"
//int  next_state;	
intf infx();
iftb  itb();
ddr3 mem(infx.mem);
ddr3_controller ctrl(infx.cntrl,itb.cntrl); //,next_state

 integer                   i, j;
reg [8*DQ_BITS-1:0] d0, d1, d2, d3;
parameter [31:0] DAT = DQ_BITS/8.0;
reg clock;


 

//generate clock
initial begin
$display($time,"\tStarting the simulation");
  clock = 1'b0;
  #400;
  infx.ck <=1'b1;
  itb.clk <= 1'b1;
  forever #400 clock = ~clock; 
end

initial begin
 forever  @(posedge itb.clk)begin
 itb.clk <= #(1/2) 1'b0;
 itb.clk <= #1 1'b1;
 end
end
initial begin
  forever @(posedge infx.ck) begin //ddr3 clock at tck_min = 938ps
    infx.ck <= #(tck/2) 1'b0;
    infx.ck <= #(tck) 1'b1;
  end
end

initial begin
   
   //Power Up
    itb.cmd = pwr_up;
    itb.next_state = activating;
    $display($time,"\ttb: Power Up Command Asserted");


    //Bank Activate
    @(posedge itb.cmd_en); 
    itb.cmd = act;
    itb.next_state = prec; 
    itb.t = int'(TRAS_MIN/tck) + 1;  //activate to precharge command time
    itb.ba = 3;//$urandom_range (8);
		itb.row = $urandom_range (1<<ROW_BITS);
		itb.col = $urandom_range (1<<COL_BITS);
	//	$display($time,"\ttb: Bank Activate Command Asserted.");
 
//Precharge bank
	@(posedge itb.cmd_en);
    itb.cmd = pre;
    itb.next_state = refrs; 
  //  $display($time,"\ttb: Precharge-all-banks Command Asserted.");
		itb.t = int'(TRP/tck)+1;


  @(posedge itb.cmd_en);
    itb.cmd = refr;
    itb.next_state = activating; 
  //   $display($time,"\ttb: Self Refresh Entry Command Asserted.");
   

 //Bank Activate
    @(posedge itb.cmd_en); 
    itb.cmd = act;
    // @(posedge itb.cmd_en);
     itb.next_state = write; 
    itb.t = int'(TRCD/tck) + 1;  //activate to read command time
    itb.ba = 4;//$urandom_range (8);
		itb.row = $urandom_range (1<<ROW_BITS);
		itb.col = $urandom_range (1<<COL_BITS);

         
   //Write  without precharge, burst fixed to 8bl in MRS mode//
   	//requires 4 inputs from test bench, {bank,col,dm,dq}	
    @(posedge itb.cmd_en);
    itb.next_state = read; 
    itb.cmd = wr;
    itb.wr_cmd = wr_mrs;
    itb.ap = ap_off;
    itb.t = wl + int'(bl/2) + TWTR_TCK; //write to read command delay
    itb.rlen = 8;
		itb.dm = 1'b0;
		itb.dq = {$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom,$urandom};
  //  $display($time,"\ttb: Write Command Asserted.");
 	//	$display($time,"\ttb: Write:bank = %d,column = %h,row = %h dm = %d, dq = %d",itb.ba,itb.col,itb.row,itb.dm,itb.dq);
		

    //Read  without precharge, burst fixed to 8bl in MRS mode
        @(posedge itb.cmd_en); 
    itb.cmd = rd;
    itb.wr_cmd = wr_mrs;
    itb.next_state = prec; 
    itb.ap = ap_off;
   itb.t = rl + bl/2;// +TRTP_TCK; 
   
  //  $display($time,"\ttb: Read Command Asserted.");
	
    
	//Precharge bank
	@(posedge itb.cmd_en);
    itb.cmd = pre;
    itb.next_state = sref; 
   //  $display($time,"\ttb: Precharge-all-banks Command Asserted.");
    // @(posedge itb.cmd_en);
		itb.t = int'(TRP/tck);
	
		
		//Self refresh entry and exit
	@(posedge itb.cmd_en);
    itb.cmd = sre;
    itb.t = int'(TRFC_MIN/tck)+1;
    itb.next_state = srfx; 
  //   $display($time,"\ttb: Self Refresh Entry Command Asserted.");
    //repeat (7) @(posedge clock);
     @(posedge itb.cmd_en);
		itb.cmd = srx;
	//	$display($time,"\ttb: Self Refresh Exit Command Asserted");
		@(posedge itb.cmd_en);
$finish;
end

//initial begin
//    $dumpfile ("ddr3_controller.vcd");
//    $dumpvars (0, top);
//end
endmodule :top



