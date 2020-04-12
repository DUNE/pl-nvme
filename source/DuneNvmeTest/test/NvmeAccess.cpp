/*******************************************************************************
 *	NvmeAccess.cpp	Provides access to an Nvme storage device on FpgaFabric
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
#define	LDEBUG1		0		// High level debug
#define	LDEBUG2		0		// Debug host to NVMe queued requests
#define	LDEBUG3		0		// Debug NVMe to host queued requests (bus master)
#define	LDEBUG4		0		// Xlinux PCIe DMA IP register debug

#include <NvmeAccess.h>

#define DMA_ID				0x00
#define DMA_CONTROL			0x04
#define DMA_STATUS			0x40
#define DMA_COMPLETE			0x48
#define DMA_ALIGNMENTS			0x4C
#define DMA_WRITEBACK_ADDRESS_LOW	0x88
#define DMA_WRITEBACK_ADDRESS_HIGH	0x8C
#define DMA_INT_MASK			0x90

#define DMASC_ID			0x00
#define DMASC_ADDRESS_LOW		0x80
#define DMASC_ADDRESS_HIGH		0x84
#define DMASC_NEXT			0x88
#define DMASC_CREDITS			0x8C

/// Start nvmeProcess thread
static void* nvmeProcess(void* arg){
	NvmeAccess*	nvmeAccess = (NvmeAccess*)arg;
	
	nvmeAccess->nvmeProcess();
	return 0;
}

NvmeAccess::NvmeAccess(){
	oregsFd = -1;
	ohostSendFd = -1;
	ohostRecvFd = -1;
	oregs = 0;
	obufTx1 = 0;
	obufTx2 = 0;
	obufRx = 0;
	otag = 0;
	oqueueNum = 64;
	oqueueAdminRx = 0;
	oqueueAdminTx = 0;
	oqueueAdminId = 0;
	oqueueDataRx = 0;
	oqueueDataTx = 0;
}

NvmeAccess::~NvmeAccess(){
	if(obufRx)
		free(obufRx);
	if(obufTx2)
		free(obufTx2);
	if(obufTx1)
		free(obufTx1);

	if(odmaRegs)
		munmap((void*)odmaRegs, 4096);
	if(oregs)
		munmap((void*)oregs, 4096);
	
	if(ohostRecvFd >= 0)
		close(ohostRecvFd);
	if(ohostSendFd >= 0)
		close(ohostSendFd);
	if(oregsFd >= 0)
		close(oregsFd);
}


int NvmeAccess::init(){
	int	r;

	if((oregsFd = open("/dev/bfpga0", O_RDWR | O_SYNC)) < 0){
		fprintf(stderr, "Unable to open /dev/xdma0_user\n");
		return 1;
	}

	if((r = ioctl(oregsFd, BFPGA_CMD_GETINFO, &oinfo)) < 0){
		fprintf(stderr, "Error ioctl: %s\n", strerror(errno));
		return 1;
	}
	dl1printf("Driver Register Addresses: %x(%x)\n", oinfo.regs.physAddress, oinfo.regs.length);

	if((oregs = (volatile BUInt32*)mmap(0, oinfo.regs.length, PROT_READ|PROT_WRITE, MAP_SHARED, oregsFd, oinfo.regs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	
	if((odmaRegs = (volatile BUInt32*)mmap(0, oinfo.dmaRegs.length, PROT_READ|PROT_WRITE, MAP_SHARED, oregsFd, oinfo.dmaRegs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}


	if((ohostSendFd = open("/dev/bfpga0-send0", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-send0\n");
		return 1;
	}

	if((ohostRecvFd = open("/dev/bfpga0-recv0", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-recv0\n");
		return 1;
	}

	posix_memalign((void **)&obufTx1, 4096, 4096);
	posix_memalign((void **)&obufTx2, 4096, 4096);
	posix_memalign((void **)&obufRx, 4096, 4096);

	// Start of NVme request processing
	pthread_create(&othread, 0, ::nvmeProcess, this);

	return 0;
}

// Send a queued request to the Nvme
int NvmeAccess::nvmeRequest(int queue, int opcode, BUInt32 address, BUInt32 arg10, BUInt32 arg11, BUInt32 arg12){
	BUInt32*	cmd;
	int		e;
	
	if(queue){
		cmd = &oqueueDataMem[oqueueDataTx * 16];
	}
	else {
		cmd = &oqueueAdminMem[oqueueAdminTx * 16];
	}
	
	memset(cmd, 0, 64);

	cmd[0] = (++oqueueAdminId << 16) | opcode;
	cmd[1] = 0;		// Namespace
	cmd[2] = 0;		// Reserved
	cmd[3] = 0;
	cmd[4] = 0x00;		// Metadata
	cmd[5] = 0x00;
	cmd[6] = address;		// PRP1
	cmd[7] = 0x00000000;
	cmd[8] = 0x00000000;		// PRP2
	cmd[9] = 0x00000000;
	cmd[10] = arg10;	// The argument CMD10
	cmd[11] = arg11;	// The argument CMD11
	cmd[12] = arg12;	// The argument CMD12
	
	if(queue){
		dl2printf("Submit IO: queue: %d 0x%x to slot: %d\n", queue, opcode, oqueueDataTx);
		dl2hd32(cmd, 64 / 4);

		cmd[1] = 1;		// Namespace

		oqueueDataTx++;
		if(oqueueDataTx >= oqueueNum)
			oqueueDataTx = 0;

		if(e = writeNvmeReg32(0x1008, oqueueDataTx)){
			printf("Error: %d\n", e);
			return 1;
		}
	}
	else {
		dl2printf("Submit command: queue: %d opcode: 0x%x to slot: %d\n", queue, opcode, oqueueAdminTx);
		dl2hd32(cmd, 64 / 4);
	
		oqueueAdminTx++;
		if(oqueueAdminTx >= oqueueNum)
			oqueueAdminTx = 0;

		if(e = writeNvmeReg32(0x1000, oqueueAdminTx)){
			printf("Error: %d\n", e);
			return 1;
		}
	}

	return 0;
}

/// This function runs as a separate thread in order to receive both replies and requests from the Nvme.
int NvmeAccess::nvmeProcess(){
	int			nt;
	NvmeRequestPacket	request;
	NvmeReplyPacket		reply;
	BUInt32*		data;
	BUInt32			nWordsRet;
	BUInt32			nWords;
	int			e;
	int			status = 0;
	
	// This reads packets from the NVMe and processes them. The packets have a special requester header produced by the Xilinx PCIe DMA IP.
	// Responces have the special completer header added for the Xilinx PCIe DMA IP.
	while(1){
		dl3printf("NvmeAccess::nvmeProcess: loop\n");

		// Read the packet from the Nvme. Coupdl be a request or a reply
		nt = read(ohostRecvFd, obufRx, 4096);

		dl3printf("NvmeAccess::nvmeProcess: awoken with: %d bytes\n", nt);
		//dl3hd32(obufRx, nt / 4);
		
		// Determine if packet is a reply or an Nvme request from the stream number in the header
		if(obufRx[0] == 1){
			memcpy(&opacketReply, obufRx, sizeof(opacketReply));
			opacketReplySem.set();
			continue;
		}
		else if(obufRx[0] == 2){
			memcpy(&request, obufRx, sizeof(request));
		}
		else {
			printf("NvmeAccess::nvmeProcess: Error packet with unknown stream\n");
			continue;
		}
		
		dl3printf("NvmeAccess::nvmeProcess: recvNum: %d Stream: %d Req: %d nWords: %d address: 0x%8.8x\n", nt, request.stream, request.request, request.numWords, request.address);
		dl3hd32(&request, nt / 4);
		//dumpStatus();

		if(request.request == 0){
			// PCIe Read requests
			dl3printf("NvmeAccess::nvmeProcess: Read memory: address: %8.8x nWords: %d\n", request.address, request.numWords);
			if((request.address & 0xF0000000) == 0x10000000){
				data = oqueueAdminMem;
			}
			else if((request.address & 0xF0000000) == 0x30000000){
				data = oqueueDataMem;
			}
			else if((request.address & 0xF0000000) == 0x80000000){
				data = odataBlockMem;
			}
			else {
				printf("NvmeAccess::nvmeProcess: Error read from uknown address: 0x%8.8x\n", request.address);
				continue;
			}

			nWordsRet = request.numWords;
			while(nWordsRet){
				nWords = nWordsRet;
				if(nWords > 32)
					nWords = 32;

				reply.stream = 2;
				reply.numBytes = (nWordsRet * 4);
				reply.numWords = nWords;
				reply.tag = request.tag;
				memcpy(reply.data, &data[(request.address & 0x0FFFFFFF) / 4], nWords * 4);

				dl3printf("NvmeAccess::nvmeProcess: ReadData block from: 0x%8.8x nWords: %d\n", request.address, nWords);
				dl3hd32(&reply, (7 + nWords));
				if(packetSend(reply)){
					printf("NvmeAccess::nvmeProcess: packet send error\n");
					exit(1);
				}
					
				nWordsRet -= nWords;
			}
		}
		else if(request.request == 1){
			// PCIe Write requests
			dl3printf("NvmeAccess::nvmeProcess: Write memory: address: %8.8x nWords: %d\n", request.address, request.numWords);
			status = 0;
			
			if((request.address & 0xF0000000) == 0x20000000){
				status = request.data[3] >> 17;
				dl3printf("NvmeAccess::nvmeProcess: NvmeReply: Queue: %d QueueHeadPointer: %d Status: 0x%4.4x Command: 0x%x\n", request.data[2] >> 16, request.data[2] & 0xFFFF, request.data[3] >> 17, request.data[3] & 0xFFFF);

				// Write to completion queue doorbell
				oqueueAdminRx++;
				if(oqueueAdminRx >= oqueueNum)
					oqueueAdminRx = 0;

				dl3printf("NvmeAccess::nvmeProcess: Write completion queue doorbell: %d\n", oqueueAdminRx);
				if(e = writeNvmeReg32(0x1004, oqueueAdminRx)){
					printf("Error: %d\n", e);
					return 1;
				}
			}
			else if((request.address & 0xF0000000) == 0x40000000){
				status = request.data[3] >> 17;
				dl3printf("NvmeAccess::nvmeProcess: IoCompletion: Queue: %d QueueHeadPointer: %d Status: 0x%4.4x Command: 0x%x\n", request.data[2] >> 16, request.data[2] & 0xFFFF, request.data[3] >> 17, request.data[3] & 0xFFFF);

				// Write to completion queue doorbell
				oqueueDataRx++;
				if(oqueueDataRx >= oqueueNum)
					oqueueDataRx = 0;

				dl3printf("NvmeAccess::nvmeProcess: Write completion queue doorbell: %d\n", oqueueDataRx);
				if(e = writeNvmeReg32(0x100C, oqueueDataRx)){
					printf("Error: %d\n", e);
					return 1;
				}
			}
			else if((request.address & 0xF0000000) == 0x80000000){
				dl3printf("NvmeAccess::nvmeProcess: IoBlockWrite: address: %8.8x nWords: %d\n", (request.address & 0x0FFFFFFF), nWords);

				memcpy(&odataBlockMem[(request.address & 0x0FFFFFFF) / 4], request.data, request.numWords * 4);
			}
			else if((request.address & 0xF0000000) == 0xF0000000){
				printf("NvmeAccess::nvmeProcess: Write: address: %8.8x nWords: %d\n", (request.address & 0x0FFFFFFF), nWords);
				memcpy(&odataBlockMem[(request.address & 0x0FFFFFFF) / 4], request.data, request.numWords * 4);
				bhd32(odataBlockMem, request.numWords);
			}
			else {
				printf("NvmeAccess::nvmeProcess: Write data: unknown address: 0x%8.8x\n", request.address);
			}
			
			if(status){
				printf("NvmeAccess::nvmeProcess: Command returned error: status: %4.4x\n", status);
			}
		}
		else {
			printf("NvmeAccess::nvmeProcess: Error: Uknown request: %x\n", request.request);
		}
	}

	return 0;
}


int NvmeAccess::readNvmeReg32(BUInt32 address, BUInt32& data){
	return readRegister(0, address, 1, (BUInt32*)&data);
}

int NvmeAccess::writeNvmeReg32(BUInt32 address, BUInt32 data){
	return writeRegister(0, address, 1, (BUInt32*)&data);
}

int NvmeAccess::readNvmeReg64(BUInt32 address, BUInt64& data){
	return readRegister(0, address, 2, (BUInt32*)&data);
}

int NvmeAccess::writeNvmeReg64(BUInt32 address, BUInt64 data){
	return writeRegister(0, address, 2, (BUInt32*)&data);
}

int NvmeAccess::readRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data){
	NvmeRequestPacket	txPacket;
	BUInt8			err;
	int			nt = num;

	if(config){
		txPacket.request = 8;		// Config read
	}
	else {
		txPacket.request = 0;		// Memory read
	}

	if(num > 1)
		oregs[1] = 0x80000000;
	else
		oregs[1] = 0x00000000;

	// Memory or Config read
	dl1printf("NvmeAccess::readRegister read: address: %d num: %d\n", address, num);
	txPacket.stream = 1;			// Stream header with stream number
	
	txPacket.address = address;		// 32bit address
	txPacket.numWords = num;		// Number of 32bit DWords
	txPacket.tag = ++otag;			// Tag
	
	dl2printf("NvmeAccess::readRegister: Send packet\n");
	dl2hd32(&txPacket, 8);

#if LDEBUG4
	dumpDmaRegs(0, 0);
	dumpDmaRegs(1, 0);
#endif
	if(packetSend(txPacket)){
		printf("Packet send error\n");
		return 1;
	}	

	dl2printf("Recv data\n");
	memset(obufRx, 0, 4096);
	
#if LDEBUG4
	usleep(100000);
	dumpDmaRegs(0, 0);
	dumpDmaRegs(1, 0);
#endif
	
#ifdef ZAP
	nt = read(ohostRecvFd, obufRx, 4096);
	dl2printf("Read %d\n", nt);

	if(nt > 0)
		dl2hd32(obufRx, nt / 4);

	pause();
#endif

	// Wait for a reply
	opacketReplySem.wait();
	dl2printf("Received reply: status: %x, error: %x, numWords: %d\n", opacketReply.status, opacketReply.error, opacketReply.numWords);
	
	dl2hd32(&opacketReply, 7 + opacketReply.numWords);
	if(opacketReply.error)
		return opacketReply.error;

	memcpy(data, opacketReply.data, (num * sizeof(BUInt32)));

	return 0;
}

int NvmeAccess::writeRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data){
	NvmeRequestPacket	txPacket;
	int			nt;
	int			reqType;
	BUInt8			err;
	
	if(config){
		txPacket.request = 10;	// Config write
	}
	else {
		txPacket.request = 1;	// Memory write
	}

#ifdef ZAP
	// This is a bit of a fudge. We need to inform the naff Xilinx PCIe interface of the DWords present somehow.
	// This is now handled in the FPGA
	if(num > 1)
		oregs[1] = 0x80000000;
	else
		oregs[1] = 0x00000000;
#endif
	
	// Memory or Config read
	dl2printf("NvmeAccess::writeRegister address: 0x%8.8x num: %d\n", address, num);
	txPacket.stream = 1;			// Stream header with stream number
	
	txPacket.address = address;		// 32bit address
	txPacket.numWords = num;		// Number of 32bit DWords
	txPacket.tag = ++otag;			// Tag

	memcpy(txPacket.data, data, (num * 4));

	dl2printf("Send packet\n");
	dl2hd32(&txPacket, 8 + num);

#if LDEBUG4
	dumpDmaRegs(0, 0);
	dumpDmaRegs(1, 0);
#endif
	if(packetSend(txPacket)){
		printf("Packet send error\n");
		return 1;
	}	

	if(config){
		// Wait for a reply
		opacketReplySem.wait();
		dl2printf("Received reply: status: %x, error: %x, numWords: %d\n", opacketReply.status, opacketReply.error, opacketReply.numWords);
		opacketReply.numWords++;
		
		dl2hd32(&opacketReply, 7 + opacketReply.numWords);
		if(opacketReply.error)
			return opacketReply.error;
	}
	else {
		// Not sure why this is needed ?
		usleep(10000);
	}
	
	return 0;
}


int NvmeAccess::packetSend(const NvmeRequestPacket& packet){
	BUInt	nb = 32;

	if((packet.request == 1) || (packet.request == 10))
		nb += (4 * packet.numWords);

	memcpy(obufTx1, &packet, nb);
	//printf("SendPacket: numWords: %d %d\n", packet.numWords, nb);
	//bhd32(obufTx1, nb/4);

	if(write(ohostSendFd, obufTx1, nb) != nb){
		printf("Send error\n");
		return 1;
	}
	return 0;
}

int NvmeAccess::packetSend(const NvmeReplyPacket& packet){
	BUInt	nb = 28 + (4 * packet.numWords);

	memcpy(obufTx2, &packet, nb);
	//printf("NvmeAccess::packetSend: reply: nWords: %d nBytes: %d\n", packet.numWords, nb);
	//bhd32(obufTx2, nb / 4);

	if(write(ohostSendFd, obufTx2, nb) != nb){
		printf("Send error\n");
		return 1;
	}
	return 0;
}


void NvmeAccess::dumpRegs(){
	printf("Id   : %8.8x\n", oregs[0]);
	//printf("Address1: %8.8x\n", oregs[1]);
	//printf("Address2: %8.8x\n", oregs[2]);
	printf("Test0: %8.8x\n", oregs[3]);
	printf("Test1: %8.8x\n", oregs[4]);
	printf("Test2: %8.8x\n", oregs[5]);
	printf("Test3: %8.8x\n", oregs[6]);
	printf("Test4: %8.8x\n", oregs[7]);
}

void  NvmeAccess::dumpDmaRegs(bool c2h, int chan){
	int			regsAddress = (c2h << 12) | (chan << 8);
	int			sgregsAddress = ((4 + c2h) << 12) | (chan << 8);
	volatile BUInt32*	regs = &odmaRegs[regsAddress / 4];
	volatile BUInt32*	sgregs = &odmaRegs[sgregsAddress / 4];
	
	printf("DMA Channel:    %d.%d\n", c2h, chan);
	//printf("DMA regs:       0x%x\n", regsAddress);
	printf("DMA_ID:		%x\n", regs[DMA_ID / 4]);
	printf("DMA_CONTROL:	%x\n", regs[DMA_CONTROL / 4]);
	printf("DMA_STATUS:	%x\n", regs[DMA_STATUS / 4]);
	printf("DMA_COMPLETE:	%x\n", regs[DMA_COMPLETE / 4]);
	printf("DMA_INT_MASK:	%x\n", regs[DMA_INT_MASK / 4]);

	if(0){	
		printf("DMASC_ID:		%x\n", sgregs[DMASC_ID / 4]);
		//printf("DMASC regs:             0x%x\n", sgregsAddress);
		printf("DMASC_ADDRESS_LOW:	%x\n", sgregs[DMASC_ADDRESS_LOW / 4]);
		printf("DMASC_ADDRESS_HIGH:	%x\n", sgregs[DMASC_ADDRESS_HIGH / 4]);
		printf("DMASC_NEXT:		%x\n", sgregs[DMASC_NEXT / 4]);
#ifdef ZAP
		printf("SGmemory\n");
		if(chan)
			bhd32((void*)dma1Mem, 64);
		else
			bhd32((void*)dma0Mem, 64);
#endif
	}
}

void NvmeAccess::dumpStatus(){
	BUInt32	data;
	int	e;
	
	if(e = readNvmeReg32(0x1C, data)){
		printf("Error: %d\n", e);
		return;
	}
	printf("StatusReg: 0x%3.3x 0x%8.8x\n", 0x1C, data);
}
