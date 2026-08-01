--	State machine that parses Ethernet, IPv4, and UDP headers, filters by EtherType/protocol/port, and extracts the UDP payload.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity eth_parser is
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
end eth_parser;

architecture Behavioral of eth_parser is
type state is  (IDLE, PREAMBLE, ETH_HEADER, IP_HEADER, UDP_HEADER, PAYLOAD, DROP);
signal state_p : state := IDLE;
--signal interne pour verifier le type et la destination
signal msb_tmp : std_logic_vector(7 downto 0);
--signal pour stocker les quatres dernieres valeurs de playload
signal playload_shift : std_logic_vector(31 downto 0);
signal cpt : integer range 0 to 46;  
begin
process(clk_50,rst)
begin
if rst = '1' then
   payload_byte <= (others =>'0'); 
   payload_valid <= '0'; 
   frame_error <= '0';
   state_p <= IDLE;
   msb_tmp <= (others =>'0');  
   cpt <= 0; 
   playload_shift <= (others =>'0');
   preamble_out <= '0';
elsif rising_edge(clk_50) then
   case state_p is 
       -- etat IDLE j'initialise mes signaux 
       when IDLE =>
           payload_byte <= (others =>'0'); 
           payload_valid <= '0'; 
           frame_error <= '0'; 
           msb_tmp <= (others =>'0'); 
           cpt <= 0; 
           playload_shift <= (others =>'0');
           preamble_out <= '0';
           if CRS_DV ='1' then 
                state_p <= PREAMBLE;
           end if;
       -- Dans le preambule j'attend AB pour savoir le debut du MAC
       when PREAMBLE => 
           if  CRS_DV ='1' then
               if ( byte_valid = '1' and  byte_in = x"D5" ) then 
               state_p <= ETH_HEADER; 
               preamble_out <= '1';              
               end if;                
           else state_p <= IDLE; 
           end if;
       -- Dans cet etat je compte ljusqua la fin du MAC et je verifie que jai bien un tupe IP4 sinon je drop
       when ETH_HEADER =>
           if  CRS_DV ='1' then
               if byte_valid = '1' then
                    -- je stock le premier byte du type
                    if cpt = 12 then msb_tmp <= byte_in; 
                    elsif cpt = 13 then 
                    -- je verifie le type est IP4
                      if ( msb_tmp&byte_in =  x"0800") then state_p <= IP_HEADER; 
                      else state_p <= DROP;
                      end if;                                                      
                    end if; 
                    cpt<= cpt+1;              
               end if;                
           else state_p <= IDLE; 
           end if;
        -- dans  IP je verifie juste le protocol 
        when IP_HEADER =>
           if  CRS_DV ='1' then
               if byte_valid = '1' then
                    if cpt = 23 then 
                    -- je verifie le protocol
                      if ( byte_in /=  x"11") then state_p <= DROP; 
                      end if;  
                    -- fin de ip je passe à UDP                                                     
                    elsif  cpt = 33 then state_p <= UDP_HEADER; 
                    end if;
                    cpt<= cpt+1;              
               end if;                
           else state_p <= IDLE; 
           end if;   
        -- dans  UDP je verifie le port de destinantion 
        when UDP_HEADER =>
           if  CRS_DV ='1' then
               if byte_valid = '1' then
                    -- je stock le premier byte du port destination
                    if cpt = 36 then msb_tmp <= byte_in; 
                    elsif cpt = 37 then 
                    -- je verifie la destination
                      if ( msb_tmp&byte_in /=  x"04D2") then state_p <= DROP; 
                      end if;  
                    -- la fin de UDP je passe PAYLOAD  
                    elsif cpt = 41 then 
                        state_p <= PAYLOAD ;                                                    
                    end if; 
                    cpt<= cpt+1;              
               end if;                
           else state_p <= IDLE; 
           end if;  
        when PAYLOAD =>
            if CRS_DV = '1' then
                if byte_valid = '1' then
                    -- je stock les 4 dernieres valeurs de playload
                    playload_shift <= playload_shift(23 downto 0)&byte_in;
                    -- valeur de playload retarde par 4
                    payload_byte  <= playload_shift(31 downto 24);
                    -- j'attend 4 cycle pourque mon playload est valide
                    if cpt >= 46 then payload_valid <= '1';
                    elsif cpt<46 then cpt <= cpt+1;
                    end if; 
                else     
                    payload_valid <= '0';
                end if;
            else
                state_p <= IDLE;
                payload_valid <= '0';
                -- si crc est valide je declare que les signaux que jai envoye sont bon
                if crc_in /= x"DEBB20E3" then frame_error <='1';
                end if;         
            end if; 
       -- j'attend la fin de trame puis je remonte a IDLE 
       when DROP => 
           frame_error <= '1';
           if CRS_DV = '0' then state_p <= IDLE;
           end if;                            
   end case; 
end if;
end process;

end Behavioral;
