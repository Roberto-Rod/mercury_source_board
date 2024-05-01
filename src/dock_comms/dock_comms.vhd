----------------------------------------------------------------------------------
--! @file dock_comms.vhd
--! @brief Dock RS485 communications master
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

--! @brief Entity providing control of the dock RS485 communications
--!
--! This module transmits a packet every time it sees the register input bus valid signal asserted.
--! The addresses that are transmitted directly and so it is expected that address translation
--! has occurred in a higher level module where the valid signal has been filtered so that it is
--! only asserted when a packet is to be transmitted to the dock comms port.
entity dock_comms is
    generic (
        VSWR_ADDRESS        : std_logic_vector(1 downto 0)  := "01"
    );
    port (
        -- Register Bus
        reg_clk             : in std_logic;                         --! The register clock
        reg_srst            : in std_logic;                         --! Register synchronous reset
        reg_mosi            : in reg_mosi_type;                     --! Register master-out, slave-in signals
        reg_miso            : out reg_miso_type;                    --! Register master-in, slave-out signals

        -- VSWR Engine Bus
        vswr_mosi           : in vswr_mosi_type;                    --! VSWR engine master-out, slave-in signals
        vswr_miso           : out vswr_miso_type;                   --! VSWR engine master-in, slave-out signals

        -- Dock RS485 Transceiver Pins
        dock_comms_ro       : in std_logic;
        dock_comms_re_n     : out std_logic;
        dock_comms_de       : out std_logic;
        dock_comms_di       : out std_logic
    );
end dock_comms;

architecture rtl of dock_comms is
    signal clk_uart_x16         : std_logic;

    signal tx_active            : std_logic;

    -- Asynchronous reset which we use in clk_uart_x16 domain.
    -- This is just an alias of reg_srst as we can use the reset
    -- which is synchronous to reg_clk as the async reset in the other
    -- clock domain.
    alias  arst                 : std_logic is reg_srst;

    -- Register bus FIFO signals
    signal reg_fifo_din         : std_logic_vector(48 downto 0);
    signal reg_fifo_wr_en       : std_logic;
    signal reg_fifo_dout        : std_logic_vector(48 downto 0);
    signal reg_fifo_rd_en       : std_logic;
    signal reg_fifo_empty       : std_logic;

    -- VSWR req/ack signals
    signal vswr_req             : std_logic;
    signal vswr_ack             : std_logic;

    -- Dock packet generator input signals
    signal dock_addr            : std_logic_vector(15 downto 0);
    signal dock_din             : std_logic_vector(31 downto 0);
    signal dock_rd_wr_n         : std_logic;
    signal dock_din_valid       : std_logic;

    -- Dock packet decoder output signals
    signal dock_dout            : std_logic_vector(31 downto 0);
    signal dock_resp            : std_logic_vector(7 downto 0);
    signal dock_dout_valid      : std_logic;

    -- Tx FIFO signals
    signal tx_fifo_din          : std_logic_vector(7 downto 0);
    signal tx_fifo_din_valid    : std_logic;

    signal tx_fifo_dout         : std_logic_vector(7 downto 0);
    signal tx_fifo_rd_en        : std_logic;
    signal tx_fifo_empty        : std_logic;
    signal tx_fifo_dout_valid   : std_logic;

    -- Rx FIFO signals
    signal rx_fifo_din          : std_logic_vector(7 downto 0);
    signal rx_fifo_din_valid    : std_logic;

    signal rx_fifo_dout         : std_logic_vector(7 downto 0);
    signal rx_fifo_rd_en        : std_logic;
    signal rx_fifo_empty        : std_logic;
    signal rx_fifo_dout_valid   : std_logic;

    type fsm_dock_t is (IDLE, REG_SEND, WAIT_RD_RESP_REG, WAIT_WR_RESP_REG, WAIT_RD_RESP_VSWR, DELAY);
    signal fsm_dock : fsm_dock_t := IDLE;

    signal timeout_count        : unsigned(19 downto 0);                       --! 20-bits gives timeout period of 13.1 ms at 80 MHz
    signal delay_count          : unsigned(12 downto 0);                       --! 13-bits gives delay period of 102.4 us at 80 MHz
    signal retry_count          : unsigned(3 downto 0);                        --! Retry count (first attempt increments this to 1)

    constant MAX_RETRY          : unsigned(3 downto 0) := to_unsigned(6, 4);  --! Max rd/wr attempts after checksum error / timeout = 6

    constant DOCK_ADDR_PWR_MON  : std_logic_vector(15 downto 0) := x"0174";    --! Dock PA RF Power Monitor

    constant RESP_OK            : std_logic_vector(7 downto 0)  := x"00";      --! Dock response code: OK
    constant RESP_ERR_CKSUM     : std_logic_vector(7 downto 0)  := x"01";      --! Dock response code: Checksum error
    constant RESP_ERR_CMD       : std_logic_vector(7 downto 0)  := x"02";      --! Dock response code: Command code error
    constant RESP_ERR_ADDR      : std_logic_vector(7 downto 0)  := x"03";      --! Dock response code: Address error
begin
    -------------------------------------------------------------------
    --! @brief Writes the register bus FIFO
    --!
    --! Loads data into the FIFO from the register bus which will be
    --! unloaded when the dock comms bus is available
    --!
    --! @param[in]   reg_clk  Clock, used on rising edge
    -------------------------------------------------------------------
    fifo_load: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                reg_fifo_wr_en <= '0';
            else
                -- Register the data, addr (16 LSBs) & rd_wr_n signals
                reg_fifo_din <= reg_mosi.data & reg_mosi.addr(15 downto 0) & reg_mosi.rd_wr_n;

                if reg_mosi.valid = '1' and reg_mosi.addr >= REG_ADDR_BASE_DOCK and
                                            reg_mosi.addr <= REG_ADDR_TOP_DOCK then
                    reg_fifo_wr_en <= '1';
                else
                    reg_fifo_wr_en <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------
    --! @brief The register bus FIFO
    --!
    --! Used to store register bus rd/wr commands
    --------------------------------------------------
    i_fifo: entity work.fifo_dock_comms
    port map (
        clk   => reg_clk,
        srst  => reg_srst,
        din   => reg_fifo_din,
        wr_en => reg_fifo_wr_en,
        full  => open,
        dout  => reg_fifo_dout,
        rd_en => reg_fifo_rd_en,
        empty => reg_fifo_empty
    );

    -------------------------------------------------------------------
    --! @brief Sets/clears VSWR request and acknowledge signals
    --!
    --! These are used by this module to schedule reading of power
    --! monitor data to be returned to VSWR engine.
    --!
    --! @param[in]   reg_clk  Clock, used on rising edge
    -------------------------------------------------------------------
    vswr_req_ack: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                vswr_req <= '0';
            else
                -- If the VSWR engine is trying to read the dock then register the request
                if vswr_mosi.valid = '1' and vswr_mosi.addr = VSWR_ADDRESS then
                    vswr_req <= '1';
                -- If the FSM has issued the request to the dock then clear the request flag
                elsif vswr_ack = '1' then
                    vswr_req <= '0';
                end if;
            end if;
        end if;
    end process;

    -------------------------------------------------------------------------------
    --! @brief The FSM which unloads register FIFO and sends/receives data to dock
    --!
    --! This process sends VSWR read commands to be returned to the VSWR engine.
    --! It also unloads the register bus FIFO and sends/receives register read/write
    --! commands.
    --!
    --! The process handles retry-on-error and incorporates timeouts to handle
    --! the dock not being present or not communicating.
    --!
    --! @param[in]   reg_clk  Clock, used on rising edge
    -------------------------------------------------------------------------------
    fsm: process(reg_clk)
    begin
        if rising_edge(reg_clk) then
            if reg_srst = '1' then
                fsm_dock        <= IDLE;
                reg_miso.ack    <= '0';
                reg_miso.data   <= (others => '0');
                vswr_miso.valid <= '0';
                vswr_miso.fwd   <= (others => '0');
                vswr_miso.rev   <= (others => '0');
                dock_din_valid  <= '0';
                retry_count     <= (others => '0');
            else
                -- Defaults
                reg_miso.ack    <= '0';
                reg_miso.data   <= (others => '0');
                vswr_miso.valid <= '0';
                vswr_miso.fwd   <= (others => '0');
                vswr_miso.rev   <= (others => '0');
                dock_din_valid  <= '0';
                vswr_ack        <= '0';
                reg_fifo_rd_en  <= '0';

                case fsm_dock is
                    when IDLE =>
                        timeout_count       <= (others => '1');

                        -- If the VSWR engine is trying to read the dock then give it priority
                        if vswr_req = '1' then
                            -- Issue a power monitor read command to the dock
                            dock_din        <= (others => '0');
                            dock_addr       <= DOCK_ADDR_PWR_MON;
                            dock_rd_wr_n    <= '1';
                            dock_din_valid  <= '1';
                            -- Move to the next state - note that we go straight to waiting
                            -- for read response and that state will not resend - no time for that.
                            -- If it fails then just let the VSWR engine timeout
                            fsm_dock        <= WAIT_RD_RESP_VSWR;
                            retry_count     <= (others => '0');
                            -- Acknowledge the request
                            vswr_ack        <= '1';
                        -- If there is a register request in the FIFO then send it, only allow the register
                        -- FIFO to be unloaded outside of the VSWR test period. This makes sure register requests
                        -- aren't sent to the dock whilst the power is settling during the VSWR test, thus making
                        -- the dock comms bus available to read the VSWR results after that power settling period.
                        elsif vswr_mosi.vswr_period = '0' then

                            if retry_count > 0 then
                                -- Retry: dock data/addr/rd_wr_n will be latched,
                                -- just need to (re-)assert the valid flag
                                retry_count     <= retry_count - 1;
                                fsm_dock        <= REG_SEND;
                            elsif reg_fifo_empty = '0' then
                                -- Register the data, addr (16 LSBs) & rd_wr_n signals
                                dock_din        <= reg_fifo_dout(48 downto 17);
                                dock_addr       <= reg_fifo_dout(16 downto 1);
                                dock_rd_wr_n    <= reg_fifo_dout(0);
                                reg_fifo_rd_en  <= '1';

                                -- Move to the next state
                                fsm_dock        <= REG_SEND;
                                retry_count     <= MAX_RETRY;
                            end if;
                        end if;

                    when REG_SEND =>
                        dock_din_valid <= '1';
                        timeout_count  <= (others => '1');

                        -- Move to the next state (depending on whether this is read or write request)
                        if dock_rd_wr_n = '1' then
                            fsm_dock  <= WAIT_RD_RESP_REG;
                        else
                            fsm_dock  <= WAIT_WR_RESP_REG;
                        end if;

                    when WAIT_RD_RESP_VSWR =>
                        if dock_dout_valid = '1' then
                            if dock_resp = RESP_OK then
                                -- Response OK - send data back to master
                                vswr_miso.valid <= '1';
                                vswr_miso.fwd   <= dock_dout(11 downto 0);
                                vswr_miso.rev   <= dock_dout(27 downto 16);
                                fsm_dock        <= DELAY;
                            else
                                -- If there is an error then just let master timeout, no time to retry VSWR comms
                                fsm_dock        <= DELAY;
                            end if;
                        elsif timeout_count = 0 then
                            -- If we timeout waiting then just let master timeout, no time to retry VSWR comms
                            fsm_dock            <= DELAY;
                        else
                            timeout_count       <= timeout_count - 1;
                        end if;

                        -- Reset the delay counter
                        delay_count <= (others => '1');

                    when WAIT_RD_RESP_REG =>
                        if dock_dout_valid = '1' then
                            if dock_resp = RESP_OK then
                                -- Response OK - send data back to master
                                reg_miso.ack  <= '1';
                                reg_miso.data <= dock_dout;
                                fsm_dock      <= DELAY;
                                -- Reset the retry counter
                                retry_count     <= (others => '0');
                            elsif dock_resp = RESP_ERR_CKSUM then
                                -- Checksum error - have another go (up to MAX_RETRY)
                                fsm_dock        <= DELAY;
                            else
                                -- If this is a command/address error then just don't send 
                                -- data back to internal register master (let it timeout).
                                fsm_dock        <= DELAY;
                                -- Reset the retry counter - don't retry because the dock responded
                                -- and validated the checksum - the packet must contain bad data.
                                retry_count     <= (others => '0');
                            end if;
                        elsif timeout_count = 0 then
                            -- Timeout - have another go (up to MAX_RETRY)
                            fsm_dock            <= DELAY;
                        else
                            timeout_count       <= timeout_count - 1;
                        end if;

                        -- Reset the delay counter
                        delay_count <= (others => '1');

                    when WAIT_WR_RESP_REG =>
                        if dock_dout_valid = '1' then
                            if dock_resp = RESP_OK then
                                -- Response OK - return to idle state (after delay)
                                fsm_dock        <= DELAY;
                                -- Reset the retry counter
                                retry_count     <= (others => '0');                                
                            elsif dock_resp = RESP_ERR_CKSUM then
                                -- Checksum error - have another go (up to MAX_RETRY)
                                fsm_dock        <= DELAY;
                            else
                                -- If this is a command/address error then just don't send 
                                -- data back to internal register master (let it timeout).
                                fsm_dock        <= DELAY;
                                -- Reset the retry counter - don't retry because the dock responded
                                -- and validated the checksum - the packet must contain bad data.
                                retry_count     <= (others => '0');
                            end if;
                        elsif timeout_count = 0 then
                            -- Timeout - have another go (up to MAX_RETRY)
                            fsm_dock            <= DELAY;
                        else
                            timeout_count       <= timeout_count - 1;
                        end if;

                        -- Reset the delay counter
                        delay_count <= (others => '1');

                    when DELAY =>
                        if delay_count = 0 then
                            -- Delay time expired - return to idle
                            fsm_dock      <= IDLE;
                        else
                            -- Decrement delay count
                            delay_count   <= delay_count - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------
    --! @brief Packet Generation
    --------------------------------------------------
    i_dock_packet_gen: entity work.dock_packet_gen
    port map(
        srst        => reg_srst,
        clk         => reg_clk,

        addr        => dock_addr,
        din         => dock_din,
        rd_wr_n     => dock_rd_wr_n,
        din_valid   => dock_din_valid,

        tx_data     => tx_fifo_din,
        tx_valid    => tx_fifo_din_valid
    );

    --------------------------------------------------
    --! @brief Packet Decoding
    --------------------------------------------------
    i_dock_packet_decode: entity work.dock_packet_decode
    port map(
        srst        => reg_srst,
        clk         => reg_clk,

        dout        => dock_dout,
        resp_out    => dock_resp,
        dout_valid  => dock_dout_valid,

        rx_data     => rx_fifo_dout,
        rx_valid    => rx_fifo_dout_valid
    );

    --------------------------------------------------
    --! @brief UART Clock Generation
    --------------------------------------------------
    i_uart_clk: entity work.uart_clk
    port map (
        clk_in1         => reg_clk,
        clk_out1        => clk_uart_x16
    );

    ----------------------------------------------------
    --! @brief Process to control reading of Tx FIFO
    ----------------------------------------------------
    fifo_tx_proc: process(arst, clk_uart_x16)
    begin
        if arst = '1' then
            tx_fifo_rd_en <= '0';
            tx_fifo_dout_valid <= '0';
        elsif rising_edge(clk_uart_x16) then
            -- Issue a read when the FIFO is empty, issue reads every other
            -- clock cycle at most so that empty flag is up-to-date.
            tx_fifo_rd_en <= not tx_fifo_empty and not tx_fifo_rd_en;
            tx_fifo_dout_valid <= tx_fifo_rd_en;    -- read was issued on last clock - data is now valid
        end if;
    end process;

    ----------------------------------------------------
    --! @brief Process to control reading of Rx FIFO
    ----------------------------------------------------
    fifo_rx_proc: process(arst, reg_clk)
    begin
        if arst = '1' then
            rx_fifo_rd_en <= '0';
            rx_fifo_dout_valid <= '0';
        elsif rising_edge(reg_clk) then
            -- Issue a read when the FIFO is empty, issue reads every other
            -- clock cycle at most so that empty flag is up-to-date.
            rx_fifo_rd_en <= not rx_fifo_empty and not rx_fifo_rd_en;
            rx_fifo_dout_valid <= rx_fifo_rd_en;    -- read was issued on last clock - data is now valid
        end if;
    end process;

    ------------------------------------------------------
    --! @brief Tx FIFO to cross between register
    --! clock domain and UART clock domain
    ------------------------------------------------------
    i_fifo_tx: entity work.fifo_8x16
    port map (
        rst             => arst,

        wr_clk          => reg_clk,
        din             => tx_fifo_din,
        wr_en           => tx_fifo_din_valid,
        full            => open,

        rd_clk          => clk_uart_x16,
        dout            => tx_fifo_dout,
        rd_en           => tx_fifo_rd_en,
        empty           => tx_fifo_empty
    );

    ------------------------------------------------------
    --! @brief Rx FIFO to cross between UART
    --! clock domain and register clock domain
    ------------------------------------------------------
    i_fifo_rx: entity work.fifo_8x16
    port map (
        rst             => arst,

        wr_clk          => clk_uart_x16,
        din             => rx_fifo_din,
        wr_en           => rx_fifo_din_valid,
        full            => open,

        rd_clk          => reg_clk,
        dout            => rx_fifo_dout,
        rd_en           => rx_fifo_rd_en,
        empty           => rx_fifo_empty
    );

    --------------------------------------
    --! @brief UART Instance
    --------------------------------------
    i_uart: entity work.uart
    port map (
        rst             => arst,
        clk_uart_x16    => clk_uart_x16,
        uart_tx         => dock_comms_di  ,
        uart_rx         => dock_comms_ro  ,
        rx_data         => rx_fifo_din,
        rx_data_valid   => rx_fifo_din_valid,
        tx_data         => tx_fifo_dout,
        tx_data_valid   => tx_fifo_dout_valid,
        tx_rdy          => open,
        tx_active       => tx_active
    );

    --------------------------------------
    --! @brief RS485 Half Duplex Control
    --------------------------------------
    i_rs485_ctrl: entity work.rs485_ctrl
    port map (
        arst         => arst,
        data_clk     => clk_uart_x16,
        tx_active    => tx_active,
        rs485_txe    => dock_comms_de,
        rs485_rxe_n  => dock_comms_re_n
    );

end rtl;


