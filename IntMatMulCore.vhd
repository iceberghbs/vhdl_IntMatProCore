library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

-- Required entity declaration
entity IntMatMulCore is
	port(
		Reset, Clock, 	WriteEnable: in std_logic;
		BufferSel:      in std_logic_vector (1 downto 0);
		WriteAddress: 	in std_logic_vector (9 downto 0);
		WriteData16: 		in std_logic_vector (15 downto 0);
        WriteData64: 		in std_logic_vector (63 downto 0);
		ReadAddress: 	in std_logic_vector (9 downto 0);
		ReadEnable: 	in std_logic;
		ReadData: 		out std_logic_vector (63 downto 0);
		
		DataReady: 		out std_logic
	);
end IntMatMulCore;

architecture IntMatMulCore_arch of IntMatMulCore is

COMPONENT dpram1024x16
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
  );
END COMPONENT;

COMPONENT dpram1024x64
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    clkb : IN STD_LOGIC;
    enb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
END COMPONENT;

-- state definitions
type	stateType is (stIdle, stWriteBufferA, stWriteBufferB, stWriteBufferC, stReadBufferAB, stWaitWriteBufferD, stWriteBufferD, stComplete);
	   			
signal presState: stateType;
signal nextState: stateType;

signal iWriteEnableA, iWriteEnableB, iWriteEnableC, iWriteEnableD: std_logic_vector(0 downto 0);
signal iReadEnableAB, iMacReset, iMacEnable,  
		 iCountReset, iRowCountAReset, iColCountAReset, iRowCountBReset, iColCountBReset,
 		 iCountEnable, iRowCountAEnable, iColCountAEnable, iRowCountBEnable, iColCountBEnable: std_logic;

signal iWriteAddressD, iWriteAddressD1, iReadAddressA, iReadAddressB,iReadAddressC: std_logic_vector(9 downto 0);

signal iReadDataA, iReadDataB: std_logic_vector (15 downto 0);
signal iReadDataC: std_logic_vector (63 downto 0);
signal iMacResult: std_logic_vector (63 downto 0);
signal iadd: std_logic_vector (63 downto 0);


signal iColCountA: unsigned(4 downto 0); 
signal iRowCountA, iColCountB: unsigned(5 downto 0);  
signal iCount: unsigned(9 downto 0); 


begin	

	iWriteEnableA(0) <= WriteEnable and (not BufferSel(0)) and (not BufferSel(1)) ;
	iWriteEnableB(0) <= WriteEnable and (not BufferSel(1)) and BufferSel(0);
	iWriteEnableC(0) <= WriteEnable and  BufferSel(1) and ( not(BufferSel(0)));
	InputBufferA : dpram1024x16
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableA,
			addra 	=> WriteAddress,
			dina  	=> WriteData16,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressA,
			doutb 	=> iReadDataA
		);
		
	InputBufferB : dpram1024x16
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableB,
			addra 	=> WriteAddress,
			dina  	=> WriteData16,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressB,
			doutb 	=> iReadDataB
		);	
    InputBufferC : dpram1024x64
		PORT MAP (
			clka  	=> Clock,
			wea   	=> iWriteEnableC,
			addra 	=> WriteAddress,
			dina  	=> WriteData64,
			clkb 	=> Clock,
			enb		=> iReadEnableAB,
			addrb 	=> iReadAddressC,
			doutb 	=> iReadDataC
		);	
	OutputBufferD : dpram1024x64
		PORT MAP (
			clka 	=> Clock,
			wea 	=> iWriteEnableD,
			addra 	=> iWriteAddressD,
			dina 	=> iadd,
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
				iadd <= std_logic_vector(signed(iMacResult)+ signed(iReadDataC)+ signed(iReadDataA) * signed(iReadDataB));
			end if;
		end if;
	end process;		
		
	iReadAddressA <= std_logic_vector(iRowCountA(4 downto 0) & iColCountA);	
	iReadAddressB <= std_logic_vector(iColCountA & iColCountB(4 downto 0));		
    iReadAddressC <= std_logic_vector(iRowCountA(4 downto 0) & iColCountB(4 downto 0));
	process (Clock)
	begin
		if rising_edge(Clock) then		
			iMacEnable <= iReadEnableAB; 
			iWriteAddressD1	<= std_logic_vector(iRowCountA(4 downto 0) & iColCountB(4 downto 0));
			iWriteAddressD		<= iWriteAddressD1;
			
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
	
		iWriteEnableD(0) <= '0';		
		iMacReset <= '0';
		
		DataReady <= '0';

		case presState is
			when stIdle =>
				if (WriteEnable = '1' and BufferSel = "00") then
					nextState <= stWriteBufferA;
				else
					iCountReset <= '1';
					nextState <= stIdle;
				end if;
			
			when stWriteBufferA =>
				if iCount = "1111111111" then
					iCountReset <= '1';				
					nextState <= stWriteBufferB;
 				else
					nextState <= stWriteBufferA;
				end if;
			
			when stWriteBufferB =>
				if iCount = "1111111111" then
					iCountReset <= '1';				
					nextState <= stWriteBufferC;
 				else
					nextState <= stWriteBufferB;
				end if;
			
			when stWriteBufferC =>
				if iCount = "1111111111" then
					iCountReset <= '1';
					iRowCountAReset <= '1';
					iColCountAReset <= '1';
					iColCountBReset <= '1';
					iMacReset <= '1';
					
					nextState <= stReadBufferAB;
 				else
					nextState <= stWriteBufferC;
				end if;
			
			when stReadBufferAB =>
				if iRowCountA = "100000" then
					iRowCountAReset <= '1';
					iColCountBReset <= '1';
					iColCountAReset <= '1';
					nextState <= stComplete;
				elsif iColCountB = "100000" then
					iRowCountAEnable <= '1';
					iColCountBReset <= '1';
					iColCountAReset <= '1';
					nextState <= stReadBufferAB;
				elsif iColCountA = "11111" then
					iReadEnableAB <= '1';
					iColCountAReset <= '1';
					
					nextState <= stWaitWriteBufferD;
				else
					iReadEnableAB <= '1';
					iColCountAEnable <= '1';
					nextState <= stReadBufferAB;
				end if;
				
			when stWaitWriteBufferD =>
				iColCountBEnable <= '1';
				nextState <= stWriteBufferD;

			when stWriteBufferD=>
				iWriteEnableD(0) <= '1';
				iMacReset <= '1';
				nextState <= stReadBufferAB;
 
			when stComplete =>
				DataReady <= '1';
				nextState <= stIdle;			
		
		end case;
		
	end process;

end IntMatMulCore_arch;
