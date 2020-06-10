#!/usr/bin/sh
#######################################################################
# test_deallocate.shh	Test performance with various dellocate delays
#######################################################################
#
# Note this test should be performed with the NvmeStorage modules NvmeWrite
# trim functionality disabled.
#

# Drives testing with two off 500 GByte drives
let "driveAllBlocks = 2 * 450 * 1024 * 1024 * 1024 / 4096"
let "captureBlocks = 200 * 1024 * 1024 * 1024 / 4096"
delay=60

echo "Test for NVMe drive deallocate time. Total drive blocks: ${driveAllBlocks} Capture Blocks: ${captureBlocks}"

testCapture(){
	#echo "Simple capture of available space"

	IFS=, r1=(`./test_nvme -m -nr -d 2 -s $1 -n ${captureBlocks} capture`)
	
	#echo "Capture: ${r1[*]}"
	echo ${r1[2]}
}

compareRate(){
	r=`(echo "$1 > 4000" | bc)`
	if [ "$r" = "1" ]; then
		return 1;
	else
		return 0;
	fi
}

test1(){
	# Initiallity allocate most of the drives blocks for worst case
	echo "Allocate most of the drives blocks to start"
	start=0
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	
	while true; do
		echo
		echo "Test cycle with deallocate delay set to: $delay"
		echo "Deallocate at 0"
		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} trim
		sleep $delay

		echo "Run Capture at block: 0"
		rate=`testCapture 0`
		echo "Rate: $rate"
		if compareRate $rate; then
			echo "Error rate was ${rate}"
			#return 1;
		fi
		

		echo
		echo "Deallocate at ${captureBlocks}"
		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} trim
		sleep $delay

		echo "Run Capture at block: ${captureBlocks}"
		rate=`testCapture ${captureBlocks}`
		echo "Rate: $rate"
		if compareRate $rate; then
			echo "Error Rate was ${rate}"
			#return 1;
		fi;

		delay=`expr $delay + 10`
	done
}


#captureBlocks=100
test1

exit 0
