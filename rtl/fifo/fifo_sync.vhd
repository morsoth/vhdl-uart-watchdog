library ieee;
use ieee.std_logic_1164.all;

entity fifo_sync is
    generic (
        DATA_BITS : positive := 8;
        SIZE      : positive := 4
    );

    port(
        clk     : in std_logic;
        rst     : in std_logic;

        rd_en   : in std_logic;
        rd_data : out std_logic_vector(DATA_BITS-1 downto 0);

        wr_en   : in std_logic;
        wr_data : in std_logic_vector(DATA_BITS-1 downto 0);

        full    : out std_logic;
        empty   : out std_logic
    );
end entity;

architecture rtl of fifo_sync is
    type mem_t is array (0 to SIZE-1) of std_logic_vector(DATA_BITS-1 downto 0);
    signal mem : mem_t := (others => (others => '0'));

    signal rd_ptr : natural range 0 to SIZE-1 := 0;
    signal wr_ptr : natural range 0 to SIZE-1 := 0;

    signal count : natural range 0 to SIZE := 0;

    signal will_rd : std_logic;
    signal will_wr : std_logic;

    function inc_ptr(p : natural) return natural is
    begin
        if p = SIZE-1 then
            return 0;
        else
            return p + 1;
        end if;
    end function;

begin
    empty <= '1' when count = 0 else '0';
    full <= '1' when count = SIZE else '0';

    rd_data <= mem(rd_ptr) when empty = '0' else
               wr_data     when wr_en = '1' else
               (others => '0');

    will_rd <= '1' when (rd_en = '1') and ((empty = '0') or (wr_en = '1')) else '0';
    will_wr <= '1' when (wr_en = '1') and ((full = '0') or (will_rd = '1')) else '0';

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rd_ptr <= 0;
                wr_ptr <= 0;
                count <= 0;
                mem <= (others => (others => '0'));

            else
                if will_wr = '1' then
                    mem(wr_ptr) <= wr_data;
                    wr_ptr <= inc_ptr(wr_ptr);
                end if;

                if will_rd = '1' then
                    rd_ptr <= inc_ptr(rd_ptr);
                end if;

                if will_wr = '1' and will_rd = '0' then
                    count <= count + 1;
                elsif will_wr = '0' and will_rd = '1' then
                    count <= count - 1;
                end if;

            end if;
        end if;
        
    end process;

end architecture;