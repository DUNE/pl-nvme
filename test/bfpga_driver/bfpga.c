/*******************************************************************************
 *	BFpga.c		BFpga FPGA device driver
 *	T.Barnaby,	BEAM Ltd,	2020-03-05
 *******************************************************************************
 *
 * This is a simple test driver for accessing FPGA hardware using the Xilinx XDMA IP core.
 * It is designed to aid testing of the host to FPGA interface and FPGA designs.
 * Being simple it is easy to debug the communications.
 *
 * It supports a simple memory mapped register interface that can be mapped to
 * the user space applications memory area. The Xilinx XDMA IP core provides an
 * AXI4-Lite interface for this on the FPGA.
 * It also supports up to 8 DMA channels. These unidirectional DMA streams
 * can be configured to function in either direction.
 * The Xilinx XDMA IP provides up to 8 AXI4 streams on the FPGA.
 * The driver creates a physically contiguous memory region for each DMA channel of a
 * fixed size. This simplifies the DMA as multiple scatter/gather regions are not needed.
 * For simplicty data is coped from/to the applications user space memort from these regions
 * by the driver. It would be possible to map these regions into the applications memory if
 * wanted for greater performance.
 * The Xilinx XDMA PCIe IP core manual, PG195, should be looked at for information on
 * the hardware interface that this driver uses.
 *
 * As stated it is simple, lots of improvements could be had, but it is relatively
 * easy to use and to debug bcuase of its simplicity.
 *
 * There is some problem with interrupt status reporting. Not sure if this is the test FPGA hardware
 * design or someing in this driver. It appears that the end of dma status interrupt is lost occassionaly.
 * Here we force a retest of status in the wait loops if a timeout occures.
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
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/pci.h>
#include <linux/init.h>
#include <linux/cdev.h>
#include <linux/interrupt.h>
#include <linux/version.h>
#include <linux/wait.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/spinlock.h>
#include <linux/delay.h>
#include <asm/ioctls.h>
#include <asm/uaccess.h>
#include <asm/irq.h>
#include <asm/set_memory.h>
#include "bfpga.h"

#define LDEBUG1		0		// Basic debuging
#define LDEBUG2		0		// Detailed debuging
#define LDEBUG3		0		// Interrupt debuging

#if LDEBUG1
#define	dl1printk(fmt, a...)       printk(fmt, ##a);
#else
#define	dl1printk(fmt, a...)
#endif

#if LDEBUG2
#define	dl2printk(fmt, a...)       printk(fmt, ##a);
#else
#define	dl2printk(fmt, a...)
#endif

#if LDEBUG3
#define	dl3printk(fmt, a...)       printk(fmt, ##a);
#else
#define	dl3printk(fmt, a...)
#endif

#define	VERSION			"1.2.0"
#define NAME			"bfpga"
#define NAME_PREFIX		"bfpga: "
#define MAX_NUM_CARDS		1

// DMA registers
#define DMA_ID				0x00
#define DMA_CONTROL			0x04
#define DMA_STATUS			0x40
#define DMA_STATUS_CLR			0x44
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

// IRQ registers
#define IRQ_MASK			0x2010
#define IRQ_MASK_CLEAR			0x2018
#define IRQ_PENDING			0x204C


typedef struct {
	uint64_t		physAddress;
	unsigned		len;
	void __iomem*		address;
} MemMap;

typedef struct {
	uint32_t		control;
	uint32_t		len;
	uint64_t		srcAddress;
	uint64_t		destAddress;
	uint64_t		nextDesc;
} DmaDesc;

#define DmaDescMagic		0xad4b0000
#define DmaDescEop		0x00000010
#define DmaDescInt		0x00000002
#define DmaDescStop		0x00000001

typedef struct {
	uint32_t		channel;		// The DMA channel number
	bool			c2h;			// If this is a card to host DMA channel
	uint32_t		devChannel;		// The devices channel number
	uint32_t		registers;		// Register offset in DMA registers for this channel
	uint8_t*		dmaDescs;
	dma_addr_t		dmaDescsPhysAddress;
	uint32_t		dmaBufferLen;
	uint8_t*		dmaBuffer;
	dma_addr_t		dmaPhysAddress;
	DmaDesc*		dmaDesc;
	uint32_t		available;
	wait_queue_head_t	event;
	bool			waitForEvent;
	uint32_t		nTrans;
} DmaChan;

typedef struct DeviceData_struct {
	int			opened;
	struct pci_dev*		pdev;
	struct cdev		cdev;
	struct device*		device;
	MemMap			regs;
	MemMap			dmaRegs;
	uint32_t		numChannels;		// The number of DMA channels
	DmaChan			dmaChannels[8];
	__iomem char*		ccsrRegs;
	__iomem u8*		cfpgaRegs;
} DeviceData;

static void bfpga_start(DeviceData* dev);
static void bfpga_stop(DeviceData* dev);
static void bfpga_process_events(DeviceData* dev, bool processStuck);

// Settings
const int	DmaBufferLen		= (10 * PAGE_SIZE);		// DMA Buffer length


static struct class*		class;
static int			cardsNum;
static DeviceData		cards[MAX_NUM_CARDS];
static dev_t			firstDev;
static spinlock_t		nextDevLock;

static struct pci_device_id bfpga_ids[] = {
	{ PCI_VENDOR_ID_XILINX, 0x8014, PCI_VENDOR_ID_XILINX, 0x0007 },
	{ PCI_VENDOR_ID_XILINX, 0x8024, PCI_VENDOR_ID_XILINX, 0x0007 },
	{ PCI_VENDOR_ID_XILINX, 0x8034, PCI_VENDOR_ID_XILINX, 0x0007 },
	{ 0, }
};
MODULE_DEVICE_TABLE(pci, bfpga_ids);

#if LDEBUG1
static void hd8(void* data, unsigned int n){
	unsigned char*	d = (unsigned char*)data;
	unsigned		i;
	
	for(i = 0; i < n; i++){
		printk(KERN_CONT "%2.2x ", *d++);
		if((i & 0xF) == 0xF)
			printk("\n");
	}
	printk("\n");
}

static void hd32(void* data, unsigned int n){
	unsigned int*	d = (unsigned int*)data;
	unsigned		i;
	
	for(i = 0; i < n; i++){
		printk(KERN_CONT "%8.8x ", *d++);
		if((i & 0x7) == 0x7)
			printk("\n");
	}
	printk("\n");
}
#endif

// Register access
static void reg_write(DeviceData* dev, uint32_t address, uint32_t data){
	iowrite32(data, &((uint32_t*)dev->regs.address)[address]);
}

static uint32_t reg_read(DeviceData* dev, uint32_t address){
	return ioread32(&((uint32_t*)dev->regs.address)[address]);
}

static void dma_reg_write(DeviceData* dev, uint32_t address, uint32_t data){
	iowrite32(data, &((uint32_t*)dev->dmaRegs.address)[address/4]);
}

static uint32_t dma_reg_read(DeviceData* dev, uint32_t address){
	return ioread32(&((uint32_t*)dev->dmaRegs.address)[address/4]);
}


static int bfpga_reset(DeviceData* dev){
	return 0;
}

static int dma_init(DeviceData* dev, uint32_t channel, bool c2h, uint32_t devChannel){
	DmaChan*	dma;
	DmaDesc*	dmaDesc;
	uint32_t	regSgAddress;

	if(channel > 7)
		return -1;
		
	dma = &dev->dmaChannels[channel];
	dma->channel = channel;
	dma->c2h = c2h;
	dma->devChannel = devChannel;
	dma->dmaBufferLen = DmaBufferLen;
	dma->registers = (dma->c2h << 12) | (dma->devChannel << 8);
	dma->available = 0;
	dma->waitForEvent = 0;
	dma->nTrans = 0;
	
	regSgAddress = ((4 + dma->c2h) << 12) | (dma->devChannel << 8);

	//dl1printk("dma_init: %p %p %d %p\n", dev->device, &dev->pdev->dev, dma->dmaBufferLen, &dma->dmaPhysAddress);

	// Allocate DMA descriptor and metadata uncached memory area
	if(!(dma->dmaDescs = dma_alloc_coherent(&dev->pdev->dev, PAGE_SIZE, &dma->dmaDescsPhysAddress, GFP_KERNEL))){
		printk(KERN_ERR NAME_PREFIX "DMA allocation failed\n");
		return -ENODEV;
	}
	//dl1printk("dma_init: Descriptors: phys: %llx virtual: %p\n", dma->dmaDescsPhysAddress, dma->dmaDescs);
	set_memory_uc((unsigned long)dma->dmaDescs, 1);

	// Allocate data buffer
	if(!(dma->dmaBuffer = dma_alloc_coherent(&dev->pdev->dev, dma->dmaBufferLen, &dma->dmaPhysAddress, GFP_KERNEL))){
		printk(KERN_ERR NAME_PREFIX "DMA allocation failed\n");
		return -ENODEV;
	}
	//dl1printk("dma_init: phys: %llx virtual: %p\n", dma->dmaPhysAddress, dma->dmaBuffer);
	//set_memory_uc((unsigned long)dma->dmaBuffer, (dma->dmaBufferLen/PAGE_SIZE));

	init_waitqueue_head(&dma->event);

	// Setup DMA descriptors
	dmaDesc = (DmaDesc*)dma->dmaDescs;
	dma->dmaDesc = dmaDesc;
	
	if(dma->c2h){
		dmaDesc[0].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[0].len = 0;
		dmaDesc[0].srcAddress = dma->dmaDescsPhysAddress + PAGE_SIZE - 8;	// Location of return metadata
		dmaDesc[0].destAddress = dma->dmaPhysAddress;
		dmaDesc[0].nextDesc = dma->dmaDescsPhysAddress + sizeof(DmaDesc);

		dmaDesc[1].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[1].len = 0;
		dmaDesc[1].srcAddress = 0;
		dmaDesc[1].destAddress = 0;
		dmaDesc[1].nextDesc = 0;
	}
	else {
		dmaDesc[0].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[0].len = 0;
		dmaDesc[0].srcAddress = dma->dmaPhysAddress;
		dmaDesc[0].destAddress = 0;
		dmaDesc[0].nextDesc = dma->dmaDescsPhysAddress + sizeof(DmaDesc);

		dmaDesc[1].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[1].len = 0;
		dmaDesc[1].srcAddress = 0;
		dmaDesc[1].destAddress = 0;
		dmaDesc[1].nextDesc = 0;
		
		dma->available = dma->dmaBufferLen;
	}

	// Setup registers to point to descriptors
	dma_reg_write(dev, regSgAddress + DMASC_ADDRESS_LOW, (dma->dmaDescsPhysAddress & 0xFFFFFFFF));
	dma_reg_write(dev, regSgAddress + DMASC_ADDRESS_HIGH, ((dma->dmaDescsPhysAddress >> 32) & 0xFFFFFFFF));
	dma_reg_write(dev, regSgAddress + DMASC_NEXT, 0);
	dma_reg_write(dev, regSgAddress + DMASC_CREDITS, 0);
	
	//dl1printk("dma_init: %d %d: 0x%8.8x 0x%8.8x\n", dma->channel, dma->c2h, dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_HIGH), dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_LOW));
	
	// Setup control registers
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0);
	dma_reg_write(dev, dma->registers + DMA_INT_MASK, 0x06);	

	//dl1printk("dma_init: %x %p %x %d\n", dma->registers, dma->dmaBuffer, (int)dma->dmaPhysAddress, dma->dmaBufferLen);

	return 0;
}

static void dma_release(DeviceData* dev, DmaChan* dma){
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0);

//	dl1printk("dma_release: %p %p %d %p\n", dev->device, &dev->pdev->dev, dma->len, &dma->dmaPhysAddress);
	if(dma->dmaBuffer){
		dma_free_coherent(&dev->pdev->dev, dma->dmaBufferLen, dma->dmaBuffer, dma->dmaPhysAddress);
		dma->dmaBuffer = 0;
	}
	if(dma->dmaDescs){
		dma_free_coherent(&dev->pdev->dev, PAGE_SIZE, dma->dmaDescs, dma->dmaDescsPhysAddress);
		dma->dmaDescs = 0;
	}
}

static void dma_start(DeviceData* dev, DmaChan* dma, uint32_t len){
	dl1printk("dma_start: channel: %d regs: 0x%x\n", dma->channel, dma->registers);

	// Setup DMA channel and start running
	dma->dmaDesc[0].len = len;

	//printk("dma_start: %d complete: %d\n", dma->channel, dma_reg_read(dev, dma->registers + DMA_COMPLETE));
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0x07);

#ifdef ZAP	
	udelay(10000);
	printk("Completed: %8.8x\n", dma_reg_read(dev, dma->registers + DMA_COMPLETE));
	printk("Status0: %8.8x\n", dma_reg_read(dev, dma->registers + DMA_STATUS));			// Warning will clear the status
	printk("Irqpending: %8.8x\n", dma_reg_read(dev, IRQ_PENDING));
#endif
}

static void dma_stop(DeviceData* dev, DmaChan* dma){
	// Stop DMA channel running
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0);
}

static uint32_t dma_available(DeviceData* dev, DmaChan* dma){
	return dma->available;
}

static int dma_read(DeviceData* dev, DmaChan* dma, void* buf, uint32_t nbytes){
	uint32_t	count = dma->available;
	uint32_t	readPointer = 0;

	if(count > nbytes)
		count = nbytes;

	if(copy_to_user(buf, &dma->dmaBuffer[readPointer], nbytes))
		return -EFAULT;

	dma->available = 0;
	
	return count;
}

static int dma_write(DeviceData* dev, DmaChan* dma, const void* buf, uint32_t nbytes){
	dl1printk("dma_write: channel: %d len: %d\n", dma->channel, nbytes);
	if(copy_from_user(dma->dmaBuffer, buf, nbytes))
		return -EFAULT;

	dma->waitForEvent = 1;
	dma->available = 0;
	dma_start(dev, dma,  nbytes);
	
	return nbytes;
}

static void dma_status(DeviceData* dev){
	uint32_t	control;
	uint32_t	status;
	uint32_t	complete;
	uint32_t	c;

	printk("Dma status: intMask: 0x%8.8x\n", dma_reg_read(dev, IRQ_MASK));

	for(c = 0; c < dev->numChannels; c++){
		control = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_CONTROL);
		status = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_STATUS);
		complete = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_COMPLETE);

		printk("DmaChannel: %d control: %8.8x status: %8.8x completed: %d available: %d\n", c, control, status, complete, dev->dmaChannels[c].available);
	}
}

static ssize_t bfpga_read(struct file* file, char __user* buf, size_t nbytes, loff_t* ppos){
	DeviceData*	dev = file->private_data;
	unsigned int	minor = iminor(file_inode(file));
	DmaChan*	dmaChan;
	int		ret = 0;
	int		r;
	
	dmaChan = &dev->dmaChannels[minor - 1];

	dl1printk("bfpga_read: Minor: %d available: %u\n", minor, dma_available(dev, dmaChan));

	// Wait for some data
	while(dma_available(dev, dmaChan) == 0){
		dl2printk("bfpga_read: wait: IntStatus: %x Available: %d\n",  reg_read(dev, BFpgaIntStatus), dma_available(dev, dmaChan));
		if(signal_pending(current))
			return -EINTR;

		// printk("bfpga_read: dma wait2: BFpga: IntControl: %x IntStatus: %x %d\n", reg_read(dev, BFpgaIntControl), reg_read(dev, BFpgaIntStatus), reg_read(dev, dmaChan->registers + BFpgaDmaAvailable));
		if((r = wait_event_interruptible_timeout(dmaChan->event, (dma_available(dev, dmaChan) > 0), HZ/10)) < 0){
			return r;
		}

		if(r == 0){
			// On a timeout, reprocess events in case they are stuck
			//dma_status(dev);
			bfpga_process_events(dev, 1);
		}

	}

	// dl2printk("bfpga_read: dma read req: %d\n", nbytes);
	ret = dma_read(dev, dmaChan, buf, nbytes);

	// Re-start DMA
	dmaChan->waitForEvent = 1;
	dma_start(dev, dmaChan,  dmaChan->dmaBufferLen);

	dl1printk("bfpga_read: dma read end: %d\n", ret);

	return ret;
}

static ssize_t bfpga_write(struct file* file, const char __user* buf, size_t nbytes, loff_t* ppos){
	DeviceData*	dev = file->private_data;
	unsigned int	minor = iminor(file_inode(file));
	DmaChan*	dmaChan;
	int		ret = 0;
	int		r;

	dmaChan = &dev->dmaChannels[minor - 1];

	dl1printk("bfpga_write: Minor: %d available: %u\n", minor, dma_available(dev, dmaChan));

	// Wait for enough space
	while(dma_available(dev, dmaChan) < nbytes){
		dl2printk("bfpga_write: wait: IntStatus: %x Available: %d\n",  reg_read(dev, BFpgaIntStatus), dma_available(dev, dmaChan));
		if(signal_pending(current))
			return -EINTR;

		// dl1printk("bfpga_write: dma wait1: BFpga: IntControl: %x IntStatus: %x %d\n", reg_read(dev, BFpgaIntControl), reg_read(dev, BFpgaIntStatus), reg_read(dev, dmaChan->registers + BFpgaDmaAvailable));
		if((r = wait_event_interruptible_timeout(dmaChan->event, (dma_available(dev, dmaChan) >= nbytes), HZ/10)) < 0){
			return r;
		}
	}

	ret = dma_write(dev, dmaChan, buf, nbytes);

	dl1printk("bfpga_write: sent\n");
	
	return ret;
}


static int bfpga_open(struct inode* inode, struct file* filp){
	int		ret = 0;
	unsigned int	minor = iminor(inode);
	unsigned int	c;
	DeviceData*	dev;

	dev = container_of(inode->i_cdev, DeviceData, cdev);
	filp->private_data = dev;;

	dl1printk("bfpga_open address: %p minor: %u\n", dev, minor);
	
	if(minor && (dev->pdev == 0)){
		return -EBUSY;
	}

	if(minor > 1){
		c = minor - 1;
		dma_stop(dev, &dev->dmaChannels[c]);
		if(dev->dmaChannels[c].c2h){
			dev->dmaChannels[c].waitForEvent = 1;
			dma_start(dev, &dev->dmaChannels[c],  dev->dmaChannels[c].dmaBufferLen);
		}
	}
	dev->opened++;
	
	return ret;
}

static int bfpga_release(struct inode* inode, struct file* filp){
	unsigned int	minor = iminor(inode);
	DeviceData*	dev;

	dev = filp->private_data;

	dl1printk("bfpga_release address: %p minor: %u\n", dev, minor);
	if(minor > 1){
		dma_stop(dev, &dev->dmaChannels[minor - 1]);
	}
	dev->opened --;

	return 0;
}

static long bfpga_ioctl(struct file* file, unsigned int cmd, unsigned long arg){
	int		ret = 0;
	DeviceData*	dev = file->private_data;
	unsigned int	minor = iminor(file_inode(file));
	DmaChan*	dmaChan = 0;
	BFpgaInfo	info;
	uint32_t	v;
	uint32_t	c;

	if(minor > 1)
		dmaChan = &dev->dmaChannels[minor - 1];

	switch(cmd){
	case BFPGA_CMD_GETINFO:
		info.regs.physAddress = dev->regs.physAddress;
		info.regs.length = dev->regs.len;
		info.dmaRegs.physAddress = dev->dmaRegs.physAddress;
		info.dmaRegs.length = dev->dmaRegs.len;
		
		for(c = 0; c < 8; c++){
			info.dmaChannels[c].physAddress = dev->dmaChannels[c].dmaPhysAddress;
			info.dmaChannels[c].length = dev->dmaChannels[c].dmaBufferLen;
		}
		
		unlikely(copy_to_user((void __user*)arg, &info, sizeof(info)));
		break;

	case BFPGA_CMD_GET_CONTROL:
		v = reg_read(dev, BFpgaControl);
		unlikely(copy_to_user((void __user*)arg, &v, sizeof(v)));
		break;

	case BFPGA_CMD_SET_CONTROL:
		reg_write(dev, BFpgaControl, (uint32_t)arg);
		break;

	case BFPGA_CMD_RESET:
		if(dev->pdev){
			bfpga_stop(dev);
			udelay(100);
		}

		bfpga_reset(dev);

		if(dev->pdev){
			// Enable board dma and interrupts
			bfpga_start(dev);
		}
		break;

	case FIONREAD:
		if(dmaChan){
			if(put_user(dmaChan->available, (int __user*)arg))
				ret= -EFAULT;
		}
		else {
			ret = -EINVAL;
		}
		break;
		
	default:
		ret = -EINVAL;
	}
	return ret;
}

static int bfpga_mmap(struct file* file, struct vm_area_struct* vma){
	DeviceData*	dev;
	unsigned long	physAddress;
	unsigned long	len;
	int		ret;

	dev = file->private_data;
	physAddress = vma->vm_pgoff << PAGE_SHIFT;
	
	dl1printk("bfpga_mmap: physAddress: %lx Regs: %llx\n", physAddress, dev->regs.physAddress);

	if(physAddress == 0){
		physAddress = dev->regs.physAddress;
		len = dev->regs.len;
	}
	else if(physAddress == dev->regs.physAddress){
		len = dev->regs.len;
	}
	else if(physAddress == dev->dmaRegs.physAddress){
		len = dev->dmaRegs.len;
	}
	else if(physAddress == dev->dmaChannels[0].dmaPhysAddress){
		len = dev->dmaChannels[0].dmaBufferLen;
	}
	else if(physAddress == dev->dmaChannels[1].dmaPhysAddress){
		len = dev->dmaChannels[1].dmaBufferLen;
	}
	else if(physAddress == dev->dmaChannels[2].dmaPhysAddress){
		len = dev->dmaChannels[2].dmaBufferLen;
	}
	else if(physAddress == dev->dmaChannels[3].dmaPhysAddress){
		len = dev->dmaChannels[3].dmaBufferLen;
	}
#ifdef ZAP
	else {
		return -EINVAL;
	}
#else
	else {
		len = vma->vm_end - vma->vm_start;
	}
#endif

	dl1printk("bfpga_mmap: phys: %lx start: %lx end %lx len: %lu\n", physAddress, vma->vm_start, vma->vm_end, len);
	
	if((vma->vm_end - vma->vm_start) > len)
		return -EINVAL;
	
	len = vma->vm_end - vma->vm_start;

	/* Ensure mapping is suitable for IO */
	vma->vm_flags |= VM_IO | VM_DONTEXPAND | VM_DONTDUMP;
	vma->vm_page_prot = pgprot_noncached(vma->vm_page_prot);

	ret = remap_pfn_range(vma, vma->vm_start, physAddress >> PAGE_SHIFT, len, vma->vm_page_prot);
 
 	dl1printk("bfpga_mmap: end: %d start: %lx end: %lx\n", ret, vma->vm_start, vma->vm_end);
	if(ret)
		return -EAGAIN;

	return 0;
}

static void bfpga_process_events(DeviceData* dev, bool processStuck){
	uint32_t	control;
	uint32_t	status = 0;
	uint32_t	complete = 0;
	uint32_t	c;

	dma_reg_write(dev, IRQ_MASK, 0);
	dl3printk("bfpga_intr_handler: mask: 0x%8.8x\n", dma_reg_read(dev, IRQ_MASK));

	for(c = 0; c < dev->numChannels; c++){
		control = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_CONTROL);
		status = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_STATUS_CLR);
		complete = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_COMPLETE);
		
		// Handle descripter complete status. Note that interrupts can be lost for some reason, so check DMA complete status as well when processStuck == 1
		if((status & 0x4) || (processStuck && (control & 4) && complete)){
			if(dev->dmaChannels[c].c2h){
				if(dev->dmaChannels[c].waitForEvent){
					dma_reg_write(dev, dev->dmaChannels[c].registers + DMA_CONTROL, 0);
					dev->dmaChannels[c].waitForEvent = 0;
					dev->dmaChannels[c].available = *((uint32_t*)&dev->dmaChannels[c].dmaDescs[4096 - 4]);
					dev->dmaChannels[c].nTrans++;
					wake_up_interruptible(&dev->dmaChannels[c].event);
				}
				else {
					printk("Error RX event when not expecting it: %d nTrans: %d control: %8.8x status: 0x%8.8x complete: %d\n", c, dev->dmaChannels[c].nTrans, control, status, complete);
					dma_status(dev);
				}

				dl3printk("bfpga_intr_handler: RX[%d]: nTrans: %d %p control: %8.8x status: 0x%8.8x complete: %d available: %d\n", c, dev->dmaChannels[c].nTrans, dev, control, status, complete, dev->dmaChannels[c].available);
			}
			else {
				if(dev->dmaChannels[c].waitForEvent){
					dma_reg_write(dev, dev->dmaChannels[c].registers + DMA_CONTROL, 0);
					dev->dmaChannels[c].waitForEvent = 0;
					dev->dmaChannels[c].available = dev->dmaChannels[c].dmaBufferLen;
					dev->dmaChannels[c].nTrans++;
					wake_up_interruptible(&dev->dmaChannels[c].event);
				}
				else {
					printk("Error TX event when not expecting it: %d nTrans: %d control: %8.8x status: 0x%8.8x complete: %d\n", c, dev->dmaChannels[c].nTrans, control, status, complete);
					dma_status(dev);
				}

				dl3printk("bfpga_intr_handler: TX[%d]: nTrans: %d %p control: %8.8x status: 0x%8.8x complete: %d available: %d\n", c, dev->dmaChannels[c].nTrans, dev, control, status, complete, dev->dmaChannels[c].available);
			}
		}
		else if(status){
			dl3printk("bfpga_intr_handler: channel: %u had status: 0x%8.8x\n", c, status);
		}
	}
	dma_reg_write(dev, IRQ_MASK, 0xFF);
}

static irqreturn_t bfpga_intr_handler(int irq, void *arg){
	DeviceData*	dev = (DeviceData*)arg;

	bfpga_process_events(dev, 0);

	return IRQ_HANDLED;
}


static struct file_operations fops = {
	.owner = THIS_MODULE,
	open:		bfpga_open,
	release:	bfpga_release,
//	ioctl:		bfpga_ioctl,
	unlocked_ioctl:	bfpga_ioctl,
	read:		bfpga_read,
	write:		bfpga_write,
	mmap:		bfpga_mmap,
};

static int map_region(struct pci_dev* pdev, int region, MemMap* map){
	/* Map in memory region */
	map->physAddress = pci_resource_start(pdev, region);
	map->len = pci_resource_len(pdev, region);
	if(!map->physAddress){
		printk(KERN_ERR NAME_PREFIX "PCI region %d not available\n", region);
		return -ENODEV;
	}

	dl1printk("map_region: %d address: %llx len: %d\n", region, map->physAddress, map->len);
	map->address = ioremap(map->physAddress, map->len);
	if(!map->address){
		printk(KERN_ERR NAME_PREFIX "Cannot map PCI Region: %d Address: 0x%llx: Len: %u\n", region, map->physAddress, map->len);
		release_mem_region(map->physAddress, map->len);
		return -ENODEV;
	}
	return 0;
}

static int unmap_region(struct pci_dev* pdev, int region, MemMap* map){
	/* Unmap memory region */
	iounmap(map->address);

	return 0;
}

static void bfpga_start(DeviceData* dev){
#ifdef ZAP
	uint32_t	c;

	// Start all C2H DMA engines
	for(c = 0; c < dev->numChannels; c++){
		if(dev->dmaChannels[c].c2h){
			dev->dmaChannels[c].waitForEvent = 1;
			dma_start(dev, &dev->dmaChannels[c],  dev->dmaChannels[c].dmaBufferLen);
		}
	}

	// Enable board interrupts
#endif
}

static void bfpga_stop(DeviceData* dev){
	uint32_t	c;

	// DisableEnable DMA engines
	for(c = 0; c < dev->numChannels; c++)
		dma_stop(dev, &dev->dmaChannels[c]);
}

static int bfpga_probe(struct pci_dev* pdev, const struct pci_device_id* id){
	int			ret;
	DeviceData*		dev = &cards[0];
	uint16_t		i;

	dl1printk("bfpga_probe\n");
	if(pci_enable_device(pdev))
		return -EIO;

	if((ret = pci_request_regions(pdev, NAME)))
		return ret;

	/* Setup card information */
	pci_set_drvdata(pdev, dev);
	dev->pdev = pdev;
	
	/* Map in memory regions */
	if((ret = map_region(pdev, 0, &dev->regs)))
		return ret;

	dl1printk("BFpga: FPGA Regs: %llx\n", dev->regs.physAddress);

	if((ret = map_region(pdev, 1, &dev->dmaRegs)))
		return ret;

	dl1printk("BFpga: FPGA DmaRegs: %llx\n", dev->dmaRegs.physAddress);

	// Make sure interrupts are disabled
	dma_reg_write(dev, IRQ_MASK, 0x0);	

	if((ret = pci_enable_msi(pdev))){
		printk(KERN_ERR NAME_PREFIX "Cannot set MSI interrupts\n");
		return -ENODEV;
	}

	/* Register interrupt handler */
	if((ret = request_irq(pdev->irq, bfpga_intr_handler, 0, NAME, dev))){
		printk(KERN_ERR NAME_PREFIX "Cannot get interrupt: %d\n", pdev->irq);
		return -ENODEV;
	}

	dl1printk("bfpga: Allocate DmaBufferLen: %d\n", DmaBufferLen);
	
	// Allocate DMA channels looking at FPGA registers to see which ones are present
	for(i = 0; i < 15; i++){
		if((dma_reg_read(dev, (0 << 12) | (i << 8)) & 0xFFFF0000) != 0x1FC00000)
			break;
			
		device_create(class, NULL, MKDEV(MAJOR(firstDev), dev->numChannels + 1), dev, "bfpga%d-send%d", 0, i);
		if((ret = dma_init(dev, dev->numChannels, 0, i)))
			return ret;

		dev->numChannels++;
	}
	for(i = 0; i < 15; i++){
		if((dma_reg_read(dev, (1 << 12) | (i << 8)) & 0xFFFF0000) != 0x1FC10000)
			break;
			
		device_create(class, NULL, MKDEV(MAJOR(firstDev), dev->numChannels + 1), dev, "bfpga%d-recv%d", 0, i);
		if((ret = dma_init(dev, dev->numChannels, 1, i)))
			return ret;

		dev->numChannels++;
	}
	
	printk("bfpga: NumChannels: %d\n", dev->numChannels);

	dl1printk("FpgaId ID: %8.8x\n", reg_read(dev, 0x0000));

	// Enable board dma and interrupts
	bfpga_start(dev);

	// Enable interrupts for 8 channels
	dma_reg_write(dev, IRQ_MASK, 0xFF);

	printk(KERN_INFO NAME_PREFIX "PCIe Driver loaded: Version: %s\n", VERSION);

	return 0;
}

static void bfpga_remove(struct pci_dev *pdev){
	DeviceData*	dev;
	uint32_t	c;

	dl1printk("bfpga_remove\n");

	/* Clean up any allocated resources and stuff */
	dev = pci_get_drvdata(pdev);

	// Disable interrupts and DMA
	dma_reg_write(dev, IRQ_MASK, 0x0);	

	// Stop processes etc
	bfpga_stop(dev);
	udelay(100);

	free_irq(pdev->irq, dev);
	pci_disable_msi(pdev);

	for(c = 0; c < dev->numChannels; c++){
		dma_release(dev, &dev->dmaChannels[c]);
		device_destroy(class, MKDEV(MAJOR(firstDev), 1 + c));
	}

	unmap_region(pdev, 1, &dev->dmaRegs);
	unmap_region(pdev, 0, &dev->regs);
	pci_release_regions(pdev);

	dev->pdev = 0;
	printk(KERN_INFO NAME_PREFIX "PCIe Driver unloaded\n");
}

static struct pci_driver pci_driver = {
	.name		= "bfpga",
	.id_table	= bfpga_ids,
	.probe		= bfpga_probe,
	.remove		= bfpga_remove,
};

static int __init bfpga_init(void){
	int		ret;
	DeviceData*	dev;

	dl1printk("bfpga_init\n");

	spin_lock_init(&nextDevLock);

	// Create class for device	
	if(IS_ERR(class = class_create(THIS_MODULE, NAME)))
		return PTR_ERR(class);

	// Allocate Device
	if((ret = alloc_chrdev_region(&firstDev, 0, 1, NAME))){
		printk(KERN_ERR NAME_PREFIX "Failed to allocate device number block\n");
		return ret;
	}

	/* Allocate a new card */
	spin_lock(&nextDevLock);
	if((cardsNum + 1) > MAX_NUM_CARDS){
		spin_unlock(&nextDevLock);
		return -ENODEV;
	}
	dev = &cards[cardsNum];
	cardsNum++;
	spin_unlock(&nextDevLock);

	dl1printk("deviceData address: %p\n", dev);

	/* Setup device */
	dev->pdev = 0;
	dev->cdev.owner = THIS_MODULE;
	kobject_set_name(&dev->cdev.kobj, "bfpga-%d", MINOR(firstDev));
	cdev_init(&dev->cdev, &fops);
	if((ret = cdev_add(&dev->cdev, firstDev, 9))){
		printk(KERN_ERR NAME_PREFIX "Cannot add cdev\n");
		return -ENODEV;
	}

	/* Setup /dev entries */	
	dev->device = device_create(class, NULL, MKDEV(MAJOR(firstDev), 0), dev, "bfpga%d", 0); 
	if(dev->device)
		dev_set_drvdata(dev->device, dev);

	return pci_register_driver(&pci_driver);
}

static void __exit bfpga_exit(void)
{
	DeviceData*	dev = &cards[0];

	dl1printk("bfpga_exit\n");

	/* Unregister device driver */
	pci_unregister_driver(&pci_driver);

	device_destroy(class, MKDEV(MAJOR(firstDev), 0));

	cdev_del(&dev->cdev);

	/* Release device number block */
	unregister_chrdev_region(firstDev, 1);

	class_destroy(class);
}

module_init(bfpga_init);
module_exit(bfpga_exit);

MODULE_AUTHOR("BEAM Ltd");
MODULE_DESCRIPTION("BEAM BFPGA FPGA device driver");
MODULE_LICENSE("GPL");
