---------------------------------------------------------------------------------
-- Z80-CTC controler by Dar (darfpga@aol.fr) (19/10/2019)
-- http://darfpga.blogspot.fr
--
-- fix interrupts - Sorgelig
---------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity ctc_controler is
port(
 clock     : in std_logic;
 clock_ena : in std_logic;
 reset     : in std_logic;

 d_in      : in std_logic_vector( 7 downto 0);
 load_data : in std_logic;
 int_ack   : in std_logic;
 int_end   : in std_logic; -- RETI detected

 int_pulse_0 : in std_logic;
 int_pulse_1 : in std_logic;
 int_pulse_2 : in std_logic;
 int_pulse_3 : in std_logic;

 d_out : out std_logic_vector( 7 downto 0);
 int_n : out std_logic
);
end ctc_controler;

architecture struct of ctc_controler is

 signal int_vector : std_logic_vector(4 downto 0);

 signal wait_for_time_constant : std_logic;
 signal load_data_r  : std_logic; -- make sure load_data toggles to get one new data
 
 signal int_in_service : std_logic_vector(3 downto 0);
 signal int_req        : std_logic_vector(3 downto 0);

 signal int_ack_r : std_logic;
 signal int_end_r : std_logic;

begin


d_out <= int_vector & "000" when int_req(0) = '1' else
			int_vector & "010" when int_req(1) = '1' else
			int_vector & "100" when int_req(2) = '1' else
			int_vector & "110" when int_req(3) = '1' else (others => '0');

process (reset, clock)
begin

	if reset = '1' then -- hardware and software reset
		wait_for_time_constant <= '0';
		int_req <= (others => '0');
		int_in_service <= (others => '0');
		load_data_r <= '0';
		int_vector <= (others => '0');
		int_n <= '1';
	else
		if rising_edge(clock) then
			if clock_ena = '1' then

				load_data_r <= load_data;
				int_ack_r <= int_ack;
				int_end_r <= int_end;

				if load_data = '1' and load_data_r = '0' then

					if wait_for_time_constant = '1' then
						wait_for_time_constant <= '0';
					else
						if d_in(0) = '1' then -- check if its a control world
							wait_for_time_constant <= d_in(2);
						else                  -- its an interrupt vector
							int_vector <= d_in(7 downto 3);
						end if;
					end if;
				end if;

				if (int_req(0) = '1') or 
               (int_req(1) = '1' and int_in_service(0 downto 0) = 0) or 
               (int_req(2) = '1' and int_in_service(1 downto 0) = 0) or 
               (int_req(3) = '1' and int_in_service(2 downto 0) = 0) then
						int_n <= '0';
				end if;

				if int_pulse_0 = '1' then int_in_service(0) <= '1'; int_req(0) <= '1'; end if;
				if int_pulse_1 = '1' then int_in_service(1) <= '1'; int_req(1) <= '1'; end if;
				if int_pulse_2 = '1' then int_in_service(2) <= '1'; int_req(2) <= '1'; end if;
				if int_pulse_3 = '1' then int_in_service(3) <= '1'; int_req(3) <= '1'; end if;

				if int_ack_r = '0' and int_ack = '1' then
					if    int_req(0) = '1' then int_req(0) <= '0';
					elsif int_req(1) = '1' then int_req(1) <= '0';
					elsif int_req(2) = '1' then int_req(2) <= '0';
					elsif int_req(3) = '1' then int_req(3) <= '0';
					end if;
					int_n <= '1';
				end if;

				if int_end_r = '0' and int_end = '1' then
					if    int_in_service(0) = '1' then int_in_service(0) <= '0';
					elsif int_in_service(1) = '1' then int_in_service(1) <= '0';
					elsif int_in_service(2) = '1' then int_in_service(2) <= '0';
					elsif int_in_service(3) = '1' then int_in_service(3) <= '0';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

end struct;
