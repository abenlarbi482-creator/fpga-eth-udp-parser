-- Testbench for the full top_level module
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_top_level is
end tb_top_level;

architecture Behavioral of tb_top_level is

signal clk_50      : std_logic := '0';
signal read_clk    : std_logic := '0';
signal rst         : std_logic := '1';
signal READ_RESET  : std_logic := '1';
signal CRS_DV      : std_logic := '0';
signal RXD         : std_logic_vector(1 downto 0) := "00";
signal MY_MAC      : std_logic_vector(47 downto 0) := x"112233445566";

signal ETH_RSTN        : std_logic;
signal payload_length  : std_logic_vector(15 downto 0);
signal frame_validated : std_logic;
signal frame_error     : std_logic;
signal frame_damaged   : std_logic;

signal TDATA  : std_logic_vector(7 downto 0);
signal TVALID : std_logic;
signal TLAST  : std_logic;
signal TREADY : std_logic := '0';

component top_level is
  Port (ETH_REFCLK : in std_logic;
        READ_CLK : in std_logic;
        rst : in std_logic;
        READ_RESET : in std_logic;
        ETH_CRSDV : in std_logic;
        ETH_RXD: in std_logic_vector(1 downto 0);
        MY_MAC : in std_logic_vector(47 downto 0);
        ETH_RSTN : out std_logic;
        payload_length : out std_logic_vector(15 downto 0);
        frame_validated : out std_logic;
        frame_error : out std_logic;
        frame_damaged : out std_logic;
        TDATA  : out std_logic_vector(7 downto 0);
        TVALID : out std_logic;
        TLAST  : out std_logic;
        TREADY : in  std_logic
         );
end component;

-- envoie un octet sur 4 symboles RMII (2 bits par cycle)
procedure send_byte(
    signal RXD : out std_logic_vector(1 downto 0);
    signal clk : in std_logic;
    data : std_logic_vector(7 downto 0)
) is
begin
    RXD <= data(1 downto 0);
    wait until rising_edge(clk);

    RXD <= data(3 downto 2);
    wait until rising_edge(clk);

    RXD <= data(5 downto 4);
    wait until rising_edge(clk);

    RXD <= data(7 downto 6);
    wait until rising_edge(clk);
end procedure;

begin

-- horloge écriture (RMII / 50 MHz)
clk_50 <= not(clk_50) after 10 ns;
-- horloge lecture (domaine consommateur AXI-Stream, volontairement asynchrone)
read_clk <= not(read_clk) after 7 ns;

U : top_level
port map( ETH_REFCLK  => clk_50,
          READ_CLK    => read_clk,
          rst         => rst,
          READ_RESET  => READ_RESET,
          ETH_CRSDV   => CRS_DV,
          ETH_RXD     => RXD,
          MY_MAC      => MY_MAC,
          ETH_RSTN    => ETH_RSTN,
          payload_length  => payload_length,
          frame_validated => frame_validated,
          frame_error     => frame_error,
          frame_damaged   => frame_damaged,
          TDATA  => TDATA,
          TVALID => TVALID,
          TLAST  => TLAST,
          TREADY => TREADY
);

-- generation de trame
process
begin
    -- reset
    rst <= '1';
    READ_RESET <= '1';
    CRS_DV <= '0';
    RXD <= "00";
    wait for 100 ns;
    rst <= '0';
    READ_RESET <= '0';
    wait for 100 ns;

    -- debut de trame
    CRS_DV <= '1';

    -- preambule
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"22");
    send_byte(RXD, clk_50, x"33");
    send_byte(RXD, clk_50, x"44");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"D5");

    -- MAC destination (broadcast pour matcher facilement)
    send_byte(RXD, clk_50, x"FF");
    send_byte(RXD, clk_50, x"FF");
    send_byte(RXD, clk_50, x"FF");
    send_byte(RXD, clk_50, x"FF");
    send_byte(RXD, clk_50, x"FF");
    send_byte(RXD, clk_50, x"FF");

    -- MAC source
    send_byte(RXD, clk_50, x"AA");
    send_byte(RXD, clk_50, x"BB");
    send_byte(RXD, clk_50, x"CC");
    send_byte(RXD, clk_50, x"DD");
    send_byte(RXD, clk_50, x"EE");
    send_byte(RXD, clk_50, x"FF");

    -- ethertype IPv4
    send_byte(RXD, clk_50, x"08");
    send_byte(RXD, clk_50, x"00");

    -- entete IP
    send_byte(RXD, clk_50, x"45");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"20");

    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");

    send_byte(RXD, clk_50, x"40");
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");

    send_byte(RXD, clk_50, x"C0");
    send_byte(RXD, clk_50, x"A8");
    send_byte(RXD, clk_50, x"01");
    send_byte(RXD, clk_50, x"01");

    send_byte(RXD, clk_50, x"C0");
    send_byte(RXD, clk_50, x"A8");
    send_byte(RXD, clk_50, x"01");
    send_byte(RXD, clk_50, x"02");

    -- entete UDP (port dest 0x04D2, longueur 0x0010 -> 8 octets de payload)
    send_byte(RXD, clk_50, x"12");
    send_byte(RXD, clk_50, x"34");

    send_byte(RXD, clk_50, x"04");
    send_byte(RXD, clk_50, x"D2");

    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"10");

    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");

    -- payload
    send_byte(RXD, clk_50, x"DE");
    send_byte(RXD, clk_50, x"AD");
    send_byte(RXD, clk_50, x"BE");
    send_byte(RXD, clk_50, x"EF");
    send_byte(RXD, clk_50, x"01");
    send_byte(RXD, clk_50, x"02");
    send_byte(RXD, clk_50, x"03");
    send_byte(RXD, clk_50, x"04");

    -- FCS ethernet (4 octets)
    send_byte(RXD, clk_50, x"68");
    send_byte(RXD, clk_50, x"7A");
    send_byte(RXD, clk_50, x"C6");
    send_byte(RXD, clk_50, x"62");

    wait until rising_edge(clk_50);

    -- fin de trame
    CRS_DV <= '0';
    RXD <= "00";

    wait;
end process;

-- consommateur AXI-Stream : TREADY permanent, avec une pause pour tester le backpressure
process
begin
    TREADY <= '0';
    wait for 300 ns;
    TREADY <= '1';
    wait for 500 ns;
    -- pause volontaire pour verifier que TDATA/TVALID restent geles
    TREADY <= '0';
    wait for 40 ns;
    TREADY <= '1';
    wait;
end process;

-- capture des mots recus sur le bus AXI-Stream
process(read_clk)
begin
    if rising_edge(read_clk) then
        if TVALID = '1' and TREADY = '1' then
            report "AXIS beat : data=" & integer'image(to_integer(unsigned(TDATA)));
        end if;
    end if;
end process;

-- verification du statut de trame
process
begin
    wait until frame_validated = '1' or frame_error = '1' or frame_damaged = '1';
    assert frame_error = '0'
        report "ERREUR : frame_error inattendu" severity error;
    assert frame_damaged = '0'
        report "ERREUR : frame_damaged inattendu " severity error;
    assert frame_validated = '1'
        report "ERREUR : la trame aurait du etre validee" severity error;
    assert payload_length = x"0008"
        report "ERREUR : payload_length incorrect" severity error;
    wait;
end process;

-- verification du contenu et de TLAST sur le bus AXI-Stream
process
    type payload_array is array (0 to 7) of std_logic_vector(7 downto 0);
    constant expected : payload_array := (x"DE", x"AD", x"BE", x"EF",
                                           x"01", x"02", x"03", x"04");
    variable idx : integer := 0;
begin
    wait until rst = '0';
    while idx <= 7 loop
        wait until rising_edge(read_clk) and TVALID = '1' and TREADY = '1';
        assert TDATA = expected(idx)
            report "ERREUR : octet " & integer'image(idx) & " incorrect" severity error;
        if idx = 7 then
            assert TLAST = '1'
                report "ERREUR : TLAST attendu sur le dernier octet" severity error;
        else
            assert TLAST = '0'
                report "ERREUR : TLAST inattendu avant le dernier octet" severity error;
        end if;
        idx := idx + 1;
    end loop;
    report "OK : les 8 octets de payload recus sont corrects";
    wait;
end process;

end Behavioral;
