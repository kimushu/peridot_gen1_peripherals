#include <errno.h>
#include "alt_types.h"
#include "sys/alt_irq.h"
#include "peridot_swi.h"
#include "peridot_swi_regs.h"

static peridot_swi_state *swi_sp;

#ifndef ALT_ALLOW_CODE_AT_RESET
/* This dummy variable prevents linker from dropping startup sections */
extern int __reset_swi;
__attribute__((used)) static const void *peridot_swi_dummy = &__reset_swi;
#endif

#ifdef ALT_ENHANCED_INTERRUPT_API_PRESENT
static void peridot_swi_irq(void *context)
#else
static void peridot_swi_irq(void *context, alt_u32 id)
#endif
{
  peridot_swi_state *sp = (peridot_swi_state *)context;

  // Clear SWI request
  IOWR_PERIDOT_SWI_SWI(sp->base, 0);

  if (sp->isr)
  {
    (*sp->isr)(sp->param);
  }
}

void peridot_swi_init(peridot_swi_state *sp,
                      alt_u32 irq_controller_id, alt_u32 irq)
{
  swi_sp = sp;

#ifdef ALT_ENHANCED_INTERRUPT_API_PRESENT
  alt_ic_isr_register(irq_controller_id, irq, peridot_swi_irq, sp, NULL);
#else
  (void)irq_controller_id;
  alt_irq_register(irq, sp, peridot_swi_irq);
#endif
}

int peridot_swi_set_handler(void (*isr)(void *), void *param)
{
  if (!swi_sp)
  {
    return -ENODEV;
  }

  swi_sp->isr = NULL;
  swi_sp->param = param;
  swi_sp->isr = isr;
  return 0;
}

int peridot_swi_write_message(alt_u32 value)
{
  if (!swi_sp)
  {
    return -ENODEV;
  }

  IOWR_PERIDOT_SWI_MESSAGE(swi_sp->base, value);
  return 0;
}

int peridot_swi_read_message(alt_u32 *value)
{
  if (!swi_sp)
  {
    return -ENODEV;
  }

  *value = IORD_PERIDOT_SWI_MESSAGE(swi_sp->base);
  return 0;
}

int peridot_swi_flash_command(alt_u32 write_length, const alt_u8 *write_data,
                              alt_u32 read_length, alt_u8 *read_data,
                              alt_u32 flags)
{
  alt_u32 base;
  alt_u32 received;

  if (!swi_sp)
  {
    return -ENODEV;
  }

  base = swi_sp->base;

  while ((IORD_PERIDOT_SWI_FLASH(base) &
          PERIDOT_SWI_FLASH_RDY_MSK) == 0);

  IOWR_PERIDOT_SWI_FLASH(base, PERIDOT_SWI_FLASH_SS_MSK);

  for (; write_length > 0; --write_length)
  {
    IOWR_PERIDOT_SWI_FLASH(base,
        PERIDOT_SWI_FLASH_SS_MSK | PERIDOT_SWI_FLASH_STA_MSK |
        (((*write_data++) << PERIDOT_SWI_FLASH_TXDATA_OFST) &
          PERIDOT_SWI_FLASH_TXDATA_MSK));

    while ((IORD_PERIDOT_SWI_FLASH(base) & PERIDOT_SWI_FLASH_RDY_MSK) == 0);
  }

  for (; read_length > 0; --read_length)
  {
    IOWR_PERIDOT_SWI_FLASH(base,
        PERIDOT_SWI_FLASH_SS_MSK | PERIDOT_SWI_FLASH_STA_MSK |
        ((0x00 << PERIDOT_SWI_FLASH_TXDATA_OFST) &
          PERIDOT_SWI_FLASH_TXDATA_MSK));

    while (((received = IORD_PERIDOT_SWI_FLASH(base)) &
            PERIDOT_SWI_FLASH_RDY_MSK) == 0);

    *read_data++ = (received & PERIDOT_SWI_FLASH_RXDATA_MSK) >>
                    PERIDOT_SWI_FLASH_RXDATA_OFST;
  }

  if ((flags & PERIDOT_SWI_FLASH_COMMAND_MERGE) == 0)
  {
    IOWR_PERIDOT_SWI_FLASH(base, 0);
  }

  return read_length;
}
