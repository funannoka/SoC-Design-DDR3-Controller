`timescale 1ps/1ps

 `include "intf.svh"
module ddr3_controller ( intf.cntrl ix,iftb.cntrl ixtb);
`include "defs.svh"
`include "st_defs.svh"
/*`ifdef den1024Mb
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


//Intermediate Registers
    wire  ck;
    reg   rst_n;
    reg   cke;
    reg   cs_n;
    reg   ras_n;
    reg   cas_n;
    reg   we_n;
    reg   [BA_BITS-1:0]   ba;
    reg   [ADDR_BITS-1:0] addr;
    wire  [BA_BITS-1:0]   ba_in;
    logic active_banks[BA_BITS-1:0];
    reg   [BA_BITS-1:0] prev_bank;
    wire  [ADDR_BITS-1:0] addr_in;
    wire  [DQ_BITS-1:0] 	dq; 
    wire  [DQS_BITS-1:0]  tdqs_n;
    wire	[COL_BITS-1:0] col;
    wire  [COL_BITS-1:0] row;
    reg  [COL_BITS-1:0] prev_row;
    reg   [ADDR_BITS-1:0] a [BA_BITS-1:0];
    reg  	[COL_BITS-1:0] col_incr;
    reg  	[COL_BITS-1:0] col_start;
    
//state assignment regs/command regs
    reg [31:0] cnt,counter,wcnt,index;
    reg cnt_en,c_en,init_phase;
    reg [31:0] bcnt;
    integer    lock;
    reg cmd_en = 1'b1;
    integer done ;
    reg [4:0] cmd,prev_cmd; //enum for ddr3 commands
    reg [3:0] rd_cmd; //enum for read options
    reg [3:0] wr_cmd; //write options
		integer             ap; //Auto Precharge
		integer             bc; //Burst Chop  
		integer							rlen;
		integer i;
		reg pwr_on;
		integer en = 0;
		reg pl = 1'b1;
		reg [31:0] cnt_p;
		reg cnt_p_en,nlock,tlock,nop_run;
		int nxt_state;
		//reg st_en;
		time_st st_tm;
		//state 
		int st,prev_state,next_state;

    
    
 // dq transmit
    reg                         dq_en;
    reg           [DM_BITS-1:0] dm_out;
    reg           [DQ_BITS-1:0] dq_out;
    reg                         dqs_en;
    reg          [DQS_BITS-1:0] dqs_out;



//To and from memory<-->controller interface
/*THIS IS ASSIGNED IN CONTROLLER*/
assign        ix.rst_n = rst_n;
assign        ck = ix.ck;
assign        ix.ck_n = ~ix.ck;
assign        ix.cke = cke;
assign        ix.cs_n = cs_n;
assign        ix.ras_n = ras_n;
assign        ix.cas_n = cas_n;
assign       dq = ix.dq0;
assign        ix.we_n = we_n;
assign  ix.dm = dq_en ? dm_out :{DM_BITS{1'bz}};
assign        ix.ba = ba;
assign        ix.addr = addr;
assign  ix.dq = dq_en ? dq_out : {DQ_BITS{1'bz}}; //data is sent to memory using dq_out
assign  ix.dqs = dqs_en ? dqs_out : {DQS_BITS{1'bz}};
assign  ix.dqs_n = dqs_en ? ~dqs_out : {DQS_BITS{1'bz}};
assign  ix.odt = odt_out & !odt_fifo[0];


//from and to testbench<-->controller interface
assign  dq_in = ixtb.dq; //dq passed to controller from testbench using dq_in
assign  dm_in = ixtb.dm;
assign  ba_in = ixtb.ba;
assign  addr_in = ixtb.addr;
assign  row =  ixtb.row;
assign  col = ixtb.col;
assign  ixtb.cmd_en = cmd_en; //to test bench
assign  cmd = ixtb.cmd ;
assign rd_cmd = ixtb.rd_cmd;
assign bc = ixtb.wr_cmd;
assign ap = ixtb.ap;
assign wr_cmd = ixtb.wr_cmd;
assign rlen = ixtb.rlen;
assign nxt_state = ixtb.next_state;
//assign odt_fifo = !ix.ck ? odt_fifo>>1:odt_fifo;
//initial begin

// $monitor($time,"\tcntrl:command == %d",cmd);

//end
 
reg [31:0] nop_cnt;
reg nop_cnt_en;
logic [31:0] rw_cnt;
logic rw_cnt_en;
integer npt; 

//always @ (ix.ck) begin
//if (!ix.ck) 
//odt_fifo <= odt_fifo>>1;
//end

always @(negedge ix.ck)begin//* //slower clock with period = tck_min (ddr3 clock)
	if (nop_cnt_en) nop_cnt <= nop_cnt +1;
	else begin
	//$display($time,"\tcntrl: counter = %d",counter);
	nop_cnt <= 1'b0;
	end
end

always @(negedge ixtb.clk)begin//* 
	if (rw_cnt_en) rw_cnt <= rw_cnt +1;
	else begin
	//$display($time,"\tcntrl: counter = %d",counter);
	rw_cnt <= 1'b0;
	end
end



always @(negedge ix.ck or negedge ixtb.rst) begin 


if (ixtb.rst==0)
begin
	ba<=000;
	addr<=0;
	rst_n<=0;
	//ck=0;
	cke <= 0;
	cs_n<=0;
	ras_n<=0;
	cas_n<=0;
	we_n<=0;
	counter <= 0;	
	cnt <= 0;
	prev_state <= st;
	dq_en   <=  1'b0;
  dqs_en  <=  1'b0;
	odt_fifo <= 1'b0;
  init_phase <= 1'b0; 
  nlock <= 1'b0;
  tlock <= 1'b0;
  nop_run <= 0;
  en <= 1'b1;
	st <= initialize;
end
else
begin
//if(pwr_on) begin
if(cmd == pwr_up && pl == 1)begin
st <= power_up;  
en <= 1'b1;
cmd_en <= 1'b0;
pl <= 1'b0;
end else begin
odt_fifo <= odt_fifo>>1;

    case (st)
    power_up: begin
    						if (en)begin
                cmd_en <= 1'b0;
                done <= 1'b0;
                lock <= 1'b1;
                c_en <= 1'b0;
                nop_cnt_en <= 1'b0;
                $display($time,"\tcntrl: NOW IN POWER UP STATE");
               rst_n   <=  1'b0; //cross check this
              cke     <=  1'b0;
              ras_n   <=  1'b1;
        			cas_n   <=  1'b1;
       				we_n    <=  1'b1;
              odt_out <= 1'b0;
              ba      <=  {BA_BITS{1'bz}};
              addr    <=  {ADDR_BITS{1'bz}};
              dq_en   <=  1'b0;
              dqs_en  <=  1'b0;
              odt_fifo <= 1'b0;
              init_phase <= 1'b1; 
              nlock <= 1'b0;
              tlock <= 1'b0;
              counter <= 1'b0;
              nop_run <= 1'b0;
              prev_state <= st;
              st_tm <= t_0;
              en <= 1'b0;
              end
							if (cnt < 20000) begin 
								cnt <= cnt +1;//RESET# must be LOW for at least 200μs #200000000 to begin the initialization process.
              end else begin
                st <= initialize;
                cnt <= 1'b0;
                $display($time,"\tcntrl: POWER UP SUCCESSFUL!");
             end
            	end
initialize: begin
         //BEGIN INITIALIZATION 
             
         if((prev_state != power_up)&&(!nop_run))begin// RESET needs to be maintianed for 100ns when doing reset with no power interruption
         	if (cnt < int'(100000/tck)+1)begin
          	cnt <= cnt +1; 
        	end else begin
          cnt <= 1'b0;
					cke    <= 1'b0;
					st_tm <= t_0;
					lock <= 1'b1;
				  prev_state <= power_up;
          end
         end else begin 
           case (st_tm)
            t_0:begin
              cke     <=  1'b0;
              odt_out <= 1'b0;
            			cmd_en <= 1'b0;
            			rst_n   <= 1'b0;
                	cs_n   <= 1'b1;
                	en <= 1'b1;
                	if (cnt <= int'(10000/tck)+1) cnt <= cnt +1; // CKE must be LOW 10ns prior to RESET# transitioning HIGH.
                  else begin
                	st_tm <= t_1;
                	cnt <= 1'b0;
                	end
                end
           t_1:begin //RESET transitions high
                  cke    <= 1'b0;
                  rst_n   <= 1'b1;
                  if (cnt <= int'(10000/tck)+1) cnt <= cnt +1; // CKE must be LOW 10ns prior to RESET# transitioning HIGH.
                  else begin
                  cnt <= 1'b0;
                 st_tm <= t_2;
                  end
                 end 
            t_2:begin//trigger nop
                 	 next_state <= zq_calibr_long; //so nop goes to zq_calib next
                 	nop_run <= 1;
                  npt <= int'(TXPR/tck) + 1;
                  nop_des <= nop;
                  st <= deno;
                  done <= 1'b0;
                  init_phase <= 1'b1;
                 end
                 endcase
                 end
               end
init_mrs: begin  
                    	
                        case (st_tm)
                        t_0:begin
                             //LOAD MR2  
                               cs_n  <= 1'b0; 
                               ras_n <= 1'b0;
                               cas_n <= 1'b0; 
                               we_n  <= 1'b0;
                               ba <= 3'd2;
                               addr <= 14'b0001000_101_000;////cas write latency[5:3]001 = 6ck, dynamic odt[9:10] = RZQ/4
                               mode_reg2 <= 14'b0001000_101_000; //14'b0001000_001_000;
                               st_tm <= t_1;
                                next_state <= st;
                           	     npt <= TMRD;
                          	     nop_des <= nop;
                                 st <= deno;
                                 st_tm <= t_1;
                                 done <= 1'b0;
                                 cnt <= 1'b0;
                               en <= 1'b1;
                            end
                    t_1:begin //MR3
                               cs_n  <= 1'b0; 
                               ras_n <= 1'b0;
                               cas_n <= 1'b0; 
                               we_n  <= 1'b0; 
                               ba <= 3'd3;
                            	 addr <= 14'b00000000000000;
                            	  next_state <= st;
                           	          npt <= TMRD-1;
                          	          nop_des <= nop;
                          	          st_tm <= t_2;
                                      st <= deno;
                                      done <= 1'b0;
                                      cnt <= 1'b0;
                            	 en <= 1'b1;
                        end
                              
                t_2:begin
                        //MR1
                               cs_n  <= 1'b0;
                               ras_n <= 1'b0;
                               cas_n <= 1'b0; 
                               we_n  <= 1'b0; 
                                ba <= 1'd1;
                            addr <=  14'b0000_0_00_0_0_10_1_1_0; //DLL Enabled[0], RTT[2][6][9] = RZQ/4, output drive strength[1][5] =RZQ/7,AL(Additive Latency)[3:4] = CL -2
                            mode_reg1 <= 14'b0000_0_00_0_0_10_1_1_0;
                            next_state <= st;
                           	npt <= TMRD-1;
                          	nop_des <= nop;
                            st <= deno;
                            st_tm <= t_3;
                            done <= 1'b0;
                            cnt <= 1'b0;
                            en <= 1'b1;
                             end 
                             
                t_3:begin    //MR0
                               cs_n  <= 1'b0; 
                               ras_n <= 1'b0;
                               cas_n <= 1'b0; 
                               we_n  <= 1'b0; 
                               ba    <= 1'd0;
                            //addr = 14'b00100_1_0_100_1_0_00; //burst fixed[0:1],DLL Reset[8], cl[2][4:6] = 8, burst type[3] = interleaved, write_recovery[9:11] = 8
                            addr <= 14'b00000_1_0_010_1_1_10;  //cl = 10
                            mode_reg0 <= 14'b00000_1_0_010_1_1_10; 
                            en <= 1'b1;
                            next_state <= st;
                           npt <= (ix.tzqinit > TDLLK)? ix.tzqinit:TDLLK;
                         	 nop_des <= nop;
                           st <= deno;
                           st_tm <= t_4;
                           done <= 1'b0;
                           cnt <= 1'b0;
                       end 
            t_4:begin			//turn on odt
                          
                              // turn on odt
                            if (cnt < 10)begin
                            cke <= 1;
                            odt_out  <= 1'b1;  
                            cnt <= cnt + 1;
                            cs_n <= 1'b0;
                						ras_n <= 1'b1;
                						cas_n <= 1'b1;
                						we_n <= 1'b1;
                            end else begin 
                            st <= idle;
                            en <= 1'b1;
                            cnt <= 32'b0;
                            st_tm <= t_1;
                            done <= 1'b0;
                            init_phase <= 0;
                            cmd_en <= 1;
                            end
                       end
        					endcase 
        end
                
           
zq_calibr_long: begin  
              done <= 1'b0;
              cmd_en <= 1'b0;
              cke <= 1'b1;
              cs_n <= 1'b0;
              ras_n <= 1'b1;
              cas_n <= 1'b1;
              we_n <= 1'b0;
              ba  <=  {BA_BITS{1'b0}};
              addr <= 1<<10;
          if(init_phase)begin
              st <= init_mrs;
               // init_phase <= 1'b0;
              cnt <= 1'b0;
              en <= 1'b1;
              st_tm <= t_0; 
            end else begin
                st <= idle;
                cnt <= 1'b0;
                en <= 1'b1;
                end 
       				 end
           
zq_calibr_short:begin         
    							
             				 cnt <= cnt + 1;   
             				 en <= 1'b0;      
             				 cmd_en <= 1'b0;
             				 cke <= 1'b1;
              			 cs_n <= 1'b0;
                     ras_n <= 1'b1;
                     cas_n <= 1'b1;
                     we_n <= 1'b0;
                     ba  <=  {BA_BITS{1'b0}};
                     addr <= 0<<10;
                      if (cnt<(ix.tzqcs+tck+TIH)) cnt <= cnt + 1;
               				else begin  
                        st <= idle;
                        cnt <= 1'b0;
                        en <= 1'b1;
                      end
                end
    idle:begin
                					
														 	en <=1;
                              case(cmd)
                              reset:begin
                                		cmd_en <= 1'b0;
                 										counter <= 1'b0;
                        				  	st <= initialize;
                        				  	done <= 1'b0;

                        				    end
                                act:begin
                                    st <= activating; //bank activate
                                    ba <= ba_in;
                										addr <= row;
													          counter <= 1'b0;
                 				            done <= 1'b0;
                 				            cmd_en <= 0;
                                    end
                               refr:begin
                                    st<= refrs;    //refresh
                 				            counter <= 1'b0;
                 				            done <= 1'b0;
                                    end
                                sre:begin
                                    st <= sref;    //self refresh entry
                 				            counter <= 1'b0;
                 				            done <= 1'b0;
																		st_tm <= t_1;
																		odt_out <= 1'b0;
                                    end
                                 srx:begin
                                 		counter <= 1'b0;
                 				            done <= 1'b0;
                                 		st <= srfx;    //self refresh exit

                                 		end
                                mrs:begin
                                     st <= mode_reg_set;    //mode register set
                 				             counter <= 1'b0;
                 				             done <= 1'b0;

                                     end
                                pde:begin
                                    st <= pwd_e;    //precharge power-down entry
                 				            counter <= 1'b0;
                 				            done <= 1'b0;
																		odt_out <= 1'b0;
                                    end
                             				//pdx:st = pwd_x;    //precharge power-down exit
                            				//mpr:st = mp_reg; //multiplurpose register
                               zqcs:begin
                                    st <= zq_calibr_short;//zq_calibration short
                 				            counter <= 1'b0;
                 				            done <= 1'b0;
                                    end
                                zqcl:begin
                                    st <= zq_calibr_long;//zq_calibration long
                 				            counter <= 1'b0;
                 				            done <= 1'b0;
                                    end
                                    //nops is passed desired timing parameters from testbench
                                nops:begin
                                    next_state <= st;
                                    nop_des <= nop;
                                    npt <= ixtb.t;
                        						st <= deno;
                                    cnt <= 1'b0;
                 				           	counter <= 1'b0;
                                    done <= 1'b0;
                                    cmd_en <= 1;
                                    end
        	rd,r_ap,wr,w_ap,wr_ap_wrap,
         rd_ap_wrap,rd_wrap,wr_wrap:  st <= activating;
                            default:begin
                            							cmd_en <= 1'b0;//assert
                 				           				counter <= 1'b0;
                          							 end
                                    endcase 
                                  //  end 
                                  //  end else begin
                                   // $display($time,"\tcntrl: .....Waiting for Command.......");
                                  //  end                          
            end
            
     
        
      activating:begin
               cmd_en <= 1'b1;
              //  $display($time,"\tcntrl: NOW ACTIVATING");
                cke <= 1'b1;
                cs_n <= 1'b0;
                ras_n <= 1'b0;
                cas_n <= 1'b1;
                we_n <= 1'b1;
                ba <= ba_in;
                active_banks[ba] <= 1'b1;
                addr <= row;
                prev_bank <= ba;
                prev_row <= row;          
                next_state <= nxt_state;
                npt <= ixtb.t;//# of tck to remain in nop
                nop_des <= nop;
                st <= deno;//deno;//trigger nop
                cnt <= 1'b0;
                counter <= 1'b0;
                done <= 1'b0;
                lock <=1'b0;
                en <= 1'b1; 
               end 
   bank_active:begin
   
   							 en <= 1'b1;
							   cmd_en <= 1'b0;
                    case(cmd)
                  reset:begin
                    		st <= initialize;
                    		cmd_en <= 1'b0;
                    		done <= 1'b0;
                    		lock <=1'b0;
                 				counter <= 1'b0;
                    	  end
                     rd:begin
                    		st <= read;
                				cnt <= 1'b0;
                    		done <= 1'b0;
                    		lock <=1'b0;
                 				counter <= 1'b0;
                 				
                    		end 
                     wr:begin 
                				cnt <= 1'b0;
                          counter <= 1'b0;
                          done <= 1'b0;
                          lock <=1'b0;
                          st <= write; 
                       	end
                    pre:begin
                     		st <= prec;    //precharge
                     		done <= 1'b0;
                     		lock <=1'b0;
                 				counter <= 1'b0;
                     		end
                   prea:begin
                    		st <= preca;    //precharge
                    		done <= 1'b0;
                    		lock <=1'b0;
                 				counter <= 1'b0;
                    		end
                    pde:begin
                    		st <= pwd_e;    //power-down entry
                 				counter <= 1'b0;
                 				done <= 1'b0;
                 				lock <=1'b0;
                    		end
                wr_wrap:begin
                      	st <= write_wrap;
                      	done <= 1'b0;
                      	lock <=1'b0;
                 				counter <= 1'b0;
                        end
              	rd_wrap:begin
                 				counter <= 1'b0;
                 				lock <=1'b0;
                      	st <= read_wrap;
                         end
                  nops: begin
                    
                        next_state <= st;
                        nop_des <= nop;
                        npt <= ixtb.t;
                        st <= deno;
                          cnt <= 1'b0;
                          counter <= 1'b0;
                          done <= 1'b0;
                          cmd_en <= 1'b0;
                          lock <=1'b0;
                      end
                 default:begin
                   				 counter <= 1'b0;
                   				 done <= 1'b0;
                   				 lock <=1'b0;
													 cmd_en <= 1'b0;
                           end
                 endcase
            end



        //requires 4 inputs from test bench, {bank,col,cmd,length}            
 
read: begin
						cmd_en <= 1'b0;
            cke   <= 1'b1;
            cs_n  <= 1'b0;
            ras_n <= 1'b1;
            cas_n <= 1'b0;
            we_n  <= 1'b1;
            ba    <= ba_in;		
            a[0] = col & 10'h3ff;         
            						a[1] = ((col>>10) & 1'h1)<<11;
            						a[2] = (col>>11)<<13; 						
            addr <= a[0] | a[1] | a[2] | (ap<<10) | (bc<<12);

             /* MR0[1:0]         
                           0 0     Fixed BL8
                           0 1     4 or 8(on-the-fly via A12)
                           1 0    Fixed BC4 (chop)
                           1 1     Reserved*/
                    casex ({bc, mode_reg0[1:0]})
                            3'bx00, 3'b101:bl<=8;
                            3'bx1x, 3'b001:bl<=4;
                        endcase
	    			st <= read_latency;
         		end
read_latency: 				
	 					begin
       				cnt <= cnt +1;
	 						if(cnt <= bl/2 + 2)begin 
								odt_fifo[rl-wl + cnt] <= 1'b1;
								st <= read_latency;
								//$display($time,"\tcntrl: Write Latency Complete!");
								end
							else
							begin
								cnt <= 0;
								//st <= dqs_w;
								next_state <= bank_active;
                npt <= ixtb.t; //wl + int'(bl/2) + TWTR_TCK;//int'(TRCD/tck)+1;
                nop_des <= nop;
                st <= deno;
                cnt <= 1'b0;
                cmd_en <= 1;
							end
	 					end
	 					
read_wrap: begin
						cmd_en <= 1'b0;
            cs_n <= 1'b0;
            ras_n <= 1'b1;
            cas_n <= 1'b0;
            we_n <= 1'b1; 
            ba  <= ba_in;	
            col_start <= col;
            st <= r_update;
          end  
r_update: 
				begin
            col_incr <= col + counter;							
            addr <= (col_incr & 10'h3ff) |(((col_incr>>10) & 1'h1)<<11)|((col_incr>>11)<<13) | (ap<<10) | (bc<<12);
             /* MR0[1:0]         
                           0 0     Fixed BL8
                           0 1     4 or 8(on-the-fly via A12)
                           1 0    Fixed BC4 (chop)
                           1 1     Reserved*/
                    casex ({bc, mode_reg0[1:0]})
                            3'bx00, 3'b101:bl<=8;
                            3'bx1x, 3'b001:bl<=4;
                        endcase
	    			st <= r_latency;
         		end
r_latency: 				
	 					begin
       				cnt <= cnt +1;
	 						if(cnt >= bl/2 + 2)begin //wl = 22
								odt_fifo[rl-wl + cnt] <= 1'b1;
								st <= read_latency;
								//$display($time,"\tcntrl: Write Latency Complete!");
								end
							else
							begin
								cnt <= 0;
								st <= wrap_;
								
							end
	 					end
wrap_:
					begin
	 					if (index < rlen) begin
                   if(col_incr < {COL_BITS{1'b1}})begin
                    counter <=  counter + 1;//bl;
                    index <= index + 1;
                    st <= r_update;
                    end else begin// if (ba < 3'b111) begin //not sure we need to increment bank or just column?
                       counter <= 0;
                       index <= index + 1;
                       st <= r_update;
                    end
             end else begin
									counter <= 1'b0; 
									index <= 1'b0;
                  cnt <= 1'b0;
                  st <= read_done;
              end
            end  
 read_done:
 					begin
 							  next_state <= bank_active;
                npt <= ixtb.t;
                nop_des <= nop;
                st <= deno;
                cnt <= 1'b0;
                cmd_en <= 1;
 					end
	 					




      
    //requires 5 inputs from test bench, {bank,col,dm,dq,wr_cmd}            
write: begin
						cmd_en <= 1'b0;
       			cke   <= 1'b1;
            cs_n  <= 1'b0;
            ras_n <= 1'b1;
            cas_n <= 1'b0;
            we_n  <= 1'b0;
            ba    <= ba_in;
							a[0] = col & 10'h3ff;         
                      a[1] = ((col>>10) & 1'h1)<<11;
                      a[2] = (col>>11)<<13; 								
            addr <= a[0] | a[1] | a[2] | (ap<<10) | (bc<<12);

             /* MR0[1:0]         
                           0 0     Fixed BL8
                           0 1     4 or 8(on-the-fly via A12)
                           1 0    Fixed BC4 (chop)
                           1 1     Reserved*/
                    casex ({bc, mode_reg0[1:0]})
                            3'bx00, 3'b101:bl<=8;
                            3'bx1x, 3'b001:bl<=4;
                        endcase
	    			st <= write_latency;
         		end
write_latency: 				
	 					begin
       				 cnt <= cnt +1;
       			//	rw_cnt_en <= 1;
	 					//	if(rw_cnt < wl*tck - half_tck)begin//wl = 22
	 						if(cnt != 1)begin//wl = 22
								st <= write_latency;
								end
							else
							begin
								rw_cnt_en <= 0;
								cnt <= 0;
								st <= dqs_w;
								$display($time,"\tcntrl: Write Latency Complete!");
							end
	 					end
		 	dqs_w:
					 begin
	 					dqs_en <= 1'b1;	
	 					rw_cnt_en <= 0;
						dqs_out <=  {DQS_BITS{1'b1}}; 
						st <= burst_w;
						counter <=0; 
						lock <= 0;
	 				 end        
   	burst_w:
	 					begin
							//cnt <= cnt +1;
							if(rw_cnt < int'(counter*tck/2))
							begin
								rw_cnt_en <= 1; //uses a 1ps clock to count
								if (counter != bl)
								lock <= 0;
									st <= burst_w;
							end
							else
							begin
								cnt <= 0;
							//	rw_cnt_en <= 0;
								lock <= 1; 
							end
							if (lock ==1 )
							begin
								//counter++;
								lock <= 0;
								dqs_en <= 1'b1;
								if (counter%2==0)
									dqs_out <= {DQS_BITS{1'b0}};
		        		else
		       				dqs_out <= {DQS_BITS{1'b1}};
		       			st <= dm_set_delay;	
		       			rw_cnt_en <= 0;       
							end
							//if (counter == bl)
							//begin
							//	counter <=0;
							//	cnt <=0;
							//	st <= dm_set_delay;
							//end
					 end  
dm_set_delay:
				     begin
					     rw_cnt_en <= 1;
	 				    if(rw_cnt < int'(tck/4)+1)
						    st <= dm_set_delay;
					    else
					    begin
						   cnt <= 0;
						   rw_cnt_en <= 0;
						   st <= dm_set;
					    end
				    end
	   dm_set:
				    begin
								dq_en  <=  1'b1;
                dm_out <= dm_in >>counter*DM_BITS;
                dq_out <= dq_in >>counter*DQ_BITS;
                counter <= counter + 1;
                if (counter == bl)
								begin
									counter <= 0;
									cnt <= 0;
									st <= dq_en_off;
								end
								else
									st <= burst_w;
				    end
  dq_en_off:	
					  begin
            dq_en  <=  1'b0;
            //cnt <= cnt + 1;
            rw_cnt_en <= 1;
            if(rw_cnt < int'(tck/4)+1) //1/4(tck)
							st <= dq_en_off;
					  else 
					  begin
					  cnt <= 0;
					  rw_cnt_en <= 0;
            st <= dqs_en_off;
            end
            end
dqs_en_off:begin
						dqs_en <=  1'b0;
					      next_state <= bank_active;
                npt <= ixtb.t; //wl + int'(bl/2) + TWTR_TCK;//int'(TRCD/tck)+1;
                nop_des <= nop;
                st <= deno;
                cnt <= 1'b0;
                counter <= 1'b0;
                done <= 1'b0;
                lock <=1'b0;
                en <= 1'b1;
                cmd_en <= 1;
					  end
  
  //requires 5 inputs from test bench, {bank,col,dm,dq,wr_cmd,rlen(amount of wrapping)}  
  
  
  write_wrap: begin
						cmd_en <= 1'b0;
       			cke   <= 1'b1;
            cs_n  <= 1'b0;
            ras_n <= 1'b1;
            cas_n <= 1'b0;
            we_n  <= 1'b0;
            ba    <= ba_in;
             /* MR0[1:0]         
                           0 0     Fixed BL8
                           0 1     4 or 8(on-the-fly via A12)
                           1 0    Fixed BC4 (chop)
                           1 1     Reserved*/
                    casex ({bc, mode_reg0[1:0]})
                            3'bx00, 3'b101:bl<=8;
                            3'bx1x, 3'b001:bl<=4;
                        endcase
	    			st <= w_update;
         		end
         		
w_update: 
				begin
            col_incr <= col + wcnt;							
            addr <= (col_incr & 10'h3ff) |(((col_incr>>10) & 1'h1)<<11)|((col_incr>>11)<<13) | (ap<<10) | (bc<<12);
             /* MR0[1:0]         
                           0 0     Fixed BL8
                           0 1     4 or 8(on-the-fly via A12)
                           1 0    Fixed BC4 (chop)
                           1 1     Reserved*/
                    casex ({bc, mode_reg0[1:0]})
                            3'bx00, 3'b101:bl<=8;
                            3'bx1x, 3'b001:bl<=4;
                        endcase
	    			st <= w_latency;
         		end
         		
w_latency: 				
	 					begin
       				cnt <= cnt +1;
	 						if(cnt != wl)begin//wl = 22
								st <= w_latency;
								$display($time,"\tcntrl: Write Latency Complete!");
								end
							else
							begin
								cnt <= 0;
								st <= dqs_ww;
								$display($time,"\tcntrl: Write Latency Complete!");
							end
	 					end
		 	dqs_ww:
					 begin
	 					dqs_en <= 1'b1;	
						dqs_out <=  {DQS_BITS{1'b1}}; 
						st <= burst_ww;
						counter <=0; 
						lock <= 0;
	 				 end        
   	burst_ww:
	 					begin
							//cnt <= cnt +1;
							if(rw_cnt < int'(counter*tck/2))
							begin
								rw_cnt_en <= 1; //uses a 1ps clock to count
								if (counter != bl)
								lock <= 0;
									st <= burst_ww;
							end
							else
							begin
								cnt <= 0;
							//	rw_cnt_en <= 0;
								lock <= 1; 
							end
							if (lock ==1 )
							begin
								//counter++;
								lock <= 0;
								dqs_en <= 1'b1;
								if (counter%2==0)
									dqs_out <= {DQS_BITS{1'b0}};
		        		else
		       				dqs_out <= {DQS_BITS{1'b1}};
		       			st <= dm_set_delayw;
		       			rw_cnt_en <= 0;	       
							end
							//if (counter == bl)
							//begin
							//	counter <=0;
							//	cnt <=0;
							//	st <= dm_set_delay;
							//end
					 end  
dm_set_delayw:
				     begin
					    //if(rw_cnt < int'(tck/4)+1)
	 				    if(cnt != 1) //quarter tck
	 				    begin
	 				    cnt <= cnt + 1;
						    st <= dm_set_delayw;
						    end
					    else
					    begin
						   cnt <= 0;
						   st <= dm_setw;
					    end
				    end
	   dm_setw:
				    begin
								dq_en  <=  1'b1;
                dm_out <= dm_in >>counter*DM_BITS;
                dq_out <= dq_in >>counter*DQ_BITS;
                counter <= counter + 1;
                if (counter == bl)
								begin
									counter <= 0;
									cnt <= 0;
									st <= wrap_w;
								end
								else
									st <= burst_ww;
				    end
		wrap_w:
					begin
	 					if (index < rlen) begin
                   if(col_incr < {COL_BITS{1'b1}})begin
                    wcnt <=  wcnt + 1;//bl;
                    index <= index + 1;
                    st <= r_update;
                    end else begin// 
                       wcnt <= 0;
                       index <= index + 1;
                       st <= w_update;
                    end
             end else begin
									lock <= 1'b1;
									counter <= 1'b0; 
									index <= 1'b0;
                  bcnt <= 1'b0;
                  cnt <= 1'b0;
                  st <= dq_en_offw;
              end
            end
  dq_en_offw:	
					  begin
            dq_en  <=  1'b0;
            cnt <= cnt + 1;
            if(cnt != 1) //quarter tck round up
							st <= dq_en_offw;
					  else 
					  begin
					  cnt <= 0;
            st <= dqs_en_offw;
            end
            end
dqs_en_offw:begin
						dqs_en <=  1'b0;
					      next_state <= bank_active;
                npt <= ixtb.t; //wl + int'(bl/2) + TWTR_TCK;//int'(TRCD/tck)+1;
                nop_des <= nop;
                st <= deno;
                cnt <= 1'b0;
                			//	cmd_en <= 1'b0;
                counter <= 1'b0;
                done <= 1'b0;
                lock <=1'b0;
                en <= 1'b1;
                cmd_en <= 1;
					  end
  
            
 


//requires bank input from tb
   prec,
   preca: 
    					begin// $display($time,"\tcntrl: IN  PRECHARGE STATE");
                cmd_en <= 1'b1;
                en <= 1'b0;
                cke <= 1'b1;
                cs_n <= 1'b0;
                ras_n <= 1'b0;
                cas_n <= 1'b1;
                we_n <= 1'b0;
                ba <= ba_in;
                next_state <= idle;
                npt <= int'(TRP/tck) + 1;
                nop_des <= nop;
                st <= deno;
            	end

  


//requires no input from tb
         refrs: 
             begin
                cmd_en <= 1;
             // $display($time,"\tcntrl: NOW IN REFRESH STATE");
                cke   <= 1'b1;
                cs_n <= 1'b0;
                ras_n <= 1'b0;
                cas_n <= 1'b0;
                we_n <= 1'b1;
                next_state <= idle;
                npt <= int'(TRFC_MIN/tck)+1;
                nop_des <= nop;
                st <= deno;
              end


            sref: 
            		begin
               		 cmd_en <= 1'b1;
                  // $display($time,"\tcntrl: NOW IN SELF REFRESH STATE");
                case(st_tm)
                t_1:
                	begin
                		next_state <= sref;
                		npt <= TXP_TCK;
               			nop_des <= nop;
                		st <= deno;
                		st_tm <= t_0;
                	 end
                 t_0:
                 	begin
                   cke   <= 1'b0;
                   cs_n  <= 1'b0;
                   ras_n <= 1'b0;
                   cas_n <= 1'b0;
                   we_n  <= 1'b1;
                   if(cnt < 1)
                   cnt <= cnt + 1;
                   else
                   	begin
                   	cnt <= 0;
            				cs_n  <=  1'b1;
            				ras_n <=  1'b1;
            				cas_n <=  1'b1;
            				we_n  <=  1'b1;
         						st_tm <=  t_2;
            				end
            			end
            		t_2:
            			begin
            				if(cnt < ixtb.t)
                  	 cnt <= cnt + 1;
                  	else
                   	begin
                   	st <= idle; //srfx;
                   	cnt <= 0;
                  	// next_state <= idle;
                 		// nop_des <= nop; //...NOP or DES must be issued for tXS time.
                 		// st <= deno;
                 		// npt <= int'(TRFC_MIN/tck)+1; 
                 		end
                 	end
                 endcase
            		end
       srfx: begin
                cmd_en <= 0;
                 next_state <= idle;
                 nop_des <= nop; //...NOP or DES must be issued for tXS time.
                 st <= deno;
                 npt <= TXS_TCK; //read to precharge command delay
                cnt <= 0;
                done <= 1'b0;
             end
             
             
/*Input from test bench is bank and address*/
 mode_reg_set: begin
                    cmd_en <= 0;
                    cke <= 1'b1;
                    cs_n  <= 1'b0; 
                    ras_n <= 1'b0;
                    cas_n <= 1'b0; 
                    we_n  <= 1'b0; 
                case (ba_in)
                  0: mode_reg0 <= addr_in;
                  1: mode_reg1 <= addr_in;
                  2: mode_reg2 <= addr_in;
                endcase
                ba <= ba_in;
                addr <= addr_in;
                   next_state <= idle;
                  npt <= TMOD_TCK + ixtb.t;
                  nop_des <= nop;
                  st <= deno;
                  done <= 1'b0;
                 $display($time,"\tcntrl: MODE REG SUCCESSFULLY CONFIGURED");
            end
//receives parameter for time in power-down entry
      pwd_e: begin
                $display($time,"\tcntrl: NOW IN POWER DOWN ENTRY STATE");
              	cke   <= 1'b0;
                cs_n <= 1'b0;    
                ras_n <= 1'b1;    
                cas_n <= 1'b1;    
                we_n <= 1'b1; 
           			cmd_en <= 1;
           			st <= nxt_state;
                end
       pwd_x: begin
                cmd_en <= 1;
                 next_state <= bank_active;
                nop_des <= nop;
                st <= deno;
                npt <= TXP_TCK;
                  cnt <= 0;
                    done <= 1'b0;
                    st <= bank_active;
            end 
            
     deno:	begin
            	case (nop_des)
/*The DESELT (DES) command (CS# HIGH) prevents new commands from being executed
by the DRAM. Operations already in progress are not affected.*/
            des: begin
                cke <= 1'b1;
                cs_n <= 1'b1;
                ras_n <= 1'bx;
                cas_n <= 1'bx;
                we_n <= 1'bx;
								if(nop_cnt < npt)begin
								nop_cnt_en <= 1'b1;
								done <= 1'b0;
								end else begin
								done <= 1'b1;
								nop_cnt_en <= 1'b0;
             		$display($time,"\tcntrl: des ");
                st <= next_state;
                cmd_en <= 0;
                end
                end

/*The NO OPERATION (NOP) command (CS# LOW) prevents unwanted commands from
being registered during idle or wait states. Operations already in progress are not affected.*/
           nop: begin
                cke <= 1'b1;
                cs_n <= 1'b0;
                ras_n <= 1'b1;
                cas_n <= 1'b1;
                we_n <= 1'b1;
                if(nop_cnt < npt)begin
								nop_cnt_en <= 1'b1;
								done <= 1'b0;
								end else begin
								done <= 1'b1;
								nop_cnt_en <= 1'b0;
             		$display($time,"\tcntrl: nop");
                st <= next_state;
                nlock <= 1'b0;
               	cmd_en <= 1'b0;
                end
                end
             zero: done <= 1'b0;
            default: st <= next_state;
            endcase
           end   
  default: begin
                  rst_n <=  1'b0; //rst_n keeps all ddr inputs at z-impedence (disables)
                  cnt <= 1'b0;
            end
        endcase
       end
    end
  end
endmodule


