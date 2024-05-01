----------------------------------------------------------------------------------
--! @file jam_engine_core_tb.vhd
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
use ieee.numeric_std.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

--library unisim;
--use unisim.vcomponents.all;

--! @brief Entity description
--!
--! Further detail
entity jam_engine_core_tb is
end jam_engine_core_tb;

architecture tb of jam_engine_core_tb is
    constant LINE_ADDR_BITS       : natural := 15;

    -- Clock and synchronous enable
    signal reg_clk                : std_logic;                     --! The register clock
    signal dds_sync_clk           : std_logic;                     --! The DDS sync clock
    signal jam_srst               : std_logic;                     --! Enable jamming engine

    -- Memory bus
    signal mem_addr               : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal mem_addr_valid         : std_logic;
    signal mem_data               : std_logic_vector(31 downto 0) := (others => '0');
    signal mem_data_valid         : std_logic := '0';

    -- Start/end line
    signal start_line_addr_main   : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal end_line_addr_main     : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal start_line_addr_shadow : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal end_line_addr_shadow   : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal shadow_select          : std_logic;

    -- VSWR engine signals
    signal vswr_line_addr         : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := std_logic_vector(to_unsigned(256, LINE_ADDR_BITS));
    signal vswr_line_req          : std_logic := '0';
    signal vswr_line_ack          : std_logic;

    -- Temperature compensation
    signal temp_comp_mult_asf     : std_logic_vector(15 downto 0) := x"8000";
    signal temp_comp_offs_asf     : std_logic_vector(15 downto 0) := x"000C";
    signal temp_comp_mult_dblr    : std_logic_vector(15 downto 0) := x"8000";
    signal temp_comp_offs_dblr    : std_logic_vector(15 downto 0) := x"0002";

    -- Control lines
    signal zero_phase             : std_logic := '0';

    -- DDS interface signals
    signal jam_rd_en              : std_logic := '0';              --! Read jamming line data from FWFT FIFO
    signal jam_data               : std_logic_vector(31 downto 0); --! Jamming line read data        
    signal jam_terminate_line     : std_logic;                     --! Terminate active jamming line     
    signal jam_fifo_empty         : std_logic;                     --! Jamming engine FIFO empty

    -- Delayed versions of core outputs
    signal mem_addr_r             : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal mem_addr_valid_r       : std_logic := '0';

    -- Testbench constants
    constant reg_clk_period       : time := 12.5 ns;                --! 80 MHz clock
    constant dds_sync_clk_period  : time := 7.407407407 ns;         --! 135 MHz clock
    constant START_ADDR_MAIN      : natural := 0;
    constant END_ADDR_MAIN        : natural := 9;
    constant START_ADDR_SHADOW    : natural := 10;
    constant END_ADDR_SHADOW      : natural := 19;
begin
    reg_clk_proc: process
    begin
        reg_clk <= '0';
        wait for reg_clk_period/2;
        reg_clk <= '1';
        wait for reg_clk_period/2;
    end process;

    dds_sync_clk_proc: process
    begin
        dds_sync_clk <= '0';
        wait for dds_sync_clk_period/2;
        dds_sync_clk <= '1';
        wait for dds_sync_clk_period/2;
    end process;

    stim_proc: process
    begin
        jam_srst <= '1';
        -- Load the start/end line addresses
        start_line_addr_main   <= std_logic_vector(to_unsigned(START_ADDR_MAIN, LINE_ADDR_BITS));
        end_line_addr_main     <= std_logic_vector(to_unsigned(END_ADDR_MAIN, LINE_ADDR_BITS));
        start_line_addr_shadow <= std_logic_vector(to_unsigned(START_ADDR_SHADOW, LINE_ADDR_BITS));
        end_line_addr_shadow   <= std_logic_vector(to_unsigned(END_ADDR_SHADOW, LINE_ADDR_BITS));
        shadow_select <= '0';
        wait until rising_edge(reg_clk);
        wait until rising_edge(reg_clk);
        jam_srst <= '0';

        wait for 2 us;

        wait until rising_edge(reg_clk);
        --vswr_line_req <= '1';

        wait for 20 ns;
        wait until rising_edge(reg_clk);
        shadow_select <= '1';
        
        wait for 150 ns;
        wait until rising_edge(reg_clk);
        shadow_select <= '0';

        while true loop
            wait until rising_edge(reg_clk);
            if vswr_line_ack = '1' then
                exit;
            end if;
        end loop;
        vswr_line_req <= '0';

        wait;
    end process;

    mem_proc: process
    begin
        while true loop
            -- Delay address and valid signal and pipe back into data port
            wait until rising_edge(dds_sync_clk);
            mem_addr_r                          <= mem_addr;
            mem_data(LINE_ADDR_BITS-1 downto 0) <= mem_addr_r;
            mem_data(30 downto 16)              <= mem_addr_r;
            
            if unsigned(mem_addr_r) = to_unsigned(5, mem_addr_r'length) then
                mem_data(29 downto 24) <= "000011";
            else
                mem_data(29 downto 24) <= "000000";
            end if;

            mem_addr_valid_r <= mem_addr_valid;
            mem_data_valid   <= mem_addr_valid_r;
        end loop;
    end process;

    uut: entity work.jam_engine_core
    generic map ( LINE_ADDR_BITS => LINE_ADDR_BITS )
    port map (
        -- Clock and synchronous enable
        reg_clk                 => reg_clk,
        dds_sync_clk            => dds_sync_clk,
        jam_srst                => jam_srst,

        -- Memory bus
        mem_addr                => mem_addr,
        mem_addr_valid          => mem_addr_valid,
        mem_data                => mem_data,
        mem_data_valid          => mem_data_valid,

        -- Start/end line
        start_line_addr_main    => start_line_addr_main,
        end_line_addr_main      => end_line_addr_main,
        start_line_addr_shadow  => start_line_addr_shadow,
        end_line_addr_shadow    => end_line_addr_shadow,
        shadow_select           => shadow_select,

        -- VSWR engine signals
        vswr_line_addr          => vswr_line_addr,
        vswr_line_req           => vswr_line_req,
        vswr_line_ack           => vswr_line_ack,

        -- Temperature compensation
        temp_comp_mult_asf      => temp_comp_mult_asf,
        temp_comp_offs_asf      => temp_comp_offs_asf,
        temp_comp_mult_dblr     => temp_comp_mult_dblr,
        temp_comp_offs_dblr     => temp_comp_offs_dblr,

        -- Control lines
        zero_phase              => zero_phase,

        -- DDS interface signals
        jam_rd_en               => jam_rd_en,
        jam_data                => jam_data,
        jam_terminate_line      => jam_terminate_line,
        jam_fifo_empty          => jam_fifo_empty
    );
end tb;
