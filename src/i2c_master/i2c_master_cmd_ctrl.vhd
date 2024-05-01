library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;       

use work.reg_pkg.all;

entity i2c_master_cmd_ctrl is
    generic (
        REGISTER_BASE_ADDRESS    : std_logic_vector(23 downto 0) := (others => '0');
        CONTROL_REGISTER_ADDRESS : std_logic_vector(23 downto 0) := (others => '0');
        I2C_SLAVE_ADDR           : std_logic_vector(6 downto 0)  := "0010101"
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals        		
        
		-- I2C Buffer Signals
		scl_i               : in std_logic;                         --! Clock input (used for clock stretching)
        scl_o               : out std_logic;                        --! Clock output
        scl_oen             : out std_logic;                        --! Clock output enable, active low
        sda_i               : in std_logic;                         --! Data input
        sda_o               : out std_logic;                        --! Data output
        sda_oen             : out std_logic                         --! Data output enable, active low		
    );
end entity i2c_master_cmd_ctrl;

architecture rtl of i2c_master_cmd_ctrl is
    -- I2C FSM
    type fsm_cmd_t is (cmd_reset, cmd_idle, cmd_wr, cmd_reg, cmd_rd, cmd_data_rd, cmd_data_wr, cmd_error);
    signal fsm_cmd : fsm_cmd_t := cmd_idle;
    
    -- Core signals
    signal core_srst        : std_logic := '1';
    signal core_start       : std_logic := '0';
    signal core_stop        : std_logic := '0';
    signal core_read        : std_logic := '0';
    signal core_write       : std_logic := '0';
    signal core_ack_in      : std_logic := '0';
    signal core_i2c_al      : std_logic := '0';
    signal core_din         : std_logic_vector(7 downto 0) := (others => '0');
    signal core_dout        : std_logic_vector(7 downto 0) := (others => '0');
    signal core_cmd_ack     : std_logic := '0';
    signal core_ack_out     : std_logic := '0';
    
    signal core_done        : std_logic;
    signal ready            : std_logic;
    signal error            : std_logic;
    signal usr_srst         : std_logic;
    
    signal i2c_cmd_start    : std_logic;
    signal i2c_rd_wr_n      : std_logic;
    signal i2c_addr         : std_logic_vector(6 downto 0);
    signal i2c_reg          : std_logic_vector(7 downto 0);
    signal i2c_din          : std_logic_vector(7 downto 0);
    signal i2c_dout         : std_logic_vector(7 downto 0);
    signal i2c_dout_valid   : std_logic;
    signal i2c_dout_error   : std_logic;
    
begin
    
                
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles read/write registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    reg_rd_wr_proc: process (reg_clk)
    begin        
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                usr_srst <= '0';
                reg_miso.data <= (others => '0');
                reg_miso.ack  <= '0';
                i2c_cmd_start <= '0';                
            else
                -- Defaults
                reg_miso.data <= (others => '0');
                reg_miso.ack  <= '0';
                i2c_cmd_start <= '0';
                
                if i2c_dout_valid = '1' then
                    reg_miso.ack <= '1';
                    if i2c_dout_error = '0' then
                        reg_miso.data(7 downto 0) <= i2c_dout;
                    else
                        reg_miso.data <= x"b00b5000";
                    end if;
                end if;
                
                if reg_mosi.valid = '1' then
                    if reg_mosi.addr(23 downto 8) = REGISTER_BASE_ADDRESS(23 downto 8) then                                          
                        if reg_mosi.rd_wr_n = '1' then                        
                            -- Register read operation
                            i2c_cmd_start   <= '1';
                            i2c_addr        <= I2C_SLAVE_ADDR;
                            i2c_rd_wr_n     <= '1';
                            i2c_reg         <= reg_mosi.addr(7 downto 0);
                        else
                            -- Register write operation                            
                            i2c_cmd_start   <= '1';
                            i2c_addr        <= I2C_SLAVE_ADDR;
                            i2c_rd_wr_n     <= '0';
                            i2c_reg         <= reg_mosi.addr(7 downto 0);
                            i2c_din         <= reg_mosi.data(7 downto 0);                        
                        end if;  
                    elsif reg_mosi.addr = CONTROL_REGISTER_ADDRESS then    
                        if reg_mosi.rd_wr_n = '1' then                        
                            -- Register read operation
                            reg_miso.ack      <= '1';                                                    
                            reg_miso.data(2)  <= ready;
                            reg_miso.data(1)  <= error;                       
                            reg_miso.data(0)  <= usr_srst;                            
                        else
                            -- Register write operation
                            usr_srst          <= reg_mosi.data(0);                            
                        end if; 
                    end if;
                end if;
            end if;
        end if;
    end process;    
    
    with fsm_cmd select ready <= '1' when cmd_idle,
                                 '0' when others;

    core_srst_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then                                 
            core_srst <= usr_srst or reg_srst;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles read/write registers
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge  
    -----------------------------------------------------------------------------  
    fsm_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if core_srst = '1' then
                fsm_cmd <= cmd_reset;
                core_start <= '0';
                core_stop <= '0';  
                core_write <= '0';
                core_read <= '0';
                core_ack_in <= '0';  
                error <= '0';
                i2c_dout_valid <= '0';
            else
                -- Defaults
                i2c_dout_valid <= '0';
                
                case fsm_cmd is
                    when cmd_reset =>
                        core_start <= '0';
                        core_stop <= '0';  
                        core_write <= '0';
                        core_read <= '0';
                        core_ack_in <= '0';  
                        error <= '0';  
                        fsm_cmd <= cmd_idle;
                        
                    when cmd_idle =>                                                     
                        if i2c_cmd_start = '1' then
                            fsm_cmd <= cmd_wr;
                            error <= '0';                            
                        end if;
                    
                    when cmd_wr =>
                        if core_done = '0' then
                            core_din <= i2c_addr & '0';                    
                            core_write <= '1';
                            core_start <= '1';                             
                        else
                            core_write <= '0';
                            core_start <= '0';
                          
                            if core_ack_out = '1' then                           
                                -- No acknowledgement   
                                fsm_cmd <= cmd_error;                                 
                            else
                                fsm_cmd <= cmd_reg;
                            end if;                          
                        end if;
                    
                    when cmd_reg =>                        
                        if core_done = '0' then
                            core_din <= i2c_reg;
                            core_write <= '1';
                        else
                            core_write <= '0';
                            if core_ack_out = '1' then
                                -- No acknowledgement   
                                fsm_cmd <= cmd_error;
                            elsif i2c_rd_wr_n = '1' then
                                fsm_cmd <= cmd_rd;
                            else
                                fsm_cmd <= cmd_data_wr;
                            end if;
                        end if;
                        
                    when cmd_rd =>
                        -- Generate repeated start condition using slave address
                        if core_done = '0' then
                            core_din <= i2c_addr & '1';
                            core_write <= '1';
                            core_start <= '1'; 
                        else
                            core_write <= '0';
                            core_start <= '0';
                            if core_ack_out = '1' then
                                -- No acknowledgement   
                                fsm_cmd <= cmd_error;
                            else
                                fsm_cmd <= cmd_data_rd;
                            end if;
                        end if;
                        
                    when cmd_data_wr =>
                        if core_done = '0' then
                            core_din <= i2c_din;
                            core_stop <= '1';
                            core_write <= '1';
                        else                            
                            core_stop <= '0';
                            core_write <= '0';
                            error <= core_ack_out;  -- 1 = No acknowledgement
                            
                            fsm_cmd <= cmd_reset;
                        end if;

                    when cmd_data_rd =>
                        if core_done = '0' then
                            core_din <= i2c_din;
                            core_stop <= '1';
                            core_read <= '1';                            
                            core_ack_in <= '1'; -- Set NACK = '1' for read command
                        else                            
                            core_stop <= '0';
                            core_read <= '0';
                            core_ack_in <= '0';

                            -- Send data
                            i2c_dout <= core_dout;
                            i2c_dout_valid <= '1';
                            i2c_dout_error <= '0';
                            
                            fsm_cmd <= cmd_reset;
                        end if;
                        
                    when cmd_error =>
                        core_stop <= '1';
                        error <= '1';
                        
                        -- Send duff data for a read cycle
                        i2c_dout_valid <= i2c_rd_wr_n;
                        i2c_dout_error <= '1';
                        
                        fsm_cmd <= cmd_reset;
                end case;
            end if;
        end if;
    end process;
    
    --done_proc: process (reg_clk)
    --begin
        --if rising_edge(reg_clk) then
            core_done <= core_cmd_ack or core_i2c_al;
        --end if;
    --end process;
    
    -- hookup byte controller block
    i_i2c_master_byte_ctrl: entity work.i2c_master_byte_ctrl
    port map (
        clk      => reg_clk,
        srst     => core_srst,        
        clk_cnt  => to_unsigned(138, 16),
        start    => core_start,
        stop     => core_stop,
        read     => core_read,
        write    => core_write,
        ack_in   => core_ack_in,
        i2c_busy => open,
        i2c_al   => core_i2c_al,
        din      => core_din,
        cmd_ack  => core_cmd_ack,
        ack_out  => core_ack_out,
        dout     => core_dout,
        scl_i    => scl_i,  
        scl_o    => scl_o,  
        scl_oen  => scl_oen,
        sda_i    => sda_i,  
        sda_o    => sda_o,
        sda_oen  => sda_oen
    );


end architecture rtl;
