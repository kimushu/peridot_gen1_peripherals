// ===================================================================
// TITLE : PERIDOT / Software Interrupt sender
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/04/30 -> 2015/05/23
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


// reg00(+0)  bit31-0:frc(RO)
// reg01(+4)  bit31-0:mutexmessage(RW)
// reg02(+8)  bit31-16:ownerid(RW), bit15-0:value(RW)
// reg03(+C)  bit0:swi(RW)
// reg04(+10) bit15:irqena(RW), bit9:start(W)/ready(R), bit8:select(RW), bit7-0:txdata(W)/rxdata(R)
// reg05(+14) bit31-16:deadkey(WO), bit0:niosreset(RW)

module peridot_swi #(
	parameter CLOCKFREQ		= 25000000	// peripheral drive clock freq(Hz)
) (
	// Interface: clk & reset
	input			csi_clk,
	input			rsi_reset,

	// Interface: Avalon-MM slave
	input  [2:0]	avs_address,
	input			avs_read,
	output [31:0]	avs_readdata,
	input			avs_write,
	input  [31:0]	avs_writedata,

	// Interface: Avalon-MM Interrupt sender
	output			ins_irq,

	// External:
	output			coe_cpureset,
	output			coe_cso_n,
	output			coe_dclk,
	output			coe_asdo,
	input			coe_data0
);


/* ===== �O���ύX�\�p�����[�^ ========== */



/* ----- �����p�����[�^ ------------------ */

	localparam	SPIFLASH_MAXFREQ	= 20000000;		// SPI-Flash max freq(Hz)

	localparam	TEMP_CLKDIV			= CLOCKFREQ / (SPIFLASH_MAXFREQ * 2);
	localparam	TEMP_DEC			= (TEMP_CLKDIV > 0 && (CLOCKFREQ %(SPIFLASH_MAXFREQ * 2)) == 0)? 1 : 0;
	localparam	SPI_REG_CLKDIV		= TEMP_CLKDIV - TEMP_DEC;


/* ���ȍ~�̃p�����[�^�錾�͋֎~�� */

/* ===== �m�[�h�錾 ====================== */
				/* �����͑S�Đ��_�����Z�b�g�Ƃ���B�����Œ�`���Ă��Ȃ��m�[�h�̎g�p�͋֎~ */
	wire			reset_sig = rsi_reset;				// ���W���[�������쓮�񓯊����Z�b�g 

				/* �����͑S�Đ��G�b�W�쓮�Ƃ���B�����Œ�`���Ă��Ȃ��N���b�N�m�[�h�̎g�p�͋֎~ */
	wire			clock_sig = csi_clk;				// ���W���[�������쓮�N���b�N 

	reg  [31:0]		frc_reg;
	reg  [31:0]		message_reg;
	reg  [15:0]		owner_reg, value_reg;
	reg				irq_reg;
	reg				rreq_reg;

	wire [31:0]		spi_readdata_sig;
	wire			spi_irq_sig;
	wire			spi_write_sig;


/* ���ȍ~��wire�Areg�錾�͋֎~�� */

/* ===== �e�X�g�L�q ============== */



/* ===== ���W���[���\���L�q ============== */

	///// Avalon-MM ���W�X�^���� /////

	assign avs_readdata =
			(avs_address == 3'd0)? frc_reg :
			(avs_address == 3'd1)? message_reg :
			(avs_address == 3'd2)? {owner_reg, value_reg} :
			(avs_address == 3'd3)? {31'b0, irq_reg} :
			(avs_address == 3'd4)? spi_readdata_sig :
			(avs_address == 3'd5)? {31'b0, rreq_reg} :
			{32{1'bx}};

	assign ins_irq = irq_reg | spi_irq_sig;
	assign coe_cpureset = rreq_reg;

	assign spi_write_sig = (avs_write && avs_address == 3'd4)? 1'b1 : 1'b0;

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			frc_reg   <= 32'd0;
			owner_reg <= 16'h0000;
			value_reg <= 16'h0000;
			irq_reg   <= 1'b0;
			rreq_reg  <= 1'b0;
		end
		else begin
			frc_reg <= frc_reg + 1'd1;

			if (avs_write) begin
				case (avs_address)
				3'd1 : begin
					message_reg <= avs_writedata;
				end
				3'd2 : begin
					if (value_reg == 16'h0000 || owner_reg == avs_writedata[31:16]) begin
						owner_reg <= avs_writedata[31:16];
						value_reg <= avs_writedata[15:0];
					end
				end
				3'd3 : begin
					irq_reg <= avs_writedata[0];
				end
				3'd5 : begin
					if (avs_writedata[31:16] == 16'hdead) begin
						rreq_reg <= avs_writedata[0];
					end
				end
				endcase
			end
		end
	end


	///// �u�[�g�pSPI-Flash�y���t�F���� /////

	peridot_spi #(
		.DEFAULT_REG_BITRVS		(1'b0),
		.DEFAULT_REG_MODE		(2'd0),		// spi mode 0
		.DEFAULT_REG_CLKDIV		(SPI_REG_CLKDIV)
	)
	u0_spi (
		.csi_clk		(clock_sig),
		.rsi_reset		(reset_sig),
		.avs_address	(1'b0),
		.avs_read		(1'b1),
		.avs_readdata	(spi_readdata_sig),
		.avs_write		(spi_write_sig),
		.avs_writedata	(avs_writedata),
		.ins_irq		(spi_irq_sig),

		.spi_ss_n		(coe_cso_n),
		.spi_sclk		(coe_dclk),
		.spi_mosi		(coe_asdo),
		.spi_miso		(coe_data0)
	);



endmodule
