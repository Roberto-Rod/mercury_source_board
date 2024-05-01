----------------------------------------------------------------------------------
--! @file mercury_pkg.vhd
--! @brief Mercury package file
--!
--! Contains descriptions of Mercury register types and addresses
--!
--! @author Richard Harrison
--! @email rh@harritronics.co.uk
--!
--! @version See Git logs
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

package mercury_pkg is

type vswr_miso_type is   --! VSWR master in, slave out type.<br>Includes forward/reverse data and valid signal
    record
        fwd     : std_logic_vector(11 downto 0);
        rev     : std_logic_vector(11 downto 0);
        valid   : std_logic;
    end record;

type vswr_mosi_type is  --! VSWR master out, slave in type.<br>Includes 2-bit address and valid signal
    record
        addr        : std_logic_vector(1 downto 0);
        valid       : std_logic;
        vswr_period : std_logic;
    end record;

type pa_management_mosi_type is
    record
        monitor_cs_n    : std_logic;
        monitor_sck     : std_logic;
        monitor_mosi    : std_logic;
        monitor_en      : std_logic;
        ctrl_shdn       : std_logic;
        ctrl_mute_n     : std_logic;
    end record;

type pa_management_miso_type is
    record
        monitor_miso    : std_logic;
        ctrl_alert      : std_logic;
    end record;

type pa_management_bidir_type is
    record
        ctrl_scl        : std_logic;
        ctrl_sda        : std_logic;
    end record;

--
-- Register Addresses
--
constant REG_ADDR_VERSION               : std_logic_vector(23 downto 0) := x"000000";   --! Version register
constant REG_ADDR_DWG_NUMBER            : std_logic_vector(23 downto 0) := x"000001";   --! Drawing number register
constant REG_ADDR_EXT_GPIO_DATA         : std_logic_vector(23 downto 0) := x"000002";   --! External GPIO data register
constant REG_ADDR_EXT_GPIO_DIR          : std_logic_vector(23 downto 0) := x"000003";   --! External GPIO direction register
constant REG_ADDR_EXT_GPO_FLASH_RATE    : std_logic_vector(23 downto 0) := x"000004";   --! External GPO flash rate register
constant REG_ADDR_PPS_CLOCK_COUNT       : std_logic_vector(23 downto 0) := x"000005";   --! 10MHz clock count between 1PPS pulses
--
constant REG_ADDR_BUILD_ID_LSBS         : std_logic_vector(23 downto 0) := x"000009";   --! Interrupt status register
constant REG_ADDR_BUILD_ID_MSBS         : std_logic_vector(23 downto 0) := x"00000a";   --! Interrupt status register
constant REG_ADDR_DAC_CONTROL           : std_logic_vector(23 downto 0) := x"00000b";   --! DAC control register
constant REG_ADDR_DAC_BASE              : std_logic_vector(23 downto 0) := x"00000c";   --! DAC base register (channel A)
constant REG_ADDR_DAC_TOP               : std_logic_vector(23 downto 0) := x"00000f";   --! DAC base register (channel D)
constant REG_ADDR_TRIM_CTRL_STAT        : std_logic_vector(23 downto 0) := x"000010";   --! VC-TCXO auto-trimming control/status
constant REG_ADDR_TRIM_ERR              : std_logic_vector(23 downto 0) := x"000011";   --! VC-TCXO auto-trimming error value
constant REG_ADDR_TRIM_ACC              : std_logic_vector(23 downto 0) := x"000012";   --! VC-TCXO auto-trimming accumulator value
constant REG_ADDR_TRIM_MULT_O           : std_logic_vector(23 downto 0) := x"000013";   --! VC-TCXO auto-trimming multiplier output value
constant REG_ADDR_PPS_COUNT             : std_logic_vector(23 downto 0) := x"000014";   --! PPS position count
constant REG_ADDR_PPS_ERROR             : std_logic_vector(23 downto 0) := x"000015";   --! PPS position error, moving average

constant REG_ADDR_AURORA_CONTROL        : std_logic_vector(23 downto 0) := x"000020";   --! Aurora Control
constant REG_ADDR_AURORA_RX_COUNT       : std_logic_vector(23 downto 0) := x"000021";   --! Aurora Rx Count

-- DDS control
constant REG_ADDR_DDS_REGS_BASE         : std_logic_vector(23 downto 0) := x"000100";   --! DDS registers (0x100 to 0x11b)
constant REG_ADDR_DDS_REGS_TOP          : std_logic_vector(23 downto 0) := x"00013f";   --! DDS registers top - assign 6 LSBs to DDS address
constant REG_ADDR_DDS_CTRL              : std_logic_vector(23 downto 0) := x"000140";   --! DDS control register
constant REG_ADDR_DDS_CLK_COUNT         : std_logic_vector(23 downto 0) := x"000141";   --! DDS sync clk count - number of cycles per second
constant REG_ADDR_DDS_IO_UPDATE         : std_logic_vector(23 downto 0) := x"000142";   --! Dummy register - a write to this register initiates DDS IO_UPDATE
constant REG_ADDR_DDS_DRCTL             : std_logic_vector(23 downto 0) := x"000143";   --! Dummy register - a write to this register initiates DDS DRCTL (not documented in ICD)

-- Synth control
constant REG_ADDR_SYNTH_CTRL            : std_logic_vector(23 downto 0) := x"000150";   --! Synth control register
constant REG_ADDR_SYNTH_REG             : std_logic_vector(23 downto 0) := x"000151";   --! Synth transparent register

-- RF/Daughter Control
constant REG_ADDR_RF_CTRL               : std_logic_vector(23 downto 0) := x"000160";   --! RF control
constant REG_ADDR_DGTR_CTRL             : std_logic_vector(23 downto 0) := x"000161";   --! Daughter board control & status register
constant REG_ADDR_BLANK_CTRL            : std_logic_vector(23 downto 0) := x"000162";   --! Blanking control register

-- PA control & status registers
constant REG_ADDR_INT_PA_CONTROL        : std_logic_vector(23 downto 0) := x"000170";   --! PA Control & Status

-- RF Power Monitor ADCs
-- <Reserved> Was: Blank & Read Delay After Blanking                       x"000171";
constant REG_ADDR_INT_PA_MAF_DELAY      : std_logic_vector(23 downto 0) := x"000172";   --! Moving Average Filter Delay Between Samples
constant REG_ADDR_INT_PA_MAF_COEFF      : std_logic_vector(23 downto 0) := x"000173";   --! Moving Average Filter Coefficient
constant REG_ADDR_INT_PA_PWR_MON        : std_logic_vector(23 downto 0) := x"000174";   --! Internal PA RF Power Monitor
-- <Reserved> Was: Internal PA RF Power Monitor - Blank & Read             z"000175";
constant REG_ADDR_INT_PA_BLNK_TO_INVLD  : std_logic_vector(23 downto 0) := x"000176";   --! Internal PA RF Power Monitor Blank to RF Invalid
constant REG_ADDR_INT_PA_ACTV_TO_VALID  : std_logic_vector(23 downto 0) := x"000177";   --! Internal PA RF Power Monitor Active to RF Valid
constant REG_ADDR_JAM_TO_CVSWR_VALID    : std_logic_vector(23 downto 0) := x"000178";   --! Jam Start to CVSWR Valid register
constant REG_ADDR_BLANK_TO_CVSWR_INVALID: std_logic_vector(23 downto 0) := x"000179";   --! Blank to CVSWR Invalid register

-- Timing Protocol Registers
constant REG_ADDR_TP_TRANSITION_BASE    : std_logic_vector(23 downto 0) := x"000180";   --! Timing Protocol Transition Time Base Register
constant REG_ADDR_BITS_TP_TRANSITION    : integer                       := 4;           --! Number of address LSBs for Timing Protocol Registers
constant REG_ADDR_TP_CONTROL            : std_logic_vector(23 downto 0) := x"000190";   --! Timing Protocol Control
constant REG_ADDR_TP_HOLDOVER           : std_logic_vector(23 downto 0) := x"000191";   --! Timing Protocol Holdover Time

-- PA controller I2C master control registers
constant REG_ADDR_CONTROL_I2C_INT_PA    : std_logic_vector(23 downto 0) := x"0001f0";   --! Internal PA I2C control & status register

-- PA controller micro addresses
constant REG_ADDR_BASE_I2C_INT_PA       : std_logic_vector(23 downto 0) := x"000200";   --! Internal PA I2C base address
constant REG_ADDR_TOP_I2C_INT_PA        : std_logic_vector(23 downto 0) := x"0002ff";   --! Internal PA I2C top address

-- Doubler attenuator look-up-table memory
constant REG_ADDR_BASE_DBLR_ATT         : std_logic_vector(23 downto 0) := x"000600";   --! Doubler attenuator LUT base address
constant REG_ADDR_TOP_DBLR_ATT          : std_logic_vector(23 downto 0) := x"0006ff";   --! Doubler attenuator LUT top address

-- Jamming Engine Control
constant REG_ENG_1_CAPABILITY           : std_logic_vector(23 downto 0) := x"001000";   --! Jamming engine capabilities register
constant REG_ENG_1_CONTROL              : std_logic_vector(23 downto 0) := x"001001";   --! Jamming engine control register
constant REG_ENG_1_START_ADDR_MAIN      : std_logic_vector(23 downto 0) := x"001002";   --! Jamming engine line start address - main
constant REG_ENG_1_END_ADDR_MAIN        : std_logic_vector(23 downto 0) := x"001003";   --! Jamming engine line end address - main
constant REG_ENG_1_TEMP_COMP_ASF        : std_logic_vector(23 downto 0) := x"001004";   --! Jamming engine temperature compensation, DDS Amplitude Scale Factor
constant REG_ENG_1_TEMP_COMP_DBLR       : std_logic_vector(23 downto 0) := x"001005";   --! Jamming engine temperature compensation, daughter board doubler
constant REG_ENG_1_START_ADDR_SHADOW    : std_logic_vector(23 downto 0) := x"001006";   --! Jamming engine line start address - shadow
constant REG_ENG_1_END_ADDR_SHADOW      : std_logic_vector(23 downto 0) := x"001007";   --! Jamming engine line end address - shadow

constant REG_ENG_1_VSWR_FSM_STATE       : std_logic_vector(23 downto 0) := x"00100f";   --! VSWR FSM state (not in ICD)
constant REG_ENG_1_VSWR_CONTROL         : std_logic_vector(23 downto 0) := x"001010";   --! VSWR control register
constant REG_ENG_1_VSWR_STATUS          : std_logic_vector(23 downto 0) := x"001011";   --! VSWR status register
constant REG_ENG_1_VSWR_WINDOW_OFFS     : std_logic_vector(23 downto 0) := x"001012";   --! VSWR test window offset (1ms/LSB)
constant REG_ENG_1_VSWR_START_ADDR      : std_logic_vector(23 downto 0) := x"001013";   --! VSWR line start address
constant REG_ENG_1_VSWR_FAIL_ACTV_TIME  : std_logic_vector(23 downto 0) := x"001014";   --! VSWR failure active time (1ms/LSB)
constant REG_ENG_1_VSWR_THRESH_BASE     : std_logic_vector(23 downto 0) := x"001020";   --! VSWR threshold base address
constant REG_ENG_1_VSWR_THRESH_TOP      : std_logic_vector(23 downto 0) := x"00102f";   --! VSWR threshold top address
constant REG_ENG_1_VSWR_RESULT_BASE     : std_logic_vector(23 downto 0) := x"001040";   --! VSWR results base address
constant REG_ENG_1_VSWR_RESULT_TOP      : std_logic_vector(23 downto 0) := x"00105f";   --! VSWR results top address

-- Jamming Engine Lines
constant REG_JAM_ENG_LINE_BASE          : std_logic_vector(23 downto 0) := x"010000";   --! Jamming engine line memory base address
constant REG_JAM_ENG_LINE_TOP           : std_logic_vector(23 downto 0) := x"017fff";   --! Jamming engine line memory top address

-- Dock Transparent Registers
constant REG_ADDR_BASE_DOCK             : std_logic_vector(23 downto 0) := x"100000";   --! Dock register base address
constant REG_ADDR_TOP_DOCK              : std_logic_vector(23 downto 0) := x"1002ff";   --! Dock register top address

-- Digital Receiver Module Registers
constant REG_ADDR_BASE_DRM              : std_logic_vector(23 downto 0) := x"110000";   --! DRM base address
constant REG_MASK_DRM                   : std_logic_vector(23 downto 0) := x"FF0000";   --! DRM register mask

--
-- Register reset values
--
constant DDS_CTRL_RESET_VAL             : std_logic_vector(31 downto 0) := x"00000007"; --! DDS control reset value
constant JAM_ENG_CTRL_RESET_VAL         : std_logic_vector(31 downto 0) := x"00000001"; --! Jamming engine control reset value

--
-- PA Controller Micro I2C Slave Address
--
constant PA_CTRL_I2C_SLAVE_ADDR         : std_logic_vector(6 downto 0)  := "0010101";   --! PA management micro-controller I2C slave address on bus

--
-- VSWR addresses
--
constant VSWR_ADDR_INT                  : std_logic_vector(1 downto 0)  := "00";        --! Address for internal VSWR measurements
constant VSWR_ADDR_DOCK                 : std_logic_vector(1 downto 0)  := "01";        --! Address for dock  VSWR measurements
--
-- Interrupts
--
constant IRQ_VSWR_RESULT                : integer := 0;
constant IRQ_VSWR_FAIL                  : integer := 1;
constant IRQ_PA_CTRL_INT_A              : integer := 2;
constant IRQ_PA_CTRL_INT_B              : integer := 3;
constant IRQ_PA_CTRL_DOCK_A             : integer := 4;
constant IRQ_PA_CTRL_DOCK_B             : integer := 5;
constant IRQ_DOCK_A_STATE               : integer := 6;
constant IRQ_DOCK_B_STATE               : integer := 7;

--
-- SPI Commands
--
constant SPI_CTRL_READ_REG              : std_logic_vector(7 downto 0)  := x"00";       --! SPI read command
constant SPI_CTRL_WRITE_REG             : std_logic_vector(7 downto 0)  := x"01";       --! SPI write command

--
-- Declare functions and procedure
--
-- function <function_name>  (signal <signal_name> : in <type_declaration>) return <type_declaration>;
-- procedure <procedure_name> (<type_declaration> <constant_name>    : in <type_declaration>);
--

end mercury_pkg;

package body mercury_pkg is
end mercury_pkg;

