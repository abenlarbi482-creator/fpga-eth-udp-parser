-- testbench for rmii_rx — sends full bytes via clock-aligned RMII nibbles and asserts correct byte reassembly, single-cycle byte_valid pulse,
-- and reset behavior when CRS_DV drops mid-byte.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_rmii_rx is
--  Port ( );
end tb_rmii_rx;

architecture Behavioral of tb_rmii_rx is

signal clk_50     : std_logic := '0';
signal CRS_DV     : std_logic := '0';
signal RXD        : std_logic_vector(1 downto 0) := "00";
signal byte_out   : std_logic_vector(7 downto 0);
signal byte_valid : std_logic;

component rmii_rx is
  Port ( clk_50 : in std_logic;
         CRS_DV : in std_logic;
         RXD : in std_logic_vector(1 downto 0);
         byte_out : out std_logic_vector( 7 downto 0);
         byte_valid : out std_logic
          );
end component;

-- envoie un octet complet : 4 nibbles de 2 bits, un par cycle d'horloge
-- (LSB en premier, comme le fait rmii_rx : RXD & byte_shift(7 downto 2))
procedure send_byte(
    signal RXD : out std_logic_vector(1 downto 0);
    signal clk : in  std_logic;
    data        : std_logic_vector(7 downto 0)
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

clk_50 <= not(clk_50) after 10 ns;

UUT : rmii_rx
port map( clk_50     => clk_50,
          CRS_DV     => CRS_DV,
          RXD        => RXD,
          byte_out   => byte_out,
          byte_valid => byte_valid
    );

process
begin
  
    -- ETAT INITIAL : CRS_DV bas -> byte_out et byte_valid a 0
    CRS_DV <= '0';
    RXD    <= "00";
    wait until rising_edge(clk_50);

    assert byte_out = x"00" and byte_valid = '0'
        report "TEST 0 : byte_out/byte_valid devraient etre a 0 quand CRS_DV='0'"
        severity error;

    wait for 40 ns;


    -- TEST 1 : envoi d'un octet complet 0xA5, verifie byte_out/byte_valid
    CRS_DV <= '1';
    wait until rising_edge(clk_50);

    send_byte(RXD, clk_50, x"A5");

    -- au cycle suivant le 4eme nibble, byte_out et byte_valid sont mis a jour
    wait until rising_edge(clk_50);

    assert byte_out = x"A5"
        report "TEST 1 : byte_out incorrect, attendu 0xA5"
        severity error;

    assert byte_valid = '1'
        report "TEST 1 : byte_valid aurait du passer a '1' apres le 4eme nibble"
        severity error;


    -- TEST 2 : byte_valid ne doit rester actif qu'un seul cycle
    wait until rising_edge(clk_50);

    assert byte_valid = '0'
        report "TEST 2 : byte_valid aurait du retomber a '0' un cycle apres le pulse"
        severity error;


    -- TEST 3 : deuxieme octet a la suite, verifie l'enchainement
    send_byte(RXD, clk_50, x"3C");
    wait until rising_edge(clk_50);

    assert byte_out = x"3C"
        report "TEST 3 : byte_out incorrect pour le second octet, attendu 0x3C"
        severity error;

    assert byte_valid = '1'
        report "TEST 3 : byte_valid aurait du passer a '1' apres le second octet"
        severity error;

    wait until rising_edge(clk_50);

 
    -- TEST 4 : CRS_DV retombe au milieu d'un octet -> reset immediat
    RXD <= "01";
    wait until rising_edge(clk_50);
    RXD <= "10";
    wait until rising_edge(clk_50);

    CRS_DV <= '0';
    wait until rising_edge(clk_50);

    assert byte_out = x"00" and byte_valid = '0'
        report "TEST 4 : byte_out/byte_valid auraient du etre remis a 0 quand CRS_DV repasse a '0'"
        severity error;

    wait for 100 ns;

    report "Fin des tests rmii_rx (unitaire)" severity note;
    wait;
end process;

end Behavioral;
