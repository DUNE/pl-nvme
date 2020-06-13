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

	r=`./test_nvme -m -nr -d 2 -s $1 -n ${captureBlocks} capture`
	echo $r
	IFS=, r1=($r)
	
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

trimAll(){
	echo "Trim all blocks (well 800 MBytes)"
	start=0
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} trim
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim

	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim
}

trimAll1(){
	echo "Trim all blocks (well 800 MBytes)"
	start=0
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} trim1
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim1
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim1
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim1

	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim1
}

fillAll(){
	echo "Allocate most of the drives blocks initially"
	start=0
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
}

test1(){
	delay=140

	# Initially allocate half of the drives blocks
	echo "Allocate half of the drives blocks initially"
	start=0
	./test_nvme -d 2 -s ${start} -n ${captureBlocks} capture
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} capture

	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim
	start=`expr ${start} + ${captureBlocks}`
	./test_nvme -nr -d 2 -s ${start} -n ${captureBlocks} trim
	
	while true; do
		echo
		echo "Test cycle with deallocate delay set to: $delay"
		#echo "Deallocate at 0"
		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} trim
		sleep $delay

		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} capture

		echo
		#echo "Deallocate at ${captureBlocks}"
		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} trim
		sleep $delay

		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} capture

		#delay=`expr $delay + $delay / 3`
	done
}

test2(){
	delay=140

	# Initially allocate most of the drives blocks for worst case
	echo "Allocate most of the drives blocks initially"
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
		#echo "Deallocate at 0"
		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} trim
		sleep $delay

		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} capture

		echo
		#echo "Deallocate at ${captureBlocks}"
		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} trim
		sleep $delay

		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} capture

		#delay=`expr $delay + $delay / 3`
	done
}

test3(){
	delay=120
	./test_nvme -d 2 -s 0 -n 100 capture
	
	while true; do
		echo
		echo "Test cycle with deallocate delay set to: $delay"
		#echo "Deallocate at 0"
		#./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} trim
		#sleep $delay

		./test_nvme -nr -d 2 -s 0 -n ${captureBlocks} capture

		echo
		#echo "Deallocate at ${captureBlocks}"
		#./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} trim
		##sleep $delay

		./test_nvme -nr -d 2 -s ${captureBlocks} -n ${captureBlocks} capture

		#delay=`expr $delay + $delay / 3`
	done
}

#captureBlocks=100

#trimAll
#trimAll1
#fillAll
#test1
test2
#test3

exit 0
