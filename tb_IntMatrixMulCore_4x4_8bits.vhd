--
-- Reference Design: tb_IntMatMulCore_4x4_8bits.vhd
-- Matrix multiplier : C = A x B 
-- Input matrix: A, B - Size: 4 x 4 - 8 bits
-- Output matrix: C - Size: 4 x 4 - 20 bits
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;
use std.textio.all;
 
entity tb_IntMatMulCore is
end tb_IntMatMulCore;
 
architecture behavior of tb_IntMatMulCore is 
	 
component IntMatMulCore
	port(
		Reset, Clock, 	WriteEnable, BufferSel: 	in std_logic;
		WriteAddress: 	in std_logic_vector (3 downto 0);
		WriteData: 		in std_logic_vector (7 downto 0);

		ReadAddress: 	in std_logic_vector (3 downto 0);
		ReadEnable: 	in std_logic;
		ReadData: 		out std_logic_vector (19 downto 0);
		
		DataReady: 		out std_logic
	);
end component;	 
	 
signal tb_Reset : std_logic := '0';
signal tb_Clock : std_logic := '0';
signal tb_BufferSel : std_logic := '0';
signal tb_WriteEnable : std_logic := '0';
signal tb_WriteAddress : std_logic_vector(3 downto 0) := (others => '0');
signal tb_WriteData : std_logic_vector(7 downto 0) := (others => '0');
signal tb_ReadEnable : std_logic := '0';
signal tb_ReadAddress : std_logic_vector(3 downto 0) := (others => '0');

signal tb_DataReady : std_logic;
signal tb_ReadData : std_logic_vector(19 downto 0);


-- Clock period definitions
constant period : time := 200 ns;    

begin

	-- Instantiate the Unit Under Test (UUT)
	uut: IntMatMulCore 
		PORT MAP (
			Reset			=> tb_Reset,
			Clock			=> tb_Clock,
			WriteEnable		=> tb_WriteEnable,
			BufferSel		=> tb_BufferSel,

			WriteAddress	=> tb_WriteAddress,
			WriteData		=> tb_WriteData,		

			ReadEnable		=> tb_ReadEnable,
			ReadAddress		=> tb_ReadAddress,
			ReadData		=> tb_ReadData,
		
			DataReady		=> tb_DataReady
      );
		
	process is	
	begin
		while now <= 200 * period loop
			tb_Clock <= '0';
			wait for period/2;
			tb_Clock <= '1';
			wait for period/2;
		end loop;
		wait;
	end process;
	
	process is	
	begin
		tb_Reset <= '1';
		wait for 10*period;
		tb_Reset <= '0';
		wait;   
	end process;
		
	writing: process is						
		-- the input files must have exactly 16 rows, in other words, no empty row in the end
		file FIA: TEXT open READ_MODE is "InputA.txt";    
		file FIB: TEXT open READ_MODE is "InputB.txt";    
		variable L: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable tb_MatrixData: std_logic_vector(7 downto 0);
	begin
		tb_WriteEnable <= '0';
		tb_WriteAddress <= x"F";
		wait for 20*period;
		while not ENDFILE(FIA)  loop
			READLINE(FIA, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= '1';
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
			
		while not ENDFILE(FIB)  loop
			READLINE(FIB, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= '0';
			tb_WriteEnable <= '1';
			tb_WriteData <=tb_MatrixData;
		end loop;
		wait for period;
		tb_WriteEnable <= '0';		
		wait; 
	end process;	
	
	reading: process is						
		file FO: TEXT open WRITE_MODE is "OutputC.txt";
		file FI: TEXT open READ_MODE is "OutputC_matlab.txt";
		variable L, Lm: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable v_ReadDatam: std_logic_vector(19 downto 0);
		variable v_OK: boolean;
	begin
		tb_ReadEnable <= '0';
		tb_ReadAddress <=(others =>'0');
		
		---wait for Multiplication done	

		wait until rising_edge(tb_DataReady); 
		
		wait until falling_edge(tb_DataReady); 

		Write(L, STRING'("Results"));
		WRITELINE(FO, L);
		Write(L, STRING'("Data from Matlab"), Left, 20);
		Write(L, STRING'("Data from Simulation"), Left, 20);
		WRITELINE(FO, L);
		tb_ReadEnable<= '1';
		while not ENDFILE(FI)  loop
			wait until rising_edge(tb_Clock);
			wait for 5 ns;
			
			READLINE(FI, Lm);
			READ(Lm, tb_PreCharacterSpace);
			HREAD(Lm, v_ReadDatam);		
			if v_ReadDatam = tb_ReadData then
				v_OK := True;
			else
				v_OK := False;
			end if;
			HWRITE(L, v_ReadDatam, Left, 20);
			HWRITE(L, tb_ReadData, Left, 20);
			WRITE(L, v_OK, Left, 10);			
			WRITELINE(FO, L);		

			tb_ReadAddress <= std_logic_vector(unsigned(tb_ReadAddress)+1);

		end loop;
		tb_ReadEnable <= '0';
		wait;  
	end process;
	
end;
