----------------------------------------------------------------------------------
--! @file drm_reg_bridge.vhd
--! @brief Module which bridges register interface to DRM
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

----------------------------------------------------------------------------------
--! @brief Module which instantiates the Xilinx Aurora core
----------------------------------------------------------------------------------
entity drm_reg_bridge is
    port (
        -- Register Buses
        reg_clk         : in std_logic;        --! The register clock
        reg_srst        : in std_logic;        --! Register synchronous reset
        slv_reg_mosi    : in reg_mosi_type;    --! Register master-out, slave-in signals - slave interface
        slv_reg_miso    : out reg_miso_type;   --! Register master-in, slave-out signals - slave interface
        reg_mosi_drm    : out reg_mosi_type;   --! Register master-out, slave-in signals - master interface
        reg_miso_drm    : in reg_miso_type;    --! Register master-in, slave-out signals - master interface

        -- Aurora User Clock
        user_clk        : in std_logic;
        link_srst       : in std_logic;

        -- LocalLink Tx Interface
        tx_d            : out std_logic_vector(31 downto 0);
        tx_rem          : out std_logic_vector(0 to 1);
        tx_src_rdy_n    : out std_logic;
        tx_sof_n        : out std_logic;
        tx_eof_n        : out std_logic;
        tx_dst_rdy_n    : in std_logic;

        -- LocalLink Rx Interface
        rx_d            : in std_logic_vector(31 downto 0);
        rx_rem          : in std_logic_vector(0 to 1);
        rx_src_rdy_n    : in std_logic;
        rx_sof_n        : in std_logic;
        rx_eof_n        : in std_logic
    );
end drm_reg_bridge;

architecture rtl of drm_reg_bridge is
    ---------------------------
    -- CONSTANT DECLARATIONS --
    ---------------------------
    constant C_OP_READ       : std_logic_vector(7 downto 0) := x"00";
    constant C_OP_WRITE      : std_logic_vector(7 downto 0) := x"01";
    constant C_OP_READ_RESP  : std_logic_vector(7 downto 0) := x"02";

    --------------------------------
    -- SIGNAL & TYPE DECLARATIONS --
    --------------------------------
    type fsm_tx_t is (TX_IDLE, TX_OP_ADDR, TX_DATA);
    type fsm_rx_t is (RX_IDLE, RX_DATA);

    signal fsm_tx                : fsm_tx_t;
    signal fsm_rx                : fsm_rx_t;    
    
    -- ECM-DRM Data Sources
    signal ecm_to_drm_slv_word   : std_logic_vector(63 downto 0);
    signal ecm_to_drm_slv_valid  : std_logic;
    signal ecm_to_drm_mst_word   : std_logic_vector(63 downto 0);
    signal ecm_to_drm_mst_valid  : std_logic;
    alias ecm_to_drm_slv_op      : std_logic_vector(7 downto 0) is ecm_to_drm_slv_word(63 downto 56);
    alias ecm_to_drm_slv_addr    : std_logic_vector(23 downto 0) is ecm_to_drm_slv_word(55 downto 32);
    alias ecm_to_drm_slv_data    : std_logic_vector(31 downto 0) is ecm_to_drm_slv_word(31 downto 0);
    alias ecm_to_drm_mst_op      : std_logic_vector(7 downto 0) is ecm_to_drm_mst_word(63 downto 56);
    alias ecm_to_drm_mst_addr    : std_logic_vector(23 downto 0) is ecm_to_drm_mst_word(55 downto 32);
    alias ecm_to_drm_mst_data    : std_logic_vector(31 downto 0) is ecm_to_drm_mst_word(31 downto 0);
    
    -- ECM-DRM FIFO signals
    signal tx_d_nxt              : std_logic_vector(31 downto 0);
    signal ecm_to_drm_fifo_in    : std_logic_vector(63 downto 0);
    signal ecm_to_drm_fifo_out   : std_logic_vector(63 downto 0);
    signal ecm_to_drm_fifo_wr    : std_logic;
    signal ecm_to_drm_fifo_rd    : std_logic;
    signal ecm_to_drm_fifo_empty : std_logic;        
    
    -- DRM-ECM FIFO signals
    signal drm_to_ecm_fifo_in    : std_logic_vector(63 downto 0);
    signal drm_to_ecm_fifo_out   : std_logic_vector(63 downto 0);
    signal drm_to_ecm_fifo_wr    : std_logic;
    signal drm_to_ecm_fifo_rd    : std_logic;
    signal drm_to_ecm_fifo_empty : std_logic;    
    alias drm_to_ecm_op          : std_logic_vector(7 downto 0) is drm_to_ecm_fifo_out(63 downto 56);
    alias drm_to_ecm_addr        : std_logic_vector(23 downto 0) is drm_to_ecm_fifo_out(55 downto 32);
    alias drm_to_ecm_data        : std_logic_vector(31 downto 0) is drm_to_ecm_fifo_out(31 downto 0);
    

begin
    ------------------------
    -- SIGNAL ASSIGNMENTS --
    ------------------------
    tx_rem <= "11";

    -----------------------------
    -- COMBINATORIAL PROCESSES --
    -----------------------------

    --------------------------
    -- SEQUENTIAL PROCESSES --
    --------------------------
    -----------------------------------------------------------------------------
    --! @brief Master register read/write process, synchronous to reg_clk.
    --!
    --! Sends read/write requests from master on ECM side over to slaves on DRM side.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_master: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                ecm_to_drm_mst_valid <= '0';
            else
                -- Defaults
                ecm_to_drm_mst_valid <= '0';

                if slv_reg_mosi.valid = '1' then
                    -- Is the address destined for the Aurora link?
                    if (slv_reg_mosi.addr and REG_MASK_DRM) = REG_ADDR_BASE_DRM then
                        -- Send commands from master on this side over the link
                        if slv_reg_mosi.rd_wr_n = '1' then
                            ecm_to_drm_mst_op <= C_OP_READ;
                        else
                            ecm_to_drm_mst_op <= C_OP_WRITE;
                        end if;
                        ecm_to_drm_mst_data  <= slv_reg_mosi.data;                            
                        ecm_to_drm_mst_addr  <= x"00" & slv_reg_mosi.addr(15 downto 0);
                        ecm_to_drm_mst_valid <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Slave register read/write process, synchronous to reg_clk.
    --!
    --! Sends responses from slaves on ECM side over to master on DRM side.
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_reg_slave: process (reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                -- Synchronous Reset
                ecm_to_drm_slv_valid <= '0';
            else
                -- Defaults
                ecm_to_drm_slv_valid <= '0';
                
                -- Send responses from the slaves on the ECM side to the DRM
                if reg_miso_drm.ack = '1' then
                    ecm_to_drm_slv_op    <= C_OP_READ_RESP;
                    ecm_to_drm_slv_data  <= reg_miso_drm.data;
                    ecm_to_drm_slv_addr  <= (others => '0');
                    ecm_to_drm_slv_valid <= '1';
                end if;
            end if;
        end if;
    end process;

    -----------------------------------------------------------------------------
    --! @brief Frame transmit FSM
    --!
    --! @param[in]   user_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_tx_fsm: process (user_clk)
    begin
        if rising_edge(user_clk) then
            if link_srst = '1' then
                fsm_tx             <= TX_IDLE;
                ecm_to_drm_fifo_rd <= '0';
                tx_sof_n           <= '1';
                tx_eof_n           <= '1';
                tx_src_rdy_n       <= '1';
            else
                -- Default
                ecm_to_drm_fifo_rd <= '0';
                
                case fsm_tx is
                    when TX_IDLE =>                        
                        -- Send read/write command from ECM to DRM
                        if ecm_to_drm_fifo_empty = '0' then
                            -- Issue the read command to the FIFO but read data on this cycle as it is FWFT
                            ecm_to_drm_fifo_rd <= '1';
                            
                            -- Send the op-code and address
                            tx_d         <= ecm_to_drm_fifo_out(63 downto 32);
                            tx_d_nxt     <= ecm_to_drm_fifo_out(31 downto 0);
                            tx_sof_n     <= '0';
                            tx_eof_n     <= '1';
                            tx_src_rdy_n <= '0';
                            fsm_tx       <= TX_OP_ADDR;
                        end if;

                    when TX_OP_ADDR =>
                        -- Wait until op-code and address cycle has been accepted
                        if tx_dst_rdy_n = '0' then
                            -- Send the data
                            tx_sof_n <= '1';
                            tx_eof_n <= '0';
                            tx_d     <= tx_d_nxt;
                            fsm_tx   <= TX_DATA;
                        end if;

                    when TX_DATA =>
                        -- Wait until data cycle has been accepted
                        if tx_dst_rdy_n = '0' then
                            tx_sof_n     <= '1';
                            tx_eof_n     <= '1';
                            tx_src_rdy_n <= '1';
                            fsm_tx       <= TX_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Frame receive FSM
    --!
    --! @param[in]   user_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_rx_fsm: process (user_clk)
    begin
        if rising_edge(user_clk) then
            if link_srst = '1' then
                fsm_rx             <= RX_IDLE;
                drm_to_ecm_fifo_wr <= '0';  
            else
                -- Defaults
                drm_to_ecm_fifo_wr <= '0';
                
                case fsm_rx is
                    when RX_IDLE =>
                        -- Wait for the op-code/address cycle - this must be SOF
                        if rx_src_rdy_n = '0' and rx_sof_n = '0' then
                            -- Receive the op-code and address
                            drm_to_ecm_fifo_in(63 downto 32) <= rx_d;
                            fsm_rx <= RX_DATA;
                        end if;

                    when RX_DATA =>
                        -- Wait for the data cycle and check that it is EOF with 4 bytes,
                        -- if it is not then just return to IDLE and wait for a SOF
                        if rx_src_rdy_n = '0' then
                            -- Receive the data and write into FIFO
                            if rx_eof_n = '0' and rx_rem = "11" then
                                drm_to_ecm_fifo_in(31 downto 0) <= rx_d;
                                drm_to_ecm_fifo_wr <= '1';
                            end if;
                            
                            fsm_rx <= RX_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
    
    -----------------------------------------------------------------------------
    --! @brief Route received data to correct interface
    --!
    --! Received responses are routed via the slave interface to the master.
    --!
    --! Received read/write requests are routed via the master interface to
    --! the slave(s).
    --!
    --! @param[in]   reg_clk     Clock, used on rising edge
    -----------------------------------------------------------------------------
    p_rx_route: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                slv_reg_miso.data   <= (others => '0');
                slv_reg_miso.ack    <= '0';                
                reg_mosi_drm.valid  <= '0';
                drm_to_ecm_fifo_rd  <= '0';
            else
                -- Defaults
                slv_reg_miso.data   <= (others => '0');
                slv_reg_miso.ack    <= '0';
                reg_mosi_drm.valid  <= '0';
                drm_to_ecm_fifo_rd  <= '0';
                
                -- Process received frame from FIFO
                if drm_to_ecm_fifo_empty = '0' and drm_to_ecm_fifo_rd = '0' then
                    -- Issue the read command, read data immediately as FIFO is FWFT
                    drm_to_ecm_fifo_rd <= '1';
                    
                    if drm_to_ecm_op = C_OP_READ_RESP then
                        slv_reg_miso.data <= drm_to_ecm_data;
                        slv_reg_miso.ack  <= '1';
                    elsif drm_to_ecm_op = C_OP_READ then
                        reg_mosi_drm.addr    <= drm_to_ecm_addr;
                        reg_mosi_drm.rd_wr_n <= '1';
                        reg_mosi_drm.valid   <= '1';
                    elsif drm_to_ecm_op = C_OP_WRITE then
                        reg_mosi_drm.addr    <= drm_to_ecm_addr;
                        reg_mosi_drm.data    <= drm_to_ecm_data;
                        reg_mosi_drm.rd_wr_n <= '0';
                        reg_mosi_drm.valid   <= '1';
                    end if;
                end if;
            end if;
        end if;
    end process;

    ---------------------------
    -- ENTITY INSTANTIATIONS --
    ---------------------------
    -----------------------------------------------------------------------------
    --! @brief DRM Interface Transmit FIFO Scheduler
    --!
    --! Schedules data from the two sources into the transmit FIFO
    -----------------------------------------------------------------------------
    i_bridge_fifo_scheduler: entity work.bridge_fifo_scheduler
    generic map (DATA_WIDTH => 64)
    port map (
        -- Clock and reset
        clk_i           => reg_clk,
        srst_i          => reg_srst,
        
        -- Input data
        data_src_1_i    => ecm_to_drm_mst_word,
        data_src_2_i    => ecm_to_drm_slv_word,
        data_valid_1_i  => ecm_to_drm_mst_valid,
        data_valid_2_i  => ecm_to_drm_slv_valid,
        
        -- Output data
        data_o          => ecm_to_drm_fifo_in,
        data_valid_o    => ecm_to_drm_fifo_wr
    );
    
    -----------------------------------------------------------------------------
    --! @brief DRM Interface Transmit FIFO
    --!
    --! Transfers data from the register clock domain to the MGT user clock domain
    -----------------------------------------------------------------------------
    i_fifo_drm_tx: entity work.fifo_drm_if
    port map (
        rst    => link_srst,
        wr_clk => reg_clk,
        rd_clk => user_clk,
        din    => ecm_to_drm_fifo_in,
        wr_en  => ecm_to_drm_fifo_wr,
        rd_en  => ecm_to_drm_fifo_rd,
        dout   => ecm_to_drm_fifo_out,
        full   => open,
        empty  => ecm_to_drm_fifo_empty
    );

    -----------------------------------------------------------------------------
    --! @brief DRM Interface Receive FIFO
    --!
    --! Transfers data from the MGT user clock domain to the register clock domain
    -----------------------------------------------------------------------------    
    i_fifo_drm_rx: entity work.fifo_drm_if
    port map (
        rst    => link_srst,
        wr_clk => user_clk,
        rd_clk => reg_clk,
        din    => drm_to_ecm_fifo_in,
        wr_en  => drm_to_ecm_fifo_wr,
        rd_en  => drm_to_ecm_fifo_rd,
        dout   => drm_to_ecm_fifo_out,
        full   => open,
        empty  => drm_to_ecm_fifo_empty
    );
end rtl;