#
# PERIDOT I2C driver (master) - callback module
# Copyright (C) 2016 @kimu_shu
#

proc initialize { args } {
	foreach pin [ list SCL SDA ] {
		set name [ format "pfc.%s_func" [ string tolower $pin ] ]
		add_module_sw_setting $name decimal_number
		set_module_sw_setting_property $name default_value -1
		set_module_sw_setting_property $name identifier PFC_${pin}_FUNC
		set_module_sw_setting_property $name destination system_h_define
		set_module_sw_setting_property $name description "Function number for $pin pin"

		set name [ format "pfc.%s_pins" [ string tolower $pin ] ]
		add_module_sw_setting $name hex_number
		set_module_sw_setting_property $name default_value 0x0
		set_module_sw_setting_property $name identifier PFC_${pin}_PINS
		set_module_sw_setting_property $name destination system_h_define
		set_module_sw_setting_property $name description "Pin mapping for $pin pin"
	}

	set name [ get_module_name ]
	set mod [ string toupper $name ]
	add_module_systemh_line DRIVER_INSTANCE "({ extern peridot_i2c_master_state $name; &$name; })"
}

# End of file
