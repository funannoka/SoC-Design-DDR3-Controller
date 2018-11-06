// `include "sg187.v"
  `include "sg093.v"
  //`include "intf.svh"
//controller states /configuration params 
//controller states

 //parameter des = 1,	//deselect
 //nop = 2;	//no operation
 
enum integer{zero,nop =1,des}nop_des;
 
parameter         ap_on = 1; 
parameter         ap_off = 0;
parameter 	  bc_on = 1; 
parameter 	bc_off = 0; 
parameter         on = 1; 
parameter         off = 0; 

//timing params
parameter tck = TCK_MIN; //should be real and add one is real > integer
parameter tXPR = int'(TXPR/tck) + 1;
parameter half_tck = int'(tck/2);//tck >>1;
parameter quarter_tck = int'(tck/4)+1;//tck >>2;
//reg [15:0] wl_tck = wl*tck;

parameter pwr_up=0,desel=1,nops=2,reset=3,zqcs=4,zqcl=5,act=6,rd=7,wr=8,r_ap=9,w_ap=10,
rd_wrap=11,wr_wrap=12,rd_ap_wrap=13,wr_ap_wrap=14,pre=15,prea=16,refr=17,sre=18,srx=19,mrs=20,pde=21,pdx=22,mpr=23;

parameter wr_mrs = 0,wr_bc4 = 0,wr_bl8 = 1;
parameter rd_mrs = 0,rd_bc4 = 0,rd_bl8 = 1;

//typedef enum integer {pwr_up,desel,nops,reset,zqcs,zqcl,act,rd,wr,r_ap,w_ap,rd_wrap,wr_wrap,rd_ap_wrap,wr_ap_wrap,pre,prea,refr,sre,srx,mrs,pde,pdx,mpr}ddr3_cmd;

typedef enum integer {t_1,t_2,t_3,t_4,t_5,t_6,t_7,t_8,t_0}time_st; 
 //typedef enum integer {wr_mrs,wr_bc4,wr_bl8}write_cmd;
//typedef enum integer {rd_mrs,rd_bc4,rd_bl8}read_cmd;
 
 
 // mode registers
    reg         [ADDR_BITS-1:0] mode_reg0;                                 //Mode Register
    reg         [ADDR_BITS-1:0] mode_reg1;                                 //Extended Mode Register
    reg         [ADDR_BITS-1:0] mode_reg2;                                 //Extended Mode Register 2
    wire                  [3:0] cl       = {mode_reg0[2], mode_reg0[6:4]} + 4;              //CAS Latency
    wire                        bo       = mode_reg0[3];                    //Burst Order
    reg                   [3:0] bl;                                         //Burst Length
    wire                  [3:0] cwl      = mode_reg2[5:3] + 5;              //CAS Write Latency
    wire                  [3:0] al       = (mode_reg1[4:3] == 2'b00) ? 4'h0 : cl - mode_reg1[4:3]; //Additive Latency
    wire                  [4:0] rl       = cl + al;                         //Read Latency
    wire                  [4:0] wl       = cwl + al;                        //Write Latency

    // dq receive
    reg           [DM_BITS-1:0] dm_fifo [4*CL_MAX+BL_MAX+2:0];
    reg           [DQ_BITS-1:0] dq_fifo [4*CL_MAX+BL_MAX+2:0];
    wire                        [8*DQ_BITS-1:0] dq_in; //from tb
    wire                        [8*DM_BITS-1:0] dm_in; //from tb
    wire          [DQ_BITS-1:0] q0, q1, q2, q3;
    reg                         ptr_rst_n;
    reg                   [1:0] burst_cntr;
    // odt
    reg                         odt_out;
    reg     [(AL_MAX+CL_MAX):0] odt_fifo;
    


// assign cl       = {mode_reg0[2], mode_reg0[6:4]} + 4;              //CAS Latency = 8 
// assign bo       = mode_reg0[3];                    //Burst Order = 1 (interleved)
// assign cwl      = mode_reg2[5:3] + 5;              //CAS Write Latency = 6
// assign al       = (mode_reg1[4:3] == 2'b00) ? 4'h0 : cl - mode_reg1[4:3]; //Additive Latency = 7 //changed case equality from triple
// assign rl       = cl + al;                         //Read Latency =15
// assign wl       = cwl + al;                        //Write Latency = 13 //22
// assign wl_tck = wl*tck;                            //24375


