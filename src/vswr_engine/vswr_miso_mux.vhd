----------------------------------------------------------------------------------
--! @file vswr_miso_mux.vhd
--! @brief VSWR slave data bus mux
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
--! Modified to 2 inputs as the module is not used generally in the way the
--! "register mux" is
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

entity vswr_miso_mux is    
    port (                                                  
        -- Clock 
        clk                  : in std_logic;                --! Input clock
        
        -- Input data/valid
        vswr_miso_i_1        : in vswr_miso_type;           --! VSWR master-in, slave-out signals, input 1
        vswr_miso_i_2        : in vswr_miso_type;           --! VSWR master-in, slave-out signals, input 2
        
        -- Output data/valid
        vswr_miso_o          : out vswr_miso_type           --! VSWR master-in, slave-out signals, muxed output, delayed by one clock cycle
     );
end vswr_miso_mux;

architecture rtl of vswr_miso_mux is

begin
    -- OR the input data/valid signals together and register the outputs.    
    process(clk)
    begin
        if rising_edge(clk) then
            vswr_miso_o.fwd <= vswr_miso_i_1.fwd or 
                               vswr_miso_i_2.fwd;
                            
            vswr_miso_o.rev <= vswr_miso_i_1.rev or 
                               vswr_miso_i_2.rev;
                                 
            vswr_miso_o.valid <= vswr_miso_i_1.valid or 
                                 vswr_miso_i_2.valid;                              
        end if;        
    end process;
end rtl;




