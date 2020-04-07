/*******************************************************************************
 *	test_nvme.cpp	Test of FPGA NVME access over PCIe DMA channels
 *	T.Barnaby,	Beam Ltd,	2020-03-01
 *******************************************************************************
 */
/**
 * @file	test_nvme.cpp
 * @author	Terry Barnaby <terry.barnaby@beam.ltd.uk>
 * @date	2020-03-13
 * @version	0.0.1
 *
 * @brief
 * This is a simple test program that uses the Xilinx xdma Linux driver to access
 *
 * @details
 * an Nvme device on a KCU105 with the DuneNvmeStorageTest bit file running.
 * The system allows an NVMe situtated on the Xilinx KCU105 to be accessed and experimented with. It implements the following:
 *  - Configuration of the NVMe PCIe configuration space registers.
 *  - Accessing the NVMe registers.
 *  - Configuration of the NVMe via registers.
 *  - Sending Admin commands to the NVMe via the admin request/completion shared memory queues. This includes configuration commands.
 *  - Sending of read and write IO commands to the NVMe via IO request/completion shared memory queues.
 *
 * There is access to the memory mappend NvmeStorage registers and there are two bi-directional DMA streams.
 * The first set of DMA streams send and receive packets to/from the NVMe encapsulated in the Xilinx PCIe DMA IP's headers.
 * The second set of DMA streams are used to service NVMe requests (direct memory access) packets from/to the NVMe encapsulated in the Xilinx PCIe DMA IP's headers.
 *
 * The program accesses the FPGA test009-nvme system over the hosts PCIe bus using the Beam bfpga Linux driver. This interfaces with the Xilinx PCIe DMA IP.
 * The program uses a thread to respond to VNMe requests. Note there is no thread data synchronisation code.
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
#include <stdint.h>
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
#include </src/dune/source/bfpga_driver/bfpga.h>

#define	LDEBUG1		0		// High level debug
#define	LDEBUG2		0		// Debug host to NVMe queued requests
#define	LDEBUG3		0		// Debug NVMe to host queued requests (bus master)
#define	LDEBUG4		0		// Xlinux PCIe DMA IP register debug

#if LDEBUG1
#define	dl1printf(fmt, a...)	printf(fmt, ##a)
#define	dl1hd32(data, nWords)	hd32(data, nWords)
#else
#define	dl1printf(fmt, a...)
#define	dl1hd32(data, nWords)
#endif

#if LDEBUG2
#define	dl2printf(fmt, a...)	printf(fmt, ##a)
#define	dl2hd32(data, nWords)	hd32(data, nWords)
#else
#define	dl2printf(fmt, a...)
#define	dl2hd32(data, nWords)
#endif

#if LDEBUG3
#define	dl3printf(fmt, a...)	printf(fmt, ##a)
#define	dl3hd32(data, nWords)	hd32(data, nWords)
#else
#define	dl3printf(fmt, a...)
#define	dl3hd32(data, nWords)
#endif


typedef bool		Bool;
typedef uint8_t		BUInt8;
typedef uint32_t	BUInt32;
typedef uint64_t	BUInt64;


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

void hd8(void* data, BUInt32 n){
	BUInt8*		d = (BUInt8*)data;
	BUInt32		i;
	
	for(i = 0; i < n; i++){
		printf("%2.2x ", *d++);
		if((i & 0xF) == 0xF)
			printf("\n");
	}
	printf("\n");
}

void hd32(void* data,BUInt32 n){
	BUInt32*	d = (BUInt32*)data;
	BUInt32		i;
	
	for(i = 0; i < n; i++){
		printf("%8.8x ", *d++);
		if((i & 0x7) == 0x7)
			printf("\n");
	}
	printf("\n");
}

/// Overal operation control class.
class Control {
public:
			Control();
			~Control();
	
	int		init();
	int		run();

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

	// Debug
	void		dumpRegs();
	void		dumpDmaRegs(bool c2h, int chan);
	void		dumpStatus();
	
private:
	int			oregsFd;
	int			ohostReqFd;
	int			ohostReplyFd;
	int			onvmeReqFd;
	int			onvmeReplyFd;
	BFpgaInfo		oinfo;
	volatile BUInt32*	oregs;
	volatile BUInt32*	odmaRegs;

	BUInt32*		obufTx;
	BUInt32*		obufRx;
	BUInt32*		obufNvmeRx;
	BUInt32*		obufNvmeTx;
	BUInt8			otag;

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


void* nvmeProcess(void* arg){
	Control*	control = (Control*)arg;
	
	control->nvmeProcess();
	return 0;
}

Control::Control(){
	oregsFd = -1;
	ohostReqFd = -1;
	ohostReplyFd = -1;
	onvmeReqFd = -1;
	onvmeReplyFd = -1;
	oregs = 0;
	obufTx = 0;
	obufRx = 0;
	obufNvmeRx = 0;
	obufNvmeTx = 0;
	otag = 0;
	oqueueNum = 64;
	oqueueAdminRx = 0;
	oqueueAdminTx = 0;
	oqueueAdminId = 0;
	oqueueDataRx = 0;
	oqueueDataTx = 0;
}

Control::~Control(){
	if(obufRx)
		free(obufRx);
	if(obufTx)
		free(obufTx);
	if(obufNvmeRx)
		free(obufNvmeRx);
	if(obufNvmeTx)
		free(obufNvmeTx);

	if(odmaRegs)
		munmap((void*)odmaRegs, 4096);
	if(oregs)
		munmap((void*)oregs, 4096);
	
	if(ohostReplyFd >= 0)
		close(ohostReplyFd);
	if(ohostReqFd >= 0)
		close(ohostReqFd);
	if(onvmeReplyFd >= 0)
		close(onvmeReplyFd);
	if(onvmeReqFd >= 0)
		close(onvmeReqFd);
	if(oregsFd >= 0)
		close(oregsFd);
}


int Control::init(){
	int	r;

	if((oregsFd = open("/dev/bfpga0", O_RDWR | O_SYNC)) < 0){
		fprintf(stderr, "Unable to open /dev/xdma0_user\n");
		return 1;
	}

	if((r = ioctl(oregsFd, BFPGA_CMD_GETINFO, &oinfo)) < 0){
		fprintf(stderr, "Error ioctl: %s\n", strerror(errno));
		return 1;
	}
	printf("RegsAddresses: %x(%x)\n", oinfo.regs.physAddress, oinfo.regs.length);

	if((oregs = (volatile BUInt32*)mmap(0, oinfo.regs.length, PROT_READ|PROT_WRITE, MAP_SHARED, oregsFd, oinfo.regs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	
	if((odmaRegs = (volatile BUInt32*)mmap(0, oinfo.dmaRegs.length, PROT_READ|PROT_WRITE, MAP_SHARED, oregsFd, oinfo.dmaRegs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}


	if((ohostReqFd = open("/dev/bfpga0-send0", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-send0\n");
		return 1;
	}

	if((ohostReplyFd = open("/dev/bfpga0-recv0", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-recv0\n");
		return 1;
	}

	if((onvmeReqFd = open("/dev/bfpga0-recv1", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-recv1\n");
		return 1;
	}

	if((onvmeReplyFd = open("/dev/bfpga0-send1", O_RDWR)) < 0){
		fprintf(stderr, "Unable to open /dev/bfpga0-send1\n");
		return 1;
	}

	posix_memalign((void **)&obufTx, 4096, 4096);
	posix_memalign((void **)&obufRx, 4096, 4096);
	posix_memalign((void **)&obufNvmeRx, 4096, 4096);
	posix_memalign((void **)&obufNvmeTx, 4096, 4096);

	return 0;
}

int Control::run(){
	BUInt32	address = 0;
	BUInt32	data[8];
	BUInt32	data32;
	BUInt64	data64;
	BUInt32	a;
	int	e;
	int	n;

	// Start of NVme request processing
	pthread_create(&othread, 0, ::nvmeProcess, this);

	printf("Configure PCIe for memory reads at address %8.8x\n", address);
	readRegister(1, 4, 1, data);
	dl1printf("Commandreg: %8.8x\n", data[0]);
	data[0] |= 6;
	writeRegister(1, 4, 1, data);
	readRegister(1, 4, 1, data);
	dl1printf("Commandreg: %8.8x\n", data[0]);

#ifdef ZAP
	printf("Nvme registers\n");
	for(a = 0; a < 16; a++){
		BUInt32	data;
		
		if(e = readNvmeReg32(a * 4, data)){
			printf("Error: %d\n", e);
			return 1;
		}
		printf("Reg: 0x%3.3x 0x%8.8x\n", a * 4, data);
	}
#endif

	// Setup NVME
	printf("Setup NVMe\n");
	// Stop controller
	if(e = writeNvmeReg32(0x14, 0x00460000)){
		printf("Error: %d\n", e);
		return 1;
	}
	usleep(10000);
	
	// Disable interrupts
	if(e = writeNvmeReg32(0x0C, 0xFFFFFFFF)){
		printf("Error: %d\n", e);
		return 1;
	}
	
	if(e = writeNvmeReg32(0x24, (oqueueNum << 16) | oqueueNum)){
		printf("Error: %d\n", e);
		return 1;
	}
	if(e = writeNvmeReg64(0x28, 0x10000000)){
		printf("Error: %d\n", e);
		return 1;
	}
	if(e = writeNvmeReg64(0x30, 0x20000000)){
		printf("Error: %d\n", e);
		return 1;
	}
	// Start controller
	if(e = writeNvmeReg32(0x14, 0x00460001)){
		printf("Error: %d\n", e);
		return 1;
	}
	usleep(10000);
	
	printf("Nvme regs\n");
	for(a = 0; a < 16; a++){
		BUInt32	data;
		
		if(e = readNvmeReg32(a * 4, data)){
			printf("Error: %d\n", e);
			return 1;
		}
		printf("Reg: 0x%3.3x 0x%8.8x\n", a * 4, data);
	}

	dumpStatus();

#ifdef ZAP
	printf("Get info\n");
	nvmeRequest(0, 0x06, 0xF0000000, 0x00000001);
	printf("\n");
	pause();
#endif

#ifdef ZAP
	printf("Get namespace list\n");
	nvmeRequest(0, 0x06, 0xF0000000, 0x00000002);
	printf("\n");
	pause();
#endif

	// Test data access
	// Create an IO queue
	printf("Create IO queue 1 completer\n");
	nvmeRequest(0, 0x05, 0x40000000, 0x00200001, 0x00000001);

	// Create an IO queue
	printf("Create IO queue 1 requester\n");
	nvmeRequest(0, 0x01, 0x30000000, 0x00200001, 0x00010001);

#ifndef ZAP
	printf("Perform block read\n");
	memset(odataBlockMem, 0x77, sizeof(odataBlockMem));
	nvmeRequest(1, 0x02, 0x80000000, 0x0000000, 0x00000000, 0);
	sleep(1);

	printf("DataBlock:\n");
	hd32(odataBlockMem, 8);
	
	//pause();
#endif



#ifdef ZAP
	printf("Set asynchonous feature\n");
	nvmeRequest(0, 0x09, 0xF0000000, 0x0000000b, 0xFFFFFFFF);
	//nvmeRequest(0, 0x0A, 0x20000000, 4096/4);
	printf("\n");
	sleep(5);
#endif

#ifdef ZAP
	printf("Get asynchonous feature\n");
	nvmeRequest(0, 0x0A, 0xF0000000, 0x0000000b);
	printf("\n");
	sleep(5);
	pause();
#endif


#ifdef ZAP
	printf("Get log page\n");
	nvmeRequest(0, 0x02, 0xF0000000, 0x00100001, 0x00000000, 0);
	sleep(1);
	printf("Get asynchonous event\n");
	nvmeRequest(0, 0x0C, 0x00000000, 0x00000000, 0x00000000, 0);
	sleep(1);
#endif

	printf("Perform block write\n");
	for(a = 0; a < 4096; a++)
		odataBlockMem[a] = 0x12100000 + a;

	nvmeRequest(1, 0x01, 0x80000000, 0x00000000, 0x00000000, 0);

#ifdef ZAP
	printf("Get asynchonous event\n");
	nvmeRequest(0, 0x0C, 0x00000000, 0x00000000, 0x00000000, 0);

	printf("Get log page\n");
	nvmeRequest(0, 0x02, 0xF0000000, 0x00100001, 0x00000000, 0);
	sleep(1);
#endif

	printf("Perform block read\n");
	memset(odataBlockMem, 0x77, sizeof(odataBlockMem));
	nvmeRequest(1, 0x02, 0x80000000, 0x0000000, 0x00000000, 0);

	sleep(1);
	printf("DataBlock:\n");
	hd32(odataBlockMem, 8);
	dumpStatus();

	printf("Complete\n");

	return 0;
}

int Control::nvmeRequest(int queue, int opcode, BUInt32 address, BUInt32 arg10, BUInt32 arg11, BUInt32 arg12){
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
		dl2printf("Submit command: queue: %d 0x%x to slot: %d\n", queue, opcode, oqueueAdminTx);
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

int Control::nvmeProcess(){
	int		nt;
	BUInt32		address;
	BUInt32		req;
	BUInt32		nWords;
	BUInt32*	data;
	BUInt32		nWordsRet;
	BUInt8		tag;
	int		e;
	int		status = 0;
	
	// This reads packets from the NVMe and processes them. The packets have a special requester header produced by the Xilinx PCIe DMA IP.
	// Responces have the special completer header added for the Xilinx PCIe DMA IP.
	while(1){
		//printf("Control::runRx: read from Nvme\n");

		nt = read(onvmeReqFd, obufNvmeRx, 4096);
		//printf("Control::runRx: ReadNvme has: %d\n", nt);
		
		address = obufNvmeRx[0];
		req = (obufNvmeRx[2] >> 11) & 0xF;
		nWords = obufNvmeRx[2] & 0x7FF;
		tag = obufNvmeRx[3] & 0xFF;
		
		dl3printf("Control::runRx: recvNum: %d Req: %d nWords: %d address: 0x%8.8x\n", nt, req, nWords, address);
		dl3hd32(obufNvmeRx, nt / 4);
		//dumpStatus();

		if(req == 0){
			// PCIe Read requests
			dl3printf("Read memory: address: %8.8x nWords: %d\n", address, nWords);
			if((address & 0xF0000000) == 0x10000000){
				data = oqueueAdminMem;
			}
			else if((address & 0xF0000000) == 0x30000000){
				data = oqueueDataMem;
			}
			else if((address & 0xF0000000) == 0x80000000){
				data = odataBlockMem;
			}
			else {
				printf("Error read from uknown address: 0x%8.8x\n", address);
				continue;
			}

			nWordsRet = nWords;
			while(nWordsRet){
				nWords = nWordsRet;
				if(nWords > 32)
					nWords = 32;
				obufNvmeTx[0] = (nWordsRet * 4) << 16;
				obufNvmeTx[1] = nWords;
				obufNvmeTx[2] = tag;
				memcpy(&obufNvmeTx[3], &data[(address & 0x0FFFFFFF) / 4], nWords * 4);

				dl3printf("Control::runRx: ReadData block form: 0x%8.8x nWords: %d\n", address, (3 + nWords));
				dl3hd32(obufNvmeTx, (3 + nWords));
				nt = write(onvmeReplyFd, obufNvmeTx, (3 + nWords) * 4);

				nWordsRet -= nWords;
			}
		}
		else if(req == 1){
			// PCIe Write requests
			dl3printf("Write memory: address: %8.8x nWords: %d\n", address, nWords);
			status = 0;
			
			if((address & 0xF0000000) == 0x20000000){
				status = obufNvmeRx[7] >> 17;
				dl3printf("Competion: Queue: %d QueueHeadPointer: %d Status: 0x%4.4x Command: 0x%x\n", obufNvmeRx[6] >> 16, obufNvmeRx[6] & 0xFFFF, obufNvmeRx[7] >> 17, obufNvmeRx[7] & 0xFFFF);

				// Write to completion queue doorbell
				oqueueAdminRx++;
				if(oqueueAdminRx >= oqueueNum)
					oqueueAdminRx = 0;

				dl3printf("Write completion queue doorbell: %d\n", oqueueAdminRx);
				if(e = writeNvmeReg32(0x1004, oqueueAdminRx)){
					printf("Error: %d\n", e);
					return 1;
				}
			}
			else if((address & 0xF0000000) == 0x40000000){
				status = obufNvmeRx[7] >> 17;
				dl3printf("IoCompetion: Queue: %d QueueHeadPointer: %d Status: 0x%4.4x Command: 0x%x\n", obufNvmeRx[6] >> 16, obufNvmeRx[6] & 0xFFFF, obufNvmeRx[7] >> 17, obufNvmeRx[7] & 0xFFFF);

				// Write to completion queue doorbell
				oqueueDataRx++;
				if(oqueueDataRx >= oqueueNum)
					oqueueDataRx = 0;

				dl3printf("Write completion queue doorbell: %d\n", oqueueDataRx);
				if(e = writeNvmeReg32(0x100C, oqueueDataRx)){
					printf("Error: %d\n", e);
					return 1;
				}
			}
			else if((address & 0xF0000000) == 0x80000000){
				dl3printf("IoBlockWrite: address: %8.8x nWords: %d\n", (address & 0x0FFFFFFF), nWords);

				memcpy(&odataBlockMem[(address & 0x0FFFFFFF) / 4], &obufNvmeRx[4], nWords * 4);
			}
			else if((address & 0xF0000000) == 0xF0000000){
				printf("Write: address: %8.8x nWords: %d\n", (address & 0x0FFFFFFF), nWords);
				memcpy(&odataBlockMem[(address & 0x0FFFFFFF) / 4], &obufNvmeRx[4], nWords * 4);
				hd32(odataBlockMem, nWords);
			}
			else {
				printf("Write data: unknown address: 0x%8.8x\n", address);
			}
			
			if(status){
				printf("Command returned error: status: %4.4x\n", status);
			}
		}
	}

	return 0;
}

int Control::readNvmeReg32(BUInt32 address, BUInt32& data){
	return readRegister(0, address, 1, (BUInt32*)&data);
}

int Control::writeNvmeReg32(BUInt32 address, BUInt32 data){
	return writeRegister(0, address, 1, (BUInt32*)&data);
}

int Control::readNvmeReg64(BUInt32 address, BUInt64& data){
	return readRegister(0, address, 2, (BUInt32*)&data);
}

int Control::writeNvmeReg64(BUInt32 address, BUInt64 data){
	return writeRegister(0, address, 2, (BUInt32*)&data);
}

int Control::readRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data){
	int	reqType;
	BUInt8	err;
	int	nt = num;

	if(config){
		reqType = 8;		// Config read
	}
	else {
		reqType = 0;		// Memory read
	}

	if(num > 1)
		oregs[1] = 0x80000000;
	else
		oregs[1] = 0x00000000;

	// Memory or Config read
	dl1printf("Control::readRegister read: address: %d num: %d\n", address, num);
	obufTx[0] = address;				// 32bit address
	obufTx[1] = 0x00000000;
	obufTx[2] = (reqType << 11) | nt;		// Command
	obufTx[3] = ++otag;				// Tag

	dl2printf("Send packet\n");
	dl2hd32(obufTx, 4);

#if LDEBUG4
	dumpDmaRegs(0, 0);
	dumpDmaRegs(1, 0);
#endif
	//swap(obufTx, 4);
	if(write(ohostReqFd, obufTx, 16)  != 16){
		printf("Write error\n");
		return 1;
	}	

	dl2printf("Recv data\n");
	memset(obufRx, 0, 4096);
	
#if LDEBUG4
	usleep(100000);
	dumpDmaRegs(0, 0);
	dumpDmaRegs(1, 0);
#endif
	
	nt = read(ohostReplyFd, obufRx, 4096);
	dl2printf("Read %d\n", nt);

	if(nt > 0){
		dl2hd32(obufRx, nt / 4);
		err = (obufRx[0] >> 12) & 0x0F;
		if(err)
			return err;

		memcpy(data, &obufRx[3], (num * sizeof(BUInt32)));
	}
	else {
		printf("*** Error: Read no data\n");
		return -1;
	}

	return 0;
}

int Control::writeRegister(Bool config, BUInt32 address, BUInt32 num, BUInt32* data){
	int	nt;
	int	reqType;
	BUInt8	err;
	
	if(config){
		reqType = 10;		// Config write
	}
	else {
		reqType = 1;		// Memory write
	}

	if(num > 1)
		oregs[1] = 0x80000000;
	else
		oregs[1] = 0x00000000;

	// Memory or Config read
	dl2printf("Control::writeRegister address: 0x%8.8x num: %d\n", address, num);
	obufTx[0] = address;				// 32bit address
	obufTx[1] = 0x00000000;
	obufTx[2] = (reqType << 11) | num;		// Command
	obufTx[3] = ++otag;				// Tag
	
	memcpy(&obufTx[4], data, num * sizeof(BUInt32));

	dl2printf("Send packet\n");
	dl2hd32(obufTx, 4 + num);

	nt = 16 + (num * sizeof(BUInt32));
	if(write(ohostReqFd, obufTx, nt) != nt){
		printf("Write error\n");
		return 1;
	}	

	if(config){
		dl2printf("Recv data\n");
		memset(obufRx, 0, 4096);

		nt = read(ohostReplyFd, obufRx, 4096);
		dl2printf("Read %d\n", nt);
		if(nt > 0){
			//swap(obufRx, 4);
			dl2hd32(obufRx, nt / 4);

			err = (obufRx[0] >> 12) & 0x0F;
			if(err)
				return err;

			memcpy(data, &obufRx[3], (num * sizeof(BUInt32)));
		}
		else {
			printf("*** Error: Read no data\n");
			return -1;
		}
	}
	else {
		// Not sure why this is needed ?
		usleep(10000);
	}
	
	return 0;
}
	
void Control::dumpRegs(){
	printf("Id   : %8.8x\n", oregs[0]);
	//printf("Address1: %8.8x\n", oregs[1]);
	//printf("Address2: %8.8x\n", oregs[2]);
	printf("Test0: %8.8x\n", oregs[3]);
	printf("Test1: %8.8x\n", oregs[4]);
	printf("Test2: %8.8x\n", oregs[5]);
	printf("Test3: %8.8x\n", oregs[6]);
	printf("Test4: %8.8x\n", oregs[7]);
}

void  Control::dumpDmaRegs(bool c2h, int chan){
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
			hd32((void*)dma1Mem, 64);
		else
			hd32((void*)dma0Mem, 64);
#endif
	}
}

void Control::dumpStatus(){
	BUInt32	data;
	int	e;
	
	if(e = readNvmeReg32(0x1C, data)){
		printf("Error: %d\n", e);
		return;
	}
	printf("StatusReg: 0x%3.3x 0x%8.8x\n", 0x1C, data);
}

int main(){
	int		err;
	Control		control;

	if(err = control.init()){
		return err;
	}
	
	if(err = control.run()){
		return err;
	}

	return 0;
}
