/*******************************************************************************
 *	BeamLibBasic.h	Basic implementation of BeamLib functionality
 *	T.Barnaby,	Beam Ltd,	2020-04-10
 *******************************************************************************
 */
/**
 * @class	BeamLibBasic
 * @author	Terry Barnaby <terry.barnaby@beam.ltd.uk>
 * @date	2020-04-10
 * @version	0.0.1
 *
 * @brief
 * Basic implementation of BeamLib functionality
 *
 * @details
 * This provides some of the basic functionality from the larger BeamLib system.
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

#include <stdint.h>
#include <stdarg.h>
#include <semaphore.h>

// Snippets from Beam-lib
#if LDEBUG1
#define	dl1printf(fmt, a...)	tprintf(fmt, ##a)
#define	dl1hd32(data, nWords)	bhd32(data, nWords)
#else
#define	dl1printf(fmt, a...)
#define	dl1hd32(data, nWords)
#endif

#if LDEBUG2
#define	dl2printf(fmt, a...)	tprintf(fmt, ##a)
#define	dl2hd32(data, nWords)	bhd32(data, nWords)
#else
#define	dl2printf(fmt, a...)
#define	dl2hd32(data, nWords)
#endif

#if LDEBUG3
#define	dl3printf(fmt, a...)	tprintf(fmt, ##a)
#define	dl3hd32(data, nWords)	bhd32(data, nWords)
#else
#define	dl3printf(fmt, a...)
#define	dl3hd32(data, nWords)
#endif

#if LDEBUG4
#define	dl4printf(fmt, a...)	tprintf(fmt, ##a)
#define	dl4hd32(data, nWords)	bhd32(data, nWords)
#else
#define	dl4printf(fmt, a...)
#define	dl4hd32(data, nWords)
#endif

typedef bool		Bool;
typedef uint8_t		BUInt8;
typedef uint32_t	BUInt32;
typedef uint64_t	BUInt64;
typedef unsigned int	BUInt;

// Timeouts
typedef BUInt32			BTimeout;
const BTimeout	BTimeoutForever = 0xFFFFFFFF;		// Forever timeout

/// Semaphore class
class BSemaphore {
public:
				BSemaphore();
				BSemaphore(const BSemaphore& semaphore);
				~BSemaphore();
	
	Bool			wait(BTimeout timeoutUs = BTimeoutForever);		///< Wait for the semaphore
	void			set();							///< Set the semaphore

	int			getValue() const;
	BSemaphore&		operator=(const BSemaphore& semaphore);

private:
	sem_t			osema;
};

void tprintf(const char* fmt, ...);
void bhd8(void* data, BUInt32 n);
void bhd32(void* data,BUInt32 n);
