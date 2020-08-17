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
 * Basic implementation of BeamLib functionality for simple progeams.
 *
 * @details
 * This provides some of the basic functionality from the larger BeamLib system.
 *
 * @copyright 2020 Beam Ltd, Apache License, Version 2.0
 * Copyright 2020 Beam Ltd
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
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

#if LDEBUG5
#define	dl5printf(fmt, a...)	tprintf(fmt, ##a)
#define	dl5hd32(data, nWords)	bhd32(data, nWords)
#else
#define	dl5printf(fmt, a...)
#define	dl5hd32(data, nWords)
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

// Simple Byte Fifo
class BFifoBytes {
public:
			BFifoBytes(BUInt size);
			~BFifoBytes();

	void		clear();

	BUInt		size();						///< Returns fifo size
	int		resize(BUInt size);				///< Resize FIFO, clears it as well

	BUInt		writeAvailable();				///< How many items that can be written
	int		write(const void* data, BUInt num);		///< Write a set of items. Can only write a maximum of writeAvailableChunk() to save going beyond end of FIFO buffer

	BUInt		readAvailable();				///< How many items are available to read
	int		read(void* data, BUInt num);			///< Read a set of items

protected:
	BUInt		osize;						///< The size of the FIFO
	char*		odata;						///< FIFO memory buffer
	volatile BUInt	owritePos;					///< The write pointer
	volatile BUInt	oreadPos;					///< The read pointer
};


void tprintf(const char* fmt, ...);			///< Printf with current time
void bhd8(void* data, BUInt32 n);			///< Print hex dump of data as 8bit wide entities
void bhd32(void* data,BUInt32 n);			///< Print hex dump of data as 32bit wide entities
void bhd32a(void* data,BUInt32 n);			///< Print hex dump of data as 32bit wide entities, with address
double getTime();					///< Get current time in seconds
