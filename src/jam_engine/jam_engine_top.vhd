----------------------------------------------------------------------------------
--! @file jam_engine_top.vhd
--! @brief Mercury jamming engine
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

--! @brief Top-level jamming engine entity
--!
--! Includes jamming engine core and the jamming engine memory with
--! dual-port interface
entity jam_engine_top is
    generic (
        LINE_ADDR_BITS      : natural := 15
    );
    port (
        -- DDS Clock
        dds_sync_clk        : in std_logic;                                     --! DDS sync clock

        -- Register Clock/Reset
        reg_clk             : in std_logic;                                     --! The register clock
        reg_srst            : in std_logic;                                     --! Register synchronous reset

        -- ECM Register Bus
        reg_mosi_ecm        : in reg_mosi_type;                                 --! ECM register master-out, slave-in signals
        reg_miso_ecm        : out reg_miso_type;                                --! ECM register master-in, slave-out signals

        -- DRM Register Bus
        reg_mosi_drm        : in reg_mosi_type;                                 --! DRM register master-out, slave-in signals
        reg_miso_drm        : out reg_miso_type;                                --! DRM register master-in, slave-out signals

        -- Receive test mode enable
        rx_test_en          : out std_logic;                                    --! Receive test mode enable

        -- Jamming engine enable
        jam_en_n            : out std_logic;                                    --! Jamming engine enable (disable manual control)

        -- VSWR engine signals
        vswr_line_addr      : in std_logic_vector(LINE_ADDR_BITS-1 downto 0);   --! VSWR test line base address
        vswr_line_req       : in std_logic;                                     --! Request VSWR test using line at vswr_line_addr
        vswr_line_ack       : out std_logic;                                    --! VSWR request being serviced

        -- DDS interface signals
        jam_rd_en              : in std_logic;                                     --! Read jamming line data from FWFT FIFO
        jam_data               : out std_logic_vector(31 downto 0);                --! Jamming line read data        
        jam_terminate_line     : out std_logic;                                    --! Terminate active jamming line     
        jam_fifo_empty         : out std_logic                                     --! Jamming engine FIFO empty
     );
end jam_engine_top;

architecture rtl of jam_engine_top is

    constant CAPABILITIES        : std_logic_vector(31 downto 0) := x"0" &     -- Rserved
                                                               x"7d0" &   -- Min. line time, ns
                                                               x"7fff";   -- Max line addr

    constant C_RD_SRC_ECM        : std_logic := '0';
    constant C_RD_SRC_DRM        : std_logic := '1';
    
    -- Block memory port A (read/write) signals
    signal blk_mem_wea           : std_logic_vector(0 downto 0) := "0";
    signal blk_mem_addra         : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal blk_mem_dina          : std_logic_vector(31 downto 0) := (others => '0');
    signal blk_mem_douta         : std_logic_vector(31 downto 0);

    signal blk_mem_rd_i          : std_logic;
    signal blk_mem_rd_o          : std_logic;
    signal blk_mem_rd_src_i      : std_logic;
    signal blk_mem_rd_src_o      : std_logic;

    signal blk_mem_addra_zeroize : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal blk_mem_addra_reg     : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal blk_mem_dina_reg      : std_logic_vector(31 downto 0) := (others => '0');
    signal blk_mem_rda_reg       : std_logic := '0';
    signal blk_mem_wea_reg       : std_logic := '0';

    -- Block memory port B (read) signals
    signal blk_mem_addrb         : std_logic_vector(LINE_ADDR_BITS-1 downto 0);
    signal blk_mem_doutb         : std_logic_vector(31 downto 0);

    signal core_addr_valid       : std_logic;
    signal core_data_valid       : std_logic;

    signal start_line_reg_main   : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal end_line_reg_main     : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal start_line_reg_shadow : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');
    signal end_line_reg_shadow   : std_logic_vector(LINE_ADDR_BITS-1 downto 0) := (others => '0');

    signal control_register      : std_logic_vector(31 downto 0) := JAM_ENG_CTRL_RESET_VAL;

    alias  shadow                : std_logic is control_register(3);
    alias  zeroize               : std_logic is control_register(2);
    alias  zero_phase            : std_logic is control_register(1);
    alias  jam_srst              : std_logic is control_register(0);

    signal zeroize_r             : std_logic;
    signal zeroized              : std_logic;
    signal zeroizing             : std_logic;

    -- Temperature compensation
    signal temp_comp_mult_asf    : std_logic_vector(15 downto 0) := x"8000";
    signal temp_comp_offs_asf    : std_logic_vector(15 downto 0) := x"0000";
    signal temp_comp_mult_dblr   : std_logic_vector(15 downto 0) := x"8000";
    signal temp_comp_offs_dblr   : std_logic_vector(15 downto 0) := x"0000";
begin
    jam_en_n   <= jam_srst;
    rx_test_en <= control_register(4);

    -----------------------------------------------------------------------------
    --! @brief Block memory/jamming registers read/write process, synchronous to reg_clk.
    --!
    --! Provides read/write access to block memory port A via register
    --! bus. This port is used to allow the microcontroller to read and write
    --! jamming data.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    blk_mem_reg_proc: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                control_register    <= JAM_ENG_CTRL_RESET_VAL;
                temp_comp_mult_asf  <= x"8000";
                temp_comp_offs_asf  <= x"0000";
                temp_comp_mult_dblr <= x"8000";
                temp_comp_offs_dblr <= x"0000";
                blk_mem_rda_reg     <= '0';
                blk_mem_wea_reg     <= '0';
                reg_miso_ecm.ack    <= '0';
                reg_miso_drm.ack    <= '0';
            else
                -- Defaults
                blk_mem_rda_reg   <= '0';
                blk_mem_wea_reg   <= '0';
                reg_miso_ecm.data <= (others => '0');
                reg_miso_ecm.ack  <= '0';
                reg_miso_drm.data <= (others => '0');
                reg_miso_drm.ack  <= '0';
                
                -- Control register (MSB-1) = zeroized
                control_register(30) <= zeroized;

                if blk_mem_rd_o = '1' then
                    if blk_mem_rd_src_o = C_RD_SRC_ECM then
                        reg_miso_ecm.data <= blk_mem_douta;
                        reg_miso_ecm.ack  <= '1';
                    elsif blk_mem_rd_src_o = C_RD_SRC_DRM then
                        reg_miso_drm.data <= blk_mem_douta;
                        reg_miso_drm.ack  <= '1';
                    end if;
                end if;

                -- ECM interface to registers, note that if a write to any register is received from both ECM and DRM 
                -- on the same clock cycle then DRM will win the arbitration. This should not happen in normal operation.
                if reg_mosi_ecm.valid = '1' then
                    -- Jamming memory register access
                    if reg_mosi_ecm.addr(23 downto LINE_ADDR_BITS) = REG_JAM_ENG_LINE_BASE(23 downto LINE_ADDR_BITS) then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            -- Read block memory - don't need to do anything to block memory signals,
                            -- just assert read flag which is delayed and output on reg_miso.ack
                            blk_mem_rd_src_i  <= C_RD_SRC_ECM;
                            blk_mem_rda_reg   <= '1';
                            blk_mem_addra_reg <= reg_mosi_ecm.addr(LINE_ADDR_BITS-1 downto 0);
                        else
                            -- Write block memory
                            blk_mem_wea_reg   <= '1';
                            blk_mem_addra_reg <= reg_mosi_ecm.addr(LINE_ADDR_BITS-1 downto 0);
                            blk_mem_dina_reg  <= reg_mosi_ecm.data;
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_CAPABILITY then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data <= CAPABILITIES;
                            reg_miso_ecm.ack  <= '1';
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_CONTROL then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data <= control_register;
                            reg_miso_ecm.ack  <= '1';
                        else
                            control_register(30 downto 0) <= reg_mosi_ecm.data(30 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_START_ADDR_MAIN then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data(LINE_ADDR_BITS-1 downto 0) <= start_line_reg_main;
                            reg_miso_ecm.ack <= '1';
                        else
                            start_line_reg_main <= reg_mosi_ecm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_END_ADDR_MAIN then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data(LINE_ADDR_BITS-1 downto 0) <= end_line_reg_main;
                            reg_miso_ecm.ack <= '1';
                        else
                            end_line_reg_main <= reg_mosi_ecm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_START_ADDR_SHADOW then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data(LINE_ADDR_BITS-1 downto 0) <= start_line_reg_shadow;
                            reg_miso_ecm.ack <= '1';
                        else
                            start_line_reg_shadow <= reg_mosi_ecm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_END_ADDR_SHADOW then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data(LINE_ADDR_BITS-1 downto 0) <= end_line_reg_shadow;
                            reg_miso_ecm.ack <= '1';
                        else
                            end_line_reg_shadow <= reg_mosi_ecm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_TEMP_COMP_ASF then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data <= temp_comp_mult_asf & temp_comp_offs_asf;
                            reg_miso_ecm.ack  <= '1';
                        else
                            temp_comp_mult_asf <= reg_mosi_ecm.data(31 downto 16);
                            temp_comp_offs_asf <= reg_mosi_ecm.data(15 downto 0);
                        end if;
                    elsif reg_mosi_ecm.addr = REG_ENG_1_TEMP_COMP_DBLR then
                        if reg_mosi_ecm.rd_wr_n = '1' then
                            reg_miso_ecm.data <= temp_comp_mult_dblr & temp_comp_offs_dblr;
                            reg_miso_ecm.ack  <= '1';
                        else
                            temp_comp_mult_dblr <= reg_mosi_ecm.data(31 downto 16);
                            temp_comp_offs_dblr <= reg_mosi_ecm.data(15 downto 0);
                        end if;
                    end if;
                end if;
                
                -- DRM interface to registers, note that if a write to any register is received from both ECM and DRM 
                -- on the same clock cycle then DRM will win the arbitration. This should not happen in normal operation.
                if reg_mosi_drm.valid = '1' then
                    -- Jamming memory register access
                    if reg_mosi_drm.addr(23 downto LINE_ADDR_BITS) = REG_JAM_ENG_LINE_BASE(23 downto LINE_ADDR_BITS) then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            -- Read block memory - don't need to do anything to block memory signals,
                            -- just assert read flag which is delayed and output on reg_miso.ack
                            blk_mem_rd_src_i  <= C_RD_SRC_DRM;
                            blk_mem_rda_reg   <= '1';
                            blk_mem_addra_reg <= reg_mosi_drm.addr(LINE_ADDR_BITS-1 downto 0);
                        else
                            -- Write block memory
                            blk_mem_wea_reg   <= '1';
                            blk_mem_addra_reg <= reg_mosi_drm.addr(LINE_ADDR_BITS-1 downto 0);
                            blk_mem_dina_reg  <= reg_mosi_drm.data;
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_CAPABILITY then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data  <= CAPABILITIES;
                            reg_miso_drm.ack   <= '1';
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_CONTROL then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data <= control_register;
                            reg_miso_drm.ack  <= '1';
                        else
                            control_register(30 downto 0) <= reg_mosi_drm.data(30 downto 0);
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_START_ADDR_MAIN then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data(LINE_ADDR_BITS-1 downto 0) <= start_line_reg_main;
                            reg_miso_drm.ack <= '1';
                        else
                            start_line_reg_main <= reg_mosi_drm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_END_ADDR_MAIN then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data(LINE_ADDR_BITS-1 downto 0) <= end_line_reg_main;
                            reg_miso_drm.ack <= '1';
                        else
                            end_line_reg_main <= reg_mosi_drm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_START_ADDR_SHADOW then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data(LINE_ADDR_BITS-1 downto 0) <= start_line_reg_shadow;
                            reg_miso_drm.ack <= '1';
                        else
                            start_line_reg_shadow <= reg_mosi_drm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    elsif reg_mosi_drm.addr = REG_ENG_1_END_ADDR_SHADOW then
                        if reg_mosi_drm.rd_wr_n = '1' then
                            reg_miso_drm.data(LINE_ADDR_BITS-1 downto 0) <= end_line_reg_shadow;
                            reg_miso_drm.ack <= '1';
                        else
                            end_line_reg_shadow <= reg_mosi_drm.data(LINE_ADDR_BITS-1 downto 0);
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    blk_mem_wr_proc: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if zeroizing = '1' then
                blk_mem_rd_i   <= '0';
                blk_mem_wea(0) <= '1';
                blk_mem_addra  <= blk_mem_addra_zeroize;
                blk_mem_dina   <= (others => '0');
            else
                blk_mem_rd_i    <= blk_mem_rda_reg;
                blk_mem_wea(0)  <= blk_mem_wea_reg;
                blk_mem_addra   <= blk_mem_addra_reg;
                blk_mem_dina    <= blk_mem_dina_reg;
            end if;
        end if;
    end process;

    zeroize_proc: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                zeroize_r <= '0';
                zeroized <= '0';
                zeroizing <= '0';
                blk_mem_addra_zeroize <= (others => '0');
            else
                zeroize_r <= zeroize;

                if zeroizing = '1' then
                    if unsigned(blk_mem_addra_zeroize) = to_unsigned((2**LINE_ADDR_BITS)-1, LINE_ADDR_BITS) then
                        zeroizing <= '0';
                        zeroized  <= '1';
                    else
                        blk_mem_addra_zeroize <= blk_mem_addra_zeroize + 1;
                    end if;
                else
                    if zeroize = '1' and zeroize_r = '0' then
                        zeroized  <= '0';
                        zeroizing <= '1';
                        blk_mem_addra_zeroize <= (others => '0');
                    elsif blk_mem_wea_reg = '1' then
                        -- Reset the zeroized bit to '0' when any memory address is written to
                        -- when not zeroizing (memory writes are ignored whilst zeroizing)
                        zeroized <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Pipeline delay used to align the output data valid signal
    --!
    --! Aligns the data output valid signal with valid read data becoming valid
    --! at block memory port A output.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    i_delay_rd: entity work.slv_delay
    generic map (
        bits   => 1,
        stages => 2
    )
    port map
    (
        clk  => reg_clk,
        i(0) => blk_mem_rd_i,
        o(0) => blk_mem_rd_o
    );
    
    i_delay_rd_src: entity work.slv_delay
    generic map (
        bits   => 1,
        stages => 3
    )
    port map
    (
        clk  => reg_clk,
        i(0) => blk_mem_rd_src_i,
        o(0) => blk_mem_rd_src_o
    );    

    i_delay_core_data: entity work.slv_delay
    generic map (
        bits   => 1,
        stages => 2
    )
    port map
    (
        clk  => dds_sync_clk,
        i(0) => core_addr_valid,
        o(0) => core_data_valid
    );

    -----------------------------------------------------------------------------
    --! @brief Jamming core instance
    --!
    --!
    -----------------------------------------------------------------------------
    i_jam_engine_core: entity work.jam_engine_core
    generic map ( LINE_ADDR_BITS => LINE_ADDR_BITS )
    port map (
        -- Clock and synchronous enable
        reg_clk                 => reg_clk,
        dds_sync_clk            => dds_sync_clk,
        jam_srst                => jam_srst,

        -- Memory bus
        mem_addr                => blk_mem_addrb,
        mem_addr_valid          => core_addr_valid,
        mem_data                => blk_mem_doutb,
        mem_data_valid          => core_data_valid,

        -- Start/end line
        start_line_addr_main    => start_line_reg_main,
        end_line_addr_main      => end_line_reg_main,
        start_line_addr_shadow  => start_line_reg_shadow,
        end_line_addr_shadow    => end_line_reg_shadow,
        shadow_select           => shadow,

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

    -----------------------------------------------------------------------------
    --! @brief Jamming engine memory instance
    --!
    --! 32-bit x 32768 block memory providing the jamming line storage.
    --! Dual port memory. Port A connected to register read/write interface,
    --! Port B read interface connected to jamming engine bus, Port B write interface
    --! unused.
    -----------------------------------------------------------------------------
    i_blk_mem_jam_eng : entity work.blk_mem_jam_eng
    port map (
        -- Port A (register interface)
        clka    => reg_clk,
        wea     => blk_mem_wea,
        addra   => blk_mem_addra,
        dina    => blk_mem_dina,
        douta   => blk_mem_douta,

        -- Port B (jamming engine interface)
        clkb    => dds_sync_clk,
        web     => "0",
        addrb   => blk_mem_addrb,
        dinb    => (others => '0'),
        doutb   => blk_mem_doutb
    );
end rtl;
