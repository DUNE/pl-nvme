# -*- coding: utf-8 -*-
"""
Created on Tue Aug  4 15:22:38 2020

@author: adamg
"""

import numpy as np
import subprocess


def readFile(filename):
    """ Read a binary file and output elements as a list
    """
    f = open(filename, "rb")
    num = list(f.read()) # List of all elements
    f.close()
    
    return num
  
def dataStream(elementList, numBlocksRead):
    """ Takes in list of binary output and compiles to single datastream
    """
    elementStream = ''.join(map(str, elementList))
    if numBlocksRead <= 2:
        print(elementStream)
    
    return elementStream

def bashProcess(command):
    """ Run a bash command to terminal
    """
    subprocess.run(command, shell=True)
    print("Command completed")
    
    return
  
def lenCheck(elementList):
    if numBlocksRead <= 2:
        print(elementList)

    if len(elementList) == 4096 * numBlocksRead:
        print("No blocks missing. {} kBytes read.".format(len(elementList)/1024))
    else:
        print("Blocks missing")
      
    return


filename = "output.bin"
numBlocksRead = 10
command = """./test_nvme -d 2 -s 0 -n 5242880 capture
             ./test_nvme -d 2 -s 0 -n {0} -o {1} read""".format(numBlocksRead, filename)
             
bashProcess(command)
elementList = readFile(filename)
lenCheck(elementList)

elementStream = dataStream(elementList, numBlocksRead)
