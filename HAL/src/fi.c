#include "fi.h"

#include <stdlib.h>
#include <time.h>
#include "system.h"

volatile int fi_address;

unsigned int time_seed()
{
    time_t now = time(0);
    unsigned char *p = (unsigned char*)&now;
    unsigned int seed = 0;
    int i;

    for (i = 0; i < sizeof now; i++)
        seed = seed * (UCHAR_MAX + 2U) + p[i];

    return seed;
}

int rand_range(int low, int high)
{
    const int range = high - low + 1;
    int number;
    do
    {
        number = rand();
    }
    while (number >= (RAND_MAX / range) * range);
    return number % range + low;
}

static void handle_timer_interrupt(void* context)
{
	volatile int* address_ptr = (volatile int*) context;
	srand(time_seed());
	// 1. inject fault
	// inject in random address
	int address = rand_range(0, FI_MEM_AGENT_CONTROL_SPAN);
	int mask = 1 << rand_range(0, 32);
	INJECT_FAULT(FI_MEM_AGENT_CONTROL_BASE + address, mask)

	// share current random address
	* address_ptr = address;

	// 2. set next random time
	/*
	IOWR_ALTERA_AVALON_TIMER_PERIOD0(TIMER, random);
	IOWR_ALTERA_AVALON_TIMER_PERIOD1(TIMER, random);
	IOWR_ALTERA_AVALON_TIMER_PERIOD2(TIMER, random);
	IOWR_ALTERA_AVALON_TIMER_PERIOD3(TIMER, random);
*/
	// 3. handle irq
	IOWR_ALTERA_AVALON_TIMER_STATUS(TIMER_BASE, 0);
    IOWR_ALTERA_AVALON_TIMER_CONTROL(TIMER_BASE, ALTERA_AVALON_TIMER_CONTROL_ITO_MSK | ALTERA_AVALON_TIMER_CONTROL_START_MSK);
}

void fi_init(void)
{
	// TIMER IRQ init
    void* fi_address_ptr = (void*) &fi_address;
    alt_ic_isr_register(TIMER_IRQ_INTERRUPT_CONTROLLER_ID, TIMER_IRQ,
    		handle_timer_interrupt, fi_address_ptr, 0x0);
    IOWR_ALTERA_AVALON_TIMER_CONTROL(TIMER_BASE, ALTERA_AVALON_TIMER_CONTROL_ITO_MSK | ALTERA_AVALON_TIMER_CONTROL_START_MSK);
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

//    int* volatile test_memory_fi_inject = (int*)fi_agent_control_addr;

    alt_putstr("\nFault injection regular test... ");
    //running 1
    mask = 1;
    for (i = 0; i< 32; i++)
    {
    	for (address = 0; address<fi_agent_control_size/4; address++)
    	{

    		value_old = *(int*)(fi_agent_control_addr+address);
    		// inject fault

    		INJECT_FAULT(fi_agent_control_addr+address, mask)

    		// check
    		if (*(int*)(fi_agent_control_addr+address) != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", address);
    			alt_printf("address: %x: initial value %x modified value: %x mask %x\n", address, value_old, *(int *)address, mask);
    		}
    	}
    	mask = mask<<1;
    }
    //running 0
    mask = ~1;
    for (i = 0; i< 32; i++)
    {
    	for (address = fi_agent_control_addr; address<fi_agent_control_addr+fi_agent_control_size/4; address++)
    	{

    		value_old = *(int*)(address);
    		// inject fault

    		INJECT_FAULT(address, mask)

    		// check
    		if (*(int*)(address) != (value_old^mask))
    		{
    			alt_printf("error on address %x through fi read \n", address);
    			alt_printf("address: %x: initial value %x modified value: %x mask %x\n", address, value_old, *(int *)address, mask);
    		}
    	}
    	mask = ~((~mask)<<1);
    }

    alt_putstr("Done\n");
    return;

}

