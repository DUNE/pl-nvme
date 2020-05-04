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
 * The program accesses the FPGA system over the hosts PCIe bus using the Beam bfpga Linux driver. This interfaces with the Xilinx PCIe DMA IP.
 * The program uses a thread to respond to Nvme requests.
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

#include <NvmeAccess.h>
#include <stdio.h>
#include <getopt.h>

#define VERSION		"0.0.1"

/// Overal program control class
class Control : public NvmeAccess {
public:
			Control();
			~Control();

	int		init();					///< Initialise

	int		test1();				///< Run test1
	int		configureNvme();			///< Configure Nvme for operation
	int		test2();				///< Run test2
	int		test3();				///< Run test3
	int		test4();				///< Run test4
	int		test5();				///< Run test5
	int		test6();				///< Run test6
	int		test7();				///< Run test7

	int		test_misc();				///< Collection of misc tests

	void		dumpNvmeRegisters();			///< Dump the Nvme registers to stdout

public:
	// Params
	Bool		overbose;
	NvmeAccess	onvmeAccess;
};

Control::Control(){
	overbose = 0;
}

Control::~Control(){
}

int Control::init(){
	return NvmeAccess::init();
}

int Control::test1(){
	BUInt32	data[8];

	printf("Test1: Simple PCIe command register read, write and read.\n");

	printf("Configure PCIe for memory accesses\n");
	pcieRead(8, 4, 1, data);
	dl1printf("Commandreg: %8.8x\n", data[0]);

	data[0] |= 6;
	pcieWrite(10, 4, 1, data);

	pcieRead(8, 4, 1, data);
	dl1printf("Commandreg: %8.8x\n", data[0]);

	printf("Complete\n");

	return 0;
}

int Control::configureNvme(){
	int	e;
	BUInt32	data;

	printf("Configure Nvme for operation\n");
	
	// Perform reset
	reset();

#ifdef ZAP
	dumpNvmeRegisters();
	return 0;
#endif

#ifndef ZAP
	if(UseConfigEngine){	
		printf("Start configuration\n");
		writeNvmeStorageReg(4, 0x00000002);
		usleep(100000);
		readNvmeStorageReg(8, data); printf("Waited 100ms: Status: %8.8x\n", data);
	}
	else {
#ifdef ZAP
		// Setup Max payload, hardcoded for Seagate Nvme
		pcieRead(8, 4, 1, &data);
		printf("CommandReg: %8.8x\n", data);
		pcieRead(8, 0x34, 1, &data);
		printf("CapReg: %8.8x\n", data);
		pcieRead(8, 0x80, 1, &data);
		printf("Cap0: %8.8x\n", data);
		pcieRead(8, 0x84, 1, &data);
		printf("Cap1: %8.8x\n", data);
		pcieRead(8, 0x88, 1, &data);
		printf("Cap2: %8.8x\n", data);
		pcieRead(8, 0x8C, 1, &data);
		printf("Cap3: %8.8x\n", data);
		pcieRead(8, 0x90, 1, &data);
		printf("Cap4: %8.8x\n", data);

		pcieRead(8, 0x84, 1, &data);
		printf("MaxPayloadSizeSupported: %d\n", data & 0x07);

		// This should set device for 256 byte payloads. It probably does but packets are not received from the Nvme.
		//  Perhaps the Xilinx Pcie Gen3 block is dropping them although it is set for 1024 byte max packets.
		pcieRead(8, 0x88, 1, &data);
		printf("MaxPayloadSize: %8.8x %d\n", data, (data >> 5) & 0x07);
		printf("MaxReadSize: %8.8x %d\n", data, (data >> 12) & 0x07);
		data = (data & 0xFFFFFF1F) | (1 << 5);
		pcieWrite(10, 0x88, 1, &data);
		pcieRead(8, 0x88, 1, &data);
		printf("MaxPayloadSize: %8.8x %d\n", data, (data >> 5) & 0x07);
		//exit(0);
#endif

		// Stop controller
		if(e = writeNvmeReg32(0x14, 0x00460000)){
			printf("Error: %d\n", e);
			return 1;
		}
		usleep(10000);

		// Setup Nvme registers
		// Disable interrupts
		if(e = writeNvmeReg32(0x0C, 0xFFFFFFFF)){
			printf("Error: %d\n", e);
			return 1;
		}

		// Admin queue lengths
		if(e = writeNvmeReg32(0x24, ((oqueueNum - 1) << 16) | (oqueueNum - 1))){
			printf("Error: %d\n", e);
			return 1;
		}

		if(UseQueueEngine){
			// Admin request queue base address
			if(e = writeNvmeReg64(0x28, 0x02000000)){
				printf("Error: %d\n", e);
				return 1;
			}

			// Admin reply queue base address
			//if(e = writeNvmeReg64(0x30, 0x01100000)){		// Get replies sent directly to host
			if(e = writeNvmeReg64(0x30, 0x02100000)){		// Get replies sent via QueueEngine
				printf("Error: %d\n", e);
				return 1;
			}
		}
		else {
			// Admin request queue base address
			if(e = writeNvmeReg64(0x28, 0x01000000)){
				printf("Error: %d\n", e);
				return 1;
			}

			// Admin reply queue base address
			if(e = writeNvmeReg64(0x30, 0x01100000)){
				printf("Error: %d\n", e);
				return 1;
			}
		}

		// Start controller
		if(e = writeNvmeReg32(0x14, 0x00460001)){
			printf("Error: %d\n", e);
			return 1;
		}
		usleep(100000);

		//dumpNvmeRegisters();

#ifdef ZAP
		// Test the queue engine
		printf("Create/delete IO queue 1 for replies repeatidly\n");

		if(UseQueueEngine){
			for(int c = 0; c < 10; c++){
				printf("Do: %d\n", c);

				nvmeRequest(0, 0x05, 0x02110000, 0x00070001, 0x00000001);
				sleep(1);

				nvmeRequest(0, 0x04, 0x02110000, 0x00070001, 0x00000001);
				sleep(1);
			}
		}
		else {
			for(int c = 0; c < 10; c++){
				printf("Do: %d\n", c);

				nvmeRequest(0, 0x05, 0x00110000, 0x00070001, 0x00000001);
				sleep(1);

				nvmeRequest(0, 0x04, 0x00110000, 0x00070001, 0x00000001);
				sleep(1);
			}
		}
		return 0;
#endif

		if(UseQueueEngine){
			// Create an IO queue
			if(overbose)
				printf("Create IO queue 1 for replies\n");

			nvmeRequest(0, 0x05, 0x02110000, 0x00070001, 0x00000001);

			// Create an IO queue
			if(overbose)
				printf("Create IO queue 1 for requests\n");

			nvmeRequest(0, 0x01, 0x02010000, 0x00070001, 0x00010001);
		}
		else {
			// Create an IO queue
			if(overbose)
				printf("Create IO queue 1 for replies\n");

			nvmeRequest(0, 0x05, 0x01110000, 0x00070001, 0x00000001);

			// Create an IO queue
			if(overbose)
				printf("Create IO queue 1 for requests\n");

			nvmeRequest(0, 0x01, 0x01010000, 0x00070001, 0x00010001);
		}
	}
#endif

	//dumpNvmeRegisters();
	
	return 0;
}

int Control::test2(){
	int	e;
	
	printf("Test2: Configure Nvme\n");
	if(e = configureNvme())
		return e;

	//dumpNvmeRegisters();

	return 0;
}

int Control::test3(){
	int	e;
	
	printf("Test3: Get info from Nvme\n");

	if(e = configureNvme())
		return e;

	printf("Get info\n");
	//nvmeRequest(0, 0x06, 0x01F00000, 0x00000000);		// Namespace info
	nvmeRequest(0, 0x06, 0x01F00000, 0x00000001);		// Controller info
	printf("\n");
	sleep(2);

	return 0;
}

int Control::test4(){
	int	e;
	int	numBlocks = 8;
	
	printf("Test4: Read blocks\n");
	
	if(e = configureNvme())
		return e;

	printf("Perform block read\n");
	memset(odataBlockMem, 0x01, sizeof(odataBlockMem));

	nvmeRequest(1, 0x02, 0x01800000, 0x0000000, 0x00000000, numBlocks-1);	// Perform read
	usleep(100000);

	printf("DataBlock:\n");
	bhd32a(odataBlockMem, numBlocks*512/4);

	return 0;
}

int Control::test5(){
	int	e;
	int	a;
	BUInt32	r;
	int	numBlocks = 8;
	
	printf("Test5: Write blocks\n");
	
	if(e = configureNvme())
		return e;

	srand(time(0));
	r = rand();
	printf("Perform block write with: 0x%2.2x\n", r & 0xFF);
	for(a = 0; a < 8192; a++)
		odataBlockMem[a] = ((r & 0xFF) << 24) + a;

	nvmeRequest(1, 0x01, 0x01800000, 0x00000000, 0x00000000, numBlocks-1);	// Perform write

	return 0;
}

int Control::test6(){
	int	e;
	int	a;
	BUInt32	v;
	BUInt32	n;
	BUInt32	t;
	double	r;
	double	ts;

	printf("Test6: Enable FPGA write blocks\n");
	
	if(e = configureNvme())
		return e;

	//dumpRegs();
		
	printf("Stats\n");
	readNvmeStorageReg(32, v);
	printf("NvmeWrite: status:    %8.8x\n", v);
	readNvmeStorageReg(36, v);
	printf("NvmeWrite: numBlocks: %u\n", v);
	readNvmeStorageReg(40, v);
	printf("NvmeWrite: timeUs:    %u\n", v);

	// Start off NvmeWrite engine
	printf("\nStart NvmeWrite engine\n");
	writeNvmeStorageReg(4, 0x00000004);

#ifdef ZAP	
	ts = getTime();
	n = 0;
	while(n != 262144){
		readNvmeStorageReg(36, n);
		printf("NvmeWrite: numBlocks: %u\n", n);
	}
	printf("Time was: %f\n", getTime() - ts);
#else
	sleep(2);
#endif

#ifdef ZAP
	printf("\nPerform block read\n");
	memset(odataBlockMem, 0x0, sizeof(odataBlockMem));
	nvmeRequest(1, 0x02, 0x01800000, 0x0000000, 0x00000000, 3);	// Four blocks
	usleep(100000);

	printf("DataBlock:\n");
	bhd32(odataBlockMem, 1*512/4);
#endif
	
	printf("Stats\n");
	readNvmeStorageReg(32, v);
	printf("NvmeWrite: status:    %8.8x\n", v);
	readNvmeStorageReg(36, n);
	printf("NvmeWrite: numBlocks: %u\n", n);
	readNvmeStorageReg(40, t);
	printf("NvmeWrite: timeUs:    %u\n", t);
	
	r = (4096.0 * n / (1e-6 * t));
	printf("NvmeWrite: rate:      %f MBytes/s\n", r / (1024 * 1024));

	return 0;
}

int Control::test7(){
	int	e;
	int	a;
	BUInt32	r;
	int	numBlocks = 8;
	
	printf("Test7: Write blocks, 4 at a time\n");
	
	if(e = configureNvme())
		return e;

	srand(time(0));
	r = rand();
	printf("Perform block write with: 0x%2.2x\n", r & 0xFF);
	for(a = 0; a < 8192; a++)
		odataBlockMem[a] = ((r & 0xFF) << 24) + a;

	nvmeRequest(1, 0x01, 0x01800000, 0x00000000, 0x00000000, numBlocks-1);	// Perform write
	nvmeRequest(1, 0x01, 0x01801000, 0x00000000, 0x00000000, numBlocks-1);	// Perform write
	nvmeRequest(1, 0x01, 0x01802000, 0x00000000, 0x00000000, numBlocks-1);	// Perform write
	nvmeRequest(1, 0x01, 0x01803000, 0x00000000, 0x00000000, numBlocks-1);	// Perform write

	sleep(2);
	
	return 0;
}


int Control::test_misc(){
	BUInt32	address = 0;
	BUInt32	data[8];
	BUInt32	data32;
	BUInt64	data64;
	BUInt32	a;
	int	e;
	int	n;

	printf("Test_misc: Collection of misc tests\n");
	
	if(e = configureNvme())
		return e;

	printf("Get info\n");
	nvmeRequest(0, 0x06, 0x01F00000, 0x00000001);
	sleep(1);

	printf("\nGet namespace list\n");
	nvmeRequest(0, 0x06, 0x01F00000, 0x00000002);
	sleep(1);

	printf("\nSet asynchonous feature\n");
	nvmeRequest(0, 0x09, 0x01F00000, 0x0000000b, 0xFFFFFFFF);
	sleep(1);

	printf("\nGet asynchonous feature\n");
	nvmeRequest(0, 0x0A, 0x01F00000, 0x0000000b);
	sleep(1);


	printf("\nGet log page\n");
	nvmeRequest(0, 0x02, 0x01F00000, 0x00100001, 0x00000000, 0);
	sleep(1);

	printf("\nGet asynchonous event\n");
	nvmeRequest(0, 0x0C, 0x00000000, 0x00000000, 0x00000000, 0);
	sleep(1);

	return 0;
}

void Control::dumpNvmeRegisters(){
	int	e;
	BUInt	a;
	BUInt32	data;
	
	printf("Nvme regs\n");
	for(a = 0; a < 16; a++){
		if(e = readNvmeReg32(a * 4, data)){
			printf("Read register Error: %d\n", e);
			return;
		}
		printf("Reg: 0x%3.3x 0x%8.8x\n", a * 4, data);
	}
}



void usage(void) {
	fprintf(stderr, "test_nvme: Version: %s\n", VERSION);
	fprintf(stderr, "Usage: test_nvme [options] <testname>\n");
	fprintf(stderr, "This program provides the ability perform access tests to an Nvme device on a FPGA development board\n");
	fprintf(stderr, " -help,-h              - Help on command line parameters\n");
	fprintf(stderr, " -v                    - Verbose\n");
	fprintf(stderr, " -l                    - List tests\n");
}

static struct option options[] = {
		{ "h",			0, NULL, 0 },
		{ "help",		0, NULL, 0 },
		{ "v",			0, NULL, 0 },
		{ "l",			0, NULL, 0 },
		{ 0,0,0,0 }
};
int main(int argc, char** argv){
	int		err;
	int		optIndex = 0;
	const char*	s;
	int		c;
	Control		control;
	Bool		listTests = 0;
	const char*	test = 0;

	while((c = getopt_long_only(argc, argv, "", options, &optIndex)) == 0){
		s = options[optIndex].name;
		if(!strcmp(s, "help") || !strcmp(s, "h")){
			usage();
			return 1;
		}
		else if(!strcmp(s, "v")){
			control.overbose = 1;
		}
		else if(!strcmp(s, "l")){
			listTests = 1;
		}
		else {
			fprintf(stderr, "Error: No option: %s\n", s);
			usage();
			return 1;
		}
	}
	
	if(listTests){
		printf("test1: Simple PCIe command register read, write and read.\n");
		printf("test2: Configure Nvme\n");
		printf("test3: Get info from Nvme\n");
		printf("test4: Read block\n");
		printf("test5: Write block\n");
		printf("test_misc: Collection of misc tests\n");
	}
	else {
		if((argc - optind) != 1){
			fprintf(stderr, "Requires the test name\n");
			usage();
			return 1;
		}
		test = argv[optind++];

		if(err = control.init()){
			return err;
		}

		if(!strcmp(test, "test1")){
			err = control.test1();
		}
		else if(!strcmp(test, "test2")){
			err = control.test2();
		}
		else if(!strcmp(test, "test3")){
			err = control.test3();
		}
		else if(!strcmp(test, "test4")){
			err = control.test4();
		}
		else if(!strcmp(test, "test5")){
			err = control.test5();
		}
		else if(!strcmp(test, "test6")){
			err = control.test6();
		}
		else if(!strcmp(test, "test7")){
			err = control.test7();
		}
		else if(!strcmp(test, "test_misc")){
			err = control.test_misc();
		}
		else {
			fprintf(stderr, "No such test: %s\n", test);
		}
	}

	return 0;
}
