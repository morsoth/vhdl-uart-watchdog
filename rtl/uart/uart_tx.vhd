library ieee;
use ieee.std_logic_1164.all;

entity uart_tx is
    generic (
        DATA_BITS    : positive := 8;
        OVERSAMPLING : positive := 16
    );
    port(
        clk       : in std_logic;
        rst       : in std_logic;
        uart_tick : in std_logic;

        tx        : out std_logic;

        tx_start  : in std_logic;
        tx_data   : in std_logic_vector(DATA_BITS-1 downto 0);

        tx_busy   : out std_logic;
        tx_accept : out std_logic
    );
end entity;

architecture rtl of uart_tx is
    type state_t is (IDLE_ST, START_ST, DATA_ST, STOP_ST);
    signal state : state_t := IDLE_ST;

    signal tick_count : natural range 0 to OVERSAMPLING-1 := 0;
    signal data_idx : natural range 0 to DATA_BITS-1 := 0;

    signal data_reg : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');

begin
    tx_busy <= '1' when state /= IDLE_ST else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE_ST;
                tick_count <= 0;
                data_idx <= 0;
                data_reg <= (others => '0');
                
                tx <= '1';
                tx_accept <= '0';

            else
                tx_accept <= '0';

                if uart_tick = '1' then
                    case state is
                        when IDLE_ST =>
                            tx <= '1';
                            tick_count <= 0;

                            if tx_start = '1' then
                                tx_accept <= '1';
                                data_reg <= tx_data;
                                state <= START_ST;
                                tx <= '0';
                            end if;

                        when START_ST =>
                            if tick_count = OVERSAMPLING-1 then
                                state <= DATA_ST;
                                tx <= data_reg(0);
                                tick_count <= 0;
                                data_idx <= 0;
                            else
                                tx <= '0';
                                tick_count <= tick_count + 1;
                            end if;

                        when DATA_ST =>
                            if tick_count = OVERSAMPLING-1 then
                                tick_count <= 0;

                                if data_idx = DATA_BITS-1 then
                                    state <= STOP_ST;
                                    tx <= '1';
                                    data_idx <= 0;
                                else
                                    data_idx <= data_idx + 1;
                                    tx <= data_reg(data_idx + 1);
                                end if;

                            else
                                tx <= data_reg(data_idx);
                                tick_count <= tick_count + 1;
                            end if;

                        when STOP_ST =>
                            tx <= '1';

                            if tick_count = OVERSAMPLING-1 then
                                tick_count <= 0;
                                
                                if tx_start = '1' then
                                    tx_accept <= '1';
                                    data_reg <= tx_data;
                                    state <= START_ST;
                                    tx <= '0';
                                else
                                    state <= IDLE_ST;
                                end if;

                            else
                                tick_count <= tick_count + 1;
                            end if;

                    end case;
                end if;
            end if;
        end if;

    end process;

end architecture;