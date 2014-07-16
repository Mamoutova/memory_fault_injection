#include "fi.h"

#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include "system.h"

//#define DEBUG_MSG

volatile struct fi_point_type fi_value;

static void handle_timer_interrupt(void* context)
{
	// get fault injection parameters - address and mask
	volatile struct fi_point_type* fi_point = (volatile int*) context;
	// inject fault
#ifdef DEBUG_MSG
	int was = *((int*)((fi_point->address) | 0x80000000));
#endif
	*((int*)((fi_point->address) | 0x80000000)) = fi_point->mask;		// cache bypass
#ifdef DEBUG_MSG
	int now = *((int*)((fi_point->address) | 0x80000000));
	printf("\n\tfi adr=0x%x was=0x%x now=0x%x mask=0x%x\n",fi_point->address,was,now,fi_point->mask);
#endif
	//handle irq
	IOWR_ALTERA_AVALON_TIMER_STATUS(FI_TIMER_BASE, 0);
}

void fi_irq_init(void)
{
	// TIMER IRQ init
    void* fi_value_ptr = (void*) &fi_value;
    IOWR_ALTERA_AVALON_TIMER_CONTROL(FI_TIMER_BASE, 0);
    alt_ic_isr_register(FI_TIMER_IRQ_INTERRUPT_CONTROLLER_ID, FI_TIMER_IRQ,
    		handle_timer_interrupt, fi_value_ptr, 0x0);
}


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
int fi_test_extended(test_memory_size, memory_addr, fi_agent_control_addr, fi_agent_mem_addr, fi_agent_mem_size)
{
    int offset, old_value, mask, i = 0;
    int volatile new_value;
    int* volatile test_memory_own = (int*)(memory_addr | 0x80000000);
    int* volatile test_memory_fi_direct = (int*)(fi_agent_mem_addr | 0x80000000);
    int* volatile test_memory_fi_inject = (int*)(fi_agent_control_addr | 0x80000000);   // cache bypass

    alt_putstr("\nFault injection extended test... ");

    if (fi_agent_mem_size != test_memory_size)
    {
    	alt_putstr("Address range error\n");
    	return 1;
    }

    alt_putstr("\nChecking memory read via fi-translated interface...");
    for (offset = 0; offset<test_memory_size/4; offset++)
    	test_memory_own[offset] = 0x55;
    for (offset = 0; offset<test_memory_size/4; offset++)
    {
    	if (test_memory_own[offset] !=  test_memory_fi_direct[offset])
    	{
    		alt_printf("error on address %x \n", offset);
    		alt_printf("offset: %x: Address %x Value: %x Address %x Value: %x \n", offset, offset + test_memory_own, test_memory_own[offset], offset + test_memory_fi_direct, test_memory_fi_direct[offset]);
    	}
    }
    for (offset = 0; offset<test_memory_size/4; offset++)
       	test_memory_own[offset] = 0xaa;
    for (offset = 0; offset<test_memory_size/4; offset++)
    {
     	if (test_memory_own[offset] !=  test_memory_fi_direct[offset])
      	{
       		alt_printf("error on address %x \n", offset);
       		alt_printf("offset: %x: Address %x Value: %x Address %x Value: %x \n", offset, offset + test_memory_own, test_memory_own[offset], offset + test_memory_fi_direct, test_memory_fi_direct[offset]);
       	}
    }
    alt_putstr(" Done\n");

    for (offset = 0; offset<test_memory_size/4; offset++)
    	test_memory_own[offset] = 0;

    alt_putstr("\nChecking memory write via fi-translated interface...");
    for (offset = 0; offset<test_memory_size/4; offset++)
    {
    	test_memory_fi_direct[offset] = ~offset;
    	if (test_memory_own[offset] != ~offset)
    	{
    		alt_printf("error on address %x \n", offset);
    		alt_printf("offset: %x: Address %x Value: %x Address %x Value: %x \n", offset, offset + test_memory_own, test_memory_own[offset], offset + test_memory_fi_direct, test_memory_fi_direct[offset]);
    	}
    	if (test_memory_fi_direct[offset] != ~offset)
    	{
    		alt_printf("2error on address %x \n", offset);
    		alt_printf("offset: %x: Address %x Value: %x Address %x Value: %x \n", offset, offset + test_memory_own, test_memory_own[offset], offset + test_memory_fi_direct, test_memory_fi_direct[offset]);
    	}
    }
    alt_putstr(" Done\n");

    alt_putstr("\nFault injection test... \n");
    //running 1
    alt_putstr("running 1... \n");
    mask = 1;
    for (i = 0; i< 32; i++)
    {
    	for (offset = 0; offset<test_memory_size/4; offset++)
    	{
    		old_value = test_memory_own[offset];
    		// inject fault
    		test_memory_fi_inject[offset] = mask;
    		// check
    		new_value = test_memory_own[offset];
    		if (new_value != (old_value^mask))
    		{
    			alt_printf("error on address %x through regular read \n", test_memory_own+offset);
    			alt_printf("\toffset: %x: mask %x, initial value %x, modified value %x \n", offset, mask, old_value, new_value);
    		}
#ifdef DEBUG_MSG
    		else
    		{
    			alt_printf("no error on address %x through regular read \n", test_memory_own+offset);
    			alt_printf("\toffset: %x: mask %x, initial value %x, modified value %x \n", offset, mask, old_value, new_value);
    		}
#endif
    		new_value = test_memory_fi_direct[offset];
    		if (new_value != (old_value^mask))
    		{
    			alt_printf("error on address %x through debug fi read \n", test_memory_fi_direct+offset);
    			alt_printf("\toffset: %x: mask %x, initial value %x modified value: %x \n", offset, mask, old_value, new_value);
    		}
#ifdef DEBUG_MSG
    		else
    		{
    			alt_printf("no error on address %x through debug fi read \n", test_memory_fi_direct+offset);
    			alt_printf("\toffset: %x: mask %x, initial value %x modified value: %x \n", offset, mask, old_value, new_value);
    		}
#endif
    		if (test_memory_fi_inject[offset] != (old_value^mask))
    		{
    			alt_printf("error on address %x through dedicated read \n", test_memory_fi_inject+offset);
    			alt_printf("\toffset: %x: initial value %x modified value: %x \n", offset, old_value, test_memory_fi_inject[offset]);
    		}
#ifdef DEBUG_MSG
    		else
    		{
    			alt_printf("no error on address %x through dedicated read \n", test_memory_fi_inject+offset);
    			alt_printf("\toffset: %x: initial value %x modified value: %x \n", offset, old_value, test_memory_fi_inject[offset]);
    		}
#endif
    	}
    	mask = mask<<1;
    }
    //running 0
    alt_putstr("running 0... \n");
    mask = ~1;
    for (i = 0; i< 32; i++)
    {
    	for (offset = 0; offset<test_memory_size/4; offset++)
    	{
    		old_value = test_memory_own[offset];
    		// inject fault
    		test_memory_fi_inject[offset] = mask;
    		// check
    		if (test_memory_own[offset] != (old_value^mask))
    		{
    			alt_printf("error on address %x through separate read \n", offset);
    			alt_printf("offset: %x: mask %x, initial value %x, modified value %x \n", offset, mask, old_value, test_memory_own[offset]);
    		}
    		if (test_memory_fi_direct[offset] != (old_value^mask))
    		{
    			alt_printf("error on address %x through dedicated read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, old_value, test_memory_fi_direct[offset]);
    		}
    		if (test_memory_fi_inject[offset] != (old_value^mask))
    		{
    			alt_printf("error on address %x through dedicated read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, old_value, test_memory_fi_inject[offset]);
    		}
    	}
    	mask = ~((~mask)<<1);
    }

    alt_putstr("Done\n");
    return 0;

}

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
void fi_test_regular(fi_agent_control_addr, fi_agent_control_size)
{
    int offset, address, value_old, mask, i = 0;

    int volatile new_value;

    int* volatile test_memory_fi_inject = (int*)(fi_agent_control_addr | 0x80000000);		// cache bypass

    alt_putstr("\nFault injection regular test... \n");
    //running 1
    alt_putstr("running 1... \n");
    mask = 1;
    for (i = 0; i< 32; i++)
    {
    	for (offset = 0; offset<fi_agent_control_size/4; offset++)
    	{
    		value_old = test_memory_fi_inject[offset];
    		// inject fault

    		test_memory_fi_inject[offset] = mask;

    		// check
    		new_value = test_memory_fi_inject[offset];
#ifdef DEBUG_MSG
    		alt_printf("address: %x, initial value: %x, modified value: %x, mask: %x, current value: %x\n", &(test_memory_fi_inject[offset]), value_old, new_value, mask, test_memory_fi_inject[address]);
#endif
    		if (new_value  != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", offset);
    			alt_printf("offset %x, mask %x, initial value %x, modified value: %x \n", offset, mask, value_old, new_value );
    		}
    		new_value = test_memory_fi_inject[offset];
    		if (new_value  != (value_old^mask))
    		{
    			alt_printf("2error on address %x through fi read \n", offset);
    			alt_printf("offset %x, mask %x, initial value %x, modified value: %x \n\n", offset, mask, value_old, new_value );
    		}
    	}
    	mask = mask<<1;
    }
    //running 0
    alt_putstr("running 0... \n");
    mask = ~1;
    for (i = 0; i< 32; i++)
    {
    	for (address = 0; address<fi_agent_control_size/4; address++)
    	{
    		value_old = test_memory_fi_inject[address];
    		// inject fault

    		test_memory_fi_inject[address] = mask;

    		// check
    		int new_value = test_memory_fi_inject[address];
#ifdef DEBUG_MSG
    		alt_printf("address: %x, initial value: %x, modified value: %x, mask: %x, current value: %x\n", address, value_old, new_value, mask, test_memory_fi_inject[address]);
#endif
    		if (new_value != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", address);
    			alt_printf("address: %x, initial value: %x, modified value: %x, mask: %x, current value: %x\n", address, value_old, new_value, mask, test_memory_fi_inject[address]);
    		}
    	}
    	mask = ~((~mask)<<1);
    }

    alt_putstr("Done\n");
    return;

}

