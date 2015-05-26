// ===================================================================
// TITLE : PERIDOT / Pin function controller Qsys interface
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/04/19 -> 2015/05/17
//   UPDATE : 
//
// ===================================================================
// *******************************************************************
//   Copyright (C) 2015, J-7SYSTEM Works.  All rights Reserved.
//
// * This module is a free sourcecode and there is NO WARRANTY.
// * No restriction on use. You can use, modify and redistribute it
//   for personal, non-profit or commercial products UNDER YOUR
//   RESPONSIBILITY.
// * Redistributions of source code must retain the above copyright
//   notice.
// *******************************************************************

// BANK0(D0-D7)
//   reg00(+00)  din:bit7-0(RO)
//   reg01(+04)  mask:bit15-8(WO) / dout:bit7-0
//   reg02(+08)  pin0func:bit3-0 / pin1func:bit7-4 / dd / pin7func:bit31-28
//   reg03(+0C)  func0pin:bit3-0 / func1pin:bit7-4 / dd / func7pin:bit31-28
//
// BANK1(D8-D15)
//   reg04(+10)  din:bit7-0(RO)
//   reg05(+14)  mask:bit15-8(WO) / dout:bit7-0
//   reg06(+18)  pin0func:bit3-0 / pin1func:bit7-4 / dd / pin7func:bit31-28
//   reg07(+1C)  func0pin:bit3-0 / func1pin:bit7-4 / dd / func7pin:bit31-28
//
// BANK2(D16-D21)
//   reg08(+20)  din:bit7-0(RO)
//   reg09(+24)  mask:bit15-8(WO) / dout:bit7-0
//   reg10(+28)  pin0func:bit3-0 / pin1func:bit7-4 / dd / pin7func:bit31-28
//   reg11(+2C)  func0pin:bit3-0 / func1pin:bit7-4 / dd / func7pin:bit31-28
//
// BANK3(D22-D27)
//   reg12(+30)  din:bit7-0(RO)
//   reg13(+34)  mask:bit15-8(WO) / dout:bit7-0
//   reg14(+38)  pin0func:bit3-0 / pin1func:bit7-4 / dd / pin7func:bit31-28
//   reg15(+3C)  func0pin:bit3-0 / func1pin:bit7-4 / dd / func7pin:bit31-28

module peridot_pfc_interface(
	// Interface: clk and reset
	input			csi_clk,
	input			rsi_reset,

	// Interface: Avalon-MM slave
	input  [3:0]	avs_address,
	input			avs_read,		// read  : 0-setup,1-wait,0-hold
	output [31:0]	avs_readdata,
	input			avs_write,		// write : 0-setup,0-wait,0-hold
	input  [31:0]	avs_writedata,

	// External Interface
	output			coe_pfc_clk,
	output			coe_pfc_reset,
	output [3:0]	coe_pfc_address,
	input  [31:0]	coe_pfc_readdata,
	output			coe_pfc_write,
	output [31:0]	coe_pfc_writedata
);


/* ===== ŠO•”•ÏX‰Â”\ƒpƒ‰ƒ[ƒ^ ========== */



/* ----- “à•”ƒpƒ‰ƒ[ƒ^ ------------------ */



/* ¦ˆÈ~‚Ìƒpƒ‰ƒ[ƒ^éŒ¾‚Í‹Ö~¦ */

/* ===== ƒm[ƒhéŒ¾ ====================== */

	reg  [31:0]		readdata_reg;


/* ¦ˆÈ~‚ÌwireAregéŒ¾‚Í‹Ö~¦ */

/* ===== ƒeƒXƒg‹Lq ============== */



/* ===== ƒ‚ƒWƒ…[ƒ‹\‘¢‹Lq ============== */

	assign avs_readdata = readdata_reg;

	always @(posedge csi_clk) begin
		readdata_reg <= coe_pfc_readdata;
	end

	assign coe_pfc_clk = csi_clk;
	assign coe_pfc_reset = rsi_reset;
	assign coe_pfc_address = avs_address;
	assign coe_pfc_write = avs_write;
	assign coe_pfc_writedata = avs_writedata;



endmodule
