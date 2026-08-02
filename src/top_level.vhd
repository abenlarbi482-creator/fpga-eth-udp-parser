-- Top level

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity top_level is
  Port (ETH_REFCLK : in std_logic;
        READ_CLK : in std_logic;
         rst : in std_logic;
         READ_RESET : in std_logic;
         ETH_CRSDV : in std_logic;
         ETH_RXD: in std_logic_vector(1 downto 0);
         MY_MAC : in std_logic_vector(47 downto 0);        
         ETH_RSTN : out std_logic;
         payload_length : out std_logic_vector(15 downto 0);
         frame_validated : out std_logic; 
         frame_error : out std_logic;
         frame_damaged : out std_logic;
         TDATA  : out std_logic_vector(7 downto 0);
         TVALID : out std_logic;
         TLAST  : out std_logic;
         TREADY : in  std_logic     -- fourni par le consommateur aval
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
   generic(ADDR_MAC : std_logic_vector(47 downto 0));
   Port (clk_50: in std_logic;
         rst : in std_logic;
         CRS_DV : in std_logic;
         byte_in : in std_logic_vector( 7 downto 0);
         byte_valid : in std_logic;
         crc_in : in std_logic_vector( 31 downto 0);
         payload_byte : out std_logic_vector( 7 downto 0 );
         payload_valid : out std_logic;
         payload_length : out std_logic_vector(15 downto 0);
         payload_last : out std_logic;
         frame_validated : out std_logic; 
         frame_error : out std_logic;
         frame_damaged : out std_logic;
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
 
component asynchronous_FIFO is
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
end component;

signal byte_out :  std_logic_vector( 7 downto 0);
signal byte_valid :  std_logic;
signal crc_out : std_logic_vector( 31 downto 0 );
signal preamble_out : std_logic;
signal startup_cnt : integer range 0 to 1_250_000;
signal rst_internal : std_logic;
signal ETH_CRSDV_2ff : std_logic;
signal ETH_CRSDV_1ff : std_logic;
signal ETH_RXD_2ff : std_logic_vector(1 downto 0); 
signal ETH_RXD_1ff : std_logic_vector(1 downto 0);
signal payload_byte_s : std_logic_vector(7 downto 0);
signal payload_last_s : std_logic ;
signal payload_valid_s : std_logic ;
signal data_out_s : std_logic_vector(8 downto 0);
signal data_in_s : std_logic_vector(8 downto 0);
signal full : std_logic;
signal empty : std_logic;
signal out_valid  : std_logic := '0';
signal rd_en : std_logic;


begin

TDATA <= data_out_s(7 downto 0);
TVALID <= out_valid;
TLAST <= data_out_s(8);
data_in_s <=  payload_last_s & payload_byte_s;

rd_en <= (not empty) and ( (not out_valid) or TREADY );

U1 : rmii_rx  
port map( clk_50 => ETH_REFCLK,
          CRS_DV =>  ETH_CRSDV_2ff,
          RXD => ETH_RXD_2ff,
          byte_out => byte_out,
          byte_valid => byte_valid
    );   

U2 : eth_parser
generic map( ADDR_MAC => MY_MAC)
port map(clk_50 => ETH_REFCLK,
          rst => rst_internal,
          CRS_DV =>  ETH_CRSDV_2ff,
          byte_in => byte_out,
          crc_in => crc_out,
          byte_valid => byte_valid,
          payload_byte => payload_byte_s,
          preamble_out => preamble_out,
          payload_valid => payload_valid_s,
          payload_length => payload_length,
          payload_last => payload_last_s,
          frame_validated => frame_validated,
          frame_error => frame_error, 
          frame_damaged => frame_damaged      
    );

U3 : crc32 
port map( clk => ETH_REFCLK,
          rst => rst_internal,
          preamble_out => preamble_out,
          byte_in => byte_out,
          byte_valid => byte_valid,
          CRS_DV =>  ETH_CRSDV_2ff,
          crc_out =>  crc_out
);

U4 :  asynchronous_FIFO
generic map( FIFO_LENGTH => 2048,
             FIFO_MSB => 10)
port map( write_clk => ETH_REFCLK,
          read_clk => READ_CLK ,
          rst_write => rst,
          rst_read  => READ_RESET,
          write => payload_valid_s,
          read =>  rd_en,
          data_in => data_in_s, 
          data_out => data_out_s,
          full_fifo => full,
          empty_fifo => empty
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

-- double bascules pour eviter les metastabilitées des signaux ETH_CRSDV et ETH_RXD
process(ETH_REFCLK, rst)
begin
    if rst = '1' then 
        ETH_CRSDV_2ff <= '0';
        ETH_CRSDV_1ff <= '0';
        ETH_RXD_2ff <= (others => '0');
        ETH_RXD_1ff <= (others => '0');
    elsif rising_edge(ETH_REFCLK) then 
        ETH_CRSDV_1ff <= ETH_CRSDV ;
        ETH_CRSDV_2ff <= ETH_CRSDV_1ff;
        ETH_RXD_1ff <= ETH_RXD ;
        ETH_RXD_2ff <= ETH_RXD_1ff; 
    end if;
end process;

process(READ_CLK, READ_RESET)
begin
    if READ_RESET = '1' then
        out_valid <= '0';
    elsif rising_edge(READ_CLK) then
        if rd_en = '1' then
            out_valid <= '1';
        elsif TREADY = '1' then
            out_valid <= '0';
        end if;
    end if;
end process;
      

end Behavioral;

