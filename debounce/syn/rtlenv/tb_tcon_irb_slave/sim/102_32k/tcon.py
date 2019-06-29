#!/usr/bin/python3
################################################################################
## COPYRIGHT (c) 2019 Schweitzer Engineering Laboratories, Inc.
## SEL Confidential
################################################################################
import sys
import os
testdir = os.path.abspath(os.path.dirname(__file__))
sys.path.append(testdir + '\..\common')
import math
import pytcon
import time
from common import *
from zeromq_manager import ZeromqManager

if __name__ == "__main__":
  print('TCON instance "{}" connecting to FA at tcp://127.0.0.1:{}'.format(sys.argv[1], sys.argv[2]))
  tcon = pytcon.Tcon(ZeromqManager('tcp://127.0.0.1:' + sys.argv[2]))

  tb = TopLevelTB(tcon)
  tb.print_banner('103_32k', '32k Words', '1.2')
  tb.setup_environment()

  HIGH_ADDR, DATA_WIDTH, ADDR_WIDTH, BASE_ADDR = read_spec(testdir + '/sim_params.txt')

  # Record before time
  before_time = time.time()

  # Run test
  test_method_1(tb, HIGH_ADDR)

  # Record before time
  after_time = time.time()
  print("{} words, took {} ms to completed ".format(HIGH_ADDR - BASE_ADDR + 1, math.ceil((after_time-before_time)*1000)))

  tcon.sync(50)
  tb.print_complete()
  tcon.halt()

