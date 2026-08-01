----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 10.05.2026 14:39:43
-- Design Name: 
-- Module Name: tb_top_level - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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
    ----------------------------------------------------------------
    -- RESET
    ----------------------------------------------------------------
    rst <= '1';
    CRS_DV <= '0';
    RXD <= "00";
    wait for 100 ns;
    rst <= '0';
    wait for 100 ns;

    ----------------------------------------------------------------
    -- START FRAME
    ----------------------------------------------------------------
    CRS_DV <= '1';

   ----------------------------------------------------------------
   -- PEAMBLE
   ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"22");
    send_byte(RXD, clk_50, x"33");
    send_byte(RXD, clk_50, x"44");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"D5");
    ----------------------------------------------------------------
    -- DST MAC
    ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"11");
    send_byte(RXD, clk_50, x"22");
    send_byte(RXD, clk_50, x"33");
    send_byte(RXD, clk_50, x"44");
    send_byte(RXD, clk_50, x"55");
    send_byte(RXD, clk_50, x"66");
    
    ----------------------------------------------------------------
    -- SRC MAC
    ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"AA");
    send_byte(RXD, clk_50, x"BB");
    send_byte(RXD, clk_50, x"CC");
    send_byte(RXD, clk_50, x"DD");
    send_byte(RXD, clk_50, x"EE");
    send_byte(RXD, clk_50, x"FF");
    
    ----------------------------------------------------------------
    -- ETHERTYPE (IPv4)
    ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"08");
    send_byte(RXD, clk_50, x"00");
    
    ----------------------------------------------------------------
    -- IP HEADER
    ----------------------------------------------------------------
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
    
    ----------------------------------------------------------------
    -- UDP HEADER
    ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"12");
    send_byte(RXD, clk_50, x"34");
    
    send_byte(RXD, clk_50, x"04");
    send_byte(RXD, clk_50, x"D2");
    
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"10");
    
    send_byte(RXD, clk_50, x"00");
    send_byte(RXD, clk_50, x"00");
    
    ----------------------------------------------------------------
    -- PAYLOAD
    ----------------------------------------------------------------
    send_byte(RXD, clk_50, x"DE");
    send_byte(RXD, clk_50, x"AD");
    send_byte(RXD, clk_50, x"BE");
    send_byte(RXD, clk_50, x"EF");
    
    -- ETHERNET CRC / FCS (4 BYTES)
    send_byte(RXD, clk_50, x"32");
    send_byte(RXD, clk_50, x"F9");
    send_byte(RXD, clk_50, x"FB");
    send_byte(RXD, clk_50, x"75");
    ----------------------------------------------------------------
    -- WAIT LAST BYTE
    ----------------------------------------------------------------
    wait until rising_edge(clk_50);

    ----------------------------------------------------------------
    -- END FRAME
    ----------------------------------------------------------------
    CRS_DV <= '0';
    RXD <= "00";

    wait;
end process;


end Behavioral;

