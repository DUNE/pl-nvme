create_project -force -part xcku115-flva1517-2-e DuneNvmeTest
set_property target_language VHDL [current_project]
add_files -fileset sources_1 defines.v
add_files -fileset sources_1 ../src/NvmeStoragePkg.vhd
add_files -fileset sources_1 ../src/NvmeStorageIntPkg.vhd
add_files -fileset sources_1 ../src/Ram.vhd
add_files -fileset sources_1 ../src/Fifo.vhd
add_files -fileset sources_1 ../src/Cdc.vhd
add_files -fileset sources_1 ../src/RegAccessClockConvertor.vhd
add_files -fileset sources_1 ../src/AxisClockConverter.vhd
add_files -fileset sources_1 ../src/AxisDataConvertFifo.vhd
add_files -fileset sources_1 ../src/NvmeStreamMux.vhd
add_files -fileset sources_1 ../src/PcieStreamMux.vhd
add_files -fileset sources_1 ../src/StreamSwitch.vhd
add_files -fileset sources_1 ../src/NvmeSim.vhd
add_files -fileset sources_1 ../src/NvmeQueues.vhd
add_files -fileset sources_1 ../src/NvmeConfig.vhd
add_files -fileset sources_1 ../src/NvmeWrite.vhd
add_files -fileset sources_1 ../src/NvmeRead.vhd
add_files -fileset sources_1 ../src/NvmeStorageUnit.vhd
add_files -fileset sources_1 ../src/NvmeStorage.vhd
add_files -fileset sources_1 ../src/BlockFormatting/axis_stream_check_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/axis_stream_flow_mod_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_axis_packet_fifo.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_header_inserter_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_pad_inserter_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_spkt_splitter_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_strm_fmt.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_strm_fmt_pkg.vhd
add_files -fileset sources_1 ../src/BlockFormatting/nvme_strm_gen_blk.vhd
add_files -fileset sources_1 ../src/BlockFormatting/NvmeStrmFmtTestData.vhd
add_files -fileset sources_1 ../src/DuneNvmeTestTop.vhd
add_files -fileset constrs_1 ../src/DuneNvmeTestTop.xdc
import_ip ../src/ip/Clk_core.xci
import_ip ../src/ip/Pcie_host.xci
import_ip ../src/ip/Axis_clock_converter.xci
import_ip ../src/ip/Pcie_nvme0.xci
import_ip ../src/ip/Pcie_nvme1.xci
import_ip ../src/ip/BlockFormatting/axis_data_fifo_ic_512_x_256.xci
import_ip ../src/ip/BlockFormatting/axis_fifo_cc_512_x_16.xci
exit
