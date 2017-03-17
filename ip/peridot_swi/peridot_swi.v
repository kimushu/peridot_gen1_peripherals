// ===================================================================
// TITLE : PERIDOT / Software Interrupt sender
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/04/30 -> 2015/05/23
//   UPDATE : 2017/02/22
//
// ===================================================================
// *******************************************************************
//   Copyright (C) 2015-2017, J-7SYSTEM Works.  All rights Reserved.
//
// * This module is a free sourcecode and there is NO WARRANTY.
// * No restriction on use. You can use, modify and redistribute it
//   for personal, non-profit or commercial products UNDER YOUR
//   RESPONSIBILITY.
// * Redistributions of source code must retain the above copyright
//   notice.
// *******************************************************************


// reg00(+0)  bit31-0:class index(RO)
// reg01(+4)  bit31-0:generation time(RO)
// reg02(+8)  bit31-0:lower unique id(RO)
// reg03(+C)  bit31-0:upper unique id(RO)
// reg04(+14) bit31-16:deadkey(WO), bit15:uidvalid(RO), bit14:uidena(RW), bit1:led(RW), bit0:niosreset(RW)
// reg05(+10) bit15:irqena(RW), bit9:start(W)/ready(R), bit8:select(RW), bit7-0:txdata(W)/rxdata(R)
// reg06(+18) bit31-0:mutexmessage(RW)
// reg07(+1C) bit0:swi(RW)

module peridot_swi #(
	parameter CLOCKFREQ		= 25000000,			// peripheral drive clock freq(Hz)
	parameter CLASSID		= 32'h72A00000,		// PERIDOT Class ID
	parameter TIMECODE		= 32'd1234567890,	// Generation Time stamp
	parameter DEVICE_FAMILY	= "",
	parameter PART_NAME		= ""
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
	output			coe_led,
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

	reg				uidena_reg;
	reg				rreq_reg;
	reg				led_reg;
	reg  [31:0]		message_reg;
	reg				irq_reg;

	wire [31:0]		spi_readdata_sig;
	wire			spi_irq_sig;
	wire			spi_write_sig;
	wire			uid_enable_sig;
	wire [63:0]		uid_data_sig;
	wire			uid_valid_sig;


/* ���ȍ~��wire�Areg�錾�͋֎~�� */

/* ===== �e�X�g�L�q ============== */



/* ===== ���W���[���\���L�q ============== */

	///// Avalon-MM ���W�X�^���� /////

	assign avs_readdata =
			(avs_address == 3'd0)? CLASSID :
			(avs_address == 3'd1)? TIMECODE :
			(avs_address == 3'd2)? uid_data_sig[31:0] :
			(avs_address == 3'd3)? uid_data_sig[63:32] :
			(avs_address == 3'd4)? {16'b0, uid_valid_sig, uid_enable_sig, 12'b0, led_reg, rreq_reg} :
			(avs_address == 3'd5)? spi_readdata_sig :
			(avs_address == 3'd6)? message_reg :
			(avs_address == 3'd7)? {31'b0, irq_reg} :
			{32{1'bx}};

	assign ins_irq = irq_reg | spi_irq_sig;
	assign coe_cpureset = rreq_reg;
	assign coe_led = led_reg;

	assign spi_write_sig = (avs_write && avs_address == 3'd5)? 1'b1 : 1'b0;

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			uidena_reg <= 1'b0;
			rreq_reg <= 1'b0;
			led_reg <= 1'b0;
			irq_reg <= 1'b0;
			message_reg <= 32'd0;
		end
		else begin
			if (avs_write) begin
				case (avs_address)
				3'd4 : begin
					if (avs_writedata[31:16] == 16'hdead) begin
						rreq_reg <= avs_writedata[0];
					end
					uidena_reg <= avs_writedata[14];
					led_reg <= avs_writedata[1];
				end
				3'd6 : begin
					message_reg <= avs_writedata;
				end
				3'd7 : begin
					irq_reg <= avs_writedata[0];
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


	///// ���j�[�NID�擾 /////
	// ���Z�b�g��AID�l���m�肷��܂�64�N���b�N������ 

generate
	if (DEVICE_FAMILY == "MAX 10") begin
		assign uid_enable_sig = uidena_reg;

		altchip_id #(
			.DEVICE_FAMILY	("MAX 10"),
			.ID_VALUE		(64'hffffffffffffffff),
			.ID_VALUE_STR	("00000000ffffffff")
		)
		u1_max10_uid (
			.clkin			(clock_sig),
			.reset			(~uid_enable_sig),
			.data_valid		(uid_valid_sig),
			.chip_id		(uid_data_sig)
		);
	end
	else if (DEVICE_FAMILY == "Cyclone V") begin
		assign uid_enable_sig = uidena_reg;

		altchip_id #(
			.DEVICE_FAMILY	("Cyclone V"),
			.ID_VALUE		(64'hffffffffffffffff)
		)
		u1_cyclone5_uid (
			.clkin			(clock_sig),
			.reset			(~uid_enable_sig),
			.data_valid		(uid_valid_sig),
			.chip_id		(uid_data_sig)
		);
	end
	else begin	// CycloneIV E or other
		assign uid_enable_sig = 1'b0;
		assign uid_valid_sig = 1'b1;
		assign uid_data_sig = 64'hffffffffffffffff;
	end
endgenerate



endmodule
