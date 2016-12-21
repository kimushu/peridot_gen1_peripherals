#include "system.h"
#include "peridot_swi_regs.h"
#ifdef ALT_ALLOW_CODE_AT_RESET
#ifdef SWI_FLASH_BOOT_ENABLE
# error "You have to turn off hal.linker.allow_code_at_reset to use SWI flash boot"
#endif  /* SWI_FLASH_BOOT_ENABLE */
#else   /* ALT_ALLOW_CODE_AT_RESET */

/*----------------------------------------------------------------
 * Register usage map
 */

.set noat
#define r_zero			r0
#define r_temp			r1	/* Temporary */
#define r_return		r2	/* Used in RCALL, RRET */
#define r_spim_base		r3	/* Base of EPCS/SPImaster controller */
#define r_elf_base		r4	/* Base of ELF data */
#define r_opt_count		r5	/* SOF option bit count */
#define r_elf_magic		r5	/* ELF header magic */
#define r_e_entry		r5	/* (e_entry) */
#define r_e_phoff		r6	/* (e_phoff) */
#define r_e_phentsize	r7	/* (e_phentsize) */
#define r_e_phnum		r8	/* (e_phnum) */
#define r_p_paddr		r9	/* (p_paddr) */
#define r_paddr_fend	r10	/* (p_paddr + p_filesz) */
#define r_paddr_mend	r11	/* (p_paddr + p_memsz) */
#define r_spim_count	r12	/* Used in flash_txrx_word */
#define r_spim_read		r13	/* Used in flash_txrx_word */
#define r_spim_write	r14	/* Used in flash_txrx_word */
#define r_p_type		r15	/* (p_type) */
/*
 * r15-r31 : Free area for decompressor
 * (If decompressor does not use flash_txrx_word, r12-r14 are also free)
 */

/*----------------------------------------------------------------
 * Constants
 */

#define ELF_HEADER_LE		0x464c457f
#define ET_EXEC				2
#define EM_NIOS2			0x71
#define PT_LOAD				1
#define PT_LOCOMP			0x63700000
#define PT_COMP_LZ4			(PT_LOCOMP|0x100)
#define PT_LOAD_LZ4			(PT_COMP_LZ4|PT_LOAD)

#define CMD_READ_BYTES			0x03
#define CMD_READ_SILICON_ID		0xab
#define CMD_READ_DEVICE_ID		0x9f

/*----------------------------------------------------------------
 * Macros
 */

/*
 * Pseudo move instruction with 32-bit immediate
 *   Operation: rA <= IMM32
 *   Syntax:    MOVI32 rA, IMM32
 */
.macro MOVI32 rA,IMM32
	.if (\IMM32 & 0xffff0000)
		movhi	\rA, %hi(\IMM32)
		.if (\IMM32 & 0x0000ffff)
			ori		\rA, \rA, %lo(\IMM32)
		.endif
	.else
		movui	\rA, %lo(\IMM32)
	.endif
.endm

/*
 * Relative call
 *   Syntax: RCALL label
 */
.macro RCALL label
	nextpc	r_return
	br		\label
.endm

/*
 * Return for RCALL
 *   Syntax: RRET
 */
.macro RRET
	addi	r_return, r_return, 4
	jmp		r_return
.endm

/*
 * Open flash connection (Start CS# output)
 */
.macro FLASH_OPEN
	MOVI32	r_temp, PERIDOT_SWI_FLASH_SS_MSK
	stwio	r_temp, 0(r_spim_base)
.endm

/*
 * Send and receive one byte
 */
.macro FLASH_TXRX rTX,rRX
99:	ldwio	r_temp, 0(r_spim_base)
	andi	r_temp, r_temp, PERIDOT_SWI_FLASH_RDY_MSK
	beq		r_temp, r_zero, 99b
	andi	r_temp, \rTX, PERIDOT_SWI_FLASH_TXDATA_MSK
	ori		r_temp, r_temp, PERIDOT_SWI_FLASH_SS_MSK | PERIDOT_SWI_FLASH_STA_MSK
	stwio	r_temp, 0(r_spim_base)
99:	ldwio	r_temp, 0(r_spim_base)
	andi	r_temp, r_temp, PERIDOT_SWI_FLASH_RDY_MSK
	beq		r_temp, r_zero, 99b
	ldwio	r_temp, 0(r_spim_base)
	andi	\rRX, r_temp, PERIDOT_SWI_FLASH_RXDATA_MSK
.endm

/*----------------------------------------------------------------
 * Reset vector
 */

	.section .entry, "xa"
	.align 5

	.global __reset_swi
	.type __reset_swi, @function
__reset_swi:
#if (NIOS2_ICACHE_SIZE > 0x0)
	MOVI32	r2, NIOS2_ICACHE_SIZE
0:
	initi	r2
	subi	r2, r2, NIOS2_ICACHE_LINE_SIZE
	bgt		r2, zero, 0b
#endif  /* NIOS2_ICACHE_SIZE > 0 */

#ifdef SWI_FLASH_BOOT_ENABLE
	movhi	r1, %hi(__loader)
	ori		r1, r1, %lo(__loader)
	jmp		r1
#else   /* SWI_FLASH_BOOT_ENABLE */
	movhi	r1, %hi(_start)
	ori		r1, r1, %lo(_start)
	jmp		r1
#endif  /* !SWI_FLASH_BOOT_ENABLE */

/*----------------------------------------------------------------
 * Boot loader
 */

#ifdef SWI_FLASH_BOOT_ENABLE
	.section .ipl, "xa"
	.align 2

	.global __loader
	.type __loader, @function
__loader:
	/* Clear processor status (Disable interrupts) */
	wrctl	status, r_zero

	/* Get register base */
	MOVI32	r_spim_base, (SWI_BASE + PERIDOT_SWI_FLASH_REG * 4)

	RCALL	flash_close

	/* Wait for EPCS ready */
1:	MOVI32	r_spim_write, (CMD_READ_DEVICE_ID * 0x01010101)
	RCALL	flash_txrx_word
	RCALL	flash_close
	MOVI32	r_temp, 0xff000000
	and		r_spim_read, r_spim_read, r_temp
	beq		r_spim_read, r_temp, 1b

#if !defined(SWI_FLASH_BOOT_AFTER_CFG)
	/*
	 * ELF image is located at the fixed position
	 * specified by SWI_FLASH_BOOT_OFFSET
	 */

	/* Check ELF header (e_ident) */
	MOVI32	r_elf_base, SWI_FLASH_BOOT_OFFSET | (CMD_READ_BYTES << 24)
	mov		r_spim_write, r_elf_base
	RCALL	flash_txrx_word
	RCALL	flash_txrx_word
	RCALL	flash_close
	MOVI32	r_elf_magic, ELF_HEADER_LE
	bne		r_spim_read, r_elf_magic, halt

#else	/* SWI_FLASH_BOOT_AFTER_CFG */

	/*
	 * ELF image is located just after FPGA configuration data
	 */

	/*
	 * Get configuration data length (only bit[27..0])
	 * r_elf_base <= 0b7650_0000_0000_0000_0000_0000_0000_0000 set27_25
	 * r_elf_base <= 0b0000_7650_0000_0000_0000_0000_0000_3210 loop[6]
	 * r_elf_base <= 0b3210_0000_7650_0000_0000_0000_0000_7654 loop[5]
	 * r_elf_base <= 0b7654_3210_0000_7650_0000_0000_0000_1098 loop[4]
	 * r_elf_base <= 0b1098_7654_3210_0000_7650_0000_0000_5432 loop[3]
	 * r_elf_base <= 0b5432_1098_7654_3210_0000_7650_0000_9876 loop[2]
	 * r_elf_base <= 0b9876_5432_1098_7654_3210_0000_7650_3210 loop[1]
	 * r_elf_base <= 0b9876_5432_1098_7654_3210_0000_7654_3210 set24
	 * r_elf_base <= 0b0000_7654_3210_9876_5432_1098_7654_3210 rotate
	 */
	MOVI32	r_spim_write, ((CMD_READ_BYTES << 24) + 33)
	RCALL	flash_txrx_word
	RCALL	flash_txrx_word
	slli	r_spim_read, r_spim_read, 1
	RCALL	extract_bit5s
	slli	r_elf_base, r_spim_read, 29	/* set27_25 */
	RCALL	flash_close
	MOVI32	r_spim_write, ((CMD_READ_BYTES << 24) + 48)
	RCALL	flash_txrx_word
	MOVI32	r_opt_count, 6
1:	RCALL	flash_txrx_word
	RCALL	extract_bit5s
	roli	r_elf_base, r_elf_base, (32-4)
	or		r_elf_base, r_elf_base, r_spim_read	/* loop[r_opt_count] */
	subi	r_opt_count, r_opt_count, 1
	bne		r_opt_count, r_zero, 1b
	RCALL	flash_txrx_word
	RCALL	flash_close
	srli	r_temp, r_spim_read, 1
	andi	r_temp, r_temp, 0x0010
	or		r_elf_base, r_elf_base, r_temp	/* set24 */
	roli	r_elf_base, r_elf_base, (32-12)	/* rotate */

	/* Convert bits to bytes */
	addi	r_elf_base, r_elf_base, 7
	srli	r_elf_base, r_elf_base, 3

	/*
	 * Check ELF header (e_ident)
	 * If no ELF header found at r_elf_base, retry at r_elf_base+1
	 * (This is workaround for difference for compression data)
	 */
	orhi	r_elf_base, r_elf_base, %hi(CMD_READ_BYTES << 24)
	mov		r_spim_write, r_elf_base
	RCALL	flash_txrx_word
	RCALL	flash_txrx_word
	RCALL	flash_close
	MOVI32	r_elf_magic, ELF_HEADER_LE
	beq		r_spim_read, r_elf_magic, 1f
	addi	r_elf_base, r_elf_base, 1
	mov		r_spim_write, r_elf_base
	RCALL	flash_txrx_word
	RCALL	flash_txrx_word
	RCALL	flash_close
	bne		r_spim_read, r_elf_magic, halt
1:
#endif	/* SWI_FLASH_BOOT_AFTER_CFG */

	/* Check e_type and e_machine */
	addi	r_spim_write, r_elf_base, 16	/* offsetof(Elf32_ehdr, e_type) */
	RCALL	flash_txrx_word
	RCALL	flash_txrx_word
	MOVI32	r_temp, (ET_EXEC | (EM_NIOS2 << 16))
	bne		r_spim_read, r_temp, halt

	/* Read e_entry, e_phoff, e_phentsize and e_phnum */
	RCALL	flash_txrx_word			/* e_version */
	RCALL	flash_txrx_word			/* e_entry */
	mov		r_e_entry, r_spim_read
	RCALL	flash_txrx_word			/* e_phoff */
	add		r_e_phoff, r_elf_base, r_spim_read
	RCALL	flash_txrx_word			/* e_shoff */
	RCALL	flash_txrx_word			/* e_flags */
	RCALL	flash_txrx_word			/* lo16:e_ehsize, hi16:e_phentsize */
	srli	r_e_phentsize, r_spim_read, 16
	RCALL	flash_txrx_word			/* lo16:e_phnum, hi16:e_shentsize */
	andi	r_e_phnum, r_spim_read, 0xffff
	RCALL	flash_close

load_program_header:
	/* Read Elf32_phdr fields */
	mov		r_spim_write, r_e_phoff
	RCALL	flash_txrx_word			/* opcode and address */
	RCALL	flash_txrx_word			/* p_type */
	mov		r_p_type, r_spim_read
	RCALL	flash_txrx_word			/* p_offset */
	add		r_spim_write, r_elf_base, r_spim_read
	RCALL	flash_txrx_word			/* p_vaddr */
	RCALL	flash_txrx_word			/* p_paddr */
	mov		r_p_paddr, r_spim_read
	RCALL	flash_txrx_word			/* p_filesz */
	add		r_paddr_fend, r_p_paddr, r_spim_read
	RCALL	flash_txrx_word			/* p_memsz */
	beq		r_spim_read, r_zero, next_program_header
	add		r_paddr_mend, r_p_paddr, r_spim_read
	beq		r_paddr_fend, r_p_paddr, fill_remainder_area
	RCALL	flash_close

	RCALL	flash_txrx_word			/* opcode and address */
#if defined(SWI_FLASH_BOOT_DECOMPRESS_LZ4)
	MOVI32	r_temp, PT_LOAD_LZ4
	beq		r_temp, r_p_type, decompress_lz4
#endif	/* SWI_FLASH_BOOT_DECOMPRESS_LZ4 */
	MOVI32	r_temp, PT_LOAD
	bne		r_temp, r_p_type, next_program_header

	/* Load uncompressed data (Must be 4-byte aligned) */
1:	RCALL	flash_txrx_word
	stw		r_spim_read, 0(r_p_paddr)
	addi	r_p_paddr, r_p_paddr, 4
	bltu	r_p_paddr, r_paddr_fend, 1b
	br		fill_remainder_area

	/* Fill remainder area (Must be 4-byte aligned) */
1:	stw		r_zero, 0(r_p_paddr)
	addi	r_p_paddr, r_p_paddr, 4
fill_remainder_area:
	bltu	r_p_paddr, r_paddr_mend, 1b

next_program_header:
	RCALL	flash_close
	add		r_e_phoff, r_e_phoff, r_e_phentsize
	addi	r_e_phnum, r_e_phnum, -1
	bne		r_e_phnum, r_zero, load_program_header

start_program:
#if (NIOS2_DCACHE_SIZE > 0x0)
	/* Flush all data cache */
	MOVI32	r_temp, NIOS2_DCACHE_SIZE
1:	addi	r_temp, r_temp, -32
	flushd	0(r_temp)
	bne		r_temp, r_zero, 1b
#endif  /* NIOS2_DCACHE_SIZE > 0 */

#if (NIOS2_ICACHE_SIZE > 0x0)
	/* Flush all instruction cache */
	MOVI32	r_temp, NIOS2_ICACHE_SIZE
1:	addi	r_temp, r_temp, -32
	flushi	r_temp
	bne		r_temp, r_zero, 1b
#endif  /* NIOS2_ICACHE_SIZE > 0 */
	flushp

	jmp		r_e_entry

#if defined(SWI_FLASH_BOOT_DECOMPRESS_LZ4)
#define r_lz4_15		r12
#define r_lz4_255		r13
#define r_lz4_lit		r14
#define r_lz4_match		r15
#define r_lz4_window	r16
decompress_lz4:
	/* Initialize constants */
	MOVI32	r_lz4_255, 255
	MOVI32	r_lz4_15, 15
1:	/* Read token */
	RCALL	flash_txrx_byte
	/* Read literal length */
	srli	r_lz4_lit, r_temp, 4
	/* Read match length (-4) */
	and		r_lz4_match, r_temp, r_lz4_15
	bne		r_lz4_lit, r_lz4_15, 3f
2:	/* Read additional literal length */
	RCALL	flash_txrx_byte
	add		r_lz4_lit, r_lz4_lit, r_temp
	beq		r_temp, r_lz4_255, 2b
3:	/* Read literal */
	add		r_lz4_lit, r_lz4_lit, r_p_paddr
	beq		r_p_paddr, r_lz4_lit, 5f
4:	RCALL	flash_txrx_byte
	stb		r_temp, 0(r_p_paddr)
	addi	r_p_paddr, r_p_paddr, 1
	bltu	r_p_paddr, r_lz4_lit, 4b
	/* Stop decompression if the destination reaches the end */
	beq		r_p_paddr, r_paddr_mend, next_program_header
5:	/* Read offset and calc window position */
	RCALL	flash_txrx_byte
	sub		r_lz4_window, r_p_paddr, r_temp
	RCALL	flash_txrx_byte
	slli	r_temp, r_temp, 8
	sub		r_lz4_window, r_lz4_window, r_temp
	bne		r_lz4_match, r_lz4_15, 7f
6:	/* Read additional match length */
	RCALL	flash_txrx_byte
	add		r_lz4_match, r_lz4_match, r_temp
	beq		r_temp, r_lz4_255, 6b
7:	/* Adjust match length */
	addi	r_lz4_match, r_lz4_match, 4
	/* Output matched data */
	add		r_lz4_match, r_lz4_match, r_lz4_window
8:	ldbu	r_temp, 0(r_lz4_window)
	stb		r_temp, 0(r_p_paddr)
	addi	r_lz4_window, r_lz4_window, 1
	addi	r_p_paddr, r_p_paddr, 1
	bltu	r_lz4_window, r_lz4_match, 8b
	br		1b
#endif	/* SWI_FLASH_BOOT_DECOMPRESS_LZ4 */

halt:
	RCALL	flash_close
1:	br		1b

/*
 * flash_close - Stop CS# output (Must be called by RCALL)
 */
flash_close:
	ldwio	r_temp, 0(r_spim_base)
	andi	r_temp, r_temp, PERIDOT_SWI_FLASH_RDY_MSK
	beq		r_temp, r_zero, flash_close
	stwio	r_zero, 0(r_spim_base)
	RRET

/*
 * flash_txrx_word - TX and RX 4 bytes (Must be called by RCALL)
 *   Input:  r_spim_write - TX data (MSB first, big-endian)
 *   Output: r_spim_read  - RX data (MSB first, little-endian)
 */
flash_txrx_word:
	FLASH_OPEN
	MOVI32	r_spim_count, 4
	mov		r_spim_read, r_zero
1:	roli	r_spim_write, r_spim_write, 8
	FLASH_TXRX r_spim_write, r_temp
	or		r_spim_read, r_spim_read, r_temp
	roli	r_spim_read, r_spim_read, 24
	addi	r_spim_count, r_spim_count, -1
	bne		r_spim_count, r_zero, 1b
	RRET

/*
 * flash_txrx_byte - TX and RX 1 byte (Must be called by RCALL)
 *   Input:  r_zero - TX data (Fixed to 0x00)
 *   Output: r_temp - RX data
 */
flash_txrx_byte:
	FLASH_TXRX r_zero, r_temp
	RRET

#if defined(SWI_FLASH_BOOT_AFTER_CFG)
/*
 * extract_bit5s - Extract bit5 of each byte (Must be called by RCALL)
 *   Input:  r_spim_read (0b**A*****_**B*****_**C*****_**D*****)
 *   Output: r_spim_read (0b00000000_00000000_00000000_0000ABCD)
 */
extract_bit5s:
	/* xxAxxxxxxxBxxxxxxxCxxxxxxxDxxxxx (r_spim_read) */
	ori		r_spim_read, r_spim_read, 0xdfdf
	orhi	r_spim_read, r_spim_read, 0xdfdf
	/* 11A1111111B1111111C1111111D11111 (r_spim_read) */
	srli	r_temp, r_spim_read, 7
	/* 000011111A1111111B1111111C111111 (r_temp) */
	and		r_temp, r_temp, r_spim_read
	/* 000011111AB111111BC111111CD11111 (r_temp) */
	srli	r_spim_read, r_temp, 14
	/* 00000000000000000011111AB1111111 (r_spim_read) */
	and		r_temp, r_temp, r_spim_read
	/* 000000000000000000C1111ABCD11111 (r_temp) */
	srli	r_temp, r_temp, 5
	andi	r_spim_read, r_temp, 0xf
	/* 0000000000000000000000000000ABCD (r_spim_read) */
	RRET
#endif  /* SWI_FLASH_BOOT_AFTER_CFG */

	.long	_alt_partition_ipl_start

#endif  /* SWI_FLASH_BOOT_ENABLE */
#endif  /* !ALT_ALLOW_CODE_AT_RESET */
