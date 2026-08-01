----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07.05.2026 11:11:53
-- Design Name: 
-- Module Name: tb_rmii_rx - Behavioral
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

entity tb_rmii_rx is
-- Port ( );
end tb_rmii_rx;

architecture Behavioral of tb_rmii_rx is
signal clk_50 : std_logic :='0';
signal CRS_DV : std_logic :='0';
signal RXD : std_logic_vector(1 downto 0) :="00";
signal byte_out :  std_logic_vector( 7 downto 0);
signal byte_valid :  std_logic; 

component rmii_rx is
  Port ( clk_50 : in std_logic;
         CRS_DV : in std_logic;
         RXD : in std_logic_vector(1 downto 0);
         byte_out : out std_logic_vector( 7 downto 0);
         byte_valid : out std_logic
          );
end component;

begin
clk_50 <= not(clk_50) after 10 ns;

UUt : rmii_rx  
port map( clk_50 => clk_50,
          CRS_DV => CRS_DV,
          RXD => RXD,
          byte_out => byte_out,
          byte_valid => byte_valid
    );   
process
begin 
CRS_DV <= '0';
RXD <="11";
wait for 20 ns;
CRS_DV <= '1';
wait for 40 ns ;
RXD <="10";
wait for 32 ns;
CRS_DV <= '0';
wait for 23 ns;
CRS_DV <= '1';

wait;
end process;

end Behavioral;
