/*******************************************************************************
 *	BFpga.h		BFpga FPGA device driver definititions
 *	T.Barnaby,	BEAM Ltd,	2020-03-05
 *******************************************************************************
 *
 * Copyright (c) 2020 BEAM Ltd. All rights reserved.
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
#ifndef _BFPGA_H
#define _BFPGA_H

#define BFPGA_CMD_GETINFO		_IOR('Z', 0, BFpgaInfo)
#define BFPGA_CMD_GET_CONTROL		_IOR('Z', 1, uint32_t)
#define BFPGA_CMD_SET_CONTROL		_IOW('Z', 2, uint32_t)
#define BFPGA_CMD_RESET			_IO('Z', 3)

typedef struct {
	uint64_t	physAddress;
	uint64_t	length;
} BFpgaMem;

typedef struct {
	BFpgaMem	regs;
	BFpgaMem	dmaRegs;
	BFpgaMem	dmaChannels[8];
} BFpgaInfo;

// FPGA DDC Control Registers
const int	BFpgaId			= 0x0000;	// Firmware ID
const int	BFpgaControl		= 0x0001;	// Control
const int	BFpgaStatus		= 0x0002;	// Status
const int	BFpgaIntControl		= 0x0003;	// Interrupt Enables
const int	BFpgaIntStatus		= 0x0004;	// Interrupt Status

#endif
