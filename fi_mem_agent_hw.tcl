# fi_mem_agent "fi_mem_agent" v5.0
# Mamoutova 2013.12.18.14:42:36
# fault injection agent for memory, for external connection
# 

# 
# request TCL package from ACDS 13.1
# 
package require -exact qsys 13.1


# 
# module fi_mem_agent
# 
set_module_property DESCRIPTION "fault injection agent for memory, for external connection"
set_module_property NAME fi_mem_agent
set_module_property VERSION 5.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR Mamoutova
set_module_property DISPLAY_NAME fi_mem_agent
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true
set_module_property ANALYZE_HDL AUTO
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL fi_mem_agent
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
add_fileset_file fi_mem_agent.vhd VHDL PATH hdl/fi_mem_agent.vhd TOP_LEVEL_FILE


# 
# parameters
# 
add_parameter use_ack BOOLEAN 32 "use_ack = 0 - two-cycle read/one-cycle write"
set_parameter_property use_ack DEFAULT_VALUE TRUE
set_parameter_property use_ack DISPLAY_NAME "USE ACKNOWLEDGE"
set_parameter_property use_ack DESCRIPTION "use_ack = 0 - two-cycle read/one-cycle write"
set_parameter_property use_ack HDL_PARAMETER true
add_parameter aw INTEGER 32 "aw = log2(mem_size)-log2(dw/8). E.g. 2K memory, dw=32 => aw=11-2=9"
set_parameter_property aw DEFAULT_VALUE 32
set_parameter_property aw DISPLAY_NAME "Address width"
set_parameter_property aw TYPE INTEGER
set_parameter_property aw UNITS Bits
set_parameter_property aw ALLOWED_RANGES 1:2147483647
set_parameter_property aw DESCRIPTION "aw = log2(mem_size)-log2(dw/8). E.g. 2K memory, dw=32 => aw=11-2=9"
set_parameter_property aw HDL_PARAMETER true
add_parameter dw INTEGER 32 "Data word width."
set_parameter_property dw DEFAULT_VALUE 32
set_parameter_property dw DISPLAY_NAME "Data word width"
set_parameter_property dw TYPE INTEGER
set_parameter_property dw UNITS Bits
set_parameter_property dw ALLOWED_RANGES 1:2147483647
set_parameter_property dw DESCRIPTION "Data word width."
set_parameter_property dw HDL_PARAMETER true

# 
# display items
# 
add_display_item "" "Control Port Widths" GROUP ""


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point original_interface
# 
add_interface original_interface avalon end
set_interface_property original_interface addressUnits WORDS
set_interface_property original_interface associatedClock clock
set_interface_property original_interface associatedReset reset_sink
set_interface_property original_interface bitsPerSymbol 8
set_interface_property original_interface burstOnBurstBoundariesOnly false
set_interface_property original_interface burstcountUnits WORDS
set_interface_property original_interface explicitAddressSpan 0
set_interface_property original_interface holdTime 0
set_interface_property original_interface linewrapBursts false
set_interface_property original_interface maximumPendingReadTransactions 0
set_interface_property original_interface readLatency 0
set_interface_property original_interface readWaitTime 1
set_interface_property original_interface setupTime 0
set_interface_property original_interface timingUnits Cycles
set_interface_property original_interface writeWaitTime 0
set_interface_property original_interface ENABLED true
set_interface_property original_interface EXPORT_OF ""
set_interface_property original_interface PORT_NAME_MAP ""
set_interface_property original_interface SVD_ADDRESS_GROUP ""

add_interface_port original_interface WE write Input 1
add_interface_port original_interface A address Input aw
add_interface_port original_interface D writedata Input dw
add_interface_port original_interface Dout readdata Output dw
add_interface_port original_interface ACK waitrequest_n Output 1
add_interface_port original_interface CE chipselect Input 1
set_interface_assignment original_interface embeddedsw.configuration.isFlash 0
set_interface_assignment original_interface embeddedsw.configuration.isMemoryDevice 1
set_interface_assignment original_interface embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment original_interface embeddedsw.configuration.isPrintableDevice 0


# 
# connection point memory_interface
# 
add_interface memory_interface avalon start
set_interface_property memory_interface addressUnits WORDS
set_interface_property memory_interface associatedClock clock
set_interface_property memory_interface associatedReset reset_sink
set_interface_property memory_interface bitsPerSymbol 8
set_interface_property memory_interface burstOnBurstBoundariesOnly false
set_interface_property memory_interface burstcountUnits WORDS
set_interface_property memory_interface doStreamReads false
set_interface_property memory_interface doStreamWrites false
set_interface_property memory_interface holdTime 0
set_interface_property memory_interface linewrapBursts false
set_interface_property memory_interface maximumPendingReadTransactions 0
set_interface_property memory_interface readLatency 1
set_interface_property memory_interface readWaitTime 1
set_interface_property memory_interface setupTime 0
set_interface_property memory_interface timingUnits Cycles
set_interface_property memory_interface writeWaitTime 0
set_interface_property memory_interface ENABLED true
set_interface_property memory_interface EXPORT_OF ""
set_interface_property memory_interface PORT_NAME_MAP ""
set_interface_property memory_interface SVD_ADDRESS_GROUP ""

add_interface_port memory_interface CE_m chipselect Output 1
add_interface_port memory_interface WE_m write Output 1
add_interface_port memory_interface D_m writedata Output dw
add_interface_port memory_interface Dout_m readdata Input dw
add_interface_port memory_interface ACK_m waitrequest_n Input 1
add_interface_port memory_interface A_m address Output aw


# 
# connection point reset_sink
# 
add_interface reset_sink reset end
set_interface_property reset_sink associatedClock clock
set_interface_property reset_sink synchronousEdges DEASSERT
set_interface_property reset_sink ENABLED true
set_interface_property reset_sink EXPORT_OF ""
set_interface_property reset_sink PORT_NAME_MAP ""
set_interface_property reset_sink SVD_ADDRESS_GROUP ""

add_interface_port reset_sink rst_n reset_n Input 1


# 
# connection point conduit_end
# 
add_interface conduit_end conduit end
set_interface_property conduit_end associatedClock clock
set_interface_property conduit_end associatedReset ""
set_interface_property conduit_end ENABLED true
set_interface_property conduit_end EXPORT_OF ""
set_interface_property conduit_end PORT_NAME_MAP ""
set_interface_property conduit_end SVD_ADDRESS_GROUP ""

add_interface_port conduit_end fi_wr export Input 1
add_interface_port conduit_end fi_A export Input aw
add_interface_port conduit_end fi_Mask export Input dw
add_interface_port conduit_end fi_data_r export Output dw
add_interface_port conduit_end fi_ack export Output 1
add_interface_port conduit_end fi_ena export Input 1

