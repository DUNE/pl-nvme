/*******************************************************************************
 *	Dtest2.c	BFPGA Linux Device Driver Test
 *			T.Barnaby,	BEAM Ltd,	2012-01-03
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

int			fd;
BFpgaInfo			info;
volatile uint32_t*	bfpgaRegs;
volatile uint32_t*	dmaMem;

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
		printf("%8.8x ", ntohl(*d++));
		if((i & 0x7) == 0x7)
			printf("\n");
	}
	printf("\n");
}

void bfpgaDumpRegs(){
	printf("BFpgaId:			%x\n", ntohl(bfpgaRegs[BFpgaId]));
	printf("BFpgaControl:		%x\n", ntohl(bfpgaRegs[BFpgaControl]));
	printf("BFpgaStatus:		%x\n", ntohl(bfpgaRegs[BFpgaStatus]));
	printf("BFpgaIntControl:		%x\n", ntohl(bfpgaRegs[BFpgaIntControl]));
	printf("BFpgaIntStatus:		%x\n", ntohl(bfpgaRegs[BFpgaIntStatus]));
	printf("BFpgaSubBandSize:		%x\n", ntohl(bfpgaRegs[BFpgaSubBandSize]));
	printf("BFpgaSubBandNum:		%x\n", ntohl(bfpgaRegs[BFpgaSubBandNum]));

	printf("BFpgaFpdpTxControl:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpTxControl]));
	printf("BFpgaFpdpTxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpTxAddress]));
	printf("BFpgaFpdpTxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpTxPointer]));
	printf("BFpgaFpdpTxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpTxAvailable]));

	printf("BFpgaFpdpRxControl:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpRxControl]));
	printf("BFpgaFpdpRxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpRxAddress]));
	printf("BFpgaFpdpRxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpRxPointer]));
	printf("BFpgaFpdpRxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaFpdpRxAvailable]));

	printf("BFpgaDdcTxControl:	%x\n", ntohl(bfpgaRegs[BFpgaDdcTxControl]));
	printf("BFpgaDdcTxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaDdcTxAddress]));
	printf("BFpgaDdcTxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaDdcTxPointer]));
	printf("BFpgaDdcTxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaDdcTxAvailable]));

	printf("BFpgaDdcRxControl:	%x\n", ntohl(bfpgaRegs[BFpgaDdcRxControl]));
	printf("BFpgaDdcRxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaDdcRxAddress]));
	printf("BFpgaDdcRxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaDdcRxPointer]));
	printf("BFpgaDdcRxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaDdcRxAvailable]));
#ifndef ZAP
	printf("BFpgaTestTxControl:	%x\n", ntohl(bfpgaRegs[BFpgaTestTxControl]));
	printf("BFpgaTestTxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaTestTxAddress]));
	printf("BFpgaTestTxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaTestTxPointer]));
	printf("BFpgaTestTxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaTestTxAvailable]));

	printf("BFpgaTestRxControl:	%x\n", ntohl(bfpgaRegs[BFpgaTestRxControl]));
	printf("BFpgaTestRxAddress:	%x\n", ntohl(bfpgaRegs[BFpgaTestRxAddress]));
	printf("BFpgaTestRxPointer:	%x\n", ntohl(bfpgaRegs[BFpgaTestRxPointer]));
	printf("BFpgaTestRxAvailable:	%x\n", ntohl(bfpgaRegs[BFpgaTestRxAvailable]));
#endif
	printf("BFpgaFifoTxCount:		%x\n", ntohl(bfpgaRegs[BFpgaFifoTxCount]));
	printf("BFpgaFifoRxCount:		%x\n", ntohl(bfpgaRegs[BFpgaFifoRxCount]));
	printf("\n");
}

int test1(){
	int	r;
	int	f;
	char	buf[512];
	int	n;
//	char*	bitFile = "bfpgaLedTest.bit";
	char*	bitFile = "bfpga.bit";

	printf("Load Fpga\n");
	if((f = open(bitFile, R_OK)) < 0){
		fprintf(stderr, "Error: Unable to open bit file, %s: %s\n", bitFile, strerror(errno));
		return 1;
	}

	printf("Set program\n");
	if(r = ioctl(fd, BFPGA_CMD_PROGRAM_START, 0)){
		fprintf(stderr, "Error: ioctl: %s\n", strerror(errno));
		return 1;
	}
	
	// Write data
	printf("Write data\n");
	while((n = read(f, buf, sizeof(buf))) > 0){
//		printf("Write: %d\n", n);
		if((r = write(fd, buf, n)) <= 0){
			fprintf(stderr, "Error: write: %s\n", strerror(errno));
			return 1;
		}
	}
	
	// Check
	printf("Check programed Ok\n");
	if(r = ioctl(fd, BFPGA_CMD_PROGRAM_END, 0)){
		fprintf(stderr, "Error: program failed: %s\n", strerror(errno));
		return 1;
	}

	return 0;
}

int main(){
	int			r;
	
	if((fd = open("/dev/bfpga0", O_RDWR)) < 0){
		fprintf(stderr, "Error opening device: %s\n", strerror(errno));
		return 1;
	}

	printf("Board Opened\n");

	if((r = ioctl(fd, BFPGA_CMD_GETINFO, &info)) < 0){
		fprintf(stderr, "Error ioctl: %s\n", strerror(errno));
		return 1;
	}

	if((bfpgaRegs = (volatile uint32_t*)mmap(0, info.regsLen, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.regsPhysAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}
	
	printf("RegsAddresses: %x(%x)\n", info.regsPhysAddress, info.regsLen);
	printf("DmaMemAddresses: %x(%x)\n", info.dma0TxPhysAddress, info.dma0TxLen);
	if((dmaMem = (volatile uint32_t*)mmap(0, info.dma0TxLen, PROT_READ|PROT_WRITE, MAP_SHARED, fd, info.dma0TxPhysAddress)) == 0){
		fprintf(stderr, "Error mmap: %s\n", strerror(errno));
		return 1;
	}

	printf("Initial state\n");
//	bfpgaDumpRegs();

	test1();		// Load Bitfile
//	test1();		// Interrupt
//	test2();		// DMA to host
//	test3();		// DMA to FPGA

	close(fd);
	return 0;
}
