#
# fi_mem_agent_sw.tcl
#

# Create a new driver
create_driver fi_mem_agent_driver

# Associate it with some hardware known as "fi_mem_agent"
set_sw_property hw_class_name fi_mem_agent

# The version of this driver
set_sw_property version 2.0
set_sw_property min_compatible_hw_version 1.0

# Location in generated BSP that above sources will be copied into
set_sw_property bsp_subdirectory HAL


# Interrupt properties:
# This peripheral has an IRQ output but the driver doesn't currently
# have any interrupt service routine. To ensure that the BSP tools
# do not otherwise limit the BSP functionality for users of the
# Nios II enhanced interrupt port, these settings advertise 
# compliance with both legacy and enhanced interrupt APIs, and to state
# that any driver ISR supports preemption. If an interrupt handler
# is added to this driver, these must be re-examined for validity.
#set_sw_property isr_preemption_supported true
#set_sw_property supported_interrupt_apis "legacy_interrupt_api enhanced_interrupt_api"

#
# Source file listings...
#

# C/C++ source files
add_sw_property c_source HAL/src/fi.c

# Include files
add_sw_property include_source HAL/inc/fi.h

# This driver supports HAL & UCOSII BSP (OS) types
add_sw_property supported_bsp_type HAL

# End of file
