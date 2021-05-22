--
-- Reference Design: IntMatMulCore_4x4_8bits.vhd
-- Matrix multiplier : C = A x B 
-- Input matrix: A, B - Size: 4 x 4 - 8 bits
-- Output matrix: C - Size: 4 x 4 - 20 bits
--

library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

-- Required entity declaration
entity IntMatMulCore is
	port(
		Reset, Clock, 	WriteEnable, BufferSel: 	in std_logic;
		WriteAddress: 	in std_logic_vector (3 downto 0);
		WriteData: 		in std_logic_vector (7 downto 0);

		ReadAddress: 	in std_logic_vector (3 downto 0);
		ReadEnable: 	in std_logic;
		ReadData: 		out std_logic_vector (19 downto 0);
		
		DataReady: 		out std_logic
	);
end IntMatMulCore;

architecture IntMatMulCore_arch of IntMatMulCore is

COMPONENT dpram16x8
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;

COMPONENT dpram16x20
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(19 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(19 DOWNTO 0)
  );
END COMPONENT;

-- state definitions
type	stateType is (stIdle, stWriteBufferA, stWriteBufferB, stReadBufferAB, stWaitWriteBufferC, stWriteBufferC, stComplete);
	   			
signal presState: stateType;
signal nextState: stateType;

signal iWriteEnableA, iWriteEnableB, iWriteEnableC: std_logic_vector(0 downto 0);
signal iReadEnableAB, iMacReset, iMacEnable,
		 iCountReset, iRowCountAReset, iColCountAReset, iRowCountBReset, iColCountBReset,
 		 iCountEnable, iRowCountAEnable, iColCountAEnable, iRowCountBEnable, iColCountBEnable: std_logic;

signal iWriteAddressC, iWriteAddressC1, iReadAddressA, iReadAddressB: std_logic_vector(3 downto 0);

signal iReadDataA, iReadDataB: std_logic_vector (7 downto 0);
signal iMacResult: std_logic_vector (19 downto 0);

signal iColCountA: unsigned(1 downto 0); 
signal iRowCountA, iColCountB: unsigned(2 downto 0); 
signal iCount: unsigned(3 downto 0); 

begin	

	iWriteEnableA(0) <= WriteEnable and BufferSel;
	iWriteEnableB(0) <= WriteEnable and (not BufferSel);
	
	InputBufferA : dpram16x8
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableA,
			addra 	=> WriteAddress,
			dina  	=> WriteData,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressA,
			doutb 	=> iReadDataA
		);
		
	InputBufferB : dpram16x8
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableB,
			addra 	=> WriteAddress,
			dina  	=> WriteData,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressB,
			doutb 	=> iReadDataB
		);	

	OutputBufferC : dpram16x20
		PORT MAP (
			clka 	=> Clock,
			wea 	=> iWriteEnableC,
			addra 	=> iWriteAddressC,
			dina 	=> iMacResult,
			clkb 	=> Clock,
			enb 	=> ReadEnable,
			addrb 	=> ReadAddress,
			doutb 	=> ReadData
		);
		
	process (Clock)
	begin
		if rising_edge(Clock) then		
			if iMacReset = '1' then
				iMacResult <= (others=>'0');
			elsif iMacEnable = '1' then
				iMacResult <= std_logic_vector(signed(iReadDataA) * signed(iReadDataB) + signed(iMacResult));
			end if;
		end if;
	end process;		
		
	iReadAddressA <= std_logic_vector(iRowCountA(1 downto 0) & iColCountA);	
	iReadAddressB <= std_logic_vector(iColCountA & iColCountB(1 downto 0));		
			
	process (Clock)
	begin
		if rising_edge(Clock) then		
			iMacEnable <= iReadEnableAB; 
			iWriteAddressC1	<= std_logic_vector(iRowCountA(1 downto 0) & iColCountB(1 downto 0));
			iWriteAddressC		<= iWriteAddressC1;
		end if;
	end process;			
					
 	process (Clock)
	begin
		if rising_edge (Clock) then    
			if Reset = '1' then
				presState <= stIdle;
			else
				presState <= nextState;
			end if;
			
			if iCountReset = '1' then       
				iCount <= (others=>'0');
			elsif iCountEnable = '1' then
				iCount <= iCount + 1;
			end if;

			if iRowCountAReset = '1' then       
				iRowCountA <= (others=>'0');
			elsif iRowCountAEnable = '1' then
				iRowCountA <= iRowCountA + 1;
			end if;

			if iColCountAReset = '1' then       
				iColCountA <= (others=>'0');
			elsif iColCountAEnable = '1' then
				iColCountA <= iColCountA + 1;
			end if;		

			if iColCountBReset = '1' then       
				iColCountB <= (others=>'0');
			elsif iColCountBEnable = '1' then
				iColCountB <= iColCountB + 1;
			end if;		
								
		end if;
			
	end process;
	
	process (presState, WriteEnable, BufferSel, iCount, iRowCountA, iColCountA, iColCountB)
	begin
		-- signal defaults
		iCountReset <= '0';
		iCountEnable <= '1'; 
		
		iRowCountAReset <= '0';
		iRowCountAEnable <= '0';

		iColCountAReset <= '0';
		iColCountAEnable <= '0';

		iColCountBReset <= '0';	
		iColCountBEnable <= '0';
		
		iReadEnableAB <= '0'; 
	
		iWriteEnableC(0) <= '0';		
		iMacReset <= '0';
		
		DataReady <= '0';

		case presState is
			when stIdle =>
				if (WriteEnable = '1' and BufferSel = '1') then
					nextState <= stWriteBufferA;
				else
					iCountReset <= '1';
					nextState <= stIdle;
				end if;
			when stWriteBufferA =>
				if iCount = x"F" then
					iCountReset <= '1';				
					nextState <= stWriteBufferB;
 				else
					nextState <= stWriteBufferA;
				end if;
			when stWriteBufferB =>
				if iCount = x"F" then
					iCountReset <= '1';
					iRowCountAReset <= '1';
					iColCountAReset <= '1';
					iColCountBReset <= '1';
					iMacReset <= '1';
					nextState <= stReadBufferAB;
 				else
					nextState <= stWriteBufferB;
				end if;
			when stReadBufferAB =>
				if iRowCountA = "100" then
					iRowCountAReset <= '1';
					iColCountBReset <= '1';
					iColCountAReset <= '1';
					nextState <= stComplete;
				elsif iColCountB = "100" then
					iRowCountAEnable <= '1';
					iColCountBReset <= '1';
					iColCountAReset <= '1';
					nextState <= stReadBufferAB;
				elsif iColCountA = "11" then
					iReadEnableAB <= '1';
					iColCountAReset <= '1';
					nextState <= stWaitWriteBufferC;
				else
					iReadEnableAB <= '1';
					iColCountAEnable <= '1';
					nextState <= stReadBufferAB;
				end if;
				
			when stWaitWriteBufferC =>
				iColCountBEnable <= '1';
				nextState <= stWriteBufferC;

			when stWriteBufferC =>
				iWriteEnableC(0) <= '1';
				iMacReset <= '1';
				nextState <= stReadBufferAB;
 
			when stComplete =>
				DataReady <= '1';
				nextState <= stIdle;			
		
		end case;
		
	end process;

end IntMatMulCore_arch;