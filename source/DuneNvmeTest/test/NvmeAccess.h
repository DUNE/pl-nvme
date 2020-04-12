/*******************************************************************************
 *	NvmeAccess.h	Provides access to an Nvme storage device on FpgaFabric
 *	T.Barnaby,	Beam Ltd,	2020-04-10
 *******************************************************************************
 */
/**
 * @class	NvmeAccess
 * @author	Terry Barnaby <terry.barnaby@beam.ltd.uk>
 * @date	2020-04-10
 * @version	0.0.1
 *
 * @brief
 * This is a simple class that provides access to an Nvme storage device on FpgaFabric.
 *
 * @details
 * This requires an Nvme device on a KCU105 with the DuneNvmeStorageTest bit file running.
 * The system allows an NVMe situtated on the Xilinx KCU105 to be accessed and experimented with. It implements the following:
 *  - Configuration of the NVMe PCIe configuration space registers.
 *  - Accessing the NVMe registers.
 *  - Configuration of the NVMe's registers.
 *  - Sending Admin commands to the NVMe via the admin request/completion shared memory queues. This includes configuration commands.
 *  - Sending of read and write IO commands to the NVMe via IO request/completion shared memory queues.
 *
 * There is access to the memory mappend NvmeStorage registers and there is one bi-directional DMA stream used for communication.
 * The send and receive DMA streams are multiplexed between requests from the host and replies from the Nvme and also
 * requests from the Nvme and replies from the host.
 * The packets sent have a 128bit multiplexing stream number headerand are then encapsulated in the Xilinx PCIe DMA IP's headers.
 *
 * The class accesses the FPGA system over the hosts PCIe bus using the Beam bfpga Linux driver. This interfaces with the Xilinx PCIe DMA IP.
 * The class uses a thread to respond to Nvme requests.
 *
 * @copyright GNU GPL License
 * Copyright (c) Beam Ltd, All rights reserved. <br>
 * This code is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details. <br>
 * You should have received a copy of the GNU General Public License
 * along with this code. If not, see <https://www.gnu.org/licenses/>.
 */
#pragma once

#include <BeamLibBasic.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <sys/ioctl.h>
#include <bfpga_driver/bfpga.h>

class NvmeRequestPacket {
public:
			NvmeRequestPacket(){
				memset(this, 0, sizeof(*this));
			}

	BUInt32		stream;			///< 
	BUInt32		fill0[3];		///< 
	BUInt64		address;		///< 
	BUInt32		numWords:11;		///< 
	BUInt32		request:4;		///< 
	BUInt32		fill1:17;		///< 
	BUInt32		tag:8;			///< 
	BUInt32		fill2:24;		///< 
	BUInt32		data[32];		///< 
};

class NvmeReplyPacket {
public:
			NvmeReplyPacket(){
				memset(this, 0, sizeof(*this));
			}

	BUInt32		stream;			///< 
	BUInt32		fill0[3];		///< 
	BUInt32		address:12;		///< 
	BUInt32		error:4;		///< 
	BUInt32		numBytes:13;		///< 
	BUInt32		fill1:3;		///< 
	BUInt32		numWords:11;		///< 
	BUInt32		status:3;		///< 
	BUInt32		fill2:18;		///< 
	BUInt32		tag:8;			///< 
	BUInt32		fill3:24;		///< 
	BUInt32		data[32];		///< 
};

/// Nvme access class
class NvmeAccess {
public:
			NvmeAccess();
			~NvmeAccess();
	
	int		init();

	// Send a queued request to the NVMe
	int		nvmeRequest(int queue, int opcode, BUInt32 address, BUInt32 arg10, BUInt32 arg11 = 0, BUInt32 arg12 = 0);
	
	// NVMe process received requests thread
	int		nvmeProcess();
	
	// NVMe register access
	int		readNvmeReg32(BUInt32 address, BUInt32& data);
	int		writeNvmeReg32(BUInt32 address, BUInt32 data);
	int		readNvmeReg64(BUInt32 address, BUInt64& data);
	int		writeNvmeReg64(BUInt32 address, BUInt64 data);

	// Perform register access over PCIe both config and NVMe registers
	int		readRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data);
	int		writeRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data);

	// Packet send and receive
	int		packetSend(const NvmeRequestPacket& packet);
	int		packetSend(const NvmeReplyPacket& packet);
	
	// Debug
	void		dumpRegs();
	void		dumpDmaRegs(bool c2h, int chan);
	void		dumpStatus();

	
protected:
	int			oregsFd;
	int			ohostSendFd;
	int			ohostRecvFd;
	BFpgaInfo		oinfo;
	volatile BUInt32*	oregs;
	volatile BUInt32*	odmaRegs;

	BUInt32*		obufTx1;
	BUInt32*		obufTx2;
	BUInt32*		obufRx;
	BUInt8			otag;

	BSemaphore		opacketReplySem;		///< Semaphore when a reply packet has been received
	NvmeReplyPacket		opacketReply;			///< Reply to request

	pthread_t		othread;
	BUInt32			oqueueNum;

	BUInt32			oqueueAdminMem[4096];
	BUInt32			oqueueAdminRx;
	BUInt32			oqueueAdminTx;
	BUInt32			oqueueAdminId;
	
	BUInt32			oqueueDataMem[4096];
	BUInt32			oqueueDataRx;
	BUInt32			oqueueDataTx;

	BUInt32			odataBlockMem[4096];
};
