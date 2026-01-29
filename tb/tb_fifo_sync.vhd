library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_fifo_sync is
end entity;

architecture tb of tb_fifo_sync is
    constant DATA_BITS : positive := 8;
    constant SIZE      : positive := 4;

	constant CLK_HZ : natural := 50_000_000;
    constant T_CLK  : time := 1 sec / CLK_HZ;

    signal clk     : std_logic := '0';
    signal rst     : std_logic := '1';

    signal rd_en   : std_logic := '0';
    signal rd_data : std_logic_vector(DATA_BITS-1 downto 0);

    signal wr_en   : std_logic := '0';
    signal wr_data : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');

    signal full    : std_logic;
    signal empty   : std_logic;

    procedure tick is
    begin
        wait until rising_edge(clk);
        wait for 0 ns;
    end procedure;

begin
    clk <= not clk after T_CLK;

    u_fifo : entity work.fifo_sync
        generic map (
            DATA_BITS => DATA_BITS,
            SIZE      => SIZE
        )
        port map (
            clk     => clk,
            rst     => rst,
            rd_en   => rd_en,
            rd_data => rd_data,
            wr_en   => wr_en,
            wr_data => wr_data,
            full    => full,
            empty   => empty
        );

    stim: process
        variable v : unsigned(DATA_BITS-1 downto 0);
    begin
        ------------------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------------------
        rd_en   <= '0';
        wr_en   <= '0';
        wr_data <= (others => '0');

        tick;
        tick;
        rst <= '0';
        tick;

        assert empty = '1' report "After reset: empty should be 1" severity failure;
        assert full  = '0' report "After reset: full should be 0" severity failure;

        ------------------------------------------------------------------------
        -- WRITE 1 byte -> FIFO not empty, rd_data should show that byte (FWFT)
        ------------------------------------------------------------------------
        v := to_unsigned(16#A1#, DATA_BITS);
        wr_data <= std_logic_vector(v);
        wr_en   <= '1';
        rd_en   <= '0';

        -- During this cycle (still empty before edge), bypass shows wr_data
        wait for 2 ns;
        assert rd_data = std_logic_vector(v)
            report "FWFT bypass during write-into-empty should show wr_data"
            severity failure;

        tick; -- commit write
        wr_en <= '0';
        tick;

        assert empty = '0' report "After 1 write: empty should be 0" severity failure;
        assert rd_data = std_logic_vector(v)
            report "After 1 write: rd_data should show front element (A1)"
            severity failure;

        ------------------------------------------------------------------------
        -- READ 1 byte -> FIFO empty
        ------------------------------------------------------------------------
        rd_en <= '1';
        tick;         -- pop occurs here
        rd_en <= '0';
        tick;

        assert empty = '1' report "After read back to empty: empty should be 1" severity failure;
        assert full  = '0' report "After read back to empty: full should be 0" severity failure;

        ------------------------------------------------------------------------
        -- BYPASS TEST: empty + rd_en + wr_en same cycle => rd_data == wr_data
        -- and FIFO stays empty (count stays 0)
        ------------------------------------------------------------------------
        v := to_unsigned(16#55#, DATA_BITS);
        wr_data <= std_logic_vector(v);
        wr_en   <= '1';
        rd_en   <= '1';

        wait for 2 ns; -- combinacional
        assert empty = '1' report "Before bypass edge: should be empty" severity failure;
        assert rd_data = std_logic_vector(v)
            report "Bypass empty rd+wr: rd_data must equal wr_data (55) in same cycle"
            severity failure;

        tick; -- consume+write simultaneously, count stays 0
        wr_en <= '0';
        rd_en <= '0';
        tick;

        assert empty = '1'
            report "After bypass empty rd+wr: FIFO should remain empty (count=0)"
            severity failure;

        ------------------------------------------------------------------------
        -- FILL FIFO to FULL
        ------------------------------------------------------------------------
        for i in 0 to SIZE-1 loop
            v := to_unsigned(16#10# + i, DATA_BITS); -- 0x10,0x11,...
            wr_data <= std_logic_vector(v);
            wr_en   <= '1';
            rd_en   <= '0';
            tick;
        end loop;
        wr_en <= '0';
        tick;

        assert full  = '1' report "After filling: full should be 1" severity failure;
        assert empty = '0' report "After filling: empty should be 0" severity failure;

        -- Front should be 0x10
        assert rd_data = std_logic_vector(to_unsigned(16#10#, DATA_BITS))
            report "Front after filling should be 0x10"
            severity failure;

        ------------------------------------------------------------------------
        -- WRITE when FULL without READ -> must be blocked (front stays same)
        ------------------------------------------------------------------------
        wr_data <= x"EE";
        wr_en   <= '1';
        rd_en   <= '0';
        tick;
        wr_en <= '0';
        tick;

        assert full = '1' report "Write while full (no read): full should remain 1" severity failure;
        assert rd_data = std_logic_vector(to_unsigned(16#10#, DATA_BITS))
            report "Write while full (no read): front should remain 0x10"
            severity failure;

        ------------------------------------------------------------------------
        -- READ+WRITE when FULL -> allowed, keeps FULL and advances front
        ------------------------------------------------------------------------
        -- We read one (0x10) and write 0x99 in same cycle, count stays SIZE.
        wr_data <= x"99";
        wr_en   <= '1';
        rd_en   <= '1';

        -- before edge, rd_data is old front (0x10)
        wait for 2 ns;
        assert rd_data = std_logic_vector(to_unsigned(16#10#, DATA_BITS))
            report "Full rd+wr: rd_data before edge should be old front 0x10"
            severity failure;

        tick; -- pop+push
        wr_en <= '0';
        rd_en <= '0';
        tick;

        assert full = '1' report "After full rd+wr: should remain full" severity failure;
        -- new front should now be 0x11 (since we removed 0x10)
        assert rd_data = std_logic_vector(to_unsigned(16#11#, DATA_BITS))
            report "After full rd+wr: new front should be 0x11"
            severity failure;

        ------------------------------------------------------------------------
        -- DRAIN FIFO completely to check ordering and empty
        ------------------------------------------------------------------------
        for i in 1 to SIZE-1 loop
            rd_en <= '1';
            tick;
            rd_en <= '0';
            tick;
        end loop;

        assert empty = '1' report "After draining: empty should be 1" severity failure;

        report "TB PASSED" severity note;
        finish;
    end process;

end architecture;
