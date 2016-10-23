#include <errno.h>
#include "alt_types.h"
#include "sys/alt_irq.h"
#include "peridot_i2c_master.h"
#include "peridot_i2c_regs.h"

#ifdef ALT_ENHANCED_INTERRUPT_API_PRESENT
static void peridot_i2c_master_irq(void *context)
#else
static void peridot_i2c_master_irq(void *context, alt_u32 id)
#endif
{
  peridot_i2c_master_state *sp = (peridot_i2c_master_state *)context;

#ifdef __tinythreads__
  sem_post(&sp->done);
#else
  sp->done = 1;
#endif
}

void peridot_i2c_master_init(peridot_i2c_master_state *sp,
                             alt_u32 irq_controller_id, alt_u32 irq)
{
#ifdef __tinythreads__
  pthread_mutex_init(&sp->lock, NULL);
  sem_init(&sp->done, 0, 0);
#else
  sp->lock = 0;
  sp->done = 0;
#endif

  /* Clear reset */
  IOWR_PERIDOT_I2C_CONFIG(sp->base, PERIDOT_I2C_CONFIG_CLKDIV_MSK);

  /* Wait for ready */
  while ((IORD_PERIDOT_I2C_ACCESS(sp->base) & PERIDOT_I2C_ACCESS_RDY_MSK) == 0);

#ifdef ALT_ENHANCED_INTERRUPT_API_PRESENT
  alt_ic_isr_register(irq_controller_id, irq, peridot_i2c_master_irq, sp, NULL);
#else
  (void)irq_controller_id;
  alt_irq_register(irq, sp, peridot_i2c_master_irq);
#endif
}

int peridot_i2c_master_get_clkdiv(peridot_i2c_master_state *sp, alt_u32 bitrate, alt_u32 *clkdiv)
{
  alt_32 value;
  value = (sp->freq / bitrate / 4) - 5;
  if (value < 0)
  {
    return -EINVAL;
  }

  *clkdiv = value;
  return 0;
}

static alt_u32 wait(peridot_i2c_master_state *sp)
{
  alt_u32 resp;

  do
  {
#ifdef __tinythreads__
    sem_wait(&sp->done);
#else
    while (!sp->done);
#endif
  }
  while (((resp = IORD_PERIDOT_I2C_CONFIG(sp->base)) &
          PERIDOT_I2C_ACCESS_RDY_MSK) == 0);

  return resp;
}

static int transfer(peridot_i2c_master_state *sp,
                    alt_u16 slave_address, alt_u32 clkdiv,
                    alt_u32 write_length, const alt_u8 *write_data,
                    alt_u32 read_length, alt_u8 *read_data)
{
  alt_u32 base = sp->base;
  alt_u32 resp;
  alt_u8 saddr;

  if (slave_address & PERIDOT_I2C_MASTER_10BIT_ADDRESS)
  {
    return -ENOTSUP;  // TODO
  }
  else
  {
    saddr = (slave_address << 1) & 0xfe;
  }

  /* Wait for ready */
  while ((IORD_PERIDOT_I2C_ACCESS(base) & PERIDOT_I2C_ACCESS_RDY_MSK) == 0);

  /* Set CLKDIV */
  IOWR_PERIDOT_I2C_CONFIG(base,
      (clkdiv << PERIDOT_I2C_CONFIG_CLKDIV_OFST) &
        PERIDOT_I2C_CONFIG_CLKDIV_MSK);

  if (write_length > 0)
  {
    /* Start condition & slave address for writing */
    IOWR_PERIDOT_I2C_ACCESS(base,
        PERIDOT_I2C_ACCESS_IRQENA_MSK |
        PERIDOT_I2C_ACCESS_SC_MSK |
        PERIDOT_I2C_ACCESS_STA_MSK |
        (((saddr | 0x00) << PERIDOT_I2C_ACCESS_TXDATA_OFST) &
          PERIDOT_I2C_ACCESS_TXDATA_MSK)
    );

    resp = wait(sp);
    if (resp & PERIDOT_I2C_ACCESS_NACK_MSK)
    {
      /* Stop condition with dummy write */
      IOWR_PERIDOT_I2C_ACCESS(base,
          PERIDOT_I2C_ACCESS_IRQENA_MSK |
          PERIDOT_I2C_ACCESS_PC_MSK |
          PERIDOT_I2C_ACCESS_STA_MSK |
          PERIDOT_I2C_ACCESS_TXDATA_MSK
      );
      wait(sp);
      return -ENOENT;
    }

    for (; write_length > 0; --write_length)
    {
      /* Write data */
      IOWR_PERIDOT_I2C_ACCESS(base,
          PERIDOT_I2C_ACCESS_IRQENA_MSK |
          ((write_length == 1) && (read_length == 0) ?
            PERIDOT_I2C_ACCESS_PC_MSK : 0) |
          PERIDOT_I2C_ACCESS_STA_MSK |
          ((*write_data++ << PERIDOT_I2C_ACCESS_TXDATA_OFST) &
            PERIDOT_I2C_ACCESS_TXDATA_MSK)
      );

      resp = wait(sp);
      if (resp & PERIDOT_I2C_ACCESS_NACK_MSK)
      {
        if ((write_length > 1) || (read_length > 0))
        {
          /* Stop condition with dummy write */
          IOWR_PERIDOT_I2C_ACCESS(base,
              PERIDOT_I2C_ACCESS_IRQENA_MSK |
              PERIDOT_I2C_ACCESS_PC_MSK |
              PERIDOT_I2C_ACCESS_STA_MSK |
              PERIDOT_I2C_ACCESS_TXDATA_MSK
          );
          wait(sp);
        }
        return -ECANCELED;
      }
    }
  }

  if (read_length > 0)
  {
    /* (Re-)start condition & slave address for reading */
    IOWR_PERIDOT_I2C_ACCESS(base,
        PERIDOT_I2C_ACCESS_IRQENA_MSK |
        PERIDOT_I2C_ACCESS_SC_MSK |
        PERIDOT_I2C_ACCESS_STA_MSK |
        (((saddr | 0x01) << PERIDOT_I2C_ACCESS_TXDATA_OFST) &
          PERIDOT_I2C_ACCESS_TXDATA_MSK)
    );

    resp = wait(sp);
    if (resp & PERIDOT_I2C_ACCESS_NACK_MSK)
    {
      /* Stop condition with dummy read */
      IOWR_PERIDOT_I2C_ACCESS(base,
          PERIDOT_I2C_ACCESS_IRQENA_MSK |
          PERIDOT_I2C_ACCESS_PC_MSK |
          PERIDOT_I2C_ACCESS_NACK_MSK |
          PERIDOT_I2C_ACCESS_DIR_MSK |
          PERIDOT_I2C_ACCESS_STA_MSK
      );
      wait(sp);
      return -ENOENT;
    }

    for (; read_length > 0; --read_length)
    {
      /* Read data */
      IOWR_PERIDOT_I2C_ACCESS(base,
          PERIDOT_I2C_ACCESS_IRQENA_MSK |
          ((read_length == 1) ?
            PERIDOT_I2C_ACCESS_PC_MSK |
            PERIDOT_I2C_ACCESS_NACK_MSK : 0) |
          PERIDOT_I2C_ACCESS_DIR_MSK |
          PERIDOT_I2C_ACCESS_STA_MSK
      );

      resp = wait(sp);
      *read_data++ = (resp & PERIDOT_I2C_ACCESS_RXDATA_MSK) >>
                      PERIDOT_I2C_ACCESS_RXDATA_OFST;
    }
  }

  return 0;
}

int peridot_i2c_master_transfer(peridot_i2c_master_state *sp,
                                alt_u16 slave_address, alt_u32 clkdiv,
                                alt_u32 write_length, const alt_u8 *write_data,
                                alt_u32 read_length, alt_u8 *read_data)
{
  int result;

#ifdef __tinythreads__
  pthread_mutex_lock(&sp->lock);
#else
  {
    alt_u8 locked;
    alt_irq_context context = alt_irq_disable_all();
    locked = sp->lock;
    sp->lock = 1;
    alt_irq_enable_all(context);
    if (locked)
    {
      return -EAGAIN;
    }
  }
#endif

  result = transfer(sp, slave_address, clkdiv,
                    write_length, write_data, read_length, read_data);

#ifdef __tinythreads__
  pthread_mutex_unlock(&sp->lock);
#else
  sp->lock = 0;
#endif

  return result;
}

