// ===================================================================
// TITLE : PERIDOT / RC Servo PWM Generator
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM Works)
//   DATE   : 2015/05/17 -> 2015/05/17
//   UPDATE : 2015/05/19 1bit�����ϒ��o�͒ǉ� 
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

module peridot_servo_pwmgen #(
	parameter STARTSTEP		= 0,		// PWM�J�n�X�e�b�v��(0�`2240)
	parameter MINWIDTHSTEP	= 64		// PWM�Œᕝ(width_num=128�̎���1.5ms���ƂȂ�l���w�肷��)
) (
	input			reset,
	input			clk,

	input			reg_write,
	input  [7:0]	reg_writedata,		// PWM�����W�X�^(0:�ŏ��`255:�ő�)
	output [7:0]	reg_readdata,

	input			pwm_enable,
	input			pwm_timing,
	input [12:0]	step_num,			// 0��2559�̃J�E���g�A�b�v 
	output			pwm_out,			// �T�[�{�g�`�̏o�� 
	output			dsm_out				// �A�i���O�o��(1bit�����ϒ�) 
);


/* ===== �O���ύX�\�p�����[�^ ========== */



/* ----- �����p�����[�^ ------------------ */

	wire [31:0]		pwmwidth_init_sig = STARTSTEP + MINWIDTHSTEP;


/* ���ȍ~�̃p�����[�^�錾�͋֎~�� */

/* ===== �m�[�h�錾 ====================== */
				/* �����͑S�Đ��_�����Z�b�g�Ƃ���B�����Œ�`���Ă��Ȃ��m�[�h�̎g�p�͋֎~ */
	wire			reset_sig = reset;				// ���W���[�������쓮�񓯊����Z�b�g 

				/* �����͑S�Đ��G�b�W�쓮�Ƃ���B�����Œ�`���Ă��Ȃ��N���b�N�m�[�h�̎g�p�͋֎~ */
	wire			clock_sig = clk;				// ���W���[�������쓮�N���b�N 

	reg  [7:0]		width_reg;
	reg  [12:0]		pwmwidth_reg;
	reg				pwmout_reg;
	reg  [8:0]		dsm_reg;


/* ���ȍ~��wire�Areg�錾�͋֎~�� */

/* ===== �e�X�g�L�q ============== */



/* ===== ���W���[���\���L�q ============== */

	assign reg_readdata = width_reg;
	assign pwm_out = pwmout_reg;
	assign dsm_out = dsm_reg[8];

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			width_reg  <= 8'd128;
			pwmout_reg <= 1'b0;
			dsm_reg    <= 1'd0;
		end
		else begin
			if (reg_write) begin
				width_reg <= reg_writedata;
			end

			if (pwm_enable) begin
				if (pwm_timing) begin
					if (step_num == STARTSTEP) begin
						pwmout_reg   <= 1'b1;
						pwmwidth_reg <= pwmwidth_init_sig[12:0] + {5'b0, width_reg};
					end
					else if (step_num == pwmwidth_reg) begin
						pwmout_reg <= 1'b0;
					end
				end
			end
			else begin
				pwmout_reg <= 1'b0;
			end

			dsm_reg <= {1'b0, dsm_reg[7:0]} + {1'b0, width_reg};
		end
	end


endmodule
