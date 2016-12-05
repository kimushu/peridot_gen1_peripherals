#ifndef __PERIDOT_PFC_INTERFACE_H__
#define __PERIDOT_PFC_INTERFACE_H__

#include "alt_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct peridot_pfc_map_s
{
  alt_8 out_funcs[32];
  alt_8 in_bank;
  alt_8 in_func;
  alt_8 in_pins[32];
}
peridot_pfc_map;

extern void peridot_pfc_interface_init(alt_u32 base);

extern alt_u32 peridot_pfc_interface_direct_input(alt_u32 pin);
extern void peridot_pfc_interface_direct_output(alt_u32 pin, alt_u32 value);
extern void peridot_pfc_interface_select_output(alt_u32 pin, alt_u32 func);
extern alt_u32 peridot_pfc_interface_get_output_selection(alt_u32 pin);
extern void peridot_pfc_interface_select_input(alt_u32 bank, alt_u32 func, alt_u32 pin);

extern alt_u32 peridot_pfc_interface_direct_input_bank(alt_u32 bank);
extern void peridot_pfc_interface_direct_output_bank(alt_u32 bank, alt_u32 set, alt_u32 clear, alt_u32 toggle);
extern void peridot_pfc_interface_select_output_bank(alt_u32 bank, alt_u32 bits, alt_u32 func);

#define PERIDOT_PFC_INTERFACE_INSTANCE(name, dev) extern int alt_no_storage

#define PERIDOT_PFC_INTERFACE_INIT(name, dev) peridot_pfc_interface_init(name##_BASE)

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* __PERIDOT_PFC_INTERFACE_H__ */
