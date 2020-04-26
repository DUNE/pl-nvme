/*******************************************************************************
 *	BFpga.c		BFpga FPGA device driver
 *	T.Barnaby,	BEAM Ltd,	2020-03-05
 *******************************************************************************
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
#include <asm/uaccess.h>
#include <asm/irq.h>
#include <asm/set_memory.h>
#include "bfpga.h"

#define LDEBUG1		0		// Basic debuging
#define LDEBUG2		0		// Detailed debuging

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

#define	VERSION			"1.1.0"
#define NAME			"bfpga"
#define NAME_PREFIX		"bfpga: "
#define MAX_NUM_CARDS		1

// DMA registers
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
	uint32_t		dmaBufferLen;
	uint8_t*		dmaBuffer;
	dma_addr_t		dmaPhysAddress;
	uint32_t		dataBufferLen;
	uint8_t*		dataBuffer;
	DmaDesc*		dmaDesc;
	uint32_t		available;
	wait_queue_head_t	event;
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

// Settings
const int	DmaBufferLen		= (2*1024*1024);		// DMA Buffer length


static struct class*		class;
static int			cardsNum;
static DeviceData		cards[MAX_NUM_CARDS];
static dev_t			firstDev;
static spinlock_t		nextDevLock;

static struct pci_device_id bfpga_ids[] = {
	{ PCI_VENDOR_ID_XILINX, 0x8014, PCI_VENDOR_ID_XILINX, 0x0007 },
	{ PCI_VENDOR_ID_XILINX, 0x8024, PCI_VENDOR_ID_XILINX, 0x0007 },
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

static uint32_t reg_write(DeviceData* dev, uint32_t address, uint32_t data){
	((volatile uint32_t*)dev->regs.address)[address] = data;
	return ((volatile uint32_t*)dev->regs.address)[address];
}

static uint32_t reg_read(DeviceData* dev, uint32_t address){
	return ((volatile uint32_t*)dev->regs.address)[address];
}

static uint32_t dma_reg_write(DeviceData* dev, uint32_t address, uint32_t data){
	((volatile uint32_t*)dev->dmaRegs.address)[address/4] = data;
	return ((volatile uint32_t*)dev->dmaRegs.address)[address/4];
}

static uint32_t dma_reg_read(DeviceData* dev, uint32_t address){
	return ((volatile uint32_t*)dev->dmaRegs.address)[address/4];
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
	dma->dmaBufferLen = (4096 + DmaBufferLen);
	dma->dataBufferLen = DmaBufferLen;
	dma->registers = (dma->c2h << 12) | (dma->devChannel << 8);
	dma->available = 0;
	
	regSgAddress = ((4 + dma->c2h) << 12) | (dma->devChannel << 8);

	//dl1printk("dma_init: %p %p %d %p\n", dev->device, &dev->pdev->dev, dma->dmaBufferLen, &dma->dmaPhysAddress);

	if(!(dma->dmaBuffer = dma_alloc_coherent(&dev->pdev->dev, dma->dmaBufferLen, &dma->dmaPhysAddress, GFP_KERNEL))){
		printk(KERN_ERR NAME_PREFIX "DMA allocation failed\n");
		return -ENODEV;
	}
	//dl1printk("dma_init: phys: %llx virtual: %p\n", dma->dmaPhysAddress, dma->dmaBuffer);
	set_memory_uc((unsigned long)dma->dmaBuffer, (dma->dmaBufferLen/PAGE_SIZE));

	dma->dataBuffer = &dma->dmaBuffer[4096];
	init_waitqueue_head(&dma->event);

	// Setup DMA descriptors in first 4096 bytes of memory
	dmaDesc = (DmaDesc*)dma->dmaBuffer;
	dma->dmaDesc = dmaDesc;
	
	if(dma->c2h){
		dmaDesc[0].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[0].len = 0;
		dmaDesc[0].srcAddress = dma->dmaPhysAddress + 4096 - 8;		// Location of return metadata
		dmaDesc[0].destAddress = dma->dmaPhysAddress + 4096;
		dmaDesc[0].nextDesc = dma->dmaPhysAddress + sizeof(DmaDesc);

		dmaDesc[1].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[1].len = 0;
		dmaDesc[1].srcAddress = 0;
		dmaDesc[1].destAddress = 0;
		dmaDesc[1].nextDesc = 0;
	}
	else {
		dmaDesc[0].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[0].len = 0;
		dmaDesc[0].srcAddress = dma->dmaPhysAddress + 4096;
		dmaDesc[0].destAddress = 0;
		dmaDesc[0].nextDesc = dma->dmaPhysAddress + sizeof(DmaDesc);

		dmaDesc[1].control = DmaDescMagic | DmaDescEop | DmaDescInt | DmaDescStop;
		dmaDesc[1].len = 0;
		dmaDesc[1].srcAddress = 0;
		dmaDesc[1].destAddress = 0;
		dmaDesc[1].nextDesc = 0;
		
		dma->available = dma->dataBufferLen;
	}

	// Setup registers to point to descriptors
	dma_reg_write(dev, regSgAddress + DMASC_ADDRESS_LOW, (dma->dmaPhysAddress & 0xFFFFFFFF));
	dma_reg_write(dev, regSgAddress + DMASC_ADDRESS_HIGH, ((dma->dmaPhysAddress >> 32) & 0xFFFFFFFF));
	dma_reg_write(dev, regSgAddress + DMASC_NEXT, 0);
	dma_reg_write(dev, regSgAddress + DMASC_CREDITS, 0);
	
	//dl1printk("dma_init: %d %d: 0x%8.8x 0x%8.8x\n", dma->channel, dma->c2h, dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_HIGH), dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_LOW));
	
	// Setup control registers
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0);
	dma_reg_write(dev, dma->registers + DMA_INT_MASK, 0x06);	

	//dl1printk("dma_init: %x %p %x %d\n", dma->registers, dma->dmaBuffer, (int)dma->dmaPhysAddress, dma->dataBufferlen);

	return 0;
}

static void dma_release(DeviceData* dev, DmaChan* dma){
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0);

//	dl1printk("dma_release: %p %p %d %p\n", dev->device, &dev->pdev->dev, dma->len, &dma->dmaPhysAddress);
	if(dma->dmaBuffer){
		dma_free_coherent(&dev->pdev->dev, dma->dmaBufferLen, dma->dmaBuffer, dma->dmaPhysAddress);
		dma->dmaBuffer = 0;
	}
}

static void dma_start(DeviceData* dev, DmaChan* dma, uint32_t len){
	dl1printk("dma_start: channel: %d regs: 0x%x\n", dma->channel, dma->registers);
	//dl1printk("dma_start: %d %d: 0x%8.8x 0x%8.8x\n", dma->channel, dma->c2h, dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_HIGH), dma_reg_read(dev, regSgAddress + DMASC_ADDRESS_LOW));
	dl1printk("Status: %8.8x\n", dma_reg_read(dev, dma->registers + DMA_STATUS));

	// Setup DMA channel and start running
	dma->dmaDesc[0].len = len;
	dma_reg_write(dev, dma->registers + DMA_CONTROL, 0x07);

#ifdef ZAP	
	udelay(10000);
	printk("Completed: %8.8x\n", dma_reg_read(dev, dma->registers + DMA_COMPLETE));
	printk("Status0: %8.8x\n", dma_reg_read(dev, dma->registers + DMA_STATUS));
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

	if(copy_to_user(buf, &dma->dataBuffer[readPointer], nbytes))
		return -EFAULT;

	dma->available = 0;
	
	return count;
}

static int dma_write(DeviceData* dev, DmaChan* dma, const void* buf, uint32_t nbytes){
	dl1printk("dma_write: channel: %d len: %d\n", dma->channel, nbytes);
	if(copy_from_user(&dma->dataBuffer[0], buf, nbytes))
		return -EFAULT;

	dma->available = 0;
	dma_start(dev, dma,  nbytes);
	
	return nbytes;
}

static ssize_t bfpga_read(struct file* file, char __user* buf, size_t nbytes, loff_t* ppos){
	DeviceData*	dev = file->private_data;
	unsigned int	minor = iminor(file_inode(file));
	DmaChan*	dmaChan;
	int		ret = 0;
	int		r;
	
	dmaChan = &dev->dmaChannels[minor - 1];

	// dl1printk("bfpga_read: Start\n");

	// Wait for some data
	while(dma_available(dev, dmaChan) == 0){
		// printk("Wait: IntStatus: %x Available: %d\n",  reg_read(dev, BFpgaIntStatus), reg_read(dev, dmaChan->registers + BFpgaDmaAvailable));
		if(signal_pending(current))
			return -EINTR;

		// printk("bfpga_read: dma wait2: BFpga: IntControl: %x IntStatus: %x %d\n", reg_read(dev, BFpgaIntControl), reg_read(dev, BFpgaIntStatus), reg_read(dev, dmaChan->registers + BFpgaDmaAvailable));
		if((r = wait_event_interruptible_timeout(dmaChan->event, (dma_available(dev, dmaChan) > 0), HZ/100)) < 0){
			// printk("Return from wait_event_interruptible_timeout: %d\n", r);
			return r;
		}
	}

	// dl1printk("bfpga_read: dma read req: %d\n", nwords);
	ret = dma_read(dev, dmaChan, buf, nbytes);

	// Re-start DMA
	dma_start(dev, dmaChan,  dmaChan->dataBufferLen);

	// dl1printk("bfpga_read: dma read end: %d\n", ret);

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
		if(signal_pending(current))
			return -EINTR;

		// dl1printk("bfpga_write: dma wait1: BFpga: IntControl: %x IntStatus: %x %d\n", reg_read(dev, BFpgaIntControl), reg_read(dev, BFpgaIntStatus), reg_read(dev, dmaChan->registers + BFpgaDmaAvailable));
		if((r = wait_event_interruptible_timeout(dmaChan->event, (dma_available(dev, dmaChan) >= nbytes), HZ/10)) < 0){
			return r;
		}
	}
	ret = dma_write(dev, dmaChan, buf, nbytes);

	return ret;
}


static int bfpga_open(struct inode* inode, struct file* filp){
	int		ret = 0;
	unsigned int	minor = iminor(inode);
	DeviceData*	dev;

	dev = container_of(inode->i_cdev, DeviceData, cdev);
	filp->private_data = dev;;

	dl1printk("bfpga_open address: %p\n", dev);
	
	if(minor && (dev->pdev == 0)){
		return -EBUSY;
	}

	dev->opened++;
	
	return ret;
}

static int bfpga_release(struct inode* inode, struct file* filp){
	DeviceData*	dev;

	dev = filp->private_data;
	dev->opened --;

	return 0;
}

static long bfpga_ioctl(struct file* file, unsigned int cmd, unsigned long arg){
	int			ret = 0;
	BFpgaInfo		info;
	DeviceData*		dev;
	uint32_t		v;
	uint32_t		c;

	dev = file->private_data;

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

static irqreturn_t bfpga_intr_handler(int irq, void *arg){
	DeviceData*	dev = (DeviceData*)arg;
	uint32_t	status;
	uint32_t	c;

	status = dma_reg_read(dev, IRQ_PENDING);
	dl2printk("bfpga_intr_handler: %p mask: 0x%8.8x status: 0x%8.8x\n", dev, dma_reg_read(dev, IRQ_MASK), status);

	for(c = 0; c < dev->numChannels; c++){
		status = dma_reg_read(dev, dev->dmaChannels[c].registers + DMA_STATUS);
		if(status & 0x6){
			if(dev->dmaChannels[c].c2h){
				dev->dmaChannels[c].available = *((uint32_t*)&dev->dmaChannels[c].dmaBuffer[4096 - 4]);
				dl2printk("bfpga_intr_handler: RX available: %u\n", dev->dmaChannels[c].available);
			}
			else {
				dl2printk("bfpga_intr_handler: TX available: %u\n", dev->dmaChannels[c].available);
				dev->dmaChannels[c].available = dev->dmaChannels[c].dataBufferLen;
			}

			dma_reg_write(dev, dev->dmaChannels[c].registers + DMA_CONTROL, 0);
			wake_up_interruptible(&dev->dmaChannels[c].event);
		}
	}

	return 0;
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
	map->address = ioremap_nocache(map->physAddress, map->len);
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
	uint32_t	c;

	// Start all C2H DMA engines
	for(c = 0; c < dev->numChannels; c++){
		if(dev->dmaChannels[c].c2h){
			dma_start(dev, &dev->dmaChannels[c],  dev->dmaChannels[c].dataBufferLen);
		}
	}

	// Enable board interrupts
}

static void bfpga_stop(DeviceData* dev){
	uint32_t	c;

#ifdef DZAP
	// Disable board interrupts
	reg_write(dev, BFpgaIntControl, 0);
#endif

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

#ifdef DZAP
	bfpga_reset(dev);
#endif

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
