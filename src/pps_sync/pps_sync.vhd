----------------------------------------------------------------------------------
--! @file pps_sync.vhd
--! @brief 1PPS synchronisation module
--!
--! Monitors external 1PPS and generates synchronised internal 1PPS which
--! is asserted high for one clock cycle.
--!
--! Averages the PPS position error to remove cycle-to-cycle jitter present
--! at the GPS 1PPS output. Fires internal 1PPS early to allow for pipeline 
--! delays in FPGA and hardware delays.
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

--! @brief 1PPS synchronisation entity
--!
--! Provides 1PPS monitoring and generation
entity pps_sync is
    generic (
        PPS_THRESH    : integer := 80e6;      -- 1 second at 80 MHz
        PPS_ERROR     : integer := 8e3;       -- 100 ppm w.r.t. 80e6
        CLKS_PER_PPS  : integer := 80e6
    );
    port (
        -- Register Bus
        reg_clk_i           : in std_logic;                                     --! The register clock
        reg_srst_i          : in std_logic;                                     --! Register synchronous reset
        reg_mosi_i          : in reg_mosi_type;                                 --! Register master-out, slave-in signals
        reg_miso_o          : out reg_miso_type;                                --! Register master-in, slave-out signals

        -- 1PPS signals
        ext_pps_i           : in std_logic;                                     --! External 1PPS input signal
        ext_pps_o           : out std_logic;                                    --! External 1PPS output signal
        int_pps_o           : out std_logic;                                    --! FPGA internal 1PPS signal
        ext_pps_present_o   : out std_logic;                                    --! Flag indicating presence of external 1PPS signal (asserted high)

        -- Clock count out
        clk_count_o         : out std_logic_vector(26 downto 0);                --! Number of clocks (80 MHz) counted between each off-air 1PPS
        clk_count_valid_o   : out std_logic                                     --! Flag asserted when new count available
    );
end pps_sync;

architecture rtl of pps_sync is
    -------------------------------------------------------------------------
    -- Pipeline stages:
    --      Valid Flag              Signal
    --   1: pps_count_capture       pps_count
    --   2:                         pps_count_r
    --   3:                         pps_cnt_err
    --   4:                         pps_cnt_err_r
    --   5:                         mult_a / mult_b / error_limit
    --   6:                         mult_c
    --   7:                         ... mult-add pipeline delay ...
    --   8:                         mult_p
    --   9: pps_cnt_err_f_valid     pps_cnt_err_f
    -------------------------------------------------------------------------

    ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    constant C_PPS_PRESENT_THRESH_LO : unsigned(26 downto 0) := to_unsigned(PPS_THRESH-PPS_ERROR, 27);
    constant C_PPS_PRESENT_THRESH_HI : unsigned(26 downto 0) := to_unsigned(PPS_THRESH+PPS_ERROR, 27);
    constant C_EXT_PULSE_THRESH      : unsigned(22 downto 0) := to_unsigned((CLKS_PER_PPS/10)-1,  23);
    -- An offset of 2 allows for delays inside this module (synchronising ext_pps onto reg_clk and
    -- registering to detect rising edge), an offset of 2 would align int_pps with ext_pps_i.
    -- The extra offset, C_ERROR_OFFSET, fires 1PPS early and allows for a combination of the hardware delay from 
    -- GPS Rx 1PPS out through RS485 transceivers and cable, the pipeline delay from int_pps to ext_blank 
    -- and the time from ext_blank to RF blanking (100 ns [8 clocks] allowed for ext_blank to RF blank).
    constant C_ERROR_OFFSET          : signed(26 downto 0)   := to_signed(   20, 27);
    constant C_PPS_ERROR_MAX         : signed(26 downto 0)   := to_signed(   15, 27);
    constant C_PPS_ERROR_MIN         : signed(26 downto 0)   := to_signed(  -16, 27);
    constant C_ERR_LIM_RESET_VALUE   : signed(26 downto 0)   := to_signed(   10, 27);

    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    signal ext_pps_s                 : std_logic;
    signal ext_pps_s_r               : std_logic;
    signal pps_present               : std_logic;
    signal first_pps                 : std_logic;
    signal clk_count                 : unsigned(26 downto 0);
    signal clk_count_pps             : unsigned(26 downto 0);
    signal pulse_count               : unsigned(22 downto 0);
    
    -- PPS count capture
    signal pps_count                 : signed(26 downto 0);
    signal pps_count_r               : signed(26 downto 0);
    signal pps_count_hold            : signed(26 downto 0);
    signal pps_cnt_err               : signed(26 downto 0);
    signal pps_cnt_err_r             : signed(26 downto 0);
    
    -- Moving average error
    signal pps_cnt_err_f             : signed(8 downto 0);     -- 5.4 fixed-point precision
    signal pps_cnt_err_f_hold        : signed(8 downto 0);
    
    -- Multiplier-adder inputs/outputs
    signal mult_add_a                : std_logic_vector(8 downto 0);   -- Multiplier input A, signed (err & 4 precision bits)
    signal mult_add_b                : std_logic_vector(4 downto 0);   -- Multiplier input B, unsigned (fix at 31)
    signal mult_add_c                : std_logic_vector(8 downto 0);   -- Adder input, signed
    signal mult_add_p                : std_logic_vector(8 downto 0);   -- Multiplier-adder output, signed (mult_a x 31)/32 [5 LSBs dropped]

    -- Valid strobes
    signal pps_count_capture         : std_logic;
    signal pps_cnt_err_f_valid       : std_logic;

    -- Error limit flag
    signal error_limit               : std_logic;
begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------
    ext_pps_present_o <= pps_present;

    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------

    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------
    -----------------------------------------------------------------------------
    --! @brief Register read process, synchronous to reg_clk.
    --!
    --! Provides read-only access to clock count/status register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_regs: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            -- Defaults
            reg_miso_o.data <= (others => '0');
            reg_miso_o.ack  <= '0';

            if reg_mosi_i.valid = '1' then
                if unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_PPS_CLOCK_COUNT) then
                    if reg_mosi_i.rd_wr_n = '1' then
                        -- Read only. If ext pps is not present then return 0xffffffff
                        if pps_present = '1' then
                            reg_miso_o.data(26 downto 0) <= std_logic_vector(clk_count_pps);
                        else
                            reg_miso_o.data <= (others => '1');
                        end if;
                        reg_miso_o.ack <= '1';
                    end if;
                elsif unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_PPS_ERROR) then
                    if reg_mosi_i.rd_wr_n = '1' then
                        -- Read only
                        reg_miso_o.data <= std_logic_vector(resize(pps_cnt_err_f_hold, 32));
                        reg_miso_o.ack <= '1';
                    end if;
                elsif unsigned(reg_mosi_i.addr) = unsigned(REG_ADDR_PPS_COUNT) then
                    if reg_mosi_i.rd_wr_n = '1' then
                        -- Read only
                        reg_miso_o.data <= std_logic_vector(resize(pps_count_hold, 32));
                        reg_miso_o.ack <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Clock count process
    --!
    --! Counts number internal register clocks between external 1PPS pulses
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_clk_count: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then
                clk_count_valid_o <= '0';
                pps_present       <= '0';
                first_pps         <= '1';
            else
                -- Default
                clk_count_valid_o <= '0';

                -- Detect 1PPS rising edge
                if ext_pps_s_r = '0' and ext_pps_s = '1' then
                    first_pps <= '0';
                    clk_count <= to_unsigned(1, clk_count'length);

                    if clk_count > C_PPS_PRESENT_THRESH_HI or
                       clk_count < C_PPS_PRESENT_THRESH_LO then
                       pps_present        <= '0';
                    elsif first_pps = '0' then
                        pps_present       <= '1';
                        clk_count_pps     <= clk_count;
                        clk_count_o       <= std_logic_vector(clk_count);
                        clk_count_valid_o <= '1';
                    end if;
                else
                    clk_count <= clk_count + 1;

                    if clk_count > C_PPS_PRESENT_THRESH_HI then
                        pps_present <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief 1PPS generation process
    --!
    --! Generates:
    --!     Internal 1PPS (active for 1 clock cycle)
    --!     External 1PPS (active for 100 ms)
    --!
    --! Synchronises the 1PPS position based on the offset calculated in#
    --! subsequent processes.
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_pps_gen: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then
                int_pps_o   <= '0';
                ext_pps_o   <= '0';
                pps_count   <= (others => '0');
                pulse_count <= (others => '0');
            else
                -- Defaults
                int_pps_o   <= '0';

                -- Drive external PPS pulse (100 ms)
                if pulse_count = C_EXT_PULSE_THRESH then
                    ext_pps_o <= '0';
                else
                    pulse_count <= pulse_count + 1;
                end if;
                
                if pps_count = 0 then
                    -- Centre of PPS count range, drive int and ext PPS high
                    int_pps_o   <= '1';
                    ext_pps_o   <= '1';
                    pulse_count <= (others => '0');
                end if; 

                if pps_cnt_err_f_valid = '1' then
                    if error_limit = '1' then
                        -- Error limit hit, reset count to the reset value
                        pps_count <= C_ERR_LIM_RESET_VALUE + (C_ERROR_OFFSET + 1);
                        
                        -- If the count is less than or equal to 0 at this point then
                        -- put a pulse out now, otherwise if count is positive, 
                        -- one has already been issued
                        if pps_count <= 0 then
                            int_pps_o   <= '1';
                            ext_pps_o   <= '1';
                            pulse_count <= (others => '0');
                        end if;
                    else
                        if pps_cnt_err_f < -16 then
                            -- Negative error, advance count by 1 extra clock
                            pps_count <= pps_count + 2;
                            
                            -- If we are skipping over the pulse generation point
                            -- at count = 0 then generate pulse now
                            if pps_count = -1 then
                                int_pps_o   <= '1';
                                ext_pps_o   <= '1';
                                pulse_count <= (others => '0');
                            end if;
                        elsif pps_cnt_err_f > 16 then
                            -- Positive error, retard count by doing nothing
                            -- as opposed to adding one as normal
                            -- If we hold on 0 then the generated pulses will widen 
                            -- by 1 clock which is acceptable
                        else
                            -- No error, incremenet pps_count as normal
                            pps_count <= pps_count + 1;
                        end if;
                    end if;
                else
                    -- PPS count -40e6 to (+40e6 - 1), PPS asserted at 0
                    if pps_count < to_signed((CLKS_PER_PPS/2)-1, pps_count'length) then
                        pps_count <= pps_count + 1;
                    else
                        pps_count <= to_signed(-1*(CLKS_PER_PPS/2), pps_count'length);
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief 1PPS detection process
    --!
    --! Detects external 1PPS rising edge, registers the count error which is
    --! the difference between where the internal pulse should be driven high
    --! and where it is driven high.
    --!
    --! Limits the count error and flags if the limit has been hit.
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_pps_det: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then
                pps_count_capture <= '0';
            else
                -- Detect 1PPS rising edge
                if ext_pps_s_r = '0' and ext_pps_s = '1' then
                    pps_count_capture <= '1';
                else
                    pps_count_capture <= '0';
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Calculation pipeline process
    --!
    --!  - Calculates PPS count error
    --!  - Loads inputs to multiplier-adder
    --!  - Unloads output from multiplier-adder
    --!  - Stores the filtered error
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_calc_pipe: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            --==================--
            -- Pipeline Stage 1 --
            --==================--
            -- pps_count / pps_count_capture
            
            --==================--
            -- Pipeline Stage 2 --
            --==================--
            -- Register count error input
            pps_count_r <= pps_count;

            --==================--
            -- Pipeline Stage 3 --
            --==================--
            -- Calculate count error
            pps_cnt_err <= pps_count_r - (C_ERROR_OFFSET + 1);

            --==================--
            -- Pipeline Stage 4 --
            --==================--
            -- Register count error output
            pps_cnt_err_r <= pps_cnt_err;

            --==================--
            -- Pipeline Stage 5 --
            --==================--
            -- Limit error range - only going to use 7 LSBs of pps_cnt_err so check
            -- whether the actual error is inside that range or not
            if pps_cnt_err_r > C_PPS_ERROR_MAX or pps_cnt_err_r < C_PPS_ERROR_MIN then
                error_limit <= '1';
            else
                error_limit <= '0';
            end if;

            -- Register multiplier A input (limited error range)
            -- and add 4 precision bits
            -- 3 pipeline stages from mult_a/mult_b to mult_p
            mult_add_a <= std_logic_vector(pps_cnt_err_r(4 downto 0) & "0000");

            -- Multiplier B input fixed at F.S.
            mult_add_b <= (others => '1');

            --==================--
            -- Pipeline Stage 6 --
            --==================--
            -- 2 pipeline stages from mult_c to mult_p
            mult_add_c <= std_logic_vector(pps_cnt_err_f);

            --==================--
            -- Pipeline Stage 7 --
            --==================--

            --==================--
            -- Pipeline Stage 8 --
            --==================--                        
            
            --==================--
            -- Pipeline Stage 9 --
            --==================--
            pps_cnt_err_f <= signed(mult_add_p);
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Hold the error counts for register read-back
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_hold_counts: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if pps_cnt_err_f_valid = '1' then
                pps_cnt_err_f_hold <= pps_cnt_err_f;
            end if;
            
            if pps_count_capture = '1' then
                pps_count_hold <= pps_count;
            end if;
        end if;
    end process;
        
        

    -----------------------------------------------------------------------------
    --! @brief External PPS register process
    --!
    --! Registers the synchronised external 1PPS so that the rising edge can be
    --! seen within the reg_clk_i domain.
    --!
    --! @param[in] clk  Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_ext_pps_reg: process(reg_clk_i)
    begin
        if rising_edge(reg_clk_i) then
            if reg_srst_i = '1' then
                ext_pps_s_r <= '1';
            else
                ext_pps_s_r <= ext_pps_s;
            end if;
        end if;
    end process;

    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------
    i_mult_add_pps_sync: entity work.mult_add_pps_sync
    port map (
        clk      => reg_clk_i,
        ce       => '1',
        sclr     => reg_srst_i,
        a        => mult_add_a,
        b        => mult_add_b,
        c        => mult_add_c,
        subtract => '0',
        p        => mult_add_p,
        pcout    => open
    );

    -----------------------------------------------------------------------------
    --! @brief External 1PPS synchroniser
    -----------------------------------------------------------------------------
    i_ext_pps_synchroniser: entity work.slv_synchroniser
    generic map (
        bits            => 1,
        sync_reset      => true
    )
    port map (
        clk             => reg_clk_i,
        rst             => reg_srst_i,
        din(0)          => ext_pps_i,
        dout(0)         => ext_pps_s
    );

    -----------------------------------------------------------------------------
    --! @brief PPS count error to PPS count error-limited pipeline delay
    -----------------------------------------------------------------------------
    i_delay_cnt_err_lim_valid: entity work.slv_delay
    generic map (
        bits    => 1,
        stages  => 8
        
    )
    port map (
        clk	    => reg_clk_i,
        i(0)	=> pps_count_capture,
        o(0)    => pps_cnt_err_f_valid
    );
end rtl;