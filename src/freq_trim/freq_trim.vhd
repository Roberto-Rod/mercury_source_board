----------------------------------------------------------------------------------
--! @file freq_trim.vhd
--! @brief Frequency trimming module
--!
--! Gets the frequency error from the 1PPS module and controls the VC-TCXO using
--! the DAC module. Uses a PI control loop with a long integration time to
--! smooth out the jitter in the off-air 1PPS signal.
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_signed.all;
use ieee.numeric_std.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

----------------------------------------------------------------------------------
--! @brief Frequency trimming module
----------------------------------------------------------------------------------
entity freq_trim is
    generic (
        CLK_CNT_BITS        : integer := 27                                 --! Clock count bits
    );
    port (
        -- Register Bus
        reg_clk_i           : in std_logic;                                 --! The register clock
        reg_srst_i          : in std_logic;                                 --! Register synchronous reset
        reg_mosi_i          : in reg_mosi_type;                             --! Register master-out, slave-in signals
        reg_miso_o          : out reg_miso_type;                            --! Register master-in, slave-out signals

        -- Frequency error
        clk_count_i         : in std_logic_vector(CLK_CNT_BITS-1 downto 0); --! Clock count (80 MHz clock)
        clk_count_valid_i   : in std_logic;
        
        -- VC-TCXO Control
        dac_val_o           : out std_logic_vector(11 downto 0);            --! DAC value out, 12-bit unsigned, volts = val/1000
        dac_val_valid_o     : out std_logic
    );
end freq_trim;

architecture rtl of freq_trim is
    -------------------------------------------------------------------------
    -- Pipeline stages:
    --   1:  clk_count_valid_i (clk_count valid)
    --   2:                    (subtractor input valid)
    --   3:                    (subtractor output valid)
    --   4:                    (subtractor registered output valid, limiter input valid)
    --   5:                    (freq_err valid)
    --   6:                    (adder inputs valid)
    --   7:                    (adder output valid)
    --   8:  add_o_r_valid     (adder registered output valid, limiter input valid)
    --   9:                    (limiter output valid, multiplier input valid)
    --   10:                   ... multiplier pipeline ...
    --   11:                   ... multiplier pipeline ...
    --   12: mult_p_valid      (multiplier output valid, dac limiter input valid)
    --   13: dac_val_valid_o   (dac output valid)
    -------------------------------------------------------------------------
    
    ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    constant C_ACC_BITS        : integer := 19;                                                                          -- Accumulator bits (unsigned)
    constant C_ERR_BITS        : integer := 13;                                                                          -- Error bits (2's comp)
    constant C_DAC_BITS        : integer := 12;                                                                          -- DAC bits (unsigned)
    constant C_KI_BITS         : integer := 12;                                                                          -- Ki bits (unsigned)
    constant C_DAC_PRIME       : std_logic_vector(11 downto 0) := x"672";                                                -- DAC starting value (1.65 V)
    constant C_ACC_PRIME       : unsigned(C_ACC_BITS-1 downto 0)   := to_unsigned(216e3, C_ACC_BITS);                    -- Accumulator starting value
    constant C_KI_DEFAULT      : unsigned(C_KI_BITS-1 downto 0)    := to_unsigned(2e3,   C_KI_BITS);                     -- Ki default value
    constant C_CLK_CNT_EXPECT  : unsigned(CLK_CNT_BITS-1 downto 0) := to_unsigned(80e6,  CLK_CNT_BITS);                  -- Expected clock count    
    constant C_ERR_MAX         : signed(CLK_CNT_BITS downto 0)     := to_signed((2**(C_ERR_BITS-1))-1,  CLK_CNT_BITS+1); -- Error upper limit
    constant C_ERR_MIN         : signed(CLK_CNT_BITS downto 0)     := to_signed(-1*(2**(C_ERR_BITS-1)), CLK_CNT_BITS+1); -- Error lower limit
    constant C_NR_INS_TILL_ATV : unsigned(0 downto 0)              := to_unsigned(1, 1);                                 -- Nr. inputs to ignore after enabling module
    
    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    type t_fsm_trim is (IDLE, WAIT_ACTIVE, TRIM_ACTIVE);
    signal fsm_trim      : t_fsm_trim;
    
    signal reg_ctrl_stat : std_logic_vector(31 downto 0);           -- Auto-trimming control/status register                                                                    
    alias  ki            : std_logic_vector(C_KI_BITS-1 downto 0) is reg_ctrl_stat(C_KI_BITS-1 downto 0);
                                                                    -- Ki (integral multiplier)
    alias  trim_en       : std_logic is reg_ctrl_stat(31);          -- Trimming enable ('1' = enable)
    
    signal input_cnt     : unsigned(C_NR_INS_TILL_ATV'range);       -- Count number of inputs resceived since enabling module    
    
    signal freq_err      : signed(C_ERR_BITS-1 downto 0);           -- Frequency error in Hz
    
                                                                    -- Error subtractor
    signal sub_b         : unsigned(CLK_CNT_BITS-1 downto 0);       -- Subtractor B input    
    signal sub_o         : signed(CLK_CNT_BITS downto 0);           -- Subtractor output
    signal sub_o_r       : signed(CLK_CNT_BITS downto 0);           -- Subtractor output register
    
                                                                    -- Accumulator adder
    signal add_a         : signed(C_ACC_BITS downto 0);             -- Adder A input
    signal add_b         : signed(C_ERR_BITS-1 downto 0);           -- Adder B input
    signal add_o         : signed(C_ACC_BITS+1 downto 0);           -- Adder output
    signal add_o_r       : signed(C_ACC_BITS+1 downto 0);           -- Adder output register
    signal acc           : unsigned(C_ACC_BITS-1 downto 0);         -- Accumulator
    
                                                                    -- DAC output multiplier (Ki)
    signal mult_a        : std_logic_vector(C_KI_BITS-1 downto 0);
    signal mult_b        : std_logic_vector(C_ACC_BITS-1 downto 0);
    signal mult_p        : std_logic_vector(C_DAC_BITS downto 0);   -- 18 LSBs chopped off inside mult to provide divide by 2^18
    
    signal prime_dac     : std_logic;                               -- Prime the DAC with default value
    signal add_o_r_valid : std_logic;                               -- Registered adder output valid
    signal mult_p_valid  : std_logic;                               -- Multiplier output valid                  
begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------

    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------

    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------
    -----------------------------------------------------------------------------
    --! @brief Control/status registers
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_regs: process (reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then                
                reg_ctrl_stat     <= (others => '0');
                -- Enable trimming by default
                reg_ctrl_stat(31) <= '1';
                -- Load default Ki value
                reg_ctrl_stat(C_KI_BITS-1 downto 0) <= std_logic_vector(C_KI_DEFAULT);
                reg_miso_o.data   <= (others => '0');
                reg_miso_o.ack    <= '0';
            else
                -- Defaults
                reg_miso_o.data <= (others => '0');
                reg_miso_o.ack  <= '0';
                
                if reg_mosi_i.valid = '1' then
                    if unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_TRIM_CTRL_STAT) then
                        if reg_mosi_i.rd_wr_n = '1' then
                            -- Read trimming control/status
                            reg_miso_o.data(reg_ctrl_stat'range) <= reg_ctrl_stat;
                            reg_miso_o.ack <= '1';
                        else
                            -- Write trimming control/status
                            reg_ctrl_stat  <= reg_mosi_i.data(reg_ctrl_stat'range);
                            reg_miso_o.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_TRIM_ERR) then
                        if reg_mosi_i.rd_wr_n = '1' then
                            -- Read error value
                            reg_miso_o.data(freq_err'range) <= std_logic_vector(freq_err);
                            reg_miso_o.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_TRIM_ACC) then
                        if reg_mosi_i.rd_wr_n = '1' then
                            -- Read accumulator value
                            reg_miso_o.data(acc'range) <= std_logic_vector(acc);
                            reg_miso_o.ack <= '1';
                        end if;
                    elsif unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_TRIM_MULT_O) then
                        if reg_mosi_i.rd_wr_n = '1' then
                            -- Read multiplier output value
                            reg_miso_o.data(mult_p'range) <= mult_p;
                            reg_miso_o.ack <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Control loop
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_control: process (reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then                
                prime_dac <= '0';
                fsm_trim  <= IDLE;
            else
                -- Defaults
                prime_dac  <= '0';
                
                case fsm_trim is
                    when IDLE =>
                        input_cnt <= (others => '0');
                        
                        if trim_en = '1' then
                            prime_dac <= '1';
                            fsm_trim  <= WAIT_ACTIVE;
                        end if;
                        
                    when WAIT_ACTIVE =>                        
                        if trim_en = '0' then
                            fsm_trim <= IDLE;
                        elsif clk_count_valid_i = '1' then
                            -- Dump the first N clock counts after activating to allow primed DAC value to settle
                            if input_cnt = C_NR_INS_TILL_ATV then
                                fsm_trim <= TRIM_ACTIVE;
                            else
                                input_cnt <= input_cnt + 1;
                            end if;                            
                        end if;                    
                        
                    when TRIM_ACTIVE =>
                        if trim_en = '0' then
                            fsm_trim <= IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Error calculator (subtractor and limiter)
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_error_calc: process (reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            -- Error input register
            sub_b <= unsigned(clk_count_i);
            
            -- Error subtractor
            sub_o <= signed('0' & C_CLK_CNT_EXPECT) - signed('0' & sub_b);
            
            -- Error subtractor output register
            sub_o_r <= sub_o;
            
            -- Error limiter
            if sub_o_r > C_ERR_MAX then
                -- Set frequency error to full-scale positive
                freq_err <= (freq_err'high => '0', others => '1');
            elsif sub_o_r < C_ERR_MIN then
                -- Set frequency error to full-scale negative
                freq_err <= (freq_err'high => '1', others => '0');
            else
                -- Set frequency error to subtractor output
                freq_err <= sub_o_r(freq_err'range);
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Accumulator calculator (adder, limiter and primer)
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_accumulator: process (reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            -- Adder inputs
            add_a <= signed('0' & acc);
            add_b <= freq_err;
        
            -- Adder
            add_o <= ('0' & add_a) + add_b;
            
            -- Adder output register
            add_o_r <= add_o;
            
            -- Accumulator (with limiter)
            if fsm_trim = TRIM_ACTIVE then                
                if add_o_r_valid = '1' then
                    if add_o_r(add_o_r'high) = '1' then
                        -- Negative adder output
                        acc <= (others => '0');
                    elsif add_o_r(add_o_r'high downto acc'high+1) /= 0 then
                        -- Over-scale positive adder output
                        acc <= (others => '1');
                    else
                        acc <= unsigned(add_o_r(acc'range));
                    end if;
                end if;
            else
                acc <= C_ACC_PRIME;
            end if;
        end if;
    end process;
        
    -----------------------------------------------------------------------------
    --! @brief DAC output limiter/primer
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_dac_out: process (reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if prime_dac = '1' then
                dac_val_o       <= C_DAC_PRIME;
                dac_val_valid_o <= '1';
            elsif fsm_trim = TRIM_ACTIVE then
                if mult_p(mult_p'high) = '1' then                
                    dac_val_o <= (others => '1');
                else
                    dac_val_o <= mult_p(dac_val_o'range);
                end if;
                
                dac_val_valid_o <= mult_p_valid;
            else
                dac_val_valid_o <= '0';
            end if;
        end if;
    end process;

    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------
    -----------------------------------------------------------------------------
    --! @brief Multiplier: dac = Ki * acc
    --!
    --! Ki  [mult_a]: 12-bits
    --! acc [mult_b]: 19-bits
    --! result:       31-bits
    --! mult_p:       13-bits (18 LSBs removed to provide divide by 2^18)
    --!
    --! DAC value will be mult_p(11 downto 0) and limited to F.S. if mult_p(12)
    --! is '1'
    --!
    --! Multiplier has 3 pipeline delays
    -----------------------------------------------------------------------------
    i_mult_freq_trim: entity work.mult_freq_trim
    port map (
        clk => reg_clk_i,
        ce  => trim_en,
        a   => ki,
        b   => std_logic_vector(acc),
        p   => mult_p
    );
    
    -----------------------------------------------------------------------------
    --! @brief Clock count valid to registered adder output valid pipeline delay
    -----------------------------------------------------------------------------
    i_delay_add_o_r_valid: entity work.slv_delay
    generic map (
        bits    => 1,
        stages  => 7
    )
    port map (
        clk	    => reg_clk_i,
        i(0)	=> clk_count_valid_i,
        o(0)    => add_o_r_valid
    );
    
    -----------------------------------------------------------------------------
    --! @brief Registered adder output valid to multiplier output valid pipeline delay
    -----------------------------------------------------------------------------
    i_delay_mult_p_valid: entity work.slv_delay
    generic map (
        bits    => 1,
        stages  => 4
    )
    port map (
        clk	    => reg_clk_i,
        i(0)	=> add_o_r_valid,
        o(0)    => mult_p_valid
    );
end rtl;