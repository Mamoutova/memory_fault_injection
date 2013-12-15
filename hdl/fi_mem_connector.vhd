--345678901234567890123456789012345678901234567890123456789012345678901234567890
--       1         2         3         4         5         6         7         8
-- Title:     Entity and RTL architecture of the processor-to-fi_mem_agent connector
-- Engineer:  Olga Mamoutova 
-- Company:   SpbSTU
-- Project:   Fault injection
-- File name: fi_mem_connector.vhd
--------------------------------------------------------------------------------
-- Purpose:  Connects array of memory fault injection agents to the [NIOS] processor
--------------------------------------------------------------------------------
-- Simulator: Altera Quartus II
-- Synthesis: Altera Quartus II
--------------------------------------------------------------------------------
-- Revision:  1.0
-- Modification date: 22 Nov 2013
-- Notes: 
-- Limitation: 
-- Revision:  1.1
-- Modification date: 15 Dec 2013
-- Notes: minor improvements
-- Limitation: 
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.ALL;
--==============================================================================
ENTITY fi_mem_connector IS
	GENERIC
	(
		N				: INTEGER := 4;		-- number of fi agents
		iw				: INTEGER := 2;			-- width of fi index value
		dw_max		: INTEGER := 8;			-- maximum data width among fi_mem_agent blocks
		aw_max		: INTEGER := 5			-- maximum address width among fi_mem_agent blocks
	);
	PORT
	( 
		-- Combined signals of fault injection command - from the processor
		clk_i			: IN STD_LOGIC;
		rst_i			: IN STD_LOGIC;
		fi_i				: IN 		STD_LOGIC;		-- chipselect, active high
		fi_wr_i   		: IN 		STD_LOGIC;		-- write, active high
		fi_A_i 			: IN 		STD_LOGIC_VECTOR(aw_max+iw-1 DOWNTO 0);	-- address
		fi_Mask_i		: IN 		STD_LOGIC_VECTOR(dw_max-1 DOWNTO 0);		-- writedata
		fi_data_r_i 	: OUT 	STD_LOGIC_VECTOR(dw_max-1 DOWNTO 0);		-- readdata - debug feature
		fi_ack_i 		: OUT		STD_LOGIC;		-- waitrequest_n, active low
		
		-- Array of signals of fault injection command - to array fi_mem_agent
		clk_o			: OUT STD_LOGIC;
		rst_o			: OUT STD_LOGIC;
		fi_o				: OUT 	STD_LOGIC_VECTOR(N-1 DOWNTO 0);		-- chipselect
		fi_wr_o   		: OUT 	STD_LOGIC;										-- write
		fi_A_o 			: OUT 	STD_LOGIC_VECTOR(aw_max-1 DOWNTO 0);		-- address
		fi_Mask_o		: OUT 	STD_LOGIC_VECTOR(dw_max-1 DOWNTO 0);		-- writedata
		fi_data_r_o 	: IN 		STD_LOGIC_VECTOR(dw_max*N-1 DOWNTO 0);		-- readdata - debug feature
		fi_ack_o 		: IN		STD_LOGIC_VECTOR(N-1 DOWNTO 0)		-- waitrequest_n		
	
	);
END fi_mem_connector;

ARCHITECTURE rtl OF fi_mem_connector IS

	SIGNAL fi_A_i_rg : STD_LOGIC_VECTOR(aw_max+iw-1 DOWNTO 0); -- for readdata  - debug feature

BEGIN

assert (N = 2**iw) report "N != 2**iw in fi_mem_connector" severity error;

	-- clk, reset
	clk_o <= clk_i;
	rst_o <= rst_i;

	-- chipselect
	-- select fi_o, addressed by iw msb bits of fi_A_i
	PROCESS(fi_A_i, fi_i)
	BEGIN
		FOR i IN 0 TO N-1 LOOP
			IF (fi_A_i(aw_max+iw-1 DOWNTO aw_max)=i) AND fi_i='1' THEN
				fi_o(i) <= '1';
			ELSE
				fi_o(i) <= '0';
			END IF;
		END LOOP;
	END PROCESS;
	
	-- write
	fi_wr_o <= fi_wr_i;
	
	-- address
	fi_A_o <= fi_A_i(aw_max-1 DOWNTO 0);
	
	-- writedata
	fi_Mask_o <= fi_Mask_i;
	
	-- waitrequest_n
	PROCESS(fi_A_i, fi_ack_o)
		VARIABLE fi_ack_i_tmp : STD_LOGIC;
	BEGIN
		fi_ack_i_tmp := '1';			-- not active
		FOR i IN 0 TO N-1 LOOP
			fi_ack_i_tmp := fi_ack_i_tmp AND fi_ack_o(i);
		END LOOP;
		fi_ack_i <= fi_ack_i_tmp;
	END PROCESS;
	
	-- readdata  - debug feature
	PROCESS(fi_A_i_rg, fi_data_r_o)
	BEGIN	
		fi_data_r_i <= (OTHERS=>'0');
		FOR i IN 0 TO N-1 LOOP			
			IF (fi_A_i_rg(aw_max+iw-1 DOWNTO aw_max)=i) THEN
				fi_data_r_i <= fi_data_r_o(i*dw_max + dw_max -1 DOWNTO i*dw_max);
			END IF;
		END LOOP;
	END PROCESS;
	
	PROCESS(clk_i, rst_i, fi_A_i)
	BEGIN
		IF rst_i = '0' THEN
			fi_A_i_rg <= (OTHERS=>'0');
		ELSIF clk_i'event AND clk_i = '1' THEN
			IF fi_i='1' THEN				
				fi_A_i_rg <= fi_A_i;
			END IF;
		END IF;
	END PROCESS;
	
END rtl;