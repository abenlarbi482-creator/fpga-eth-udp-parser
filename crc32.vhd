--	Computes a running CRC32 over the frame (Ethernet CRC-32 polynomial) to verify frame integrity.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity crc32 is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    byte_in  : in  std_logic_vector(7 downto 0);
    preamble_out  : in std_logic;
    byte_valid : in std_logic;
    CRS_DV : in std_logic;
    crc_out  : out std_logic_vector(31 downto 0)
  );
end crc32;

architecture Behavioral of crc32 is
signal crc_reg : std_logic_vector(31 downto 0);
function update_crc(
    crc  : std_logic_vector(31 downto 0);
    data : std_logic_vector(7 downto 0)
) return std_logic_vector is
    variable c : unsigned(31 downto 0);
    variable d : unsigned(7 downto 0);
begin
    c := unsigned(crc);
    d := unsigned(data);

    for i in 0 to 7 loop
        if (c(0) xor d(i)) = '1' then
            c := (c srl 1) xor x"EDB88320";
        else
            c := (c srl 1);
        end if;
    end loop;

    return std_logic_vector(c);
end function;
begin
process(clk, rst)
begin
if rst = '1' then
    crc_reg <= x"FFFFFFFF"; 
elsif rising_edge(clk) then
    if CRS_DV = '0' then  
        crc_reg <= x"FFFFFFFF"; 
    else
        if (byte_valid ='1' and preamble_out = '1') then 
        crc_reg <= update_crc( crc_reg, byte_in); 
        end if;
    end if;
end if;
end process;
crc_out <= crc_reg;
end Behavioral;
