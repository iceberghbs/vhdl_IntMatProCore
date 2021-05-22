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
		Reset, Clock, 	WriteEnable: 	in std_logic;
		BufferSel:      in std_logic_vector (1 downto 0);
		WriteAddress: 	in std_logic_vector (9 downto 0);
		WriteData16: 		in std_logic_vector (15 downto 0);
        WriteData64: 		in std_logic_vector (63 downto 0);
		ReadAddress: 	in std_logic_vector (9 downto 0);
		ReadEnable: 	in std_logic;
		ReadData: 		out std_logic_vector (63 downto 0);
		
		DataReady: 		out std_logic
	);
end component;	 
	 
signal tb_Reset : std_logic := '0';
signal tb_Clock : std_logic := '0';
signal tb_BufferSel : std_logic_vector(1 downto 0) := "00";
signal tb_WriteEnable : std_logic := '0';
signal tb_WriteAddress : std_logic_vector(9 downto 0) := (others => '0');
signal tb_WriteData16 : std_logic_vector(15 downto 0) := (others => '0');
signal tb_WriteData64 : std_logic_vector(63 downto 0) := (others => '0');
signal tb_ReadEnable : std_logic := '0';
signal tb_ReadAddress : std_logic_vector(9 downto 0) := (others => '0');

signal tb_DataReady : std_logic;
signal tb_ReadData : std_logic_vector(63 downto 0);


-- Clock period definitions
constant period : time := 800 ns;    

begin

	-- Instantiate the Unit Under Test (UUT)
	uut: IntMatMulCore 
		PORT MAP (
			Reset			=> tb_Reset,
			Clock			=> tb_Clock,
			WriteEnable		=> tb_WriteEnable,
			BufferSel		=> tb_BufferSel,

			WriteAddress	=> tb_WriteAddress,
			WriteData16		=> tb_WriteData16,		
            WriteData64		=> tb_WriteData64,
			ReadEnable		=> tb_ReadEnable,
			ReadAddress		=> tb_ReadAddress,
			ReadData		=> tb_ReadData,
		
			DataReady		=> tb_DataReady
      );
		
	process is	
	begin
		while now <= 100000 * period loop
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
		file FIC: TEXT open READ_MODE is "InputC.txt";    
		variable L: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable tb_MatrixData16: std_logic_vector(15 downto 0);
		variable tb_MatrixData64: std_logic_vector(63 downto 0);
	begin
		tb_WriteEnable <= '0';
		tb_WriteAddress <= "1111111111";
		wait for 20*period;
		
		while not ENDFILE(FIA)  loop
			READLINE(FIA, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData16);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "00";
			tb_WriteEnable <= '1';
			tb_WriteData16 <=tb_MatrixData16;
		end loop;
			
		while not ENDFILE(FIB)  loop
			READLINE(FIB, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData16);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "01";
			tb_WriteEnable <= '1';
			tb_WriteData16 <=tb_MatrixData16;
		end loop;
		while not ENDFILE(FIC)  loop
			READLINE(FIC, L);		
			READ(L, tb_PreCharacterSpace);
			HREAD(L, tb_MatrixData64);	
			wait until falling_edge(tb_Clock);
			tb_WriteAddress <= std_logic_vector(unsigned(tb_WriteAddress)+1);
			tb_BufferSel <= "10";
			tb_WriteEnable <= '1';
			tb_WriteData64 <=tb_MatrixData64;
		end loop;
		wait for period;
		tb_WriteEnable <= '0';		
		wait; 
	end process;	
	
	reading: process is						
		file FO: TEXT open WRITE_MODE is "OutputD.txt";
		file FI: TEXT open READ_MODE is "OutputD_matlab.txt";
		variable L, Lm: LINE;
		variable tb_PreCharacterSpace: string(5 downto 1);
		variable v_ReadDatam: std_logic_vector(63 downto 0);
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