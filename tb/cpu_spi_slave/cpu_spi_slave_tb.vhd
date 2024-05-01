-- cpu_spi_slave_tb 

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use work.mercury_pkg.all;
use work.reg_pkg.all;

entity cpu_spi_slave_tb is
end cpu_spi_slave_tb;

architecture behavior of cpu_spi_slave_tb is 
	-- Slave SPI Bus
    signal spi_rst_n                : std_logic := '0';
    signal spi_clk                  : std_logic;
    signal spi_cs_n                 : std_logic := '1';	
    signal spi_rdy_rd               : std_logic;
    signal spi_error                : std_logic;
	signal spi_mosi                 : std_logic := '0';
	signal spi_miso	                : std_logic;	
            
	-- Register Bus         
    signal reg_clk                  : std_logic;
    signal reg_srst                 : std_logic;
    signal reg_miso                 : reg_miso_type;
    signal reg_mosi                 : reg_mosi_type; 
    
    constant NUM_TEST_PACKETS       : integer := 16;
    constant INTER_PKT_WAIT_CYCLES  : integer := 1;
    constant REG_READ_DELAY_CYCLES  : integer := 0;
	
	constant SPI_CLK_PERIOD         : time := 30 ns;
	constant REG_CLK_PERIOD         : time := 20 ns;
    
    constant VERBOSE                : boolean := false;

    type test_packets_t is array (integer range 1 to NUM_TEST_PACKETS) of std_logic_vector(15 downto 0);
    constant WRITE_PACKETS : test_packets_t := (
        -- Operation 1: Address 0
        x"0100",
        x"0000",
        x"ddee",
        x"ff00",
        -- Operation 2: Address 1
        x"0100",
        x"0001",
        x"0f0f",
        x"0f0f",            
        -- Operation 3: Address 2
        x"0100",
        x"0002",
        x"aaaa",
        x"aaaa",            
        -- Operation 4: Address 3
        x"0100",
        x"0003",
        x"1234",
        x"5678"                       
    );
    constant READ_PACKETS : test_packets_t := (
        -- Operation 1: Address 0
        x"0000",
        x"0000",
        x"0000",
        x"0000",
        -- Operation 2: Address 1
        x"0000",
        x"0001",
        x"0000",
        x"0000",            
        -- Operation 3: Address 2
        x"0000",
        x"0002",
        x"0000",
        x"0000",            
        -- Operation 4: Address 3
        x"0000",
        x"0003",
        x"0000",
        x"0000"                 
    );
begin

    -- UUT instantiation
    uut : entity work.cpu_spi_slave
    port map (                
        -- Async Reset
        spi_rst_n           => spi_rst_n,
        
        -- Slave SPI Bus
        spi_mosi            => spi_mosi,
        spi_miso            => spi_miso,
        spi_cs_n            => spi_cs_n,
        spi_clk             => spi_clk, 
        spi_rdy_rd          => spi_rdy_rd,
        spi_error           => spi_error,
        
        -- Register Bus        
        reg_clk             => reg_clk,
        reg_srst            => reg_srst,
        reg_miso            => reg_miso,
        reg_mosi            => reg_mosi
     );

	reg_clk_proc : process
	begin
		reg_clk <= '0';
		wait for REG_CLK_PERIOD/2;
		reg_clk <= '1';
		wait for REG_CLK_PERIOD/2;
	end process;

	tb : process        
    begin
        spi_rst_n <= '0';
        spi_clk <= '0';
        
		wait for 100 ns; 
        spi_rst_n <= '1';
        wait for 100 ns; -- wait until global set/reset completes
        
        -- Write Test
        for pkt in 1 to NUM_TEST_PACKETS loop            
            spi_cs_n <= '0';            
            for bit in 15 downto 0 loop
                wait for SPI_CLK_PERIOD/2;
                spi_clk <= '1';
                spi_mosi <= WRITE_PACKETS(pkt)(bit);
                wait for SPI_CLK_PERIOD/2;
                spi_clk <= '0';
            end loop;                            
            wait for SPI_CLK_PERIOD/2;
            spi_cs_n <= '1';
            wait for SPI_CLK_PERIOD*INTER_PKT_WAIT_CYCLES;
        end loop;
        
        -- Read Test        
        for pkt in 1 to NUM_TEST_PACKETS loop            
            spi_cs_n <= '0';        
            for bit in 15 downto 0 loop
                wait for SPI_CLK_PERIOD/2;
                spi_clk <= '1';
                spi_mosi <= READ_PACKETS(pkt)(bit);
                wait for SPI_CLK_PERIOD/2;
                spi_clk <= '0';
            end loop;
            wait for SPI_CLK_PERIOD/2;
            spi_cs_n <= '1';            
            
            if (pkt - 2) rem 4 = 0 then
                wait until spi_rdy_rd = '1';
            else
                wait for SPI_CLK_PERIOD*INTER_PKT_WAIT_CYCLES;
            end if;
        end loop;
		wait; -- will wait forever
	end process tb;
    
    test_reg_proc : process
        type test_reg_t is array (0 to 31) of std_logic_vector(31 downto 0);
        variable test_reg : test_reg_t;
    begin        
        wait until rising_edge(reg_clk);
        if reg_mosi.valid = '1' then
            if reg_mosi.rd_wr_n = '1' then                
                -- Read
                -- Wait to simulate pipeline delay
                wait for REG_CLK_PERIOD*REG_READ_DELAY_CYCLES;
                wait until rising_edge(reg_clk);
                reg_miso.data <= test_reg(to_integer(unsigned(reg_mosi.addr)));
                reg_miso.ack  <= '1';
            else
                -- Write
                reg_miso.ack <= '0';
                test_reg(to_integer(unsigned(reg_mosi.addr))) := reg_mosi.data;
            end if;
        else
            reg_miso.ack <= '0';
        end if;    
    end process test_reg_proc;

    decode_miso_proc : process
        variable data_received : std_logic_vector(31 downto 0);
        variable data_expected : std_logic_vector(31 downto 0);
        variable data_count : integer := 0;
        variable pkt_count : integer := 0;
        variable read_pkts : boolean := false;
        variable tests_passed : boolean := true;
    begin     
        while true loop
            wait until falling_edge(spi_clk);
            if spi_cs_n = '0' then
                data_received := data_received(30 downto 0) & spi_miso;
                data_count := data_count + 1;
                if data_count = 32 then                
                    data_count := 0;
                    pkt_count := pkt_count + 2;
                    
                    if read_pkts = true then
                        if pkt_count rem 4 = 0 then
                            data_expected := WRITE_PACKETS(pkt_count-1) & WRITE_PACKETS(pkt_count);
                            if VERBOSE = true then
                                report "Data received: " & integer'IMAGE(to_integer(unsigned(data_received))) 
                                    severity note;                        
                                report "Expected: " & integer'IMAGE(to_integer(unsigned(data_expected))) 
                                    severity note;
                            end if;                            
                            if data_received = data_expected then
                                report "Read transfer : " & integer'IMAGE(pkt_count/4) & " OK";
                            else
                                report "Read transfer : " & integer'IMAGE(pkt_count/4) & " FAILED!";
                                tests_passed := false;
                            end if;
                        end if;
                        
                        -- Break out of loop at end of test packets
                        if pkt_count = NUM_TEST_PACKETS then
                            exit;
                        end if;
                    -- Reset packet count at end of write packets
                    elsif pkt_count = NUM_TEST_PACKETS then
                        pkt_count := 0;
                        read_pkts := true;
                    end if;
                end if;        
            end if;
        end loop;
        
        if tests_passed = true then
            report "ALL TESTS PASSED!" severity note;
        else
            report "TEST FAILURE!!" severity warning;
        end if;
    end process;
end;
