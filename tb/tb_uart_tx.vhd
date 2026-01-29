library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_uart_tx is
end entity;

architecture tb of tb_uart_tx is
	constant CLK_HZ       : natural := 50_000_000;
	constant BAUDRATE     : natural := 115200;
	constant OVERSAMPLING : natural := 16;
	constant DATA_BITS    : natural := 8;

	constant T_CLK  : time := 1 sec / CLK_HZ;

	constant DIV    : positive := CLK_HZ / (BAUDRATE * OVERSAMPLING);
	constant T_TICK : time := DIV * T_CLK;
	constant T_BIT  : time := OVERSAMPLING * T_TICK;

	signal clk       : std_logic := '0';
	signal rst       : std_logic := '1';
	signal uart_tick : std_logic := '0';

	signal tx_start  : std_logic := '0';
	signal tx_data   : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
	signal tx        : std_logic;
	signal tx_accept  : std_logic;
	signal tx_busy   : std_logic;

	procedure check_tx_frame (
		signal tx_line       : in  std_logic;
		signal data  		 : in std_logic_vector(DATA_BITS-1 downto 0)
	) is
	begin
		wait until rising_edge(clk);

		wait for T_BIT/2;

		assert tx_line = '0'
			report "[ERROR]: expected start bit to be 0, got " & std_logic'image(tx_line) severity error;

		wait for T_BIT;

		for i in 0 to DATA_BITS-1 loop
			assert tx_line = data(i)
				report "[ERROR]: expected data(" & integer'image(i) & ") to be " & std_logic'image(data(i)) & ", got " & std_logic'image(tx_line) severity error;

			wait for T_BIT;
		end loop;

		assert tx_line = '1'
			report "[ERROR]: expected stop bit to be 1, got " & std_logic'image(tx_line) severity error;

		wait for T_BIT/2;
	end procedure;

begin
	u_baudgen: entity work.uart_baudgen
		generic map (
			CLK_HZ       => CLK_HZ,
			BAUDRATE     => BAUDRATE,
			OVERSAMPLING => OVERSAMPLING
		)
		port map (
			clk 	  => clk,
			rst 	  => rst,
			uart_tick => uart_tick
		);

	u_tx: entity work.uart_tx
		generic map (
			DATA_BITS    => DATA_BITS,
			OVERSAMPLING => OVERSAMPLING
		)
		port map (
			clk       => clk,
			rst       => rst,
			uart_tick => uart_tick,
			tx_start  => tx_start,
			tx_data   => tx_data,
			tx        => tx,
			tx_accept => tx_accept,
			tx_busy   => tx_busy
		);

  	clk <= not clk after T_CLK/2;

	p_tb : process
	begin
		rst <= '1';
		wait for T_CLK;
		rst <= '0';
		wait for 10 us;

		-- Test 1: Long idle --
        for i in 0 to 9 loop
            assert tx = '1'
                report "ERROR: tx no esta en idle"
                severity error;
            assert tx_busy = '0'
                report "ERROR: tx_busy activo en idle"
                severity error;

            wait for T_BIT;
		end loop;
        
		-- Test 2: 0x5A --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"5A";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 3: 0x00 --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"00";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 4: 0xFF --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"FF";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 5: 0xAA --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"AA";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 6: LSB only (0x01) --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"01";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 7: MSB only (0x80) --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"80";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		-- Test 8: Back-to-back --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"12";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;

		check_tx_frame(tx, tx_data);

		if tx_busy = '1' then
			wait until tx_busy /= '1';
		end if;
		
		tx_data <= x"34";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);

		wait for T_BIT;

		-- Test 9: Reset while transmission --

		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"99";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;

		tx_start <= '0';

		wait for T_BIT/2;

		wait for 4*T_BIT;

		rst <= '1';
		wait for T_BIT;
		rst <= '0';

		assert tx = '1'
			report "[ERROR]: tx didn't returned to idle after reset"
			severity error;

		assert tx_busy = '0'
			report "[ERROR]: tx_busy didn't returned to 0 after reset"
			severity error;

		-- Test 10: Recovery from reset --
		wait until rising_edge(clk);
		tx_start <= '1';
		tx_data <= x"E3";

		if tx_busy = '0' then
			wait until tx_busy /= '0';
		end if;
		
		tx_start <= '0';

		check_tx_frame(tx, tx_data);
		wait for T_BIT;

		wait for 10 us;

		report "[OK]: Testbench passed correctly!" severity note;
		finish;
	end process;

end architecture;
