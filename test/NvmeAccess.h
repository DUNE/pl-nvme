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

const Bool	UseFpgaConfigure = 0;			///< Expect the NvmeStorage module to have configured the Nvme's
const Bool	UseConfigEngine = 0;			///< Use the FPGA configuration engine
const Bool	UseQueueEngine = 1;			///< Use the FPGA queue engine implementation
const BUInt	PcieMaxPayloadSize = 32;		///< The Pcie maximim packet payload in 32bit DWords
const BUInt	BlockSize = 4096;			///< The NvmeStorage block size in bytes

const BUInt	RegIdent		= 0x000;	///< The ident and version
const BUInt	RegControl		= 0x004;	///< The control register
const BUInt	RegStatus		= 0x008;	///< The status register
const BUInt	RegTotalBlocks		= 0x00C;	///< The total number of blocks
const BUInt	RegLostBlocks		= 0x010;	///< The number of blocks currently read

const BUInt	RegDataChunkStart	= 0x040;	///< The data chunk start register
const BUInt	RegDataChunkSize	= 0x044;	///< The data chunk size register
const BUInt	RegWriteError		= 0x048;	///< The write error status
const BUInt	RegWriteNumBlocks	= 0x04C;	///< The number of blocks written
const BUInt	RegWriteTime		= 0x050;	///< The write time in microseconds
const BUInt	RegWritePeakLatency	= 0x054;	///< The write peak block write latency in microseconds

const BUInt	RegReadControl		= 0x080;	///< The read data control register
const BUInt	RegReadStatus		= 0x084;	///< The read data status register
const BUInt	RegReadBlock		= 0x088;	///< The read data starting block register
const BUInt	RegReadNumBlocks	= 0x08C;	///< The read data number of blocks register

class NvmeRequestPacket {
public:
			NvmeRequestPacket(){
				memset(this, 0, sizeof(*this));
			}

	BUInt64		address;		///< The 64bit read/write address
	BUInt32		numWords:11;		///< The number of 32bit data words to transfer
	BUInt32		request:4;		///< The request (0 - read, 1 - write etc.)
	BUInt32		fill2:1;		///< 
	BUInt32		requesterId:16;		///< The requestors ID used as the stream ID
	BUInt32		tag:8;			///< A tag for this request, returned in the reply
	BUInt32		completerId:16;		///< The completers ID
	BUInt32		requesterIdEnable:1;	///< Enable the manual use of the requestorId field.
	BUInt32		fill3:7;		///< 
	BUInt32		data[PcieMaxPayloadSize];	///< The data words (Max of 1024 bytes but can be increased)
};

class NvmeReplyPacket {
public:
			NvmeReplyPacket(){
				memset(this, 0, sizeof(*this));
			}

	BUInt32		address:12;		///< The lower 12 bits of the address
	BUInt32		error:4;		///< An error number
	BUInt32		numBytes:13;		///< The total number of bytes to be transfered
	BUInt32		fill1:3;		///< 
	BUInt32		numWords:11;		///< The number of 32bit words in this reply
	BUInt32		status:3;		///< The status for the request
	BUInt32		fill2:2;		///< 
	BUInt32		requesterId:16;		///< The requestors ID
	BUInt32		tag:8;			///< The requests tag
	BUInt32		completerId:16;		///< The completer id
	BUInt32		fill3:7;		///< 
	BUInt32		reply:1;		///< This bit indicates a reply (we have used an unused bit for this)
	BUInt32		data[PcieMaxPayloadSize];	///< The data words (Max of 1024 bytes but can be increased)
};

const BUInt NvmeSglTypeData	= 0;

class NvmeSgl {
	BUInt64		address;
	BUInt32		length;
	BUInt8		fill0[2];
	BUInt8		subtype:4;
	BUInt8		type:4;
};

/// Nvme access class
class NvmeAccess {
public:
			NvmeAccess();
			~NvmeAccess();
	
	int		init();
	void		close();

	void		setNvme(BUInt n);
	BUInt		getNvme();
	void		reset();
	void		start();							///< Start NVMe request processing thread

	// Send a queued request to the NVMe
	int		nvmeRequest(Bool wait, int queue, int opcode, BUInt32 address, BUInt32 arg10, BUInt32 arg11 = 0, BUInt32 arg12 = 0);
	
	// NVMe process received requests thread
	int		nvmeProcess();
	virtual void	nvmeDataPacket(NvmeRequestPacket& packet);			///< Called when read data packet received
	
	// NvmeStorage units register access
	BUInt32		readNvmeStorageReg(BUInt32 address);
	void		writeNvmeStorageReg(BUInt32 address, BUInt32 data);
	
	// NVMe register access
	int		readNvmeReg32(BUInt32 address, BUInt32& data);
	int		writeNvmeReg32(BUInt32 address, BUInt32 data);
	int		readNvmeReg64(BUInt32 address, BUInt64& data);
	int		writeNvmeReg64(BUInt32 address, BUInt64 data);

	// Perform register access over PCIe both config and NVMe registers
	int		pcieWrite(BUInt8 request, BUInt32 address, BUInt32 num, BUInt32* data);
	int		pcieRead(BUInt8 request, BUInt32 address, BUInt32 num, BUInt32* data);

	// Packet send and receive
	int		packetSend(const NvmeRequestPacket& packet);
	int		packetSend(const NvmeReplyPacket& packet);
	int		readAvailable();						///< The number of bytes available on the receive stream
	
	// Debug
	void		dumpRegs(int nvmeNum = -1);
	void		dumpDmaRegs(bool c2h, int chan);
	void		dumpStatus();

	
protected:
	int			oregsFd;			///< Device drive fd for register access
	int			ohostSendFd;			///< Device driver fd for DMA send channel
	int			ohostRecvFd;			///< Device driver fd for DMA receive channel
	BFpgaInfo		oinfo;				///< Device driver information
	volatile BUInt32*	oregs;				///< FPGA design's registers memory mapped
	volatile BUInt32*	odmaRegs;			///< FPGA's PCIe XDMA modules DMA control registers memory mapped

	BUInt32*		obufTx;
	BUInt32*		obufRx;
	BUInt8			otag;

	BSemaphore		opacketReplySem;		///< Semaphore when a reply packet has been received
	NvmeReplyPacket		opacketReply;			///< Reply to request
	BSemaphore		oqueueReplySem;			///< Semaphore when a queue reply packet has been received

	pthread_t		othread;
	BUInt32			onvmeNum;			///< The nvme to communicate with, 0 is both
	BUInt32			onvmeRegbase;			///< The register base address
	BUInt32			oqueueNum;

	BUInt32			oqueueAdminMem[4096];
	BUInt32			oqueueAdminRx;
	BUInt32			oqueueAdminTx;
	BUInt32			oqueueAdminId;
	
	BUInt32			oqueueDataMem[4096];
	BUInt32			oqueueDataRx;
	BUInt32			oqueueDataTx;

	BUInt32			odataBlockMem[8192];
};
