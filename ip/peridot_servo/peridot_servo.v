// ===================================================================
// TITLE : PERIDOT / RC Servo controller (for SG-90/MG-90S/SG-92R)
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/05/17 -> 2015/05/17
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

module peridot_servo #(
	parameter PWM_CHANNEL	= 30,		// output servo channel :1-30
	parameter CLOCKFREQ		= 25000000	// peripheral drive clock freq(Hz)
) (
	// Interface: clk
	input			csi_clk,
	input			rsi_reset,

	// Interface: Avalon-MM slave
	input  [4:0]	avs_address,
	input			avs_read,			// read  0-setup,1-wait,0-hold
	output [31:0]	avs_readdata,
	input			avs_write,			// write 0-setup,0-wait,0-hold
	input  [31:0]	avs_writedata,

	// External Interface
	output [PWM_CHANNEL-1:0]	pwm_out,
	output [PWM_CHANNEL-1:0]	dsm_out
);


/* ===== �O���ύX�\�p�����[�^ ========== */



/* ----- �����p�����[�^ ------------------ */

	localparam STEPCOUNTNUM		= 2560;
	localparam UNITFREQ			= 128000;		// 1/(20ms / 2560)
	localparam CLOCKDIV			= (CLOCKFREQ / UNITFREQ) - 1;
//	localparam CLOCKDIV			= 1;		// test

	wire [31:0]		divcount_init_sig = CLOCKDIV;


/* ���ȍ~�̃p�����[�^�錾�͋֎~�� */

/* ===== �m�[�h�錾 ====================== */
				/* �����͑S�Đ��_�����Z�b�g�Ƃ���B�����Œ�`���Ă��Ȃ��m�[�h�̎g�p�͋֎~ */
	wire			reset_sig = rsi_reset;			// ���W���[�������쓮�񓯊����Z�b�g 

				/* �����͑S�Đ��G�b�W�쓮�Ƃ���B�����Œ�`���Ă��Ȃ��N���b�N�m�[�h�̎g�p�͋֎~ */
	wire			clock_sig = csi_clk;			// ���W���[�������쓮�N���b�N 

	reg  [7:0]		readdata_reg;
	wire [7:0]		regreadsel_sig [0:31];
	wire [31:0]		regwrite_sig;

	reg				servo_ena_reg;

	reg  [11:0]		divcount_reg;
	wire			timing_sig;
	reg  [12:0]		stepcount_reg;

	genvar i;


/* ���ȍ~��wire�Areg�錾�͋֎~�� */

/* ===== �e�X�g�L�q ============== */



/* ===== ���W���[���\���L�q ============== */

	///// Avalon-MM�C���^�[�t�F�[�X /////

	assign avs_readdata = {24'b0, readdata_reg};

	assign regreadsel_sig[0] = {7'b0, servo_ena_reg};
	assign regreadsel_sig[1] = {8{1'bx}};

	generate
		for (i=0 ; i<32 ; i=i+1) begin : regwen
			assign regwrite_sig[i] = (avs_address == i)? avs_write : 1'b0;
		end
	endgenerate

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			servo_ena_reg <= 1'b0;
		end
		else begin
			readdata_reg <= regreadsel_sig[avs_address];

			if (regwrite_sig[0]) begin
				servo_ena_reg <= avs_writedata[0];
			end
		end
	end



	///// ��^�C�~���O���� /////

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			divcount_reg  <= 1'd0;
			stepcount_reg <= 1'd0;
		end
		else begin
			if (divcount_reg == 0) begin
				divcount_reg <= divcount_init_sig[11:0];
			end
			else begin
				divcount_reg <= divcount_reg - 1'd1;
			end

			if (servo_ena_reg) begin
				if (divcount_reg == 0) begin
					if (stepcount_reg == STEPCOUNTNUM-1) begin
						stepcount_reg <= 1'd0;
					end
					else begin
						stepcount_reg <= stepcount_reg + 1'd1;
					end
				end
			end
			else begin
				stepcount_reg <= 1'd0;
			end
		end
	end

	assign timing_sig = (divcount_reg == 0)? 1'b1 : 1'b0;



	///// �T�[�{�M������ /////

	generate
		for (i=0 ; i<PWM_CHANNEL ; i=i+1) begin : pwmch
			peridot_servo_pwmgen #(
				.STARTSTEP		( (i % 8)*320 ),
				.MINWIDTHSTEP	( 64 )
			)
			u_pwm (
				.reset			(reset_sig),
				.clk			(clock_sig),
				.reg_write		(regwrite_sig[i+2]),
				.reg_writedata	(avs_writedata[7:0]),
				.reg_readdata	(regreadsel_sig[i+2]),

				.pwm_enable		(servo_ena_reg),
				.pwm_timing		(timing_sig),
				.step_num		(stepcount_reg),
				.pwm_out		(pwm_out[i]),
				.dsm_out		(dsm_out[i])
			);
		end

		for (i=PWM_CHANNEL ; i<30 ; i=i+1) begin : dummy
			assign regreadsel_sig[i+2] = {8{1'bx}};
		end
	endgenerate



endmodule
