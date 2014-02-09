--345678901234567890123456789012345678901234567890123456789012345678901234567890
--       1         2         3         4         5         6         7         8
-- Title:     Entity and RTL architecture of the fault injector
-- Engineer:  Olga Mamoutova 
-- Company:   SpbSTU
-- Project:   Fault injection
-- File name: fi_block.vhd
--------------------------------------------------------------------------------
-- Purpose:  Memory fault injection
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
-- Revision:  6.0
-- Modification date: 09 Feb 2013
-- Notes: implement rd signal instead of cs + code compactness + tweaked fi_ack logic
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
		aw				: INTEGER := 32;
		dw				: INTEGER := 32
	);
	PORT
	( 
		clk 			: IN 		STD_LOGIC;
		rst_n 		: IN 		STD_LOGIC;
		
		-- fault injection command
		fi_rd			: IN 		STD_LOGIC;
		fi_wr   		: IN 		STD_LOGIC;
		fi_A 			: IN 		STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		fi_Mask		: IN 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		fi_data_r 	: OUT 	STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		fi_ack 		: OUT		STD_LOGIC;		-- active high = waitrequest_n
		
		-- Original memory interface
		RD				: IN 		STD_LOGIC;
		WE				: IN 		STD_LOGIC;
		A				: IN		STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		ACK			: OUT		STD_LOGIC;		-- active high = waitrequest_n
		D				: IN 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		Dout			: OUT 	STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		
		-- Modified memory interface
		RD_m			: OUT 	STD_LOGIC;
		WE_m			: OUT 	STD_LOGIC;
		ACK_m			: IN 		STD_LOGIC;			-- active high = waitrequest_n
		A_m			: OUT 	STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
		D_m			: OUT 	STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
		Dout_m		: IN 		STD_LOGIC_VECTOR(dw-1 DOWNTO 0)	
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

	SIGNAL fi_Mask_reg 	: STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
	SIGNAL fi_A_reg 		: STD_LOGIC_VECTOR(aw-1 DOWNTO 0);
	SIGNAL Dout_m_reg		: STD_LOGIC_VECTOR(dw-1 DOWNTO 0);
	
	SIGNAL fi_ack_int, fi_ack_int_td	: STD_LOGIC;
		
BEGIN

	fi_a_reg_p: PROCESS(clk, rst_n, A, fi_wr, fi_rd, fi_Mask)
	BEGIN
		IF rst_n = '0' THEN
			fi_A_reg <= (OTHERS=>'0');
			fi_Mask_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
			IF (fi_wr = '1' OR fi_rd = '1') THEN
				fi_A_reg <= fi_A(aw-1 DOWNTO 0);
				IF fi_wr = '1' THEN
					fi_Mask_reg <= fi_Mask;
				END IF;
			END IF;				
		END IF;
	END PROCESS;

USE_ACK_GEN: IF use_ack GENERATE
 
	-- fsm transitions
	fsm_transitions: PROCESS(clk, rst_n, A, fi_rd, fi_wr)
	BEGIN		
		IF rst_n = '0' THEN
			fsm <= idle;							
			Dout_m_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
			fsm <= fsm;
			CASE fsm IS
				WHEN idle =>
					IF (fi_wr = '1') THEN
						fsm <= fi_read_before_write;
					ELSIF (fi_rd = '1') THEN
						fsm <= fi_read;
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
	
	-- fi_ack logic
	PROCESS(fsm, D, Dout_m_reg, fi_Mask_reg, WE, rst_n, ACK_m)
	BEGIN
		IF rst_n = '0' THEN
			fi_ack_int <= '0';
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

	ACK <= '1';

	-- fsm transitions
	fsm_transitions: PROCESS(clk, rst_n, A, fi_rd, fi_wr)
	BEGIN		
		IF rst_n = '0' THEN
			fsm <= idle;	
			Dout_m_reg <= (OTHERS=>'0');
		ELSIF clk'event AND clk = '1' THEN
			fsm <= fsm;
			CASE fsm IS
				WHEN idle =>
					IF (fi_wr = '1') THEN
						fsm <= fi_read_before_write;
					ELSIF (fi_rd = '1') THEN
						fsm <= fi_read;
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

	-- fi_ack logic
	PROCESS(fsm, D, Dout_m_reg, fi_Mask_reg, WE, rst_n)
	BEGIN
		IF rst_n = '0' THEN
			fi_ack_int <= '0';
		ELSIF fsm = fi_write THEN
			fi_ack_int <= '1';
		ELSIF fsm = fi_read1 THEN
			fi_ack_int <= '1';			
		ELSE
			fi_ack_int <= '0';
		END IF;		
	END PROCESS;

END GENERATE NOT_USE_ACK_GEN;
	
	fi_ack <= fi_ack_int;
	
	-- common fsm outputs
	PROCESS(fsm, fi_A_reg, RD, A)
	BEGIN
		IF (fsm /= idle) THEN
			IF fsm = fi_write THEN
				WE_m <= '1';
				RD_m <= '0';
			ELSE
				WE_m <= '0';
				RD_m <= '1';				
			END IF;
			A_m <= fi_A_reg;
			D_m <= Dout_m_reg XOR fi_Mask_reg;			
		ELSE
			RD_m <= RD;
			WE_m <= WE;
			A_m <= A;
			D_m <= D;
		END IF;
	END PROCESS;
	
	Dout <= Dout_m;	
	fi_data_r <= Dout_m;
	
END rtl;
	