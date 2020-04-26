/*******************************************************************************
 *	BeamLibBasic.cpp	Basic implementation of BeamLib functionality
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
#define	LDEBUG1		0		// High level debug

#include <BeamLibBasic.h>
#include <stdio.h>
#include <time.h>
#include <sys/time.h>

BSemaphore::BSemaphore(){
	sem_init(&osema, 0, 0);
}

BSemaphore::BSemaphore(const BSemaphore& semaphore){
	sem_init(&osema, 0, semaphore.getValue());
}

BSemaphore& BSemaphore::operator=(const BSemaphore& semaphore){
	sem_destroy(&osema);
	sem_init(&osema, 0, semaphore.getValue());
	return *this;
}

BSemaphore::~BSemaphore(){
	sem_destroy(&osema);
}

void BSemaphore::set(){
	sem_post(&osema);
}

Bool BSemaphore::wait(BTimeout timeoutUs){
	int		ret;
	struct timeval	tv;
	struct timespec	ts;

	if(timeoutUs == BTimeoutForever){
		ret = !sem_wait(&osema);
	}
	else {
		gettimeofday(&tv, 0);
		ts.tv_sec = tv.tv_sec + timeoutUs / 1000000;
		ts.tv_nsec = (tv.tv_usec + timeoutUs % 1000000) * 1000;
		ts.tv_sec += (ts.tv_nsec / 1000000000);
		ts.tv_nsec %=  1000000000;

		ret = !sem_timedwait(&osema, &ts);
	}
	return ret;
}

int BSemaphore::getValue() const {
	int	v;
	
	sem_getvalue((sem_t*)&osema, &v);
	return v;
}

void tprintf(const char* fmt, ...){
	va_list		args;
	char		tbuf[64];
	char		buf[4096];
	struct timeval	tv;
	
	va_start(args, fmt);
	gettimeofday(&tv, 0);

	strftime(tbuf, sizeof(tbuf), "%H:%M:%S", localtime(&tv.tv_sec));
	sprintf(buf, "%s.%3.3d: %s", tbuf, tv.tv_usec/1000, fmt);

	vfprintf(stderr, buf, args);
}

void bhd8(void* data, BUInt32 n){
	BUInt8*		d = (BUInt8*)data;
	BUInt32		i;
	
	for(i = 0; i < n; i++){
		printf("%2.2x ", *d++);
		if((i & 0xF) == 0xF)
			printf("\n");
	}
	printf("\n");
}

void bhd32(void* data,BUInt32 n){
	BUInt32*	d = (BUInt32*)data;
	BUInt32		i;
	
	for(i = 0; i < n; i++){
		printf("%8.8x ", *d++);
		if((i & 0x7) == 0x7)
			printf("\n");
	}
	printf("\n");
}

// Get current time in seconds
double getTime(){
	struct timeval	tp;
	
	gettimeofday(&tp, NULL);
	return ((double) tp.tv_sec + (double) tp.tv_usec * 1e-6);
}
