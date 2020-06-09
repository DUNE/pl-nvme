#!/usr/bin/sh
#######################################################################
# test.sh	NvmeStorage simple tests
#######################################################################
#

test1(){
	echo "Simple capture test loop: 20 GByte"

	while true; do
		./test_nvme -d 2 -s 0 -n 5242880 capture
		./test_nvme -d 2 -s 5242880 -n 5242880 capture
	done
}

test2(){
	echo "Simple capture test loop: 200 GByte"

	./test_nvme -d 2 -s 0 -n 52428800 trim
	./test_nvme -nr -d 2 -s 52428800 -n 52428800 trim

	# Let NVMe's perform some trimming
	sleep 20

	while true; do
		./test_nvme -nr -d 2 -s 0 -n 52428800 capture
		#./test_nvme -nr -d 2 -s 0 -n 52428800 trim
		#sleep 20

		./test_nvme -nr -d 2 -s 52428800 -n 52428800 capture
		#./test_nvme -nr -d 2 -s 52428800 -n 52428800 trim
		#sleep 20
	done
}

test3(){
	./test_nvme -d 2 -s 0 -n 5242880 capture
	./test_nvme -nr -d 2 -s 0 -n 5242880 capture
	#./test_nvme -v -nr -nv -d 2 -s 0 -n 8 read
	./test_nvme -v -nr -d 2 -s 0 -n 8 read
}

test3

exit 0
