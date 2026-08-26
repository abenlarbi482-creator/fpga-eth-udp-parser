library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_asynchronous_FIFO is
--  Port ( );
end tb_asynchronous_FIFO;

architecture Behavioral of tb_asynchronous_FIFO is

signal write_clk : std_logic := '0';
signal read_clk  : std_logic := '0';
signal rst_write : std_logic := '1';
signal rst_read  : std_logic := '1';
signal write : std_logic := '0';
signal read : std_logic := '0';
signal full : std_logic := '0';
signal empty : std_logic:= '0';
signal data_in : std_logic_vector(8 downto 0) := (others => '0');
signal data_out : std_logic_vector(8 downto 0);


component asynchronous_FIFO is
  generic(FIFO_LENGTH : integer := 256;
          FIFO_MSB : integer := 7);
  Port ( write_clk : in std_logic;
         read_clk : in std_logic;
         rst_write : in std_logic;
         rst_read : in std_logic;
         write : in std_logic;
         read : in std_logic;
         data_in : in std_logic_vector(8 downto 0);
         data_out : out std_logic_vector(8 downto 0);
         empty_fifo : out std_logic;
         full_fifo : out std_logic
          );
end component;

begin

-- deux horloges independantes, non multiples l'une de l'autre
write_clk <= not(write_clk) after 7 ns;   -- ~71 MHz
read_clk  <= not(read_clk)  after 13 ns;  -- ~38 MHz

DUT : asynchronous_FIFO
generic map(FIFO_LENGTH => 256, FIFO_MSB => 7)
port map( write_clk => write_clk,
          read_clk  => read_clk,
          rst_write => rst_write,
          rst_read  => rst_read,
          write     => write,
          read      => read,
          data_in   => data_in,
          data_out  => data_out,
          empty_fifo => empty,
          full_fifo => full      
    );

-- process d'ecriture
process
begin
    rst_write <= '1';
    write <= '0';
    wait for 50 ns;
    rst_write <= '0';
    wait for 20 ns;

    -- ecrit 10 valeurs, une par cycle write_clk
    for i in 0 to 9 loop
        wait until rising_edge(write_clk);
        data_in <= std_logic_vector(to_unsigned(i, 9));
        write   <= '1';
        wait until rising_edge(write_clk);
        write   <= '0';
    end loop;

    wait;
end process;

-- process de lecture
process
begin
    rst_read <= '1';
    read <= '0';
    wait for 50 ns;
    rst_read <= '0';

    -- laisse le temps aux premieres ecritures d'arriver avant de lire
    wait for 100 ns;

    -- lit 10 valeurs, une par cycle read_clk
    for i in 0 to 9 loop
        wait until rising_edge(read_clk);
        read <= '1';
        wait until rising_edge(read_clk);
        read <= '0';
        wait until rising_edge(read_clk);
        assert data_out = std_logic_vector(to_unsigned(i, 9))
            report "Donnee lue incorrecte, attendu " & integer'image(i)
            severity error;
    end loop;

    wait for 100 ns;
    report "Fin du test FIFO asynchrone" severity note;
    wait;
end process;

end Behavioral;
