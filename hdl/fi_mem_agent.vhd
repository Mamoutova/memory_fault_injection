--345678901234567890123456789012345678901234567890123456789012345678901234567890
--       1         2         3         4         5         6         7         8
-- Title:     Entity and RTL architecture of the fault injector
-- Engineer:  Olga Mamoutova 
-- Company:   SpbSTU
-- Project:   Fault injection
-- File name: fi_block.vhd
--------------------------------------------------------------------------------
-- Purpose:  Block of spi slave.
--------------------------------------------------------------------------------
-- Simulator: Altera Quartus II
-- Synthesis: Altera Quartus II
--------------------------------------------------------------------------------
-- Revision:  1.0
-- Modification date: 14 Feb 2013
-- Notes: 
-- Limitation: 
-- Revision:  1.1
-- Modification date: 20 Feb 2013
-- Notes: 1. fi_read implemented 2. fi_index_width implemented
-- Limitation: 
-- Revision:  2.0
-- Modification date: Sep 2013
-- Notes: merged fi_index and fi_A - for nios-avalon
--  added ack signal for both memory interfaces - active low
-- deassert fi_ack when in reset, assert in idle - for avalon spec
-- Limitation: 
-- Revision:  3.0
-- Modification date: 17 Oct 2013
-- Notes: no index - since obsolete for qsys
-- Limitation:
-- Revision:  4.0
-- Modification date: 22 Nov 2013
-- Notes: renamed fi to fi_ena - since some glitch in qsys (names were not recognized properly for conduit connection)
-- Limitation:
-- Revision:  5.0
-- Modification date: 12 Dec 2013
-- Notes: generic USE_ACK - whether to use ack or two-cycle read/one-cycle write
-- Limitation:
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
--==============================================================================

ENTITY fi_mem_agent IS
	GENERIC
	(
		use_ack		: BOOLEAN := true; 		-- use_ack = 0 - two-cycle read/one-cycle write, use_ack = 1 - to use ack
		aw			: INTEGER := 32;
		dw			: INTEGER := 32
	);
	PORT
	( 
		clk 		: IN 		STD_LOGIC;
		rst_n 		: IN 		STD_LOGIC;
		
		-- fault injection command
		fi_ena		: IN 		STD_LOGIC;
		fi_wr   	: IN 		STD_LOGIC;
		fi_A 		: IN 		STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		fi_Mask		: IN 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		fi_data_r 	: OUT 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		fi_ack 		: OUT		STD_LOGIC;		-- active high = waitrequest_n
		
		-- Original memory interface
		CE			: IN 		STD_LOGIC;
		WE			: IN 		STD_LOGIC;
		A			: IN		STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		ACK			: OUT		STD_LOGIC;		-- active high = waitrequest_n
		D			: IN 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		Dout		: OUT 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		
		-- Modified memory interface
		CE_m		: OUT 	STD_LOGIC;
		WE_m		: OUT 	STD_LOGIC;
		ACK_m		: IN 	STD_LOGIC;			-- active high = waitrequest_n
		A_m			: OUT 	STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		D_m			: OUT 	STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		Dout_m		: IN 	STD_LOGIC_VECTOR(dw-1 DOWNTO 0)	
	);
END fi_mem_agent;

ARCHITECTURE rtl OF fi_mem_agent IS

	TYPE fi_state_type IS (
		idle, 				
		fi_read_before_write,  fi_read_before_write1,
    	fi_write,
		fi_read, fi_read1
	);
	SIGNAL fsm 	: fi_state_type;

	SIGNAL fi_Mask_reg 		: STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
	SIGNAL fi_A_reg 		: STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
	SIGNAL Dout_m_reg		: STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
	
	SIGNAL fi_ack_int, fi_ack_int_td	: STD_LOGIC;
		
BEGIN

	fi_a_reg_p: PROCESS(clk, rst_n, A, fi_ena, fi_Mask)
	BEGIN
		IF rst_n = '0' THEN
			fi_A_reg <= (OTHERS=>'0');
			fi_Mask_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
			IF (fi_ena = '1') THEN
				fi_A_reg <= fi_A(aw-1 DOWNTO 0);
				IF fi_wr = '1' THEN
					fi_Mask_reg <= fi_Mask;
				END IF;
			END IF;				
		END IF;
	END PROCESS;

USE_ACK_GEN: IF use_ack GENERATE
 
	-- fsm transitions
	fsm_transitions: PROCESS(clk, rst_n, A, fi_ena)
	BEGIN		
		IF rst_n = '0' THEN
			fsm <= idle;							
			Dout_m_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
--			fsm <= fsm;						-- !!!!!
			CASE fsm IS
				WHEN idle =>
					IF (fi_ena = '1') THEN						
						IF fi_wr = '1' THEN
							fsm <= fi_read_before_write;
						ELSE
							fsm <= fi_read;
						END IF;
					ELSE
						fsm  <= idle;
					END IF;
				WHEN fi_read_before_write =>
					IF ACK_m = '0' THEN
						fsm <= fi_read_before_write;
					ELSE
						fsm <= fi_write;	
						Dout_m_reg <= Dout_m;
					END IF;
				WHEN fi_write =>
					IF ACK_m = '0' THEN
						fsm <= fi_write;
					ELSE				
						fsm <= idle;
					END IF;
				WHEN fi_read =>
					IF ACK_m = '0' THEN
						fsm <= fi_read;
					ELSE
						fsm <= idle;
					END IF;
				WHEN OTHERS =>
					fsm <= idle;
			END CASE;
		END IF;	
	END PROCESS;
	
	ACK <= ACK_m WHEN fsm=idle ELSE '0';
	
	-- fsm outputs
	PROCESS(fsm, D, Dout_m_reg, fi_Mask_reg, WE, rst_n, ACK_m)
	BEGIN
		IF fsm = idle THEN
			D_m <= D;
		ELSE
			D_m <= Dout_m_reg XOR fi_Mask_reg;
		END IF;
		
		IF fsm = idle THEN
			WE_m <= WE;
		ELSIF fsm = fi_write THEN
			WE_m <= '1';
		ELSE
			WE_m <= '0';
		END IF;
		
		IF rst_n = '0' THEN
			fi_ack_int <= '0';
		ELSIF fsm = idle THEN
			fi_ack_int <= '1';
		ELSIF fsm = fi_write THEN
			fi_ack_int <= ACK_m;
		ELSIF fsm = fi_read THEN
			fi_ack_int <= ACK_m;			
		ELSE
			fi_ack_int <= '0';
		END IF;		
		
	END PROCESS;

END GENERATE USE_ACK_GEN;
NOT_USE_ACK_GEN: IF NOT use_ack GENERATE

	-- fsm transitions
	fsm_transitions: PROCESS(clk, rst_n, A, fi_ena)
	BEGIN		
		IF rst_n = '0' THEN
			fsm <= idle;	
			Dout_m_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
			fsm <= fsm;						-- !!!!!
			CASE fsm IS
				WHEN idle =>
					IF (fi_ena = '1') THEN
						IF fi_wr = '1' THEN
							fsm <= fi_read_before_write;
						ELSE
							fsm <= fi_read;
						END IF;
					ELSE
						fsm  <= idle;
					END IF;
				WHEN fi_read_before_write =>
					fsm <= fi_read_before_write1;
				WHEN fi_read_before_write1 =>
					fsm <= fi_write;	
					Dout_m_reg <= Dout_m;
				WHEN fi_write =>
					fsm <= idle;
				WHEN fi_read =>
					fsm <= fi_read1;
				WHEN fi_read1 =>
					fsm <= idle;
				WHEN OTHERS =>
					fsm <= idle;
			END CASE;
		END IF;	
	END PROCESS;	

	ACK <= '1';

	-- fsm outputs
	PROCESS(fsm, D, Dout_m_reg, fi_Mask_reg, WE, rst_n)
	BEGIN
		IF fsm = idle THEN
			D_m <= D;
		ELSE
			D_m <= Dout_m_reg XOR fi_Mask_reg;
		END IF;
		
		IF fsm = idle THEN
			WE_m <= WE;
		ELSIF fsm = fi_write THEN
			WE_m <= '1';
		ELSE
			WE_m <= '0';
		END IF;
		
		IF rst_n = '0' THEN
			fi_ack_int <= '0';
		ELSIF fsm = idle THEN
			fi_ack_int <= '1';
		ELSIF fsm = fi_write THEN
			fi_ack_int <= '1';
		ELSIF fsm = fi_read1 THEN
			fi_ack_int <= '1';			
		ELSE
			fi_ack_int <= '0';
		END IF;		
	END PROCESS;

END GENERATE NOT_USE_ACK_GEN;
	
	PROCESS(rst_n, clk, fi_ack_int)
	BEGIN
		IF rst_n = '0' THEN
			fi_ack_int_td  <= '0';
		ELSIF clk'event AND clk = '1' THEN
			fi_ack_int_td <= fi_ack_int;
		END IF;
	END PROCESS;
	
	fi_ack <= ((NOT fi_ena) AND fi_ack_int) OR (fi_ena AND fi_ack_int AND (NOT fi_ack_int_td));
	
	PROCESS(fsm, fi_A_reg, CE, A)
	BEGIN
		IF (fsm /= idle) THEN
			CE_m <= '1';
			A_m <= fi_A_reg;
		ELSE
			CE_m <= CE;
			A_m <= A;
		END IF;
	END PROCESS;
	
	Dout <= Dout_m;	
	fi_data_r <= Dout_m;
	
END rtl;
	