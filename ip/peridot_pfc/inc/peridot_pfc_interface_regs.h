#ifndef __PERIDOT_PFC_INTERFACE_REGS_H__
#define __PERIDOT_PFC_INTERFACE_REGS_H__

#include <io.h>

/* Constants */
#define PERIDOT_PFC_BANK_COUNT              (4)
#define PERIDOT_PFC_BANK_SHIFT              (3)
#define PERIDOT_PFC_BANK_WIDTH              (1<<PERIDOT_PFC_BANK_SHIFT)
#define PERIDOT_PFC_BANK_MASK               (PERIDOT_PFC_BANK_WIDTH-1)

/* Direct PIO input register */
#define PERIDOT_PFC_DIRIN_REG               0
#define IOADDR_PERIDOT_PFC_DIRIN(base, bank) \
  __IO_CALC_ADDRESS_NATIVE(base, PERIDOT_PFC_DIRIN_REG + 4 * (bank))
#define IORD_PERIDOT_PFC_DIRIN(base, bank) \
  IORD(base, PERIDOT_PFC_DIRIN_REG + 4 * (bank))

#define PERIDOT_PFC_DIRIN_DIN_MSK           (0x000000ffu)
#define PERIDOT_PFC_DIRIN_DIN_OFST          (0)

/* Direct PIO output register */
#define PERIDOT_PFC_DIROUT_REG              1
#define IOADDR_PERIDOT_PFC_DIROUT(base, bank) \
  __IO_CALC_ADDRESS_NATIVE(base, PERIDOT_PFC_DIROUT_REG + 4 * (bank))
#define IORD_PERIDOT_PFC_DIROUT(base, bank) \
  IORD(base, PERIDOT_PFC_DIROUT_REG + 4 * (bank))
#define IOWR_PERIDOT_PFC_DIROUT(base, bank, data) \
  IOWR(base, PERIDOT_PFC_DIROUT_REG + 4 * (bank), data)

#define PERIDOT_PFC_DIROUT_DOUT_MSK         (0x000000ffu)
#define PERIDOT_PFC_DIROUT_DOUT_OFST        (0)
#define PERIDOT_PFC_DIROUT_MASK_MSK         (0x0000ff00u)
#define PERIDOT_PFC_DIROUT_MASK_OFST        (8)

/* Output function register */
#define PERIDOT_PFC_OUTPUT_REG              2
#define IOADDR_PERIDOT_PFC_OUTPUT(base, bank) \
  __IO_CALC_ADDRESS_NATIVE(base, PERIDOT_PFC_OUTPUT_REG + 4 * (bank))
#define IORD_PERIDOT_PFC_OUTPUT(base, bank) \
  IORD(base, PERIDOT_PFC_OUTPUT_REG + 4 * (bank))
#define IOWR_PERIDOT_PFC_OUTPUT(base, bank, data) \
  IOWR(base, PERIDOT_PFC_OUTPUT_REG + 4 * (bank), data)

#define PERIDOT_PFC_OUTPUT_PIN0_MSK         (0x0000000fu)
#define PERIDOT_PFC_OUTPUT_PIN0_OFST        (0)
#define PERIDOT_PFC_OUTPUT_PIN1_MSK         (0x000000f0u)
#define PERIDOT_PFC_OUTPUT_PIN1_OFST        (4)
#define PERIDOT_PFC_OUTPUT_PIN2_MSK         (0x00000f00u)
#define PERIDOT_PFC_OUTPUT_PIN2_OFST        (8)
#define PERIDOT_PFC_OUTPUT_PIN3_MSK         (0x0000f000u)
#define PERIDOT_PFC_OUTPUT_PIN3_OFST        (12)
#define PERIDOT_PFC_OUTPUT_PIN4_MSK         (0x000f0000u)
#define PERIDOT_PFC_OUTPUT_PIN4_OFST        (16)
#define PERIDOT_PFC_OUTPUT_PIN5_MSK         (0x00f00000u)
#define PERIDOT_PFC_OUTPUT_PIN5_OFST        (20)
#define PERIDOT_PFC_OUTPUT_PIN6_MSK         (0x0f000000u)
#define PERIDOT_PFC_OUTPUT_PIN6_OFST        (24)
#define PERIDOT_PFC_OUTPUT_PIN7_MSK         (0xf0000000u)
#define PERIDOT_PFC_OUTPUT_PIN7_OFST        (28)

#define PERIDOT_PFC_OUTPUT_PINX_MSK         (0xf)
#define PERIDOT_PFC_OUTPUT_PINX_WIDTH       (4)
#define PERIDOT_PFC_OUTPUT_PINX_HIZ         (0x0)
#define PERIDOT_PFC_OUTPUT_PINX_DOUT        (0x1)
#define PERIDOT_PFC_OUTPUT_PINX_AUX0        (0x4)
#define PERIDOT_PFC_OUTPUT_PINX_AUX1        (0x5)
#define PERIDOT_PFC_OUTPUT_PINX_AUX2        (0x6)
#define PERIDOT_PFC_OUTPUT_PINX_AUX3        (0x7)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC0       (0x8)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC1       (0x9)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC2       (0xa)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC3       (0xb)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC4       (0xc)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC5       (0xd)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC6       (0xe)
#define PERIDOT_PFC_OUTPUT_PINX_FUNC7       (0xf)

/* Input function register */
#define PERIDOT_PFC_INPUT_REG               3
#define IOADDR_PERIDOT_PFC_INPUT(base, bank) \
  __IO_CALC_ADDRESS_NATIVE(base, PERIDOT_PFC_INPUT_REG + 4 * (bank))
#define IORD_PERIDOT_PFC_INPUT(base, bank) \
  IORD(base, PERIDOT_PFC_INPUT_REG + 4 * (bank))
#define IOWR_PERIDOT_PFC_INPUT(base, bank, data) \
  IOWR(base, PERIDOT_PFC_INPUT_REG + 4 * (bank), data)

#define PERIDOT_PFC_INPUT_FUNC0_MSK         (0x0000000fu)
#define PERIDOT_PFC_INPUT_FUNC0_OFST        (0)
#define PERIDOT_PFC_INPUT_FUNC1_MSK         (0x000000f0u)
#define PERIDOT_PFC_INPUT_FUNC1_OFST        (4)
#define PERIDOT_PFC_INPUT_FUNC2_MSK         (0x00000f00u)
#define PERIDOT_PFC_INPUT_FUNC2_OFST        (8)
#define PERIDOT_PFC_INPUT_FUNC3_MSK         (0x0000f000u)
#define PERIDOT_PFC_INPUT_FUNC3_OFST        (12)
#define PERIDOT_PFC_INPUT_FUNC4_MSK         (0x000f0000u)
#define PERIDOT_PFC_INPUT_FUNC4_OFST        (16)
#define PERIDOT_PFC_INPUT_FUNC5_MSK         (0x00f00000u)
#define PERIDOT_PFC_INPUT_FUNC5_OFST        (20)
#define PERIDOT_PFC_INPUT_FUNC6_MSK         (0x0f000000u)
#define PERIDOT_PFC_INPUT_FUNC6_OFST        (24)
#define PERIDOT_PFC_INPUT_FUNC7_MSK         (0xf0000000u)
#define PERIDOT_PFC_INPUT_FUNC7_OFST        (28)

#define PERIDOT_PFC_INPUT_FUNCX_MSK         (0xf)
#define PERIDOT_PFC_INPUT_FUNCX_WIDTH       (4)
#define PERIDOT_PFC_INPUT_FUNCX_LOW         (0x0)
#define PERIDOT_PFC_INPUT_FUNCX_HIGH        (0x1)
#define PERIDOT_PFC_INPUT_FUNCX_AUX0        (0x2)
#define PERIDOT_PFC_INPUT_FUNCX_AUX1        (0x3)
#define PERIDOT_PFC_INPUT_FUNCX_AUX2        (0x4)
#define PERIDOT_PFC_INPUT_FUNCX_AUX3        (0x5)
#define PERIDOT_PFC_INPUT_FUNCX_AUX4        (0x6)
#define PERIDOT_PFC_INPUT_FUNCX_AUX5        (0x7)
#define PERIDOT_PFC_INPUT_FUNCX_PIN0        (0x8)
#define PERIDOT_PFC_INPUT_FUNCX_PIN1        (0x9)
#define PERIDOT_PFC_INPUT_FUNCX_PIN2        (0xa)
#define PERIDOT_PFC_INPUT_FUNCX_PIN3        (0xb)
#define PERIDOT_PFC_INPUT_FUNCX_PIN4        (0xc)
#define PERIDOT_PFC_INPUT_FUNCX_PIN5        (0xd)
#define PERIDOT_PFC_INPUT_FUNCX_PIN6        (0xe)
#define PERIDOT_PFC_INPUT_FUNCX_PIN7        (0xf)

#endif /* __PERIDOT_PFC_INTERFACE_REGS_H__ */
