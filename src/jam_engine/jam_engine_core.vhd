----------------------------------------------------------------------------------
--! @file jam_engine_core.vhd
--! @brief Mercury jamming engine core
--!
--! Provides jamming line storage and read/write interfaces along with jamming
--! engine controller which reads jamming lines and sends them out to DDS &
--! RF control interfaces.
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

--library unisim;
--use unisim.vcomponents.all;

--! @brief Entity description
--!
--! Further detail
entity jam_engine_core is
    generic (
        LINE_ADDR_BITS      : natural := 15
    );
    port (
        -- Clock and synchronous enable
        reg_clk                : in std_logic;                                     --! The register clock
        dds_sync_clk           : in std_logic;                                     --! The DDS sync clock
        jam_srst               : in std_logic;                                     --! Reset jamming engine

        -- Memory bus
        mem_addr               : out std_logic_vector(LINE_ADDR_BITS-1 downto 0);
        mem_addr_valid         : out std_logic;
        mem_data               : in std_logic_vector(31 downto 0);
        mem_data_valid         : in std_logic;

        -- Start/end line
        start_line_addr_main   : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);
        end_line_addr_main     : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);
        start_line_addr_shadow : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);
        end_line_addr_shadow   : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);
        shadow_select          : in std_logic;

        -- VSWR engine signals
        vswr_line_addr         : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);   --! VSWR test line base address
        vswr_line_req          : in std_logic;                                     --! Request VSWR test using line at vswr_line_addr
        vswr_line_ack          : out std_logic;                                    --! VSWR request being serviced

        -- Temperature compensation
        temp_comp_mult_asf     : in std_logic_vector(15 downto 0);                 --! Temperature compensation multiplier, DDS Amplitude Scale Factor
        temp_comp_offs_asf     : in std_logic_vector(15 downto 0);                 --! Temperature compensation offset, DDS Amplitude Scale Factor
        temp_comp_mult_dblr    : in std_logic_vector(15 downto 0);                 --! Temperature compensation multiplier, doubler attenuator
        temp_comp_offs_dblr    : in std_logic_vector(15 downto 0);                 --! Temperature compensation offset, doubler attenuator

        -- Control lines
        zero_phase             : in std_logic;

        -- DDS interface signals
        jam_rd_en              : in std_logic;                                     --! Read jamming line data from FWFT FIFO
        jam_data               : out std_logic_vector(31 downto 0);                --! Jamming line read data        
        jam_terminate_line     : out std_logic;                                    --! Terminate active jamming line     
        jam_fifo_empty         : out std_logic                                     --! Jamming engine FIFO empty
     );
end jam_engine_core;

architecture rtl of jam_engine_core is
    type fsm_jam_t is (JAM_RESET, JAM_RESTART, JAM_INITIATE, JAM_WAIT, JAM_OPERATE, JAM_VSWR);
    signal fsm_jam                  : fsm_jam_t;

    signal start_line_addr          : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal end_line_addr            : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal line_addr                : unsigned(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal line_addr_valid          : std_logic := '0';
    signal line_addr_1st            : std_logic;
    signal line_addr_1st_dly        : std_logic;
    signal line_addr_repeat         : unsigned(LINE_ADDR_BITS-1 downto 0);
    signal line_count               : unsigned(2 downto 0) := (others => '0');
    signal jam_line                 : unsigned(2 downto 0) := (others => '0');
    signal jam_line_r               : unsigned(2 downto 0) := (others => '0');
    signal jam_line_dly             : unsigned(2 downto 0) := (others => '0');
    signal jam_line_addr            : unsigned(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal jam_line_addr_1st        : std_logic;
    signal mem_data_r               : std_logic_vector(31 downto 0);
    signal mem_data_dly             : std_logic_vector(31 downto 0);
    signal mem_data_valid_dly       : std_logic;
    signal line_repeat_nr           : unsigned(5 downto 0);
    signal line_repeat_count        : unsigned(5 downto 0);
    signal shadow_select_s_curr     : std_logic;
    signal wait_count               : unsigned(1 downto 0);
    signal reset_delay              : unsigned(1 downto 0);
    
    -- FIFO write interface
    signal fifo_srst                : std_logic;
    signal fifo_prog_full           : std_logic;
    signal fifo_wr_data             : std_logic_vector(31 downto 0);
    signal fifo_wr_en               : std_logic;
    
    -- Pseudo-Random Binary Sequence (used to randomise phase)
    signal prbs                     : std_logic_vector(15 downto 0);
    signal prbs_ack                 : std_logic := '0';
    signal rand_pow                 : std_logic := '0';

    -- Temperature compensation scale/offset signals
    signal amplitude_data_in_1      : signed(17 downto 0);
    signal temp_comp_mult_1         : signed(17 downto 0);
    signal temp_comp_offs_1         : signed(47 downto 0);
    signal dblr_line_1              : std_logic;
    signal scaled_data_2            : signed(35 downto 0);
    signal temp_comp_offs_2         : signed(47 downto 0);
    signal dblr_line_2              : std_logic;
    signal offset_data_3            : signed(47 downto 0);
    signal dblr_line_3              : std_logic;
    signal amplitude_data_out_4     : std_logic_vector(15 downto 0);

    -- Cross-clock-domain signals
    signal dds_srst                 : std_logic;
    signal start_line_addr_main_s   : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal end_line_addr_main_s     : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal start_line_addr_shadow_s : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal end_line_addr_shadow_s   : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal shadow_select_s          : std_logic;
    signal vswr_line_addr_s         : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal vswr_line_req_s          : std_logic;
    signal vswr_line_req_s_r        : std_logic;
    signal vswr_line_req_latch      : std_logic;
    signal vswr_line_ack_u          : std_logic;
    signal temp_comp_mult_asf_s     : std_logic_vector(15 downto 0);
    signal temp_comp_offs_asf_s     : std_logic_vector(15 downto 0);
    signal temp_comp_mult_dblr_s    : std_logic_vector(15 downto 0);
    signal temp_comp_offs_dblr_s    : std_logic_vector(15 downto 0);
    signal zero_phase_s             : std_logic;
begin
    mem_addr           <= std_logic_vector(line_addr);
    mem_addr_valid     <= line_addr_valid;
    jam_terminate_line <= fifo_srst;
    
    -----------------------------------------------------------------------------
    --! @brief Finite State Machine: Generates memory addresses
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    fsm_jam_proc: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if dds_srst = '1' then
                line_addr_valid    <= '0';
                vswr_line_ack_u    <= '0';
                fifo_srst          <= '1';
                reset_delay        <= (others => '1');
                fsm_jam            <= JAM_RESET;                
            else
                -- Default
                line_addr_valid <= '0';

                case fsm_jam is
                    when JAM_RESET =>
                        fifo_srst            <= '0';
                        vswr_line_ack_u      <= '0';
                        reset_delay          <= reset_delay - 1;
                        if reset_delay = 0 then
                            fsm_jam          <= JAM_RESTART;
                        end if;
                        
                    when JAM_RESTART =>
                        shadow_select_s_curr <= shadow_select_s;
                        line_repeat_count    <= (others => '0');
                        fifo_srst            <= '1';
                        
                        if shadow_select_s = '0' then
                            start_line_addr <= start_line_addr_main_s;
                            end_line_addr   <= end_line_addr_main_s;
                        else
                            start_line_addr <= start_line_addr_shadow_s;
                            end_line_addr   <= end_line_addr_shadow_s;
                        end if;

                        fsm_jam <= JAM_INITIATE;

                    when JAM_INITIATE =>
                        fifo_srst          <= '0';                        
                        line_addr          <= unsigned(start_line_addr);
                        line_addr_valid    <= '0';
                        line_addr_1st      <= '1';
                        jam_line_addr      <= unsigned(start_line_addr);
                        jam_line_addr_1st  <= '1';
                        line_count         <= "000";
                        wait_count         <= "10";
                        fsm_jam            <= JAM_WAIT;

                    when JAM_WAIT =>
                        wait_count <= wait_count - 1;
                        
                        -- If shadow/main selection has changed then restart
                        if shadow_select_s_curr /= shadow_select_s then
                            fsm_jam   <= JAM_RESTART;
                        elsif wait_count = 0 then                            
                            if fifo_prog_full = '0' then
                                line_addr_valid <= '1';

                                if vswr_line_req_latch = '1' then
                                    -- Over-ride line address
                                    line_addr       <= unsigned(vswr_line_addr_s);
                                    line_addr_1st   <= '0';
                                    vswr_line_ack_u <= '1';
                                    fsm_jam         <= JAM_VSWR;
                                elsif line_repeat_count < line_repeat_nr then
                                    line_repeat_count <= line_repeat_count + 1;
                                    line_addr         <= line_addr_repeat;
                                    line_addr_1st     <= '0';
                                    fsm_jam           <= JAM_OPERATE;
                                else
                                    line_repeat_count <= (others => '0');
                                    line_addr_repeat  <= line_addr;                                    
                                    fsm_jam           <= JAM_OPERATE;
                                end if;
                            end if;
                        end if;

                    when JAM_OPERATE =>
                        -- Wrap lines around
                        if line_addr >= unsigned(end_line_addr) then
                            line_addr         <= unsigned(start_line_addr);
                            line_addr_1st     <= '1';
                            -- Store jamming line address to be reloaded after VSWR line
                            jam_line_addr     <= unsigned(start_line_addr);
                            jam_line_addr_1st <= '1';
                        else
                            line_addr         <= line_addr + 1;
                            line_addr_1st     <= '0';
                            -- Store jamming line address to be reloaded after VSWR line
                            jam_line_addr     <= line_addr + 1;
                            jam_line_addr_1st <= '0';
                        end if;

                        -- Jamming line consists of 5 memory words, count 0 to 4
                        if line_count = "100" then
                            line_count      <= "000";
                            line_addr_valid <= '0';
                            wait_count      <= "10";
                            fsm_jam         <= JAM_WAIT;
                        else
                            line_count      <= line_count + 1;
                            line_addr_valid <= '1';
                        end if;

                    when JAM_VSWR =>
                        -- Jamming line consists of 5 memory words, count 0 to 4
                        if line_count = "100" then
                            line_count       <= "000";
                            line_addr        <= jam_line_addr;
                            line_addr_1st    <= jam_line_addr_1st;
                            wait_count       <= "10";
                            fsm_jam          <= JAM_WAIT;
                            vswr_line_ack_u  <= '0';
                            line_addr_valid  <= '0';
                        else
                            line_count      <= line_count + 1;
                            line_addr       <= line_addr + 1;
                            line_addr_valid <= '1';
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    vswr_req_proces: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if dds_srst = '1' then
                vswr_line_req_latch <= '0';
                vswr_line_req_s_r   <= '0';
            else
                vswr_line_req_s_r <= vswr_line_req_s;
                
                if vswr_line_req_s_r = '0' and vswr_line_req_s = '1' then
                    vswr_line_req_latch <= '1';
                elsif vswr_line_ack_u = '1' then
                    vswr_line_req_latch <= '0';
                end if;
            end if;
        end if;
    end process;
    
    data_proc: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if fifo_srst = '1' then
                fifo_wr_en <= '0';
                prbs_ack   <= '0';
            else
                -- Defaults
                prbs_ack   <= '0';
                fifo_wr_en <= mem_data_valid_dly;

                if jam_line_dly = "000" then
                    rand_pow <= mem_data_dly(30);
                end if;

                if jam_line_dly = "000" then
                    -- Control word
                    fifo_wr_data(31 downto 24) <= mem_data_dly(31 downto 24);
                    fifo_wr_data(23 downto 16) <= amplitude_data_out_4(7 downto 0);   -- 8-bit attenuator value
                    fifo_wr_data(15 downto 8)  <= mem_data_dly(15 downto 8);
                    fifo_wr_data(8)            <= line_addr_1st_dly;                  -- Flag first line
                    fifo_wr_data(7 downto 0)   <= mem_data_dly(7 downto 0);

                elsif jam_line_dly = "011" then
                    fifo_wr_data(31 downto 16) <= amplitude_data_out_4;               -- Amplitude Scale Factor

                    -- If zero phase bit is set then force phase to 0
                    if zero_phase_s = '1' then
                        fifo_wr_data(15 downto 0) <= (others => '0');
                    -- Else if phase randomisation is enabled for this line then write PRBS to phase
                    elsif rand_pow = '1' then
                        fifo_wr_data(15 downto 0) <= prbs;
                        prbs_ack <= '1';    -- Ack generates next number in pseudo-random sequence
                    -- Else write phase offset word from jamming line to phase
                    else
                        fifo_wr_data(15 downto 0) <= mem_data_dly(15 downto 0); -- Phase Offset Word
                    end if;
                else
                    fifo_wr_data <= mem_data_dly;
                end if;
            end if;
        end if;
    end process;
    
    repeat_proc: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            if fsm_jam = JAM_RESTART then
                line_repeat_nr <= (others => '0');
            elsif jam_line_r = 0 and fsm_jam = JAM_OPERATE then
                line_repeat_nr <= unsigned(mem_data_r(29 downto 24));
            end if;
        end if;
    end process;
    

    --! Scale and offset amplitude data using (18x18) multiplier and adder in DSP slice (MAC)
    --! Note: registers at cycle 2 & cycle 3 are being absorbed in MAC.
    temp_comp_proc: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            -- Cycle 1
            -- Select scale & offset values
            if jam_line_r = 0 then
                amplitude_data_in_1 <= signed("0000000000" & mem_data_r(23 downto 16));
                temp_comp_mult_1    <= signed("00" & temp_comp_mult_dblr_s);
                temp_comp_offs_1    <= resize(signed(temp_comp_offs_dblr_s & "000000000000000"), 48);
                dblr_line_1         <= '1';
            else
                amplitude_data_in_1 <= signed("000000" & mem_data_r(27 downto 16));
                temp_comp_mult_1    <= signed("00" & temp_comp_mult_asf_s);
                temp_comp_offs_1    <= resize(signed(temp_comp_offs_asf_s & "000000000000000"), 48);
                dblr_line_1         <= '0';
            end if;

            -- Cycle 2
            scaled_data_2           <= amplitude_data_in_1 * temp_comp_mult_1;
            temp_comp_offs_2        <= temp_comp_offs_1;
            dblr_line_2             <= dblr_line_1;

            -- Cycle 3
            offset_data_3           <= scaled_data_2 + temp_comp_offs_2;
            dblr_line_3             <= dblr_line_2;

            -- Cycle 4
            if offset_data_3(47) = '1'  then
                -- Negative numbers => 0
                amplitude_data_out_4    <= (others => '0');
            elsif dblr_line_3 = '0' and offset_data_3(46 downto 27) /= "00000000000000000000"  then
                -- Full-scale +ve (ASF: 12-bit amplitude data)
                amplitude_data_out_4   <= (15 downto 12 => '0', others => '1');
            elsif dblr_line_3 = '1' and offset_data_3(46 downto 23) /= "000000000000000000000000"  then
                -- Full-scale +ve (doubler: 8-bit amplitude data)
                amplitude_data_out_4   <= (15 downto 8 => '0', others => '1');
            else
                amplitude_data_out_4    <= std_logic_vector(offset_data_3(30 downto 15));
            end if;
        end if;
    end process;
    
    mem_data_reg: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            mem_data_r <= mem_data;
        end if;
    end process;
    
    jam_line_reg: process(dds_sync_clk)
    begin
        if rising_edge(dds_sync_clk) then
            jam_line_r <= jam_line;
        end if;
    end process;

    --Delay memory output data and jamming line to match pipeline delay through amplitude scaling logic
    i_mem_data_dly: entity work.slv_delay
    generic map ( bits => 32, stages => 4 )
    port map (
        clk => dds_sync_clk,
        i   => mem_data_r,
        o   => mem_data_dly
    );

    i_mem_data_valid_dly: entity work.slv_delay_srst
    generic map ( bits => 1, stages => 5 )
    port map (
        clk  => dds_sync_clk,
        srst => fifo_srst,
        i(0) => mem_data_valid,
        o(0) => mem_data_valid_dly
    );

    i_line_count_dly: entity work.unsigned_delay
    generic map ( bits => 3, stages => 2 )
    port map (
        clk => dds_sync_clk,
        i   => line_count,
        o   => jam_line
    );

    i_jam_line_dly: entity work.unsigned_delay
    generic map ( bits => 3, stages => 4 )
    port map (
        clk => dds_sync_clk,
        i   => jam_line_r,
        o   => jam_line_dly
    );

    i_line_addr_1st_dly: entity work.unsigned_delay
    generic map ( bits => 1, stages => 6 )
    port map (
        clk  => dds_sync_clk,
        i(0) => line_addr_1st,
        o(0) => line_addr_1st_dly
    );

    -- Generate pseudo-random bit sequence
    i_prbs_gen: entity work.prbs_gen
    generic map ( out_bits => 16 )
    port map (
        clk     => dds_sync_clk,
        srst    => dds_srst,
        seed    => (others => '0'),
        ack     => prbs_ack,
        prbs    => prbs
    );

    -- Reset bridge: async assertion, sync de-assertion
    process (dds_sync_clk, jam_srst)
    begin
        if jam_srst = '1' then
            dds_srst <= '1';
        elsif rising_edge(dds_sync_clk) then
            dds_srst <= '0';
        end if;
    end process;

    -- Synchronous FIFO
    i_fifo_jam_eng: entity work.fifo_jam_eng
    port map (
        clk       => dds_sync_clk,
        srst      => fifo_srst,
        din       => fifo_wr_data,
        wr_en     => fifo_wr_en,
        rd_en     => jam_rd_en,
        dout      => jam_data,
        full      => open,
        prog_full => fifo_prog_full,
        empty     => jam_fifo_empty
    );
    
    i_synchroniser_start_line_addr_main: entity work.slv_synchroniser
    generic map (bits => start_line_addr_main'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => start_line_addr_main, dout => start_line_addr_main_s);

    i_synchroniser_end_line_addr_main: entity work.slv_synchroniser
    generic map (bits => end_line_addr_main'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => end_line_addr_main, dout => end_line_addr_main_s);

    i_synchroniser_start_line_addr_shadow: entity work.slv_synchroniser
    generic map (bits => start_line_addr_shadow'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => start_line_addr_shadow, dout => start_line_addr_shadow_s);

    i_synchroniser_end_line_addr_shadow: entity work.slv_synchroniser
    generic map (bits => end_line_addr_shadow'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => end_line_addr_shadow, dout => end_line_addr_shadow_s);

    i_synchroniser_shadow_select: entity work.slv_synchroniser
    generic map (bits => 1, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din(0) => shadow_select, dout(0) => shadow_select_s);

    i_synchroniser_vswr_line_addr: entity work.slv_synchroniser
    generic map (bits => vswr_line_addr'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => vswr_line_addr, dout => vswr_line_addr_s);

    i_synchroniser_vswr_line_req: entity work.slv_synchroniser
    generic map (bits => 1, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din(0) => vswr_line_req, dout(0) => vswr_line_req_s);

    i_synchroniser_zero_phase: entity work.slv_synchroniser
    generic map (bits => 1, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din(0) => zero_phase, dout(0) => zero_phase_s);

    i_synchroniser_temp_comp_mult_asf: entity work.slv_synchroniser
    generic map (bits => temp_comp_mult_asf'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => temp_comp_mult_asf, dout => temp_comp_mult_asf_s);

    i_synchroniser_temp_comp_offs_asf: entity work.slv_synchroniser
    generic map (bits => temp_comp_offs_asf'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => temp_comp_offs_asf, dout => temp_comp_offs_asf_s);

    i_synchroniser_temp_comp_mult_dblr: entity work.slv_synchroniser
    generic map (bits => temp_comp_mult_dblr'length, sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => temp_comp_mult_dblr, dout => temp_comp_mult_dblr_s);

    i_synchroniser_temp_comp_offs_dblr: entity work.slv_synchroniser
    generic map (bits => temp_comp_offs_dblr'length,  sync_reset => true)
    port map (rst => dds_srst, clk => dds_sync_clk, din => temp_comp_offs_dblr, dout => temp_comp_offs_dblr_s);

    i_synchroniser_vswr_line_ack: entity work.slv_synchroniser
    generic map (bits => 1, sync_reset => true)
    port map (rst => jam_srst, clk => reg_clk, din(0) => vswr_line_ack_u, dout(0) => vswr_line_ack);
end rtl;
