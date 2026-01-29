library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.env.all;

entity tb_uart_core is
end entity;

architecture tb of tb_uart_core is
  ---------------------------------------------------------------------------
  -- Configuración (DEBE coincidir con el DUT)
  ---------------------------------------------------------------------------
  constant CLK_HZ       : positive := 50_000_000;
  constant BAUDRATE     : positive := 115200;
  constant OVERSAMPLING : positive := 16;

  ---------------------------------------------------------------------------
  -- Timing CORRECTO (igual que el baudgen)
  ---------------------------------------------------------------------------
  constant T_CLK  : time := 1 sec / CLK_HZ;
  constant DIV    : positive := CLK_HZ / (BAUDRATE * OVERSAMPLING);
  constant T_TICK : time := DIV * T_CLK;
  constant T_BIT  : time := OVERSAMPLING * T_TICK;

  ---------------------------------------------------------------------------
  -- Señales
  ---------------------------------------------------------------------------
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal rx : std_logic := '1';
  signal tx : std_logic;

  signal rx_en    : std_logic := '0';
  signal rx_ready : std_logic;
  signal rx_data  : std_logic_vector(7 downto 0);

  signal tx_en    : std_logic := '0';
  signal tx_ready : std_logic;
  signal tx_data  : std_logic_vector(7 downto 0);

  ---------------------------------------------------------------------------
  -- UART RX driver (TIMING CORRECTO)
  ---------------------------------------------------------------------------
  procedure uart_rx_send(
    signal rx_line : out std_logic;
    constant b     : std_logic_vector(7 downto 0)
  ) is
  begin
    -- idle antes del start
    rx_line <= '1';
    wait for T_BIT;

    -- start bit
    rx_line <= '0';
    wait for T_BIT;

    -- data bits LSB first
    for i in 0 to 7 loop
      rx_line <= b(i);
      wait for T_BIT;
    end loop;

    -- stop bit
    rx_line <= '1';
    wait for T_BIT;
  end procedure;

begin
  ---------------------------------------------------------------------------
  -- Clock
  ---------------------------------------------------------------------------
  clk <= not clk after T_CLK/2;

  ---------------------------------------------------------------------------
  -- DUT
  ---------------------------------------------------------------------------
  dut : entity work.uart_core
    generic map (
      CLK_HZ       => CLK_HZ,
      BAUDRATE     => BAUDRATE,
      OVERSAMPLING => OVERSAMPLING,
      DATA_BITS    => 8,
      FIFO_SIZE    => 4
    )
    port map (
      clk      => clk,
      rst      => rst,
      rx       => rx,
      tx       => tx,
      rx_en    => rx_en,
      rx_ready => rx_ready,
      rx_data  => rx_data,
      tx_en    => tx_en,
      tx_ready => tx_ready,
      tx_data  => tx_data
    );

  ---------------------------------------------------------------------------
  -- Stimulus
  ---------------------------------------------------------------------------
  stim : process
    variable saved_byte : std_logic_vector(7 downto 0);
  begin
    -------------------------------------------------------------------------
    -- Reset
    -------------------------------------------------------------------------
    rst <= '1';
    rx  <= '1';
    wait for 10 * T_BIT;
    rst <= '0';
    wait for 10 * T_BIT;

    -------------------------------------------------------------------------
    -- RX: enviar byte
    -------------------------------------------------------------------------
    uart_rx_send(rx, x"55");

    -- esperar a que RX FIFO tenga dato
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    saved_byte := rx_data;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';

    -------------------------------------------------------------------------
    -- TX: reenviar el byte recibido
    -------------------------------------------------------------------------
    while tx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    tx_data <= saved_byte;

    tx_en   <= '1';
    wait until rising_edge(clk);
    tx_en   <= '0';

    -------------------------------------------------------------------------
    -- RX: muchos envios seguidos
    -------------------------------------------------------------------------

    uart_rx_send(rx, x"01");
    
    uart_rx_send(rx, x"02");

    uart_rx_send(rx, x"03");

    uart_rx_send(rx, x"04");

    uart_rx_send(rx, x"05"); -- lost byte

    uart_rx_send(rx, x"06");

    -- 0x01
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';

    -- 0x02
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';

    -- 0x03
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';

    -- 0x04
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';
    
    -- 0x06
    while rx_ready /= '1' loop
        wait until rising_edge(clk);
    end loop;

    rx_en <= '1';
    wait until rising_edge(clk);
    rx_en <= '0';

    -------------------------------------------------------------------------
    -- Fin
    -------------------------------------------------------------------------
    wait for 20 * T_BIT;
    finish;
  end process;

end architecture;
