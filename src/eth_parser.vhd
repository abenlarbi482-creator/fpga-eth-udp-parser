--	State machine that parses Ethernet, IPv4, and UDP headers, filters by EtherType/protocol/port, and extracts the UDP payload.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;



entity eth_parser is
   generic(ADDR_MAC : std_logic_vector(47 downto 0):= x"112233445566");
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
end eth_parser;

architecture Behavioral of eth_parser is

    type state is  (IDLE, PREAMBLE, MAC, ETH_HEADER, IP_HEADER, UDP_HEADER, PAYLOAD, DROP);
    signal state_p : state := IDLE;
    -- signaux pour la verfivation de mon addresse mac
    signal mac_match_ok : std_logic;
    signal broadcast_ok : std_logic;
    signal multicast_ok : std_logic;   
    --signal interne pour verifier le type et la destination
    signal msb_tmp : std_logic_vector(7 downto 0);
    --signal pour stocker la longueur de l'UDP
    signal udp_length : std_logic_vector(15 downto 0);
    signal payload_length_s : std_logic_vector(15 downto 0);
    --signal pour stocker les quatres dernieres valeurs de playload
    signal playload_shift : std_logic_vector(31 downto 0);
    signal cpt : integer range 0 to 2048;  
    
    
    begin
    payload_length <= payload_length_s; 
    process(clk_50,rst)
    begin
    if rst = '1' then
       mac_match_ok <= '1'; 
       broadcast_ok <= '1';    
       multicast_ok <= '1'; 
       udp_length <= (others =>'0');    
       payload_length_s <= (others =>'0'); 
       payload_last <= '0';  
       payload_byte <= (others =>'0'); 
       payload_valid <= '0'; 
       frame_validated <= '0';
       frame_error <= '0';
       frame_damaged <= '0';
       state_p <= IDLE;
       msb_tmp <= (others =>'0');  
       cpt <= 0; 
       playload_shift <= (others =>'0');
       preamble_out <= '0';
    elsif rising_edge(clk_50) then
       case state_p is 
           -- etat IDLE j'initialise mes signaux 
           when IDLE =>
               mac_match_ok <= '1'; 
               broadcast_ok <= '1';    
               multicast_ok <= '1'; 
               udp_length <= (others =>'0');    
               payload_length_s <= (others =>'0'); 
               payload_last <= '0'; 
               payload_byte <= (others =>'0'); 
               payload_valid <= '0'; 
               frame_validated <= '0';
               frame_error <= '0'; 
               frame_damaged <= '0';
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
                   state_p <= MAC; 
                   preamble_out <= '1';              
                   end if;                
               else state_p <= DROP; 
               end if;
           -- Dans cet etat je verifie l'addr MAC soit: mon addresse stockée, broadcast ou multicast 
           when MAC => 
               if CRS_DV = '1' then
                   if byte_valid = '1' then
                        -- comparaison octet par octet de la MAC destination
                        if cpt <= 5 then
                            case cpt is
                                when 0 => if byte_in /= ADDR_MAC(47 downto 40) then mac_match_ok <= '0'; end if;
                                when 1 => if byte_in /= ADDR_MAC(39 downto 32) then mac_match_ok <= '0'; end if;
                                when 2 => if byte_in /= ADDR_MAC(31 downto 24) then mac_match_ok <= '0'; end if;
                                when 3 => if byte_in /= ADDR_MAC(23 downto 16) then mac_match_ok <= '0'; end if;
                                when 4 => if byte_in /= ADDR_MAC(15 downto 8)  then mac_match_ok <= '0'; end if;
                                when 5 => if byte_in /= ADDR_MAC(7  downto 0)  then mac_match_ok <= '0'; end if;
                                when others => null;
                            end case;
                            -- detection broadcast : accumulateur separe qui reste '1'
                            -- seulement si TOUS les octets valent xFF
                            if byte_in /= x"FF" then broadcast_ok <= '0'; end if;    
                            -- detection multicast : uniquement sur le premier octet (cpt=0)
                            if cpt = 0 then
                                multicast_ok <= byte_in(0); -- bit LSB = 1 -> multicast
                            end if;
                            cpt<= cpt+1; 
                        end if;   
                        -- a la fin des 6 octets (cpt=5 vient d'etre traite), on decide
                        if cpt = 5 then
                            if mac_match_ok = '0' and broadcast_ok = '0' and multicast_ok = '0' then
                                state_p <= DROP;
                            else state_p <= ETH_HEADER;
                            end if;
                        end if; 
                  end if;                   
                 else state_p <= DROP; 
                 end if;
           -- Dans cet etat je verifie que jai bien un type IP4 sinon je drop
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
               else state_p <= DROP; 
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
               else state_p <= DROP; 
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
                        -- je stocke la longueur de UDP et du Playload
                        elsif cpt = 38 then msb_tmp <= byte_in;
                        elsif cpt = 39 then 
                          if unsigned(msb_tmp&byte_in) < 8 then
                            state_p <= DROP; 
                          else 
                            udp_length <= msb_tmp&byte_in;
                            payload_length_s <= std_logic_vector( unsigned(msb_tmp&byte_in) - 8 );              
                          end if;
                        -- la fin de UDP je passe PAYLOAD  
                        elsif cpt = 41 then 
                            state_p <= PAYLOAD ;                                                    
                        end if; 
                        cpt<= cpt+1;              
                   end if;                
               else state_p <= DROP; 
               end if;  
            when PAYLOAD =>
                if CRS_DV = '1' then
                    if byte_valid = '1' then
                        -- j'envoie les bytes de payload 
                        payload_byte  <= byte_in;
                        payload_valid <= '1';
                        if cpt >= (41 + to_integer(unsigned(payload_length_s))) then payload_last <= '1'; end if;
                        if cpt >= (42 + to_integer(unsigned(payload_length_s))) then 
                            payload_valid <= '0'; 
                            payload_last <= '0'; 
                        end if; 
                        cpt <= cpt+1;                      
                    else     
                        payload_valid <= '0';
                    end if;
                else
                    payload_valid <= '0';
                    -- si crc est valide je declare que les signaux que jai envoye sont bon
                    if crc_in /= x"DEBB20E3" then
                     frame_damaged <='1';
                     state_p <= DROP;
                    else 
                    frame_validated <= '1';
                     state_p <= IDLE;
                    end if;         
                end if; 
           -- j'attend la fin de trame puis je remonte a IDLE 
           when DROP => 
               frame_error <= '1';
               if CRS_DV = '0' then 
                   state_p <= IDLE; 
               end if;                          
       end case; 
    end if;
    end process;

end Behavioral;

