---------------------------------------------------------------------------------------------
-- (c) Copyright 2008 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.
-- 
-- 
--------------------------------------------------------------------------------------------
--
--  drm_aurora
--
--
--  Description: This is the top level module for a 1 4-byte lane Aurora
--               reference design module. This module supports the following features:
--
--

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.all;

-- synthesis translate_off
library UNISIM;
use UNISIM.all;
--synthesis translate_on

entity drm_aurora is
    generic (                    
          SIM_GTPRESET_SPEEDUP   :integer :=   0      
    );
    port (

    -- LocalLink TX Interface

            TX_D             : in std_logic_vector(0 to 31);
            TX_REM           : in std_logic_vector(0 to 1);
            TX_SRC_RDY_N     : in std_logic;
            TX_SOF_N         : in std_logic;
            TX_EOF_N         : in std_logic;
            TX_DST_RDY_N     : out std_logic;

    -- LocalLink RX Interface

            RX_D             : out std_logic_vector(0 to 31);
            RX_REM           : out std_logic_vector(0 to 1);
            RX_SRC_RDY_N     : out std_logic;
            RX_SOF_N         : out std_logic;
            RX_EOF_N         : out std_logic;

    -- GTX Serial I/O

            RXP             : in  std_logic;
            RXN             : in  std_logic;
            TXP             : out std_logic;
            TXN             : out std_logic;

    -- GTX Reference Clock Interface

    --GTX Reference Clock Interface

            GTPD0    : in  std_logic;

    -- Error Detection Interface

            HARD_ERR      : out std_logic;
            SOFT_ERR      : out std_logic;
            FRAME_ERR     : out std_logic;

    -- Status

            CHANNEL_UP      : out std_logic;
            LANE_UP         : out std_logic;

    -- Clock Compensation Control Interface

            WARN_CC         : in  std_logic;
            DO_CC           : in  std_logic;

     -- System Interface

            USER_CLK        : in  std_logic;
            SYNC_CLK        : in  std_logic;
            RESET           : in  std_logic;
            POWER_DOWN      : in  std_logic;
            LOOPBACK        : in  std_logic_vector(2 downto 0);
            GT_RESET        : in  std_logic;
            GTPCLKOUT        : out std_logic;
    RXEQMIX_IN            : in  std_logic_vector(1 downto 0);
    TX_DIFF_CTRL          : in  std_logic_vector(3 downto 0);
    TX_PREEMPHASIS        : in  std_logic_vector(2 downto 0);
    
    DADDR_IN       : in   std_logic_vector(7 downto 0);
    DCLK_IN        : in   std_logic;
    DEN_IN         : in   std_logic;
    DI_IN          : in   std_logic_vector(15 downto 0);
    DRDY_OUT       : out  std_logic;
    DRPDO_OUT      : out  std_logic_vector(15 downto 0);
    DWE_IN         : in   std_logic;
            TX_LOCK         : out std_logic

         );

end drm_aurora;


architecture MAPPED of drm_aurora is
  attribute core_generation_info           : string;
  attribute core_generation_info of MAPPED : architecture is "drm_aurora,aurora_8b10b_v5_3,{user_interface=Legacy_LL, backchannel_mode=Sidebands, c_aurora_lanes=1, c_column_used=None, c_gt_clock_1=GTPD0, c_gt_clock_2=None, c_gt_loc_1=1, c_gt_loc_10=X, c_gt_loc_11=X, c_gt_loc_12=X, c_gt_loc_13=X, c_gt_loc_14=X, c_gt_loc_15=X, c_gt_loc_16=X, c_gt_loc_17=X, c_gt_loc_18=X, c_gt_loc_19=X, c_gt_loc_2=X, c_gt_loc_20=X, c_gt_loc_21=X, c_gt_loc_22=X, c_gt_loc_23=X, c_gt_loc_24=X, c_gt_loc_25=X, c_gt_loc_26=X, c_gt_loc_27=X, c_gt_loc_28=X, c_gt_loc_29=X, c_gt_loc_3=X, c_gt_loc_30=X, c_gt_loc_31=X, c_gt_loc_32=X, c_gt_loc_33=X, c_gt_loc_34=X, c_gt_loc_35=X, c_gt_loc_36=X, c_gt_loc_37=X, c_gt_loc_38=X, c_gt_loc_39=X, c_gt_loc_4=X, c_gt_loc_40=X, c_gt_loc_41=X, c_gt_loc_42=X, c_gt_loc_43=X, c_gt_loc_44=X, c_gt_loc_45=X, c_gt_loc_46=X, c_gt_loc_47=X, c_gt_loc_48=X, c_gt_loc_5=X, c_gt_loc_6=X, c_gt_loc_7=X, c_gt_loc_8=X, c_gt_loc_9=X, c_lane_width=4, c_line_rate=0.625, c_nfc=false, c_nfc_mode=IMM, c_refclk_frequency=62.5, c_simplex=false, c_simplex_mode=TX, c_stream=false, c_ufc=false, flow_mode=None, interface_mode=Framing, dataflow_config=Duplex}";

-- Component Declarations --

    component FD

        generic (
                    INIT : bit := '0'
                );

        port (
                Q : out std_ulogic;
                C : in  std_ulogic;
                D : in  std_ulogic
             );

    end component;


    component drm_aurora_AURORA_LANE_4BYTE
        
        port (

        -- GTX Interface

                RX_DATA             : in  std_logic_vector(31 downto 0);    -- 4-byte data bus from the GTX.
                RX_NOT_IN_TABLE     : in  std_logic_vector(3 downto 0);     -- Invalid 10-bit code was recieved.
                RX_DISP_ERR         : in  std_logic_vector(3 downto 0);     -- Disparity error detected on RX interface.
                RX_CHAR_IS_K        : in  std_logic_vector(3 downto 0);     -- Indicates which bytes of RX_DATA are control.
                RX_CHAR_IS_COMMA    : in  std_logic_vector(3 downto 0);     -- Comma received on given byte.
                RX_BUF_ERR          : in  std_logic;                        -- Overflow/Underflow of RX buffer detected.
                RX_STATUS           : in  std_logic_vector(5 downto 0);     -- Part of GT_11 status and error bus
                TX_BUF_ERR          : in  std_logic;                        -- Overflow/Underflow of TX buffer detected.
                RX_REALIGN          : in  std_logic;                        -- SERDES was realigned because of a new comma.
                RX_POLARITY         : out std_logic;                        -- Controls interpreted polarity of serial data inputs.
                RX_RESET            : out std_logic;                        -- Reset RX side of GTX logic.
                TX_CHAR_IS_K        : out std_logic_vector(3 downto 0);     -- TX_DATA byte is a control character.
                TX_DATA             : out std_logic_vector(31 downto 0);    -- 4-byte data bus to the GTX.
                TX_RESET            : out std_logic;                        -- Reset TX side of GTX logic.

        -- Comma Detect Phase Align Interface

                ENA_COMMA_ALIGN     : out std_logic;                        -- Request comma alignment.

        -- TX_LL Interface

                GEN_SCP             : in  std_logic_vector(0 to 1);         -- SCP generation request from TX_LL.
                GEN_ECP             : in  std_logic_vector(0 to 1);         -- ECP generation request from TX_LL.
                GEN_PAD             : in  std_logic_vector(0 to 1);         -- PAD generation request from TX_LL
                TX_PE_DATA          : in  std_logic_vector(0 to 31);        -- Data from TX_LL to send over lane.
                TX_PE_DATA_V        : in  std_logic_vector(0 to 1);         -- Indicates TX_PE_DATA is Valid.
                GEN_CC              : in  std_logic;                        -- CC generation request from TX_LL.

        -- RX_LL Interface

                RX_PAD              : out std_logic_vector(0 to 1);         -- Indicates lane received PAD.
                RX_PE_DATA          : out std_logic_vector(0 to 31);        -- RX data from lane to RX_LL.
                RX_PE_DATA_V        : out std_logic_vector(0 to 1);         -- RX_PE_DATA is data, not control symbol.
                RX_SCP              : out std_logic_vector(0 to 1);         -- Indicates lane received SCP.
                RX_ECP              : out std_logic_vector(0 to 1);         -- Indicates lane received ECP

        -- Global Logic Interface

                GEN_A               : in  std_logic;                        -- 'A character' generation request from Global Logic.
                GEN_K               : in  std_logic_vector(0 to 3);         -- 'K character' generation request from Global Logic.
                GEN_R               : in  std_logic_vector(0 to 3);         -- 'R character' generation request from Global Logic.
                GEN_V               : in  std_logic_vector(0 to 3);         -- Verification data generation request.
                LANE_UP             : out std_logic;                        -- Lane is ready for bonding and verification.
                SOFT_ERR            : out std_logic_vector(0 to 1);         -- Soft error detected.
                HARD_ERR            : out std_logic;                        -- Hard error detected.
                CHANNEL_BOND_LOAD   : out std_logic;                        -- Channel Bongding done code recieved.
                GOT_A               : out std_logic_vector(0 to 3);         -- Indicates lane recieved 'A character' bytes.
                GOT_V               : out std_logic;                        -- Verification symbols received.

        -- System Interface

                USER_CLK            : in  std_logic;                        -- System clock for all non-GTX Aurora Logic.
                RESET_SYMGEN        : in  std_logic;                        -- Reset the SYM_GEN module.
                RESET               : in  std_logic                         -- Reset the lane.

             );

    end component;


    component drm_aurora_GTP_WRAPPER
       generic(
                  SIM_GTPRESET_SPEEDUP   :integer :=   0      --Set to 1 to speed up sim reset
              );
        port  (
                ENCHANSYNC_IN           : in    std_logic;
                ENMCOMMAALIGN_IN        : in    std_logic;
                ENPCOMMAALIGN_IN        : in    std_logic;
                REFCLK                                         : in    std_logic;
                LOOPBACK_IN             : in    std_logic_vector (2 downto 0);
                RXPOLARITY_IN           : in    std_logic;
                RXRESET_IN              : in    std_logic;
                RXUSRCLK_IN             : in    std_logic;
                RXUSRCLK2_IN            : in    std_logic;
                RXEQMIX_IN              : in    std_logic_vector(1 downto 0);
                TXDIFFCTRL0_IN          : in   std_logic_vector(3 downto 0);
                TXPREEMPHASIS0_IN       : in   std_logic_vector(2 downto 0);
    DADDR_IN       : in   std_logic_vector(7 downto 0);
    DCLK_IN        : in   std_logic;
    DEN_IN         : in   std_logic;
    DI_IN          : in   std_logic_vector(15 downto 0);
    DRDY_OUT       : out  std_logic;
    DRPDO_OUT      : out  std_logic_vector(15 downto 0);
    DWE_IN         : in   std_logic;
                RX1N_IN                 : in    std_logic;
                RX1P_IN                 : in    std_logic;
                TXCHARISK_IN            : in    std_logic_vector (3 downto 0);
                TXDATA_IN               : in    std_logic_vector (31 downto 0);
                GTPRESET_IN                                     : in    std_logic;
                TXRESET_IN              : in    std_logic;
                TXUSRCLK_IN             : in    std_logic;
                TXUSRCLK2_IN            : in    std_logic;
                RXBUFERR_OUT            : out   std_logic;
                RXCHARISCOMMA_OUT       : out   std_logic_vector (3 downto 0);
                RXCHARISK_OUT           : out   std_logic_vector (3 downto 0);
                RXDATA_OUT              : out   std_logic_vector (31 downto 0);
                RXDISPERR_OUT           : out   std_logic_vector (3 downto 0);
                RXNOTINTABLE_OUT        : out   std_logic_vector (3 downto 0);
                RXREALIGN_OUT           : out   std_logic;
                RXRECCLK1_OUT           : out   std_logic;
                RXRECCLK2_OUT           : out   std_logic;
                CHBONDDONE_OUT          : out   std_logic;
                TXBUFERR_OUT            : out   std_logic;
                PLLLKDET_OUT            : out   std_logic;
                GTPCLKOUT_OUT                 : out    std_logic_vector (1 downto 0);
                TX1N_OUT                : out   std_logic;
                TX1P_OUT                : out   std_logic;

RXCHARISCOMMA_OUT_unused : out   std_logic_vector (3 downto 0);
RXCHARISK_OUT_unused     : out   std_logic_vector (3 downto 0);
RXDISPERR_OUT_unused     : out   std_logic_vector (3 downto 0);
RXNOTINTABLE_OUT_unused  : out   std_logic_vector (3 downto 0);
------------------- Receive Ports - Channel Bonding Ports -----------------
RXREALIGN_OUT_unused     : out   std_logic;
RXDATA_OUT_unused        : out   std_logic_vector (31 downto 0);
RX1N_IN_unused           : in    std_logic;
RX1P_IN_unused           : in    std_logic;
RXBUFERR_OUT_unused      : out   std_logic_vector(2 downto 0);
TXBUFERR_OUT_unused      : out   std_logic_vector(1 downto 0);
CHBONDDONE_OUT_unused    : out   std_logic;
TX1N_OUT_unused          : out   std_logic;
TX1P_OUT_unused          : out   std_logic;


                POWERDOWN_IN            : in    std_logic

             );

    end component;

    component BUFG

        port (
                O : out STD_ULOGIC;
                I : in STD_ULOGIC
             );

    end component;


    component drm_aurora_GLOBAL_LOGIC

        port (

        -- GTX Interface

                CH_BOND_DONE       : in std_logic;
                EN_CHAN_SYNC       : out std_logic;

        -- Aurora Lane Interface

                LANE_UP            : in std_logic;
                SOFT_ERR         : in std_logic_vector(0 to 1);
                HARD_ERR         : in std_logic;
                CHANNEL_BOND_LOAD  : in std_logic;
                GOT_A              : in std_logic_vector(0 to 3);
                GOT_V              : in std_logic;
                GEN_A              : out std_logic;
                GEN_K              : out std_logic_vector(0 to 3);
                GEN_R              : out std_logic_vector(0 to 3);
                GEN_V              : out std_logic_vector(0 to 3);
                RESET_LANES        : out std_logic;

        -- System Interface

                USER_CLK           : in std_logic;
                RESET              : in std_logic;
                POWER_DOWN         : in std_logic;
                CHANNEL_UP         : out std_logic;
                START_RX           : out std_logic;
                CHANNEL_SOFT_ERR   : out std_logic;
                CHANNEL_HARD_ERR   : out std_logic

             );

    end component;


    component drm_aurora_TX_LL

        port (

        -- LocalLink PDU Interface

                TX_D           : in std_logic_vector(0 to 31);
                TX_REM         : in std_logic_vector(0 to 1);
                TX_SRC_RDY_N   : in std_logic;
                TX_SOF_N       : in std_logic;
                TX_EOF_N       : in std_logic;
                TX_DST_RDY_N   : out std_logic;

        -- Clock Compensation Interface

                WARN_CC        : in std_logic;
                DO_CC          : in std_logic;

        -- Global Logic Interface

                CHANNEL_UP     : in std_logic;

        -- Aurora Lane Interface

                GEN_SCP        : out std_logic;
                GEN_ECP        : out std_logic;
                TX_PE_DATA_V   : out std_logic_vector(0 to 1);
                GEN_PAD        : out std_logic_vector(0 to 1);
                TX_PE_DATA     : out std_logic_vector(0 to 31);
                GEN_CC         : out std_logic;

        -- System Interface

                USER_CLK       : in std_logic
             );

    end component;


    component drm_aurora_RX_LL

        port (

        -- LocalLink PDU Interface
                RX_D             : out std_logic_vector(0 to 31);
                RX_REM           : out std_logic_vector(0 to 1);
                RX_SRC_RDY_N     : out std_logic;
                RX_SOF_N         : out std_logic;
                RX_EOF_N         : out std_logic;

        -- Global Logic Interface

                START_RX         : in std_logic;

        -- Aurora Lane Interface

                RX_PAD           : in std_logic_vector(0 to 1);
                RX_PE_DATA       : in std_logic_vector(0 to 31);
                RX_PE_DATA_V     : in std_logic_vector(0 to 1);
                RX_SCP           : in std_logic_vector(0 to 1);
                RX_ECP           : in std_logic_vector(0 to 1);

        -- Error Interface

                FRAME_ERR      : out std_logic;

        -- System Interface

                USER_CLK         : in std_logic

             );

    end component;

-- Signal Declarations --

    signal TX1N_OUT_unused                 : std_logic;
    signal TX1P_OUT_unused                 : std_logic;
    signal RX1N_IN_unused                  : std_logic;
    signal RX1P_IN_unused                  : std_logic;
    signal rx_char_is_comma_i_unused       : std_logic_vector(3 downto 0);    
    signal rx_char_is_k_i_unused           : std_logic_vector(3 downto 0);
    signal rx_data_i_unused                : std_logic_vector(31 downto 0);
    signal rx_disp_err_i_unused            : std_logic_vector(3 downto 0);
    signal rx_not_in_table_i_unused        : std_logic_vector(3 downto 0);
    signal rx_realign_i_unused             : std_logic;
    signal ch_bond_done_i_unused           : std_logic;
    signal rx_buf_err_i_unused             : std_logic_vector(2 downto 0);    
    signal tx_buf_err_i_unused             : std_logic_vector(1 downto 0);    



   signal   ch_bond_done_i          :   std_logic;            
   signal   ch_bond_done_r1         :   std_logic;            
   signal   ch_bond_done_r2         :   std_logic;            
   signal   ch_bond_load_not_used_i :   std_logic;            
   signal   channel_up_i            :   std_logic;         
   signal   chbondi_not_used_i      :   std_logic_vector(4 downto 0);         
   signal   chbondo_not_used_i      :   std_logic_vector(4 downto 0);          
   signal   combus_in_not_used_i    :   std_logic_vector(15 downto 0);            
   signal   combusout_out_not_used_i:   std_logic_vector(15 downto 0);            
   signal   en_chan_sync_i          :   std_logic;         
   signal   ena_comma_align_i       :   std_logic;            

   signal   gen_a_i                 :   std_logic;            
   signal   gen_cc_i                :   std_logic;            
   signal   gen_ecp_i               :   std_logic;         
   signal   gen_ecp_striped_i       :   std_logic_vector(0 to 1);         
   signal   gen_k_i                 :   std_logic_vector(0 to 3);          
   signal   gen_pad_i               :   std_logic_vector(0 to 1);            
   signal   gen_pad_striped_i       :   std_logic_vector(0 to 1);          
   signal   gen_r_i                 :   std_logic_vector(0 to 3);          
   signal   gen_scp_i               :   std_logic;         
   signal   gen_scp_striped_i       :   std_logic_vector(0 to 1);         
   signal   gen_v_i                 :   std_logic_vector(0 to 3);          
   signal   got_a_i                 :   std_logic_vector(0 to 3);          
   signal   got_v_i                 :   std_logic;            
   signal   hard_err_i            :   std_logic;            
   signal   lane_up_i               :   std_logic;            
   signal   open_rx_char_is_comma_i :   std_logic_vector(3 downto 0);          
   signal   open_rx_char_is_k_i     :   std_logic_vector(3 downto 0);          
   signal   open_rx_comma_det_i     :   std_logic;            
   signal   open_rx_data_i          :   std_logic_vector(31 downto 0);         
   signal   open_rx_disp_err_i      :   std_logic_vector(3 downto 0);          
   signal   open_rx_loss_of_sync_i  :   std_logic_vector(1 downto 0);          
   signal   open_rx_not_in_table_i  :   std_logic_vector(3 downto 0);          
   signal   open_rx_rec1_clk_i      :   std_logic;            
   signal   open_rx_rec2_clk_i      :   std_logic;            
   signal   open_rx_run_disp_i      :   std_logic_vector(7 downto 0);          
   signal   open_tx_k_err_i         :   std_logic_vector(7 downto 0);          
   signal   open_tx_run_disp_i      :   std_logic_vector(7 downto 0);          
   signal   pma_rx_lock_i           :   std_logic;       
 
    signal raw_gtpclkout_i             :   std_logic_vector(1 downto 0);
   signal   reset_lanes_i           :   std_logic;            
   signal   rx_buf_err_i            :   std_logic;            
   signal   rx_char_is_comma_i      :   std_logic_vector(3 downto 0);          
   signal   rx_char_is_comma_gtx_i  :   std_logic_vector(7 downto 0);          
   signal   rx_char_is_k_i          :   std_logic_vector(3 downto 0);          
   signal   rx_char_is_k_gtx_i      :   std_logic_vector(7 downto 0);          
   signal   rx_data_i               :   std_logic_vector(31 downto 0);         
   signal   rx_data_gtx_i           :   std_logic_vector(63 downto 0);         
   signal   rx_disp_err_i           :   std_logic_vector(3 downto 0);          
   signal   rx_disp_err_gtx_i       :   std_logic_vector(7 downto 0);          
   signal   rx_ecp_i                :   std_logic_vector(0 to 1);            
   signal   rx_ecp_striped_i        :   std_logic_vector(0 to 1);          
   signal   rx_not_in_table_i       :   std_logic_vector(3 downto 0);          
   signal   rx_not_in_table_gtx_i   :   std_logic_vector(7 downto 0);          
   signal   rx_pad_i                :   std_logic_vector(0 to 1);            
   signal   rx_pad_striped_i        :   std_logic_vector(0 to 1);          
   signal   rx_pe_data_i            :   std_logic_vector(0 to 31);         
   signal   rx_pe_data_striped_i    :   std_logic_vector(0 to 31);         
   signal   rx_pe_data_v_i          :   std_logic_vector(0 to 1);            
   signal   rx_pe_data_v_striped_i  :   std_logic_vector(0 to 1);          
   signal   rx_polarity_i           :   std_logic;            
   signal   rx_realign_i            :   std_logic;            
   signal   rx_reset_i              :   std_logic;            
   signal   rx_scp_i                :   std_logic_vector(0 to 1);            
   signal   rx_scp_striped_i        :   std_logic_vector(0 to 1);          
   signal   rx_status_float_i       :   std_logic_vector(4 downto 0);            
   signal   soft_err_i            :   std_logic_vector(0 to 1);            
   signal   all_soft_err_i        :   std_logic;
   signal   start_rx_i              :   std_logic;         
   signal   tied_to_ground_i        :   std_logic;         
   signal   tied_to_ground_vec_i    :   std_logic_vector(31 downto 0);            
   signal   tied_to_vcc_i           :   std_logic;         
   signal   tx_buf_err_i            :   std_logic;            
   signal   tx_char_is_k_i          :   std_logic_vector(3 downto 0);          
   signal   tx_data_i               :   std_logic_vector(31 downto 0);         
    signal tx_lock_i                : std_logic;
   signal   tx_out_clk_i            :   std_logic;            
   signal   tx_pe_data_i            :   std_logic_vector(0 to 31);         
   signal   tx_pe_data_striped_i    :   std_logic_vector(0 to 31);         
   signal   tx_pe_data_v_i          :   std_logic_vector(0 to 1);            
   signal   tx_pe_data_v_striped_i  :   std_logic_vector(0 to 1);          
   signal   tx_reset_i              :   std_logic;            
   signal   ufc_tx_ms_i             :   std_logic_vector(0 to 3);         
    
    signal tied_to_gnd_vec_i        : std_logic_vector(0 to 31);
begin
-- Main Body of Code --

    -- Tie off top level constants.
    tied_to_gnd_vec_i    <= (others => '0');
    tied_to_ground_vec_i <= (others => '0');
    tied_to_ground_i     <= '0';
    tied_to_vcc_i        <= '1';


     all_soft_err_i        <= soft_err_i(0) or soft_err_i(1);
    chbondi_not_used_i   <= (others => '0');

    -- Connect top level logic.

    CHANNEL_UP           <= channel_up_i;
    GTPCLKOUT   <=   raw_gtpclkout_i(0);

    -- Connect TX_LOCK to tx_lock_i from lane 0
    TX_LOCK    <=  tx_lock_i;
    

    -- Instantiate Lane 0 --

    LANE_UP <= lane_up_i;

    -- Aurora lane striping rules require each 4-byte lane to carry 2 bytes
    -- from the first half of the overall word, and 2 bytes from the second
    -- half. This ensures that the data will be ordered correctly if it is
    -- sent to a 2-byte lane.  Here we perform the required concatenation.

    gen_scp_striped_i <= gen_scp_i & '0';
    gen_ecp_striped_i <= '0' & gen_ecp_i;
    gen_pad_striped_i(0 to 1) <= gen_pad_i(0) & gen_pad_i(1);
    tx_pe_data_striped_i(0 to 31) <= tx_pe_data_i(0 to 15) & tx_pe_data_i(16 to 31);
    tx_pe_data_v_striped_i(0 to 1) <= tx_pe_data_v_i(0) & tx_pe_data_v_i(1);
    rx_pad_i(0) <= rx_pad_striped_i(0);
    rx_pad_i(1) <= rx_pad_striped_i(1);
    rx_pe_data_i(0 to 15) <= rx_pe_data_striped_i(0 to 15);
    rx_pe_data_i(16 to 31) <= rx_pe_data_striped_i(16 to 31);
    rx_pe_data_v_i(0) <= rx_pe_data_v_striped_i(0);
    rx_pe_data_v_i(1) <= rx_pe_data_v_striped_i(1);
    rx_scp_i(0) <= rx_scp_striped_i(0);
    rx_scp_i(1) <= rx_scp_striped_i(1);
    rx_ecp_i(0) <= rx_ecp_striped_i(0);
    rx_ecp_i(1) <= rx_ecp_striped_i(1);


    drm_aurora_aurora_lane_4byte_0_i : drm_aurora_AURORA_LANE_4BYTE

        port map (

        -- GTX Interface

                    RX_DATA             => rx_data_i(31 downto 0),
                    RX_NOT_IN_TABLE     => rx_not_in_table_i(3 downto 0),
                    RX_DISP_ERR         => rx_disp_err_i(3 downto 0),
                    RX_CHAR_IS_K        => rx_char_is_k_i(3 downto 0),
                    RX_CHAR_IS_COMMA    => rx_char_is_comma_i(3 downto 0),
                    RX_STATUS           => tied_to_ground_vec_i(5 downto 0),
                    TX_BUF_ERR          => tx_buf_err_i,
                    RX_BUF_ERR          => rx_buf_err_i,
                    RX_REALIGN          => rx_realign_i,
                    RX_POLARITY         => rx_polarity_i,
                    RX_RESET            => rx_reset_i,
                    TX_CHAR_IS_K        => tx_char_is_k_i(3 downto 0),
                    TX_DATA             => tx_data_i(31 downto 0),
                    TX_RESET            => tx_reset_i,

        -- Comma Detect Phase Align Interface

                    ENA_COMMA_ALIGN     => ena_comma_align_i,

        -- TX_LL Interface
                    GEN_SCP             => gen_scp_striped_i,
                    GEN_ECP             => gen_ecp_striped_i,
                    GEN_PAD             => gen_pad_striped_i(0 to 1),
                    TX_PE_DATA          => tx_pe_data_striped_i(0 to 31),
                    TX_PE_DATA_V        => tx_pe_data_v_striped_i(0 to 1),
                    GEN_CC              => gen_cc_i,

        -- RX_LL Interface

                    RX_PAD              => rx_pad_striped_i(0 to 1),
                    RX_PE_DATA          => rx_pe_data_striped_i(0 to 31),
                    RX_PE_DATA_V        => rx_pe_data_v_striped_i(0 to 1),
                    RX_SCP              => rx_scp_striped_i(0 to 1),
                    RX_ECP              => rx_ecp_striped_i(0 to 1),

        -- Global Logic Interface

                    GEN_A               => gen_a_i,
                    GEN_K               => gen_k_i(0 to 3),
                    GEN_R               => gen_r_i(0 to 3),
                    GEN_V               => gen_v_i(0 to 3),
                    LANE_UP             => lane_up_i,
                    SOFT_ERR          => soft_err_i(0 to 1),
                    HARD_ERR          => hard_err_i,
                    CHANNEL_BOND_LOAD   => ch_bond_load_not_used_i,
                    GOT_A               => got_a_i(0 to 3),
                    GOT_V               => got_v_i,

        -- System Interface

                    USER_CLK            => USER_CLK,
                    RESET_SYMGEN        => RESET,
                    RESET               => reset_lanes_i

                 );




    -- Instantiate GTP Wrapper --
    gtp_wrapper_i  :  drm_aurora_GTP_WRAPPER
        generic map
        (
            SIM_GTPRESET_SPEEDUP  => SIM_GTPRESET_SPEEDUP
        )
        port map
        (
        -- Aurora Lane Interface

                    RXPOLARITY_IN           => rx_polarity_i,
                    RXRESET_IN              => rx_reset_i,
                    TXCHARISK_IN            => tx_char_is_k_i(3 downto 0),
                    TXDATA_IN               => tx_data_i(31 downto 0),
                    TXRESET_IN              => tx_reset_i,
                    RXDATA_OUT              => rx_data_i(31 downto 0),
                    RXNOTINTABLE_OUT        => rx_not_in_table_i(3 downto 0),
                    RXDISPERR_OUT           => rx_disp_err_i(3 downto 0),
                    RXCHARISK_OUT           => rx_char_is_k_i(3 downto 0),
                    RXCHARISCOMMA_OUT       => rx_char_is_comma_i(3 downto 0),
                    TXBUFERR_OUT            => tx_buf_err_i,
                    RXBUFERR_OUT            => rx_buf_err_i,
                    RXREALIGN_OUT           => rx_realign_i,
                    
                    TXDIFFCTRL0_IN          => TX_DIFF_CTRL,
                    TXPREEMPHASIS0_IN       => TX_PREEMPHASIS,

        -- Phase Align Interface

                    ENMCOMMAALIGN_IN        => ena_comma_align_i,
                    ENPCOMMAALIGN_IN        => ena_comma_align_i,
                    RXRECCLK1_OUT           => open_rx_rec1_clk_i,                      RXRECCLK2_OUT           => open_rx_rec2_clk_i,          -- Global Logic Interface

                    ENCHANSYNC_IN           => en_chan_sync_i,
                    CHBONDDONE_OUT          => ch_bond_done_i,

        -- Serial IO
        RXEQMIX_IN     => RXEQMIX_IN,
        DADDR_IN       => DADDR_IN,
        DCLK_IN        => DCLK_IN,
        DEN_IN         => DEN_IN,
        DI_IN          => DI_IN,
        DRDY_OUT       => DRDY_OUT,
        DRPDO_OUT      => DRPDO_OUT,
        DWE_IN         => DWE_IN,
                    RX1N_IN                => RXN,
                    RX1P_IN                => RXP,
                    TX1N_OUT               => TXN,
                    TX1P_OUT               => TXP,


        -- Reference Clocks and User Clock

                    RXUSRCLK_IN                                       => SYNC_CLK,
                    RXUSRCLK2_IN                                      => USER_CLK,
                    TXUSRCLK_IN                                       => SYNC_CLK,
                    TXUSRCLK2_IN                                      => USER_CLK,
                    REFCLK                                            => GTPD0,

                    GTPCLKOUT_OUT => raw_gtpclkout_i,
                    PLLLKDET_OUT            => tx_lock_i,       

        -- System Interface

                    GTPRESET_IN                                      => GT_RESET,  
                    LOOPBACK_IN                                      => LOOPBACK,



		    RXCHARISCOMMA_OUT_unused => rx_char_is_comma_i_unused(3 downto 0),
		    RXCHARISK_OUT_unused     => rx_char_is_k_i_unused(3 downto 0),
    		    RXDISPERR_OUT_unused     => rx_disp_err_i_unused(3 downto 0),
    		    RXNOTINTABLE_OUT_unused  => rx_not_in_table_i_unused(3 downto 0),
----------------- Receive Ports - Channel Bonding Ports -----------------
   		    RXREALIGN_OUT_unused     => rx_realign_i_unused,
   		    RXDATA_OUT_unused        => rx_data_i_unused(31 downto 0),
   		    RX1N_IN_unused           => RX1N_IN_unused,
   		    RX1P_IN_unused           => RX1P_IN_unused,
    		    RXBUFERR_OUT_unused      => rx_buf_err_i_unused,
   		    TXBUFERR_OUT_unused      => tx_buf_err_i_unused,
   		    CHBONDDONE_OUT_unused    => ch_bond_done_i_unused,
  		    TX1N_OUT_unused          => TX1N_OUT_unused,
   		    TX1P_OUT_unused          => TX1P_OUT_unused,



                    POWERDOWN_IN                                     => POWER_DOWN
                 );        
        
    -- Instantiate Global Logic to combine Lanes into a Channel --

    drm_aurora_global_logic_i : drm_aurora_GLOBAL_LOGIC
        port map (
        -- GTX Interface

                    CH_BOND_DONE            => ch_bond_done_i,
                    EN_CHAN_SYNC            => en_chan_sync_i,

        -- Aurora Lane Interface

                    LANE_UP                 => lane_up_i,
                    SOFT_ERR              => soft_err_i,
                    HARD_ERR              => hard_err_i,
                    CHANNEL_BOND_LOAD       => ch_bond_done_i,
                    GOT_A                   => got_a_i,
                    GOT_V                   => got_v_i,
                    GEN_A                   => gen_a_i,
                    GEN_K                   => gen_k_i,
                    GEN_R                   => gen_r_i,
                    GEN_V                   => gen_v_i,
                    RESET_LANES             => reset_lanes_i,

        -- System Interface

                    USER_CLK                => USER_CLK,
                    RESET                   => RESET,
                    POWER_DOWN              => POWER_DOWN,
                    CHANNEL_UP              => channel_up_i,
                    START_RX                => start_rx_i,
                    CHANNEL_SOFT_ERR      => SOFT_ERR,
                    CHANNEL_HARD_ERR      => HARD_ERR
                 );


    -- Instantiate TX_LL --

    drm_aurora_tx_ll_i : drm_aurora_TX_LL
        port map (
        -- LocalLink PDU Interface

                    TX_D                    => TX_D,
                    TX_REM                  => TX_REM,
                    TX_SRC_RDY_N            => TX_SRC_RDY_N,
                    TX_SOF_N                => TX_SOF_N,
                    TX_EOF_N                => TX_EOF_N,
                    TX_DST_RDY_N            => TX_DST_RDY_N,

        -- Clock Compenstaion Interface

                    WARN_CC                 => WARN_CC,
                    DO_CC                   => DO_CC,

        -- Global Logic Interface

                    CHANNEL_UP              => channel_up_i,

        -- Aurora Lane Interface

                    GEN_SCP                 => gen_scp_i,
                    GEN_ECP                 => gen_ecp_i,
                    TX_PE_DATA_V            => tx_pe_data_v_i,
                    GEN_PAD                 => gen_pad_i,
                    TX_PE_DATA              => tx_pe_data_i,
                    GEN_CC                  => gen_cc_i,

        -- System Interface

                    USER_CLK                => USER_CLK
                 );


    -- Instantiate RX_LL --

   drm_aurora_rx_ll_i : drm_aurora_RX_LL
        port map (
        -- LocalLink PDU Interface

                    RX_D                    => RX_D,
                    RX_REM                  => RX_REM,
                    RX_SRC_RDY_N            => RX_SRC_RDY_N,
                    RX_SOF_N                => RX_SOF_N,
                    RX_EOF_N                => RX_EOF_N,

        -- Global Logic Interface

                    START_RX                => start_rx_i,

        -- Aurora Lane Interface

                    RX_PAD                  => rx_pad_i,
                    RX_PE_DATA              => rx_pe_data_i,
                    RX_PE_DATA_V            => rx_pe_data_v_i,
                    RX_SCP                  => rx_scp_i,
                    RX_ECP                  => rx_ecp_i,

        -- Error Interface

                    FRAME_ERR             => FRAME_ERR,

        -- System Interface

                    USER_CLK                => USER_CLK
                 );
end MAPPED;
