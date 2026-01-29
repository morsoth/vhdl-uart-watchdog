library ieee;
use ieee.std_logic_1164.all;

entity uart_rx is
    generic (
        DATA_BITS    : positive := 8;
        OVERSAMPLING : positive := 16
    );
    port(
        clk       : in std_logic;
        rst       : in std_logic;
        uart_tick : in std_logic;

        rx        : in std_logic;

        rx_valid  : out std_logic;
        rx_data   : out std_logic_vector(DATA_BITS-1 downto 0)
    );
end entity;

architecture rtl of uart_rx is
    type state_t is (IDLE_ST, START_ST, DATA_ST, STOP_ST);
    signal state : state_t := IDLE_ST;

    signal tick_count : natural range 0 to OVERSAMPLING-1 := 0;
    signal data_idx : natural range 0 to DATA_BITS-1 := 0;

    signal rx_ff1, rx_ff2 : std_logic := '1';  -- to reduce metastability 
    signal data_reg : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= IDLE_ST;
                tick_count <= 0;
                data_idx <= 0;
                rx_ff1 <= '1';
                rx_ff2 <= '1';
                data_reg <= (others => '0');

                rx_valid <= '0';
                rx_data <= (others => '0');

            else
                rx_ff1 <= rx;
                rx_ff2 <= rx_ff1;

                rx_valid <= '0';

                if uart_tick = '1' then
                    case state is
                        when IDLE_ST =>
                            tick_count <= 0;
							data_reg <= (others => '0');

                            if rx_ff2 = '0' then
                                state <= START_ST;
                            end if;

                        when START_ST =>
                            if tick_count = (OVERSAMPLING / 2) - 1 then
                                if rx_ff2 = '1' then
                                    state <= IDLE_ST;
                                    tick_count <= 0;
                                end if;
                            end if;

                            if tick_count = OVERSAMPLING - 1 then
                                state <= DATA_ST;
                                tick_count <= 0;
                                data_idx <= 0;
                            else
                                tick_count <= tick_count + 1;
                            end if;

                        when DATA_ST =>
                            if tick_count = (OVERSAMPLING / 2) - 1 then
                                data_reg(data_idx) <= rx_ff2;
                            end if;

                            if tick_count = OVERSAMPLING - 1 then
                                tick_count <= 0;

                                if data_idx = DATA_BITS - 1 then
                                    state <= STOP_ST;
                                    data_idx <= 0;
                                else 
                                    data_idx <= data_idx + 1;
                                end if;

                            else
                                tick_count <= tick_count + 1;
                            end if;

                        when STOP_ST =>
                            if tick_count = (OVERSAMPLING / 2) - 1 then
                                if rx_ff2 = '0' then
                                    state <= IDLE_ST;
                                    tick_count <= 0;
                                end if;
                            end if;

                            if tick_count = OVERSAMPLING - 1 then
                                rx_data <= data_reg;
                                rx_valid <= '1';

                                tick_count <= 0;
                                if rx_ff2 = '0' then
                                    state <= START_ST;
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