#ifndef __PERIDOT_I2C_MASTER_H__
#define __PERIDOT_I2C_MASTER_H__

#include "alt_types.h"
#ifdef __tinythreads__
# include <pthread.h>
# include <semaphore.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct peridot_i2c_master_state_s
{
  struct peridot_i2c_master_state_s *next;
  const char *name;
  alt_u32 base;
  alt_u32 freq;
  alt_u8  pfc_scl_func;
  alt_u32 pfc_scl_pins;
  alt_u8  pfc_sda_func;
  alt_u32 pfc_sda_pins;
#ifdef __tinythreads__
  pthread_mutex_t lock;
  sem_t done;
#else
  volatile alt_u8 lock;
  volatile alt_u8 done;
#endif
}
peridot_i2c_master_state;

#define PERIDOT_I2C_MASTER_STATE_INSTANCE(name, state) \
  peridot_i2c_master_state state =              \
  {                                             \
    NULL,                                       \
    #name,                                      \
    name##_BASE,                                \
    name##_FREQ,                                \
    name##_PFC_SCL_FUNC, name##_PFC_SCL_PINS,   \
    name##_PFC_SDA_FUNC, name##_PFC_SDA_PINS,   \
  }

extern void peridot_i2c_master_init(peridot_i2c_master_state *state,
                                    alt_u32 irq_controller_id, alt_u32 irq);

#define PERIDOT_I2C_MASTER_STATE_INIT(name, state) \
  peridot_i2c_master_init(                  \
    &state,                                 \
    name##_IRQ_INTERRUPT_CONTROLLER_ID,     \
    name##_IRQ                              \
  )

extern int peridot_i2c_master_get_clkdiv(peridot_i2c_master_state *sp, alt_u32 bitrate, alt_u32 *clkdiv);

#define PERIDOT_I2C_MASTER_10BIT_ADDRESS    (0x8000)

extern int peridot_i2c_master_transfer(peridot_i2c_master_state *sp,
                                       alt_u16 slave_address, alt_u32 clkdiv,
                                       alt_u32 write_length, const alt_u8 *write_data,
                                       alt_u32 read_length, alt_u8 *read_data);

#define PERIDOT_I2C_MASTER_INSTANCE(name, state) \
  PERIDOT_I2C_MASTER_STATE_INSTANCE(name, state)

#define PERIDOT_I2C_MASTER_INIT(name, state) \
  PERIDOT_I2C_MASTER_STATE_INIT(name, state)

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* __PERIDOT_I2C_MASTER_H__ */
