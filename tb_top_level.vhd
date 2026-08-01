-- Testbench for the full top_level module — drives raw RMII bits (RXD) through the complete pipeline (rmii_rx → eth_parser → crc32) with a valid
-- reference frame and checks frame_error stays low end-to-end

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_top_level is
--  Port ( );
end tb_top_level;

architecture Behavioral of tb_top_level is
signal clk_50 : std_logic :='0';
signal rst : std_logic :='1';
signal CRS_DV : std_logic :='0';
signal RXD : std_logic_vector(1 downto 0) :="00";
signal payload_byte : std_logic_vector( 7 downto 0 );
signal payload_valid : std_logic;
signal frame_error : std_logic;
signal ETH_RSTN : std_logic; 

component top_level is 
  Port (ETH_REFCLK : in std_logic;
         rst : in std_logic;
         ETH_CRSDV : in std_logic;
         ETH_RXD: in std_logic_vector(1 downto 0);
         ETH_RSTN : out std_logic;
         payload_byte : out std_logic_vector( 7 downto 0 );
         payload_valid : out std_logic;
         frame_error : out std_logic
          );
end component;

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
clk_50 <= not(clk_50) after 10 ns;

U : top_level
port map( ETH_REFCLK => clk_50,
         rst => rst,
         ETH_CRSDV => CRS_DV,
         ETH_RXD => RXD,
         ETH_RSTN => ETH_RSTN ,
         payload_byte => payload_byte,
         payload_valid => payload_valid,
         frame_error => frame_error
);

process
begin

    -- RESET
    rst <= '1';
    CRS_DV <= '0';
    RXD <= "00";
    wait for 100 ns;
    rst <= '0';
    wait for 100 ns;


    -- START FRAME
    CRS_DV <= '1';

    -- PREAMBULE + SFD
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"D5");  -- SFD

    -- DST MAC
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"22");
    send_byte(RXD, clk_50, x"33");
    send_byte(RXD, clk_50, x"44");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"66");
    
    -- SRC MAC
    send_byte(RXD, clk_50, x"AA");
    send_byte(RXD, clk_50, x"BB");
    send_byte(RXD, clk_50, x"CC");
    send_byte(RXD, clk_50, x"DD");
    send_byte(RXD, clk_50, x"EE");
    send_byte(RXD, clk_50, x"FF");
    
    -- ETHERTYPE (IPv4)
    send_byte(RXD, clk_50, x"08");
    send_byte(RXD, clk_50, x"00");
    
    -- IP HEADER (checksum correct = F7 79)
    send_byte(RXD, clk_50, x"45");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"20");  -- total length = 32 (20+8+4)
    
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    
    send_byte(RXD, clk_50, x"40");
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"F7");  -- checksum IP (octet fort)
    send_byte(RXD, clk_50, x"79");  -- checksum IP (octet faible)
    
    send_byte(RXD, clk_50, x"C0");
    send_byte(RXD, clk_50, x"A8");
    send_byte(RXD, clk_50, x"01");
    send_byte(RXD, clk_50, x"01");    
    send_byte(RXD, clk_50, x"C0");
    send_byte(RXD, clk_50, x"A8");
    send_byte(RXD, clk_50, x"01");
    send_byte(RXD, clk_50, x"02");
    
    -- UDP HEADER
    send_byte(RXD, clk_50, x"12");
    send_byte(RXD, clk_50, x"34");
    
    send_byte(RXD, clk_50, x"04");
    send_byte(RXD, clk_50, x"D2");  -- port destination attendu
    
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"0C");  -- longueur UDP = 12 (8+4)
    
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    

    -- PAYLOAD
    send_byte(RXD, clk_50, x"DE");
    send_byte(RXD, clk_50, x"AD");
    send_byte(RXD, clk_50, x"BE");
    send_byte(RXD, clk_50, x"EF");
    
    -- ETHERNET CRC / FCS (4 octets, residu attendu = 0xDEBB20E3)
    send_byte(RXD, clk_50, x"6F");
    send_byte(RXD, clk_50, x"7B");
    send_byte(RXD, clk_50, x"72");
    send_byte(RXD, clk_50, x"86");

    -- WAIT LAST BYTE
    wait until rising_edge(clk_50);

    -- END FRAME
    CRS_DV <= '0';
    RXD <= "00";

    wait for 100 ns;

    assert frame_error = '0'
        report "tb_top_level : frame_error inattendu a '1' sur une trame valide"
        severity error;

    report "Fin du test top_level" severity note;
    wait;
end process;

end Behavioral;
