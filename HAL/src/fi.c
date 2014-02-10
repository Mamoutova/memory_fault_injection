#include "fi.h"

#include <stdlib.h>
#include <time.h>
#include "system.h"

volatile struct fi_point_type fi_value;

static void handle_timer_interrupt(void* context)
{
	volatile struct fi_point_type* fi_point = (volatile int*) context;

	*((int*)(fi_point->address)) = fi_point->mask;
	printf("*");

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

int fi_test_extended(test_memory_size, memory_addr, fi_agent_control_addr, fi_agent_mem_addr, fi_agent_mem_size)
{
    int offset, value_old, mask, i = 0;

    int* volatile test_memory_own = (int*)memory_addr;
    int* volatile test_memory_fi_direct = (int*)fi_agent_mem_addr;
    int* volatile test_memory_fi_inject = (int*)fi_agent_control_addr;

    alt_putstr("\nFault injection extended test... ");

    if (fi_agent_mem_size != test_memory_size)
    {
    	alt_putstr("Address range error\n");
    	return 1;
    }

    alt_putstr("\nChecking memory read via fi-translated interface...");
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
    }
    alt_putstr(" Done\n");

    alt_putstr("\nFault injection test... ");
    //running 1
    mask = 1;
    for (i = 0; i< 32; i++)
    {
    	for (offset = 0; offset<test_memory_size/4; offset++)
    	{
    		value_old = test_memory_own[offset];
    		// inject fault
    		test_memory_fi_inject[offset] = mask;
    		// check
    		if (test_memory_own[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through separate read \n", offset);
    			alt_printf("offset: %x: mask %x, initial value %x, modified value %x \n", offset, value_old, mask, test_memory_own[offset]);
    		}
    		else if (test_memory_fi_inject[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, value_old, test_memory_fi_inject[offset]);
    		}
    		else if (test_memory_fi_direct[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through dedicated read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, value_old, test_memory_fi_direct[offset]);
    		}
    	}
//    	alt_printf("mask %x \n", mask);
    	mask = mask<<1;
    }
    //running 0
    mask = ~1;
    for (i = 0; i< 32; i++)
    {
    	for (offset = 0; offset<test_memory_size/4; offset++)
    	{
    		value_old = test_memory_own[offset];
    		// inject fault
    		test_memory_fi_inject[offset] = mask;
    		// check
    		if (test_memory_own[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through separate read \n", offset);
    			alt_printf("offset: %x: mask %x, initial value %x, modified value %x \n", offset, value_old, mask, test_memory_own[offset]);
    		}
    		else if (test_memory_fi_inject[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, value_old, test_memory_fi_inject[offset]);
    		}
    		else if (test_memory_fi_direct[offset] != (value_old^mask))
    		{
    			alt_printf("error on address %x through dedicated read \n", offset);
    			alt_printf("offset: %x: initial value %x modified value: %x \n", offset, value_old, test_memory_fi_direct[offset]);
    		}
    	}
//    	alt_printf("mask %x \n", mask);
    	mask = ~((~mask)<<1);
    }

    alt_putstr("Done\n");
    return 0;

}

void fi_test_regular(fi_agent_control_addr, fi_agent_control_size)
{
    int address, value_old, mask, i = 0;

    int* volatile test_memory_fi_inject = (int*)fi_agent_control_addr;

    alt_putstr("\nFault injection regular test... \n");
    //running 1
    mask = 1;
    for (i = 0; i< 32; i++)
    {
    	for (address = 0; address<fi_agent_control_size/4; address++)
    	{
    		value_old = test_memory_fi_inject[address];
    		// inject fault

    		test_memory_fi_inject[address] = mask;
    		int new_value = test_memory_fi_inject[address];

    		// check
    		if (new_value != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", address);
    			alt_printf("address: %x, initial value: %x, modified value: %x, mask: %x, current value: %x\n", address, value_old, new_value, mask, test_memory_fi_inject[address]);
    		}
    	}
    	mask = mask<<1;
    }
    //running 0
    mask = ~1;
    for (i = 0; i< 32; i++)
    {
    	for (address = 0; address<fi_agent_control_size/4; address++)
    	{
    		value_old = test_memory_fi_inject[address];
    		// inject fault

    		test_memory_fi_inject[address] = mask;

    		// check
    		if (test_memory_fi_inject[address] != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", address);
    			alt_printf("address: %x: initial value %x modified value: %x mask %x\n", address, value_old, test_memory_fi_inject[address], mask);
    		}
    	}
    	mask = ~((~mask)<<1);
    }

    alt_putstr("Done\n");
    return;

}

