/*******************************************************************************
 *	Dtest1.c	BFPGA Linux Device Driver Test
 *			T.Barnaby,	BEAM Ltd,	2011-09-11
 *******************************************************************************
 * Copyright (c) 2011 BEAM Ltd. All rights reserved.
 *
 * This software is available to you under a choice of one of two
 * licenses.  You may choose to be licensed under the terms of the GNU
 * General Public License (GPL) Version 2, available from the file
 * COPYING in the main directory of this source tree, or the
 * OpenIB.org BSD license below:
 *
 *     Redistribution and use in source and binary forms, with or
 *     without modification, are permitted provided that the following
 *     conditions are met:
 *
 *      - Redistributions of source code must retain the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer.
 *
 *      - Redistributions in binary form must reproduce the above
 *        copyright notice, this list of conditions and the following
 *        disclaimer in the documentation and/or other materials
 *        provided with the distribution.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <arpa/inet.h>
#include "bfpga.h"

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

typedef unsigned int	BUInt;
typedef unsigned int	BUInt32;

int			fd;
BFpgaInfo		info;

volatile BUInt32*	fpgaRegs;
volatile BUInt32*	dmaRegs;
volatile BUInt32*	dma0Mem;
volatile BUInt32*	dma1Mem;

void hd8(void* data, unsigned int n){
	unsigned char*	d = (unsigned char*)data;
	unsigned		i;
	
	for(i = 0; i < n; i++){
		printf("%2.2x ", *d++);
		if((i & 0xF) == 0xF)
			printf("\n");
	}
	printf("\n");
}

void hd32(void* data, unsigned int n){
	unsigned int*	d = (unsigned int*)data;
	unsigned		i;
	
	for(i = 0; i < n; i++){
		printf("%8.8x ", *d++);
		if((i & 0x7) == 0x7)
			printf("\n");
	}
	printf("\n");
}

void dumpRegs(){
	printf("BFpgaId:		%x\n", ntohl(fpgaRegs[BFpgaId]));
	printf("BFpgaControl:		%x\n", ntohl(fpgaRegs[BFpgaControl]));
	printf("BFpgaStatus:		%x\n", ntohl(fpgaRegs[BFpgaStatus]));
	printf("BFpgaIntControl:	%x\n", ntohl(fpgaRegs[BFpgaIntControl]));
	printf("BFpgaIntStatus:		%x\n", ntohl(fpgaRegs[BFpgaIntStatus]));
	printf("\n");
}

void dumpDmaRegs(int chan){
	int			regsAddress = ((chan & 1) << 12) | ((chan / 2) << 8);
	int			sgregsAddress = ((4 + (chan & 1)) << 12) | ((chan / 2) << 8);
	volatile BUInt32*	regs = &dmaRegs[regsAddress / 4];
	volatile BUInt32*	sgregs = &dmaRegs[sgregsAddress / 4];
	
	printf("DMA Channel:    %d\n", chan);
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

		printf("SGmemory\n");
		if(chan)
			hd32((void*)dma1Mem, 64);
		else
			hd32((void*)dma0Mem, 64);
	}
}

#ifdef ZAP
int test1(){
	int			r;

	printf("Generate Interrupt\n");
	printf("BoardType: %08.8x\n", ntohl(fpgaRegs[DdcId]));

#ifdef ZAP
	fpgaRegs[DdcTestIrq] = 1;
#else
	if(r = ioctl(fd, BFPGA_CMD_IRQ, 0)){
		fprintf(stderr, "Error ioctl: %s\n", strerror(errno));
		return 1;
	}
#endif
	sleep(1);

	return 0;
}
#endif

int test2(){
	int			dmaFd;
	int			r;
	int			n;
	int			l;
	char			buf[1024];
	
	printf("Dma to FPGA\n");
	if((dmaFd = open("/dev/bfpga0-send0", O_RDWR)) < 0){
		fprintf(stderr, "Error opening device: %s\n", strerror(errno));
		return 1;
	}
	
	printf("DmaMem Mapped at: %p\n", dma0Mem);

	dumpDmaRegs(0);
	dumpDmaRegs(1);

	printf("Write data 0\n");
	memset(buf, 0x13, sizeof(buf));
	r = write(dmaFd, buf, 16);
	printf("Write ret: %d\n", r);
	
	sleep(1);

	printf("DmaEnd\n");	
	dumpDmaRegs(0);
	dumpDmaRegs(1);
	
	printf("dma0Memory\n");
	hd32((void*)&dma0Mem[4096 / 4], 16);

	printf("dma1Memory\n");
	hd32((void*)&dma1Mem[(4096-8) / 4], 8);
	hd32((void*)&dma1Mem[4096 / 4], 16);

	printf("IrqId:		%8.8x\n", dmaRegs[0x2000 / 4]);
	printf("IrqMask:	%8.8x\n", dmaRegs[0x2010 / 4]);
	printf("IrqPending:	%8.8x\n", dmaRegs[0x204C / 4]);

#ifndef ZAP
	printf("Write data 1\n");
	memset(buf, 0x14, sizeof(buf));
	r = write(dmaFd, buf, 16);
	printf("Write ret: %d\n", r);
#endif

	return 0;
}

#ifdef ZAP
int test3(){
	int			r;
	int			n;
	int			l;
	char			buf[1024];

	printf("DMA to FPGA\n");
	printf("DmaMem Mapped at: %p\n", dmaMem);
	printf("DmaMem Value: %x\n", dmaMem[0]);

	printf("Set FpdpFifoTxAddress: %x\n", info.dma0TxPhysAddress);
	fpgaRegs[FpdpFifoTxAddress] =  htonl(info.dma0TxPhysAddress);
	
	dumpRegs();

	printf("Start DMA\n");	
	fpgaRegs[FpdpFifoTxControl] =  htonl(0x80000000);
	
	sleep(1);
	dumpRegs();
	
	printf("Write some data\n");
	for(n = 0; n < 64; n++){
		dmaMem[n] = htonl(0x12340000 + n);
	}
	fpgaRegs[FpdpFifoTxWritePointer] = htonl(ntohl(fpgaRegs[FpdpFifoTxWritePointer]) + 8);
	
	sleep(1);
	dumpRegs();
	
	// Read back the data
	for(n = 0; n < 8; n++){
		printf("DdcFifoRx:	%x\n", ntohl(fpgaRegs[DdcFifoRx]));
		printf("DdcFifoRxCount:	%x\n", ntohl(fpgaRegs[DdcFifoRxCount]));
	}

	
	return 0;
}
#endif

int main(){
	int			r;
	int			n;
	int			l;
	char			buf[1024];
	
	if((fd = open("/dev/bfpga0", O_RDWR)) < 0){
		fprintf(stderr, "Error opening device: %s\n", strerror(errno));
		return 1;
	}

	printf("Board Opened\n");

	if((r = ioctl(fd, BFPGA_CMD_GETINFO, &info)) < 0){
		fprintf(stderr, "Error ioctl: %s\n", strerror(errno));
		return 1;
	}
	printf("RegsAddresses: %x(%x)\n", info.regs.physAddress, info.regs.length);

#ifdef ZAP
	if((fpgaRegs = (volatile BUInt32*)mmap(0, info.regs.length, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.regs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
#else
	if((fpgaRegs = (volatile BUInt32*)mmap(0, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
#endif
	
	printf("Regs Mapped at: %p\n", fpgaRegs);
	printf("Regs Value: %x\n", fpgaRegs[0]);

	if((dmaRegs = (volatile BUInt32*)mmap(0, info.dmaRegs.length, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.dmaRegs.physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	
	printf("DmaRegs Mapped at: %p\n", dmaRegs);
	printf("DmaRegs Value: %x\n", dmaRegs[0]);

	printf("dma0MemAddresses: %x(%x)\n", info.dmaChannels[0].physAddress, info.dmaChannels[0].length);
	if((dma0Mem = (volatile uint32_t*)mmap(0, info.dmaChannels[0].length, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.dmaChannels[0].physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	hd32((void*)dma0Mem, 16);

	printf("dma1MemAddresses: %x(%x)\n", info.dmaChannels[1].physAddress, info.dmaChannels[1].length);
	if((dma1Mem = (volatile uint32_t*)mmap(0, info.dmaChannels[1].length, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.dmaChannels[1].physAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	hd32((void*)dma1Mem, 16);

#ifdef ZAP
	printf("Initial state\n");
	dumpRegs();
#endif

//	test1();		// Interrupt
	test2();		// DMA to FPGA
//	test3();		// DMA from FPGA

	close(fd);
	return 0;
}
