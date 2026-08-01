----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 09.05.2026 17:33:34
-- Design Name: 
-- Module Name: top_level - Behavioral
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

entity top_level is
  Port (ETH_REFCLK : in std_logic;
         rst : in std_logic;
         ETH_CRSDV : in std_logic;
         ETH_RXD: in std_logic_vector(1 downto 0);
         ETH_RSTN : out std_logic;
         payload_byte : out std_logic_vector( 7 downto 0 );
         payload_valid : out std_logic;
         frame_error : out std_logic
          );
end top_level;

architecture Behavioral of top_level is
component rmii_rx is
  Port ( clk_50 : in std_logic;
         CRS_DV : in std_logic;
         RXD : in std_logic_vector(1 downto 0);
         byte_out : out std_logic_vector( 7 downto 0);
         byte_valid : out std_logic
          );
end component;

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

component crc32 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    byte_in  : in  std_logic_vector(7 downto 0);
    preamble_out : in std_logic;
    byte_valid : in std_logic;
    CRS_DV : in std_logic;
    crc_out  : out std_logic_vector(31 downto 0)
  );
end component;
signal byte_out :  std_logic_vector( 7 downto 0);
signal byte_valid :  std_logic;
signal crc_out : std_logic_vector( 31 downto 0 );
signal preamble_out : std_logic;
signal startup_cnt : integer range 0 to 1_250_000;
signal rst_internal : std_logic;


begin
U1 : rmii_rx  
port map( clk_50 => ETH_REFCLK,
          CRS_DV =>  ETH_CRSDV,
          RXD => ETH_RXD,
          byte_out => byte_out,
          byte_valid => byte_valid
    );   

U2 : eth_parser
port map(clk_50 => ETH_REFCLK,
          rst => rst_internal,
          CRS_DV =>  ETH_CRSDV,
          byte_in => byte_out,
          crc_in => crc_out,
          byte_valid => byte_valid,
          payload_byte => payload_byte,
          preamble_out => preamble_out ,
          payload_valid => payload_valid,
          frame_error => frame_error        
    );

U3 : crc32 
port map( clk => ETH_REFCLK,
          rst => rst_internal,
          preamble_out => preamble_out,
          byte_in => byte_out,
          byte_valid => byte_valid,
          CRS_DV =>  ETH_CRSDV,
          crc_out =>  crc_out
);

process(ETH_REFCLK)
begin
    if rising_edge(ETH_REFCLK) then
        if rst = '1' then  -- bouton reset appuyé
            startup_cnt  <= 0;
            rst_internal <= '1';
            ETH_RSTN     <= '0';
        elsif startup_cnt >= 5 then
            rst_internal <= '0';
            ETH_RSTN     <= '1';
        else
            startup_cnt <= startup_cnt + 1;
            ETH_RSTN    <= '0';
        end if;
    end if;
end process;
end Behavioral;
