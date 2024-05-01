----------------------------------------------------------------------------------
--! @file blank_ctrl.vhd
--! @brief Blanking control module
--!
--! Takes all the blanking sources and outputs the internal and external blanking
--! signals based on the states of the enable bits in the control register provided
--! by this module.
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

library unisim;
use unisim.vcomponents.all;

--! @brief Blanking control entity
--!
--! Takes internal and external blanking inputs and masks them
--! before distributing internally/outputting externally
entity blank_ctrl is
    port (
        -- Register Bus
        reg_clk             : in std_logic;      --! The register clock
        reg_srst            : in std_logic;      --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;  --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type; --! Register master-in, slave-out signals

        -- Blanking inputs
        ext_blank_in_n      : in std_logic;      --! External blanking input (asynchronous)
        jam_blank_n         : in std_logic;      --! Jamming engine blanking input
        vswr_blank_rev_n    : in std_logic;      --! VSWR engine blanking input (reverse measurement/mute-on-fail)
        vswr_blank_all_n    : in std_logic;      --! VSWR engine blanking input (entire test)
        tp_async_blank_n    : in std_logic;      --! Timing Protocol asynchronous blanking input

        -- Blanking outputs
        int_blank_n         : out std_logic;     --! Internal blanking signal
        tp_ext_blank_n      : out std_logic;     --! Masked external blanking signal to Timing Protocol module
        ext_blank_out_n     : out std_logic;     --! External blanking output
        
        -- Tx/Rx Control in/out
        tx_rx_ctrl_in       : in std_logic;      --! Tx/Rx control in to module (internal)
        tx_rx_ctrl_out      : out std_logic      --! Tx/Rx control out of module (external)
     );
end blank_ctrl;

architecture rtl of blank_ctrl is
    -- Control register
    signal ctrl_reg                 : std_logic_vector(31 downto 0);

    -- Mask bits within control register
    alias int_blank_mask_ext        : std_logic is ctrl_reg(0);
    alias int_blank_mask_jam        : std_logic is ctrl_reg(1);
    alias int_blank_mask_vswr_rev   : std_logic is ctrl_reg(2);
    alias ext_blank_mask_ext        : std_logic is ctrl_reg(4);
    alias ext_blank_mask_jam        : std_logic is ctrl_reg(5);
    alias ext_blank_mask_vswr_rev   : std_logic is ctrl_reg(6);
    alias ext_blank_mask_vswr_all   : std_logic is ctrl_reg(7);
    
    -- Synchronised external blanking signal
    signal ext_blank_in_n_s         : std_logic;
begin

    -----------------------------------------------------------------------------
    --! @brief Blanking process - generates blanking signals based on mask bits
    --!
    --! TP asynchronous blank does not have a mask bit, enabling/disabling
    --! of that source is handled in the timing_protocol module.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    blank_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            int_blank_n     <= ((ext_blank_in_n_s or not int_blank_mask_ext) and
                                (jam_blank_n      or not int_blank_mask_jam) and
                                (vswr_blank_rev_n or not int_blank_mask_vswr_rev) and
                                 tp_async_blank_n);

            ext_blank_out_n <= ((ext_blank_in_n_s or not ext_blank_mask_ext) and
                                (jam_blank_n      or not ext_blank_mask_jam) and
                                (vswr_blank_rev_n or not ext_blank_mask_vswr_rev) and
                                (vswr_blank_all_n or not ext_blank_mask_vswr_all) and
                                 tp_async_blank_n);
                                 
            -- Interlock Tx/Rx control at this final register as a safety mechanism,
            -- never drive switch into Rx state when PA is un-blanked
            tx_rx_ctrl_out  <= tx_rx_ctrl_in or tp_async_blank_n;
                                 
            tp_ext_blank_n  <= ext_blank_in_n_s or not ext_blank_mask_ext;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Register read/write process, synchronous to reg_clk.
    --!
    --! Handles blanking control register
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    reg_rd_wr_proc: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                ctrl_reg     <= x"000000EF";
                reg_miso.ack <= '0';
                reg_miso.data  <= (others => '0');
            elsif reg_mosi.valid = '1' then
                -- Defaults
                reg_miso.ack  <= '0';
                reg_miso.data <= (others => '0');

                if reg_mosi.addr = REG_ADDR_BLANK_CTRL then
                    -- Control register
                    if reg_mosi.rd_wr_n = '1' then
                        reg_miso.ack  <= '1';
                        reg_miso.data <= ctrl_reg;
                    else
                        ctrl_reg <= reg_mosi.data ;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief External blanking synchroniser - register into reg_clk domain
    -----------------------------------------------------------------------------
    i_blank_in_synchroniser: entity work.slv_synchroniser
    generic map (
        bits            => 1,
        sync_reset      => true
    )
    port map (
        rst             => reg_srst,
        clk             => reg_clk,
        din(0)          => ext_blank_in_n,
        dout(0)         => ext_blank_in_n_s
    );
end rtl;
