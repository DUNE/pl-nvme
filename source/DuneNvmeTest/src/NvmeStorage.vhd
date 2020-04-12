--------------------------------------------------------------------------------
--	NvmeStorage.vhd Nvme storage access module
--	T.Barnaby, Beam Ltd. 2020-02-28
-------------------------------------------------------------------------------
--!
--! @class	NvmeStorage
--! @author	Terry Barnaby (terry.barnaby@beam.ltd.uk)
--! @date	2020-02-28
--! @version	0.0.1
--!
--! @brief
--! This is a simple NvmeStorage module that just provides access to the NVMe device
--! over the Axis request/reply streams. It is used for NVMe protocol experimentation
--! and testing from a host software program.
--!
--! @details
--! Communication is performed over the Axis request/reply streams. It is used for NVMe protocol experimentation
--! and testing from a host software program.
--! It also implements a few local registers to allow testing of the Axi lite bus interface.
--!
--! @copyright GNU GPL License
--! Copyright (c) Beam Ltd, All rights reserved. <br>
--! This code is free software: you can redistribute it and/or modify
--! it under the terms of the GNU General Public License as published by
--! the Free Software Foundation, either version 3 of the License, or
--! (at your option) any later version.
--! This program is distributed in the hope that it will be useful,
--! but WITHOUT ANY WARRANTY; without even the implied warranty of
--! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--! GNU General Public License for more details. <br>
--! You should have received a copy of the GNU General Public License
--! along with this code. If not, see <https://www.gnu.org/licenses/>.
--!
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library work;
use work.AxiPkg.all;

entity NvmeStorage is
generic(
	Simulate	: boolean	:= False;
	Divider		: integer	:= 5000000
);
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line

	-- Control and status interface
	axilIn		: in AxilToSlave;			--! Axil bus input signals
	axilOut		: out AxilToMaster;			--! Axil bus output signals

	-- From host to NVMe request/reply streams
	hostSend	: inout AxisStream := AxisInput;	--! Host request stream
	hostRecv	: inout AxisStream := AxisOutput;	--! Host reply stream

	-- AXIS data stream input
	--dataRx	: inout AxisStream	:= AxisInput;	--! Raw data to save stream

	-- NVMe interface
	nvme_clk_p	: in std_logic;				--! Nvme external clock +ve
	nvme_clk_n	: in std_logic;				--! Nvme external clock -ve
	nvme_reset_n	: out std_logic;			--! Nvme reset output to reset NVMe devices
	nvme0_exp_txp	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX plus lanes
	nvme0_exp_txn	: out std_logic_vector(3 downto 0);	--! Nvme0 PCIe TX minus lanes
	nvme0_exp_rxp	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX plus lanes
	nvme0_exp_rxn	: in std_logic_vector(3 downto 0);	--! Nvme0 PCIe RX minus lanes

	-- Debug
	leds		: out std_logic_vector(3 downto 0)
);
end;

architecture Behavioral of NvmeStorage is

component AxilClockConverter is
generic(
	Simulate	: boolean	:= Simulate
);
port (
	clk0		: in std_logic;
	reset0		: in std_logic;

	-- Bus0
	axil0In		: in AxilToSlave;
	axil0Out	: out AxilToMaster;

	clk1		: in std_logic;
	reset1		: in std_logic;

	-- Bus1
	axil1Out	: out AxilToSlave;
	axil1In		: in AxilToMaster
);
end component;

component AxisClockConverter is
generic(
	Simulate	: boolean	:= Simulate
);
port (
	clkRx		: in std_logic;
	resetRx		: in std_logic;
	streamRx	: inout AxisStream := AxisInput;                        

	clkTx		: in std_logic;
	resetTx		: in std_logic;
	streamTx	: inout AxisStream := AxisOutput
);
end component;

component Pcie_nvme0
	port (
	pci_exp_txn : out std_logic_vector(3 downto 0);
	pci_exp_txp : out std_logic_vector(3 downto 0);
	pci_exp_rxn : in std_logic_vector(3 downto 0);
	pci_exp_rxp : in std_logic_vector(3 downto 0);
	user_clk : out std_logic;
	user_reset : out std_logic;
	user_lnk_up : out std_logic;
	s_axis_rq_tdata : in std_logic_vector(127 downto 0);
	s_axis_rq_tkeep : in std_logic_vector(3 downto 0);
	s_axis_rq_tlast : in std_logic;
	s_axis_rq_tready : out std_logic_vector(3 downto 0);
	s_axis_rq_tuser : in std_logic_vector(59 downto 0);
	s_axis_rq_tvalid : in std_logic;
	
	m_axis_rc_tdata : out std_logic_vector(127 downto 0);
	m_axis_rc_tkeep : out std_logic_vector(3 downto 0);
	m_axis_rc_tlast : out std_logic;
	m_axis_rc_tready : in std_logic;
	m_axis_rc_tuser : out std_logic_vector(74 downto 0);
	m_axis_rc_tvalid : out std_logic;
	
	m_axis_cq_tdata : out std_logic_vector(127 downto 0);
	m_axis_cq_tkeep : out std_logic_vector(3 downto 0);
	m_axis_cq_tlast : out std_logic;
	m_axis_cq_tready : in std_logic;
	m_axis_cq_tuser : out std_logic_vector(84 downto 0);
	m_axis_cq_tvalid : out std_logic;
	
	s_axis_cc_tdata : in std_logic_vector(127 downto 0);
	s_axis_cc_tkeep : in std_logic_vector(3 downto 0);
	s_axis_cc_tlast : in std_logic;
	s_axis_cc_tready : out std_logic_vector(3 downto 0);
	s_axis_cc_tuser : in std_logic_vector(32 downto 0);
	s_axis_cc_tvalid : in std_logic;
	pcie_rq_seq_num : out std_logic_vector(3 downto 0);
	pcie_rq_seq_num_vld : out std_logic;
	pcie_rq_tag : out std_logic_vector(5 downto 0);
	pcie_rq_tag_av : out std_logic_vector(1 downto 0);
	pcie_rq_tag_vld : out std_logic;
	pcie_tfc_nph_av : out std_logic_vector(1 downto 0);
	pcie_tfc_npd_av : out std_logic_vector(1 downto 0);
	pcie_cq_np_req : in std_logic;
	pcie_cq_np_req_count : out std_logic_vector(5 downto 0);

	cfg_phy_link_down : out std_logic;
	cfg_phy_link_status : out std_logic_vector(1 downto 0);
	cfg_negotiated_width : out std_logic_vector(3 downto 0);
	cfg_current_speed : out std_logic_vector(2 downto 0);
	cfg_max_payload : out std_logic_vector(2 downto 0);
	cfg_max_read_req : out std_logic_vector(2 downto 0);
	cfg_function_status : out std_logic_vector(15 downto 0);
	cfg_function_power_state : out std_logic_vector(11 downto 0);
	cfg_vf_status : out std_logic_vector(15 downto 0);
	cfg_vf_power_state : out std_logic_vector(23 downto 0);
	cfg_link_power_state : out std_logic_vector(1 downto 0);

	cfg_mgmt_addr : in std_logic_vector(18 downto 0);
	cfg_mgmt_write : in std_logic;
	cfg_mgmt_write_data : in std_logic_vector(31 downto 0);
	cfg_mgmt_byte_enable : in std_logic_vector(3 downto 0);
	cfg_mgmt_read : in std_logic;
	cfg_mgmt_read_data : out std_logic_vector(31 downto 0);
	cfg_mgmt_read_write_done : out std_logic;
	cfg_mgmt_type1_cfg_reg_access : in std_logic;

	cfg_err_cor_out : out std_logic;
	cfg_err_nonfatal_out : out std_logic;
	cfg_err_fatal_out : out std_logic;
	cfg_ltr_enable : out std_logic;
	cfg_ltssm_state : out std_logic_vector(5 downto 0);
	cfg_rcb_status : out std_logic_vector(3 downto 0);
	cfg_dpa_substate_change : out std_logic_vector(3 downto 0);
	cfg_obff_enable : out std_logic_vector(1 downto 0);
	cfg_pl_status_change : out std_logic;
	cfg_tph_requester_enable : out std_logic_vector(3 downto 0);
	cfg_tph_st_mode : out std_logic_vector(11 downto 0);
	cfg_vf_tph_requester_enable : out std_logic_vector(7 downto 0);
	cfg_vf_tph_st_mode : out std_logic_vector(23 downto 0);
	cfg_fc_ph : out std_logic_vector(7 downto 0);
	cfg_fc_pd : out std_logic_vector(11 downto 0);
	cfg_fc_nph : out std_logic_vector(7 downto 0);
	cfg_fc_npd : out std_logic_vector(11 downto 0);
	cfg_fc_cplh : out std_logic_vector(7 downto 0);
	cfg_fc_cpld : out std_logic_vector(11 downto 0);
	cfg_fc_sel : in std_logic_vector(2 downto 0);

	cfg_interrupt_int : in std_logic_vector(3 downto 0);
	cfg_interrupt_pending : in std_logic_vector(3 downto 0);
	cfg_interrupt_sent : out std_logic;

	sys_clk : in std_logic;
	sys_clk_gt : in std_logic;
	sys_reset : in std_logic;
	phy_rdy_out : out std_logic
	);
end component;

component AxisStreamMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn1	: inout AxisStream := AxisInput;	--! Input data stream
	streamIn2	: inout AxisStream := AxisInput;	--! Input data stream

	streamOut	: inout AxisStream := AxisOutput	--! Output data stream
);
end component;

component AxisStreamDeMux is
port (
	clk		: in std_logic;				--! The interface clock line
	reset		: in std_logic;				--! The active high reset line
	
	streamIn	: inout AxisStream := AxisInput;	--! Input data stream

	streamOut1	: inout AxisStream := AxisOutput;	--! Output data stream1
	streamOut2	: inout AxisStream := AxisOutput	--! Output data stream2
);
end component;

component NvmeSim is
generic(
	Simulate	: boolean	:= True
);
port (
	clk		: in std_logic;
	reset		: in std_logic;

	-- AXIS Interface to PCIE
	hostReq		: inout AxisStream := AxisInput;
	hostReply	: inout AxisStream := AxisOutput;                        
	
	-- From Nvme reqeuest and reply stream
	nvmeReq		: inout AxisStream := AxisOutput;
	nvmeReply	: inout AxisStream := AxisInput
);
end component;

constant TCQ			: time := 1 ns;

signal axil1Out			: AxilToMaster;
signal axil1In			: AxilToSlave;

signal hostSend1		: AxisStream;
signal hostRecv1		: AxisStream;

signal hostReq			: AxisStream;
signal hostReq_ready		: std_logic_vector(3 downto 0);
signal hostReq_morethan1	: std_logic;
signal hostReq_user		: std_logic_vector(59 downto 0);
signal hostReq_keep		: std_logic_vector(3 downto 0);

signal hostReply		: AxisStream;
signal hostReply_keep		: std_logic_vector(3 downto 0);

signal nvmeReq			: AxisStream;
signal nvmeReq_keep		: std_logic_vector(3 downto 0);

signal nvmeReply		: AxisStream;
signal nvmeReply_ready		: std_logic_vector(3 downto 0);
signal nvmeReply_user		: std_logic_vector(32 downto 0);
signal nvmeReply_keep		: std_logic_vector(3 downto 0);

-- Register interface
constant RegWidth		: integer := 32;
subtype RegDataType		is std_logic_vector(RegWidth-1 downto 0);

type StateType is (STATE_START, STATE_IDLE, STATE_WRITE, STATE_READ1, STATE_READ2);
signal state			: StateType := STATE_START;

signal address			: std_logic_vector(3 downto 0);
signal reg_id			: RegDataType := x"56010200";
signal reg_control		: RegDataType := (others => '0');
signal reg_status		: RegDataType := (others => '0');
signal reg_test1		: RegDataType := (others => '0');
signal reg_test2		: RegDataType := (others => '0');
signal reg_test3		: RegDataType := (others => '0');
signal reg_test4		: RegDataType := (others => '0');
signal reg_test5		: RegDataType := (others => '0');

-- Pcie_nvme signals
signal nvme_clk			: std_logic := 'U';
signal nvme_clk_gt		: std_logic := 'U';
signal nvme_reset_local_n	: std_logic := '0';
signal nvme_user_clk		: std_logic := 'U';
signal nvme_user_reset		: std_logic := 'U';

signal cfg_mgmt_addr			: std_logic_vector(18 downto 0);
signal cfg_mgmt_write			: std_logic;
signal cfg_mgmt_write_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_read			: std_logic;
signal cfg_mgmt_read_data		: std_logic_vector(31 downto 0);
signal cfg_mgmt_read_write_done		: std_logic;
signal cfg_mgmt_type1_cfg_reg_access	: std_logic;

signal counter	: std_logic_vector(7 downto 0)  := (others => 'U');

begin
	-- AXI Lite bus clock domain crossing
	axilClockConverter0 : AxilClockConverter
	port map (
		clk0		=> clk,
		reset0		=> reset,

		-- Bus0
		axil0In		=> axilIn,
		axil0Out	=> axilOut,

		--clk1		=> nvme_user_clk,
		--reset1	=> nvme_user_reset,
		clk1		=> clk,
		reset1		=> reset,

		-- Bus1
		axil1In		=> axil1Out,
		axil1Out	=> axil1In
	);

	axisClockConverter0 :  AxisClockConverter
	port map (
		clkRx		=> clk,
		resetRx		=> reset,
		streamRx	=> hostSend,

		clkTx		=> nvme_user_clk,
		resetTx		=> nvme_user_reset,
		streamTx	=> hostSend1
	);

	axisClockConverter1 :  AxisClockConverter
	port map (
		clkRx		=> nvme_user_clk,
		resetRx		=> nvme_user_reset,
		streamRx	=> hostRecv1,

		clkTx		=> clk,
		resetTx		=> reset,
		streamTx	=> hostRecv
	);

	-- Register access
	axil1Out.rdata <=	reg_id when address = "0000" else
				reg_control when address = "0001" else
				reg_status when address = "0010" else
				reg_test1 when address = "0011" else
				reg_test2 when address = "0100" else
				reg_test3 when address = "0101" else
				reg_test4 when address = "0110" else
				reg_test5 when address = "0111" else
				x"FFFFFFFF";
		
	-- Always return OK to read and write requests
	axil1Out.rresp <= "00";
	axil1Out.bresp <= "00";
	axil1Out.bvalid <= '1';

	-- Process register access
	process(clk)
	begin
		if(rising_edge(clk)) then
			if(reset = '1') then
				reg_control	<= (others => '0');
				reg_test1	<= (others => '0');
				reg_test2	<= (others => '0');
				reg_test3	<= (others => '0');
				reg_test4	<= (others => '0');
				reg_test5	<= (others => '0');
				axil1Out.arready	<= '0';
				axil1Out.rvalid	<= '0';
				axil1Out.awready	<= '0';
				axil1Out.wready	<= '0';
				state		<= STATE_IDLE;
			else
				case(state) is
				when STATE_START =>
					axil1Out.arready	<= '0';
					axil1Out.rvalid		<= '0';
					axil1Out.awready	<= '0';
					axil1Out.wready		<= '0';
					state			<= STATE_IDLE;

				when STATE_IDLE =>
					if(axil1In.awvalid= '1') then
						address			<= axil1In.awaddr(5 downto 2);
						axil1Out.awready	<= '1';
						state			<= STATE_WRITE;

					elsif(axil1In.arvalid= '1') then
						address			<= axil1In.araddr(5 downto 2);
						axil1Out.arready	<= '1';
						state			<= STATE_READ1;
					end if;

				when STATE_WRITE =>
					axil1Out.awready	<= '0';

					if(axil1In.wvalid = '1') then
						if(address = "0001") then
							reg_control <= axil1In.wdata;
							axil1Out.wready	<= '1';
						end if;

						state	<= STATE_START;
					end if;

				when STATE_READ1 =>
					axil1Out.arready	<= '0';
					axil1Out.rvalid		<= '1';
					state			<= STATE_READ2;

				when STATE_READ2 =>
					if(axil1In.rready = '1') then
						axil1Out.rvalid	<= '0';
						state		<= STATE_START;
					end if;
				end case;
				
				if((hostReq.last = '1') and (hostReq.valid = '1') and (hostReq.ready = '1')) then
					reg_test1(15 downto 0) <= hostReq.keep;
					--reg_test2 <= reg_test2 + 1;
				end if;

				if((hostReply.last = '1') and (hostReply.valid = '1') and (hostReply.ready = '1')) then
					--reg_test1(15 downto 0) <= hostReply.keep;
					--reg_test3 <= reg_test3 + 1;
				end if;
				
				if((nvmeReq.last = '1') and (nvmeReq.valid = '1') and (nvmeReq.ready = '1')) then
					reg_test2 <= reg_test2 + 1;
				end if;
				if((nvmeReq.last = '1') and (nvmeReq.valid = '1')) then
					reg_test5 <= reg_test5 + 1;
				end if;
				if((nvmeReply.last = '1') and (nvmeReply.valid = '1') and (nvmeReply.ready = '1')) then
					reg_test4(15 downto 0) <= nvmeReply.keep;
					reg_test3 <= reg_test3 + 1;
				end if;

			end if;
		end if;
	end process; 


	sim: if (Simulate = True) generate
	nvme_user_clk	<= clk;
	nvme_user_reset	<= reset;

	nvmeSim0 : NvmeSim
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		hostReq		=> hostReq,
		hostReply	=> hostReply,

		nvmeReq		=> nvmeReq,
		nvmeReply	=> nvmeReply
	);
	end generate;
	
	synth: if (Simulate = False) generate
	nvme_reset_local_n <= not reset;
	nvme_reset_n <= nvme_reset_local_n;
	
	-- NVME PCIE Clock, 100MHz
	nvme_clk_buf0 : IBUFDS_GTE3
	port map (
		I       => nvme_clk_p,
		IB      => nvme_clk_n,
		O       => nvme_clk_gt,
		ODIV2   => nvme_clk,
		CEB     => '0'
	);
	
	-- The PCIe to NVMe interface
	pcie_nvme0_0 : Pcie_nvme0
	port map (
		sys_clk			=> nvme_clk,
		sys_clk_gt		=> nvme_clk_gt,
		sys_reset		=> nvme_reset_local_n,
		phy_rdy_out		=> leds(0),

		pci_exp_txn		=> nvme0_exp_txn,
		pci_exp_txp		=> nvme0_exp_txp,
		pci_exp_rxn		=> nvme0_exp_rxn,
		pci_exp_rxp		=> nvme0_exp_rxp,

		user_clk		=> nvme_user_clk,
		user_reset		=> nvme_user_reset,
		user_lnk_up		=> leds(1),

		s_axis_rq_tdata		=> hostReq.data,
		--s_axis_rq_tkeep	=> hostReq.keep(1 downto 0),
		s_axis_rq_tkeep		=> hostReq_keep,
		s_axis_rq_tlast		=> hostReq.last,
		s_axis_rq_tready	=> hostReq_ready,
		s_axis_rq_tuser		=> hostReq_user,
		s_axis_rq_tvalid	=> hostReq.valid,
		
		m_axis_rc_tdata		=> hostReply.data,
		m_axis_rc_tkeep		=> hostReply_keep,
		m_axis_rc_tlast		=> hostReply.last,
		m_axis_rc_tready	=> hostReply.ready,
		--m_axis_rc_tuser	=> hostReply_user,
		m_axis_rc_tvalid	=> hostReply.valid,
		
		m_axis_cq_tdata		=> nvmeReq.data,
		m_axis_cq_tkeep		=> nvmeReq_keep,
		m_axis_cq_tlast		=> nvmeReq.last,
		m_axis_cq_tready	=> nvmeReq.ready,
		--m_axis_cq_tuser	=> nvmeReq_user,
		m_axis_cq_tvalid	=> nvmeReq.valid,
		
		s_axis_cc_tdata		=> nvmeReply.data,
		s_axis_cc_tkeep		=> nvmeReply_keep,
		s_axis_cc_tlast		=> nvmeReply.last,
		s_axis_cc_tready	=> nvmeReply_ready,
		s_axis_cc_tuser		=> nvmeReply_user,
		s_axis_cc_tvalid	=> nvmeReply.valid,

		--pcie_rq_seq_num		=> pcie_rq_seq_num,
		--pcie_rq_seq_num_vld		=> pcie_rq_seq_num_vld,
		--pcie_rq_tag			=> pcie_rq_tag,
		--pcie_rq_tag_av		=> pcie_rq_tag_av,
		--pcie_rq_tag_vld		=> pcie_rq_tag_vld,
		--pcie_tfc_nph_av		=> pcie_tfc_nph_av,
		--pcie_tfc_npd_av		=> pcie_tfc_npd_av,
		pcie_cq_np_req			=> '1',					-- ?
		--pcie_cq_np_req_count		=> pcie_cq_np_req_count,

		--cfg_phy_link_down		=> --cfg_phy_link_down,
		--cfg_phy_link_status		=> --cfg_phy_link_status,
		--cfg_negotiated_width		=> --cfg_negotiated_width,
		--cfg_current_speed		=> --cfg_current_speed,
		--cfg_max_payload		=> --cfg_max_payload,
		--cfg_max_read_req		=> --cfg_max_read_req,
		--cfg_function_status		=> --cfg_function_status,
		--cfg_function_power_state	=> --cfg_function_power_state,
		--cfg_vf_status			=> --cfg_vf_status,
		--cfg_vf_power_state		=> --cfg_vf_power_state,
		--cfg_link_power_state		=> --cfg_link_power_state,

		cfg_mgmt_addr			=> cfg_mgmt_addr,
		cfg_mgmt_write			=> cfg_mgmt_write,
		cfg_mgmt_write_data		=> cfg_mgmt_write_data,
		cfg_mgmt_byte_enable		=> "1111",
		cfg_mgmt_read			=> cfg_mgmt_read,
		cfg_mgmt_read_data		=> cfg_mgmt_read_data,
		cfg_mgmt_read_write_done	=> cfg_mgmt_read_write_done,
		cfg_mgmt_type1_cfg_reg_access	=> cfg_mgmt_type1_cfg_reg_access,

		--cfg_err_cor_out		=> --cfg_err_cor_out,
		--cfg_err_nonfatal_out		=> --cfg_err_nonfatal_out,
		--cfg_err_fatal_out		=> --cfg_err_fatal_out,
		--cfg_local_error		=> --cfg_local_error,
		--cfg_ltr_enable		=> --cfg_ltr_enable,
		--cfg_ltssm_state		=> --cfg_ltssm_state,
		--cfg_rcb_status		=> --cfg_rcb_status,
		--cfg_dpa_substate_change	=> --cfg_dpa_substate_change,
		--cfg_obff_enable		=> --cfg_obff_enable,
		--cfg_pl_status_change		=> --cfg_pl_status_change,
		--cfg_tph_requester_enable	=> --cfg_tph_requester_enable,
		--cfg_tph_st_mode		=> --cfg_tph_st_mode,
		--cfg_vf_tph_requester_enable	=> --cfg_vf_tph_requester_enable,
		--cfg_vf_tph_st_mode		=> --cfg_vf_tph_st_mode,
		--cfg_fc_ph			=> --cfg_fc_ph,
		--cfg_fc_pd			=> --cfg_fc_pd,
		--cfg_fc_nph			=> --cfg_fc_nph,
		--cfg_fc_npd			=> --cfg_fc_npd,
		--cfg_fc_cplh			=> --cfg_fc_cplh,
		--cfg_fc_cpld			=> --cfg_fc_cpld,
		cfg_fc_sel			=> "000",				-- ?


		cfg_interrupt_int			=> "0000",			-- ?
		cfg_interrupt_pending			=> "0000"
		--cfg_interrupt_sent			=> --cfg_interrupt_sent,
	);

	-- Interface between Axis streams and PCIe Gen3 streams
	hostReq.ready <= hostReq_ready(0);

	-- The last_be bits in hostReq_user should be 0 when reading/writing less than 2 words due to the daft PCIe Gen3 core.
	-- This code peeks at the PCIe TLP headers numDwords field and sets the be bits appropriately. Only valid in the first
	-- beat of the 128bit wide data stream packet.
	-- Warning: This may not be valid for message and atomic packets.
	--hostReq_morethan1 <= reg_control(31);
	hostReq_morethan1 <= '1' when(unsigned(hostReq.data(74 downto 64)) > 1) else '0';
	hostReq_user <= x"00000000" & "0000" & "00000000" & "0" & "00" & "0" & "0" & "000" & "1111" & "1111" when(hostReq_morethan1 = '1')
		else x"00000000" & "0000" & "00000000" & "0" & "00" & "0" & "0" & "000" & "0000" & "1111";

	hostReq_keep <= hostReq.keep(12) & hostReq.keep(8) & hostReq.keep(4) & hostReq.keep(0);	-- Indicate which words are present

	hostReply.keep <= concat(hostReply_keep(3), 4) & concat(hostReply_keep(2), 4) & concat(hostReply_keep(1), 4) & concat(hostReply_keep(0), 4);
	
	nvmeReq.keep <= concat(nvmeReq_keep(3), 4) & concat(nvmeReq_keep(2), 4) & concat(nvmeReq_keep(1), 4) & concat(nvmeReq_keep(0), 4);

	nvmeReply.ready <= nvmeReply_ready(0) and nvmeReply_ready(1) and nvmeReply_ready(2) and nvmeReply_ready(3);
	nvmeReply_user <= (others => '0');
	nvmeReply_keep <= nvmeReply.keep(12) & nvmeReply.keep(8) & nvmeReply.keep(4) & nvmeReply.keep(0);	-- Indicate which words are present
	
	cfg_mgmt_addr <= (others => '0');
	cfg_mgmt_write <= '0';
	cfg_mgmt_write_data <= (others => '0');
	cfg_mgmt_read <= '0';
	cfg_mgmt_type1_cfg_reg_access <= '0';
	

	leds(2) <= '0';
	leds(3) <= '0';
	
	end generate;
	
	-- Host to Nvme stream DeMux
	axisDeMux0 : AxisStreamDeMux
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		streamIn	=> hostSend1,

		streamOut1	=> hostReq,
		streamOut2	=> nvmeReply
	);

	-- Nvme to Host stream Mux
	axisMux0 : AxisStreamMux
	port map (
		clk		=> nvme_user_clk,
		reset		=> nvme_user_reset,

		streamIn1	=> hostReply,
		streamIn2	=> nvmeReq,

		streamOut	=> hostRecv1
	);
end;
