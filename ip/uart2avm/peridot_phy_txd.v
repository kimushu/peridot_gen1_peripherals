// ===================================================================
// TITLE : PERIDOT / UART sender phy
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/12/27 -> 2015/12/27
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

`timescale 1ns / 100ps

module peridot_phy_txd (
	// Interface: clk
	input			clk,
	input			reset,

	// Interface: ST in
	output			in_ready,
	input			in_valid,
	input [7:0]		in_data,

	// interface UART
	output			txd
);


/* ===== 外部変更可能パラメータ ========== */

	parameter CLOCK_FREQUENCY	= 50000000;
	parameter UART_BAUDRATE		= 115200;
//	parameter UART_BAUDRATE		= 12500000;		// test


/* ----- 内部パラメータ ------------------ */

	localparam CLOCK_DIVNUM = (CLOCK_FREQUENCY / UART_BAUDRATE) - 1;


/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
				/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
	wire			reset_sig = reset;				// モジュール内部駆動非同期リセット 

				/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = clk;				// モジュール内部駆動クロック 

	reg [11:0]		divcount_reg;
	reg [3:0]		bitcount_reg;
	reg [8:0]		txd_reg;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */



/* ===== モジュール構造記述 ============== */

	assign in_ready = (bitcount_reg == 4'd0)? 1'b1 : 1'b0;
	assign txd = txd_reg[0];

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			divcount_reg <= 1'd0;
			bitcount_reg <= 1'd0;
			txd_reg <= 9'h1ff;

		end
		else begin
			if (bitcount_reg == 4'd0) begin
				if (in_valid) begin
					divcount_reg <= CLOCK_DIVNUM;
					bitcount_reg <= 4'd10;
					txd_reg <= {in_data, 1'b0};
				end
			end
			else begin
				if (divcount_reg == 0) begin
					divcount_reg <= CLOCK_DIVNUM;
					bitcount_reg <= bitcount_reg - 1'd1;
					txd_reg <= {1'b1, txd_reg[8:1]};
				end
				else begin
					divcount_reg <= divcount_reg - 1'd1;
				end
			end

		end
	end



endmodule
