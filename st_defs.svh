//controller states /configuration params 
//controller states
//typedef enum logic [5:0]{
parameter power_up = 0, //power up, begin initialization
initialize = 1,
init_mrs = 2,	//initialization MRS load mode
zq_calibr_short = 3,	//zq_calibration short
zq_calibr_long =30,//zq_calibration long
idle = 4,
activating = 5,		//activating
bank_active = 6,
read = 7,	//rd
read_latency = 31,
r_update = 32,
r_latency = 35,
read_done = 33,
wrap_ = 34,
//read_ap, //read  ap
read_wrap = 8,
after_activate = 9,
nop_exit_write = 10,
//read_ap_wrap,
write = 11,		//wr 
//write_ap,//write auto precharge 
//write_ap_wrap,
write_wrap = 12,
//wr_burst,
dqs_en_off = 13,
dq_en_off = 14,
dm_set = 15,
dm_set_delay = 16,
burst_w = 17,
burst_cnt = 79,
dqs_w = 18,
write_latency = 19,
dqs_en_offw = 51,
dq_en_offw = 52,
wrap_w = 53,
dm_setw= 54,
dm_set_delayw = 56,
burst_ww = 57,
dqs_ww = 58,
w_latency = 59,
w_update = 60,
prec = 20,//precharge
preca = 21,//precharge all
refrs = 22,	//refresh
sref = 23,	//self refresh entry
srfx = 24,	//self refresh exit
mode_reg_set = 25,	//mode register set
pwd_e = 26,	//power-down entry
pwd_x = 27,	//power-down exit
mp_reg = 28, //multiplurpose register
deno = 29;
//}state;
