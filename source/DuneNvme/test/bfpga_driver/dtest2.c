/*******************************************************************************
 *	Dtest2.c	BFPGA Linux Device Driver Test
 *			T.Barnaby,	BEAM Ltd,	2020-03-07
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

int main(){
	int	fd;
	int	r;
	char	buf[1024];
	
	if((fd = open("/dev/bfpga0-recv0", O_RDWR)) < 0){
		fprintf(stderr, "Error opening device: %s\n", strerror(errno));
		return 1;
	}

	printf("Board Opened\n");
	memset(buf, 0, sizeof(buf));

	printf("Perform read\n");
	r = read(fd, buf, 1024);
	printf("Read: %d\n", r);
	hd32(buf, 16);

	close(fd);

	return 0;
}
