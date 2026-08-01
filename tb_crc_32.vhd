----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01.08.2026
-- Design Name: 
-- Module Name: tb_crc32 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testbench unitaire pour crc32 SEUL (pas de rmii_rx, pas de eth_parser).
--              byte_in / byte_valid / preamble_out / CRS_DV sont pilotes directement.
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_crc32 is
--  Port ( );
end tb_crc32;

architecture Behavioral of tb_crc32 is

signal clk           : std_logic := '0';
signal rst           : std_logic := '1';
signal byte_in       : std_logic_vector(7 downto 0) := (others => '0');
signal preamble_out  : std_logic := '0';
signal byte_valid    : std_logic := '0';
signal CRS_DV        : std_logic := '0';
signal crc_out       : std_logic_vector(31 downto 0);

-- valeur residuelle attendue pour la trame de reference (message + FCS corrects)
constant CRC_OK : std_logic_vector(31 downto 0) := x"DEBB20E3";

component crc32 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    byte_in  : in  std_logic_vector(7 downto 0);
    preamble_out  : in std_logic;
    byte_valid : in std_logic;
    CRS_DV : in std_logic;
    crc_out  : out std_logic_vector(31 downto 0)
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

clk <= not(clk) after 10 ns;

DUT : crc32
port map( clk          => clk,
          rst          => rst,
          byte_in      => byte_in,
          preamble_out => preamble_out,
          byte_valid   => byte_valid,
          CRS_DV       => CRS_DV,
          crc_out      => crc_out
    );

process
begin
    ----------------------------------------------------------------
    -- RESET
    ----------------------------------------------------------------
    rst          <= '1';
    CRS_DV       <= '0';
    preamble_out <= '0';
    byte_in      <= (others => '0');
    byte_valid   <= '0';

    wait for 100 ns;

    rst <= '0';
    wait until rising_edge(clk);

    assert crc_out = x"FFFFFFFF"
        report "TEST 0 : crc_out devrait valoir FFFFFFFF juste apres reset"
        severity error;

    wait for 100 ns;

    ----------------------------------------------------------------
    -- TEST 1 : trame valide -> residu final attendu = CRC_OK
    --          on envoie d'abord un faux "preambule" (preamble_out='0')
    --          pour verifier qu'il n'est PAS accumule dans le CRC
    ----------------------------------------------------------------
    CRS_DV <= '1';

    -- octets de preambule envoyes AVANT que preamble_out ne passe a '1'
    -- -> ne doivent pas etre pris en compte dans le calcul du CRC
    send_byte(byte_in, byte_valid, clk, x"55");
    send_byte(byte_in, byte_valid, clk, x"55");
    send_byte(byte_in, byte_valid, clk, x"D5");  -- SFD (toujours hors CRC)

    assert crc_out = x"FFFFFFFF"
        report "TEST 1a : le preambule/SFD n'aurait pas du etre accumule dans le CRC"
        severity error;

    -- a partir d'ici, preamble_out passe a '1' comme le ferait eth_parser
    -- juste apres detection du SFD
    preamble_out <= '1';

    ----------------------------------------------------------------
    -- DST MAC + SRC MAC + ETHERTYPE + IP HEADER + UDP HEADER + PAYLOAD
    -- (memes octets que dans la trame de reference deja validee)
    ----------------------------------------------------------------
    send_byte(byte_in, byte_valid, clk, x"11");
    send_byte(byte_in, byte_valid, clk, x"22");
    send_byte(byte_in, byte_valid, clk, x"33");
    send_byte(byte_in, byte_valid, clk, x"44");
    send_byte(byte_in, byte_valid, clk, x"55");
    send_byte(byte_in, byte_valid, clk, x"66");

    send_byte(byte_in, byte_valid, clk, x"AA");
    send_byte(byte_in, byte_valid, clk, x"BB");
    send_byte(byte_in, byte_valid, clk, x"CC");
    send_byte(byte_in, byte_valid, clk, x"DD");
    send_byte(byte_in, byte_valid, clk, x"EE");
    send_byte(byte_in, byte_valid, clk, x"FF");

    send_byte(byte_in, byte_valid, clk, x"08");
    send_byte(byte_in, byte_valid, clk, x"00");

    send_byte(byte_in, byte_valid, clk, x"45");
    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"20");

    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"00");

    send_byte(byte_in, byte_valid, clk, x"40");
    send_byte(byte_in, byte_valid, clk, x"11");
    send_byte(byte_in, byte_valid, clk, x"F7");
    send_byte(byte_in, byte_valid, clk, x"79");

    send_byte(byte_in, byte_valid, clk, x"C0");
    send_byte(byte_in, byte_valid, clk, x"A8");
    send_byte(byte_in, byte_valid, clk, x"01");
    send_byte(byte_in, byte_valid, clk, x"01");

    send_byte(byte_in, byte_valid, clk, x"C0");
    send_byte(byte_in, byte_valid, clk, x"A8");
    send_byte(byte_in, byte_valid, clk, x"01");
    send_byte(byte_in, byte_valid, clk, x"02");

    send_byte(byte_in, byte_valid, clk, x"12");
    send_byte(byte_in, byte_valid, clk, x"34");

    send_byte(byte_in, byte_valid, clk, x"04");
    send_byte(byte_in, byte_valid, clk, x"D2");

    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"0C");

    send_byte(byte_in, byte_valid, clk, x"00");
    send_byte(byte_in, byte_valid, clk, x"00");

    send_byte(byte_in, byte_valid, clk, x"DE");
    send_byte(byte_in, byte_valid, clk, x"AD");
    send_byte(byte_in, byte_valid, clk, x"BE");
    send_byte(byte_in, byte_valid, clk, x"EF");

    ----------------------------------------------------------------
    -- FCS (4 octets) -> lui aussi accumule dans le CRC par ce design
    ----------------------------------------------------------------
    send_byte(byte_in, byte_valid, clk, x"6F");
    send_byte(byte_in, byte_valid, clk, x"7B");
    send_byte(byte_in, byte_valid, clk, x"72");
    send_byte(byte_in, byte_valid, clk, x"86");
    wait until rising_edge(clk);
    assert crc_out = CRC_OK
        report "TEST 1b : residu final incorrect, CRC_OK attendu (0xDEBB20E3)"
        severity error;

    wait for 40 ns;

    ----------------------------------------------------------------
    -- TEST 2 : CRS_DV retombe a '0' -> crc_out doit revenir a FFFFFFFF
    ----------------------------------------------------------------
    CRS_DV       <= '0';
    preamble_out <= '0';
    wait until rising_edge(clk);

    assert crc_out = x"FFFFFFFF"
        report "TEST 2 : crc_out aurait du revenir a FFFFFFFF quand CRS_DV repasse a 0"
        severity error;

    wait for 100 ns;

    ----------------------------------------------------------------
    -- TEST 3 : byte_valid='0' ne doit jamais faire evoluer le CRC,
    --          meme si preamble_out='1' et CRS_DV='1'
    ----------------------------------------------------------------
    CRS_DV       <= '1';
    preamble_out <= '1';
    byte_in      <= x"AB";
    byte_valid   <= '0';

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    CRS_DV       <= '0';
    preamble_out <= '0';
    wait until rising_edge(clk);
    assert crc_out = x"FFFFFFFF"
        report "TEST 3 : le CRC n'aurait pas du evoluer sans byte_valid='1'"
        severity error;
        
   wait until rising_edge(clk);

    wait for 100 ns;

    report "Fin des tests crc32 (unitaire)" severity note;
    wait;
end process;

end Behavioral;