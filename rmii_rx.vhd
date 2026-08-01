-- Receives raw RMII signals (2 bits/cycle) and reassembles them into 8-bit bytes with a valid pulse.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity rmii_rx is
  Port ( clk_50 : in std_logic;
         CRS_DV : in std_logic;
         RXD : in std_logic_vector(1 downto 0);
         byte_out : out std_logic_vector( 7 downto 0);
         byte_valid : out std_logic
          );
end rmii_rx;

architecture Behavioral of rmii_rx is

-- signal interne que je shift
signal byte_shift : std_logic_vector( 7 downto 0);
-- j recois 2bits/cycle donc j'ai besoin de 4 cycle pour un byte
signal cpt : integer range 0 to 3:=0;
begin
process(clk_50)
begin
    if rising_edge(clk_50) then
        -- j'attend la commande pour commencer la lecture
        if CRS_DV = '1' then
            -- quand cpt est à 3 jai deja à ce cycle mon octet 
            if cpt  = 3 then 
                cpt <= 0;
                -- je shift mon sinal et je lis mon entre et je les lie à ma sortie  
                byte_out <= RXD & byte_shift(7 downto 2);
                byte_valid <= '1';
            else 
                byte_shift <= RXD & byte_shift(7 downto 2);
                cpt <= cpt + 1;
                byte_valid <= '0';           
            end if;
        else -- quand CRS_DV est à 0 je doit initialiser mes signaux
            cpt <= 0;
            byte_out <= "00000000";
            byte_valid <= '0';          
        end if; 
    end if;
end process;
end Behavioral;
