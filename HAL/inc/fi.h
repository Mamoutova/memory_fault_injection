/*
 * fi.h
 *
 *  Created on: 20.10.2013
 *      Author: olia
 */

#ifndef FI_H_
#define FI_H_
#include "sys/alt_stdio.h"
#include "sys/alt_irq.h"
#include "altera_avalon_timer_regs.h"

#define FI_MEM_AGENT_CONTROL_SPAN FI_CONNECTOR_SPAN
#define FI_MEM_AGENT_CONTROL_BASE FI_CONNECTOR_BASE

extern volatile struct fi_point_type fi_value;

struct fi_point_type {
	unsigned int address;
	unsigned int mask;
};

void fi_irq_init(void);
static void handle_fi_timer_interrupt(void* context);
static void handle_wd_timer_interrupt(void* context);

// Fault injection macro INJECT_FAULT
// where - an address in fault injection control space (int)
// what - mask to rule the injection: mask bit value = 1 - invert target bit value (int)
#define INJECT_FAULT(base, offset, what) *(volatile int *)(base + offset) = (what);

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
// Function name: 	fi_test_extended
// Description: 	test of fault injection into the memory on the processor
// 					bus with doubled direct connection to the processor
// Parameters:		test_memory_size - address span of separate memory connection
// 					memory_addr - base address of separate memory connection
// 					fi_agent_control_addr - base address of fault injection control interface
// 					fi_agent_mem_addr - base address of regular memory interface
// 					fi_agent_mem_size - address span of regular memory interface
// Return value: 	0 - test  passed with possible errors in the stdout
// 					1 - memory spans do not comply
int fi_test_extended(int test_memory_size, int memory_addr, int fi_agent_control_addr, int fi_agent_mem_addr, int fi_agent_mem_size);

//%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
// Function name: 	fi_test_extended
// Description: 	Test of fault injection into the memory on the processor bus
// 					with doubled direct connection to the processor
// 					Performs running 0/1 mask for all addresses of fault injection agent
// Parameters:		test_memory_size - address span of separate memory connection
// 					memory_addr - base address of separate memory connection
// 					fi_agent_control_addr - base address of fault injection control interface
// 					fi_agent_mem_addr - base address of regular memory interface
// 					fi_agent_mem_size - address span of regular memory interface
// Return value: 	no
void fi_test_regular(int fi_agent_control_addr, int fi_agent_control_size);

#endif /* FI_H_ */
