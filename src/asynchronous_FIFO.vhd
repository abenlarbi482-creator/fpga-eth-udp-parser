library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity asynchronous_FIFO is
  generic(FIFO_LENGTH : integer := 256;
          FIFO_MSB : integer := 7);
  Port ( write_clk : in std_logic;
         read_clk : in std_logic;
         rst_write : std_logic;
         rst_read : std_logic;
         write : in std_logic;
         read : in std_logic;
         data_in : in std_logic_vector(8 downto 0);
         data_out : out std_logic_vector(8 downto 0);
         empty_fifo : out std_logic;
         full_fifo : out std_logic
          );
end asynchronous_FIFO;

architecture Behavioral of asynchronous_FIFO is

    type ram_p is array (0 to FIFO_LENGTH - 1) of std_logic_vector(8 downto 0);
    signal ram_payload : ram_p := (others => (others =>'0'));
    signal full : std_logic;
    signal empty : std_logic;  
    signal cpt_write_bi : unsigned(FIFO_MSB +1  downto 0);
    signal cpt_write_Gr : unsigned(FIFO_MSB +1 downto 0);
    signal cpt_write_Gr_1ff : unsigned(FIFO_MSB +1 downto 0);
    signal cpt_write_Gr_2ff : unsigned(FIFO_MSB  +1downto 0);
    signal cpt_read_bi : unsigned(FIFO_MSB +1 downto 0);
    signal cpt_read_Gr : unsigned(FIFO_MSB +1 downto 0);
    signal cpt_read_Gr_1ff : unsigned(FIFO_MSB +1 downto 0);
    signal cpt_read_Gr_2ff : unsigned(FIFO_MSB +1 downto 0);

           
begin
    empty_fifo <= empty;
    full_fifo <= full;
    process(write_clk, rst_write)
    begin 
        if rst_write = '1' then 
           cpt_write_bi <= (others =>'0');  
        elsif rising_edge(write_clk) then 

           if write = '1' and full = '0' then 
                ram_payload(to_integer(cpt_write_bi(FIFO_MSB downto 0))) <= data_in;
                cpt_write_bi <= cpt_write_bi + 1;
           end if;
        end if;
   end process;  
     
    process(read_clk, rst_read)
    begin 
        if rst_read = '1' then 
           cpt_read_bi <= (others =>'0');
        elsif rising_edge(read_clk) then 
           if read = '1' and empty = '0'  then 
                data_out <= ram_payload(to_integer(cpt_read_bi(FIFO_MSB downto 0)));
                cpt_read_bi <= cpt_read_bi + 1;
           end if;
        end if;
    end process; 

  
   process(write_clk)
    begin
        if rising_edge(write_clk) then
            cpt_read_Gr_1ff <= cpt_read_Gr;
            cpt_read_Gr_2ff <= cpt_read_Gr_1ff;
        end if;
    end process; 
   
   process(read_clk)
    begin
        if rising_edge(read_clk) then
            cpt_write_Gr_1ff <= cpt_write_Gr;
            cpt_write_Gr_2ff <= cpt_write_Gr_1ff;
        end if;
    end process;  
   
    cpt_write_Gr <= cpt_write_bi xor (cpt_write_bi srl 1);
    cpt_read_Gr <= cpt_read_bi xor (cpt_read_bi srl 1); 
    full <= '1' when cpt_write_Gr = (not cpt_read_Gr_2ff(FIFO_MSB+1 downto FIFO_MSB) & cpt_read_Gr_2ff(FIFO_MSB-1 downto 0)) else '0';
    empty <= '1' when cpt_read_Gr = cpt_write_Gr_2ff else '0';
end Behavioral;
