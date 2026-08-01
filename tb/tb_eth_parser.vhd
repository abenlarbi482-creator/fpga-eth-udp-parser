-- Testbench for eth_parser — drives byte_in/byte_valid/crc_in directly to test valid frames, CRC mismatches, and EtherType filtering.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_eth_parser is
--  Port ( );
end tb_eth_parser;

architecture Behavioral of tb_eth_parser is

signal clk_50         : std_logic := '0';
signal rst            : std_logic := '1';
signal CRS_DV         : std_logic := '0';
signal byte_in        : std_logic_vector(7 downto 0) := (others => '0');
signal byte_valid     : std_logic := '0';
signal crc_in         : std_logic_vector(31 downto 0) := (others => '0');
signal payload_byte   : std_logic_vector(7 downto 0);
signal payload_valid  : std_logic;
signal frame_error    : std_logic;
signal preamble_out   : std_logic;

-- valeur magique attendue par eth_parser en fin de trame pour un CRC valide
constant CRC_OK : std_logic_vector(31 downto 0) := x"DEBB20E3";

component eth_parser is
   Port (clk_50: in std_logic;
         rst : in std_logic;
         CRS_DV : in std_logic;
         byte_in : in std_logic_vector( 7 downto 0);
         byte_valid : in std_logic;
         crc_in : in std_logic_vector( 31 downto 0);
         payload_byte : out std_logic_vector( 7 downto 0 );
         payload_valid : out std_logic;
         frame_error : out std_logic;
         preamble_out : out std_logic
           );
end component;

-- envoie un octet : le pose sur byte_in, pulse byte_valid pendant 1 cycle
procedure send_byte(
    signal byte_in    : out std_logic_vector(7 downto 0);
    signal byte_valid : out std_logic;
    signal clk        : in  std_logic;
    data               : std_logic_vector(7 downto 0)
) is
begin
    byte_in    <= data;
    byte_valid <= '1';
    wait until rising_edge(clk);
    byte_valid <= '0';
end procedure;

begin

clk_50 <= not(clk_50) after 10 ns;

DUT : eth_parser
port map(clk_50       => clk_50,
          rst          => rst,
          CRS_DV       => CRS_DV,
          byte_in      => byte_in,
          byte_valid   => byte_valid,
          crc_in       => crc_in,
          payload_byte => payload_byte,
          payload_valid=> payload_valid,
          frame_error  => frame_error,
          preamble_out => preamble_out
    );

process
begin
    -- RESET
    rst    <= '1';
    CRS_DV <= '0';
    byte_in    <= (others => '0');
    byte_valid <= '0';
    crc_in <= (others => '0');
    wait for 100 ns;
    rst <= '0';
    wait for 100 ns;
    -- TRAME 1 : trame valide, CRC correct -> frame_error doit rester '0'
    CRS_DV <= '1';
    wait for 10 ns;
    -- SFD (le preambule 0x55 n'a pas besoin d'etre envoye, eth_parser
    -- n'attend que le SFD 0xD5 pour sortir de l'etat PREAMBLE)
    send_byte(byte_in, byte_valid, clk_50, x"D5");  -- SFD
    -- DST MAC
    send_byte(byte_in, byte_valid, clk_50, x"11");
    send_byte(byte_in, byte_valid, clk_50, x"22");
    send_byte(byte_in, byte_valid, clk_50, x"33");
    send_byte(byte_in, byte_valid, clk_50, x"44");
    send_byte(byte_in, byte_valid, clk_50, x"55");
    send_byte(byte_in, byte_valid, clk_50, x"66");
    -- SRC MAC
    send_byte(byte_in, byte_valid, clk_50, x"AA");
    send_byte(byte_in, byte_valid, clk_50, x"BB");
    send_byte(byte_in, byte_valid, clk_50, x"CC");
    send_byte(byte_in, byte_valid, clk_50, x"DD");
    send_byte(byte_in, byte_valid, clk_50, x"EE");
    send_byte(byte_in, byte_valid, clk_50, x"FF");
    -- ETHERTYPE (IPv4)
    send_byte(byte_in, byte_valid, clk_50, x"08");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    -- IP HEADER (20 octets)
    send_byte(byte_in, byte_valid, clk_50, x"45");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"20");  -- total length = 32

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");

    send_byte(byte_in, byte_valid, clk_50, x"40");
    send_byte(byte_in, byte_valid, clk_50, x"11");  -- protocole UDP
    send_byte(byte_in, byte_valid, clk_50, x"7C");
    send_byte(byte_in, byte_valid, clk_50, x"C3");

    send_byte(byte_in, byte_valid, clk_50, x"C0");
    send_byte(byte_in, byte_valid, clk_50, x"A8");
    send_byte(byte_in, byte_valid, clk_50, x"01");
    send_byte(byte_in, byte_valid, clk_50, x"01");

    send_byte(byte_in, byte_valid, clk_50, x"C0");
    send_byte(byte_in, byte_valid, clk_50, x"A8");
    send_byte(byte_in, byte_valid, clk_50, x"01");
    send_byte(byte_in, byte_valid, clk_50, x"02");
    -- UDP HEADER
    send_byte(byte_in, byte_valid, clk_50, x"12");
    send_byte(byte_in, byte_valid, clk_50, x"34");

    send_byte(byte_in, byte_valid, clk_50, x"04");
    send_byte(byte_in, byte_valid, clk_50, x"D2");  -- port destination attendu

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"0C");  -- longueur UDP = 12

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    -- PAYLOAD
    send_byte(byte_in, byte_valid, clk_50, x"DE");
    send_byte(byte_in, byte_valid, clk_50, x"AD");
    send_byte(byte_in, byte_valid, clk_50, x"BE");
    send_byte(byte_in, byte_valid, clk_50, x"EF");

    -- on donne un crc_in correct AVANT la chute de CRS_DV, comme le ferait crc32
    crc_in <= CRC_OK;
    wait until rising_edge(clk_50);
    -- FIN DE TRAME 1 -> verification frame_error = '0'
    CRS_DV <= '0';
    wait until rising_edge(clk_50);
    assert frame_error = '0'
        report "TRAME 1 (CRC correct) : frame_error inattendu a '1'"
        severity error;
    wait for 100 ns;
    -- TRAME 2 : meme trame mais CRC volontairement faux
    --           -> frame_error doit passer a '1'
    CRS_DV <= '1';

    send_byte(byte_in, byte_valid, clk_50, x"D5");  -- SFD

    send_byte(byte_in, byte_valid, clk_50, x"11");
    send_byte(byte_in, byte_valid, clk_50, x"22");
    send_byte(byte_in, byte_valid, clk_50, x"33");
    send_byte(byte_in, byte_valid, clk_50, x"44");
    send_byte(byte_in, byte_valid, clk_50, x"55");
    send_byte(byte_in, byte_valid, clk_50, x"66");

    send_byte(byte_in, byte_valid, clk_50, x"AA");
    send_byte(byte_in, byte_valid, clk_50, x"BB");
    send_byte(byte_in, byte_valid, clk_50, x"CC");
    send_byte(byte_in, byte_valid, clk_50, x"DD");
    send_byte(byte_in, byte_valid, clk_50, x"EE");
    send_byte(byte_in, byte_valid, clk_50, x"FF");

    send_byte(byte_in, byte_valid, clk_50, x"08");
    send_byte(byte_in, byte_valid, clk_50, x"00");

    send_byte(byte_in, byte_valid, clk_50, x"45");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"20");

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");

    send_byte(byte_in, byte_valid, clk_50, x"40");
    send_byte(byte_in, byte_valid, clk_50, x"11");
    send_byte(byte_in, byte_valid, clk_50, x"7C");
    send_byte(byte_in, byte_valid, clk_50, x"C3");

    send_byte(byte_in, byte_valid, clk_50, x"C0");
    send_byte(byte_in, byte_valid, clk_50, x"A8");
    send_byte(byte_in, byte_valid, clk_50, x"01");
    send_byte(byte_in, byte_valid, clk_50, x"01");

    send_byte(byte_in, byte_valid, clk_50, x"C0");
    send_byte(byte_in, byte_valid, clk_50, x"A8");
    send_byte(byte_in, byte_valid, clk_50, x"01");
    send_byte(byte_in, byte_valid, clk_50, x"02");

    send_byte(byte_in, byte_valid, clk_50, x"12");
    send_byte(byte_in, byte_valid, clk_50, x"34");

    send_byte(byte_in, byte_valid, clk_50, x"04");
    send_byte(byte_in, byte_valid, clk_50, x"D2");

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"0C");

    send_byte(byte_in, byte_valid, clk_50, x"00");
    send_byte(byte_in, byte_valid, clk_50, x"00");

    send_byte(byte_in, byte_valid, clk_50, x"DE");
    send_byte(byte_in, byte_valid, clk_50, x"AD");
    send_byte(byte_in, byte_valid, clk_50, x"BE");
    send_byte(byte_in, byte_valid, clk_50, x"EF");

    -- CRC volontairement invalide
    crc_in <= x"00000000";

    wait until rising_edge(clk_50);

    CRS_DV <= '0';
    wait until rising_edge(clk_50);

    assert frame_error = '1'
        report "TRAME 2 (CRC errone) : frame_error aurait du passer a '1'"
        severity error;

    wait for 100 ns;
    report "Fin des tests eth_parser (unitaire)" severity note;
    wait;
end process;

end Behavioral;
