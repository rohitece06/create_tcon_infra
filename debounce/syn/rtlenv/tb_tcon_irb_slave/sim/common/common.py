#!/usr/bin/python3
################################################################################
## COPYRIGHT (c) 2019 Schweitzer Engineering Laboratories, Inc.
## SEL Confidential
################################################################################
import sys
import os
import math
import pytcon
from pytcon_objects import *

################################################################################
# Requests for tcon components
################################################################################
REQ_CLOCKER     = 0
REQ_IRB_MASTER  = 1
REQ_IRB_SLAVE   = 2

################################################################################
# IRB Slave Internal Register Address
################################################################################
IRB_SLAVE_BASE_ADDRESS      = 0
IRB_SLAVE_ADDRESS_REG       = IRB_SLAVE_BASE_ADDRESS + 0
IRB_SLAVE_DATA_REG          = IRB_SLAVE_BASE_ADDRESS + 1
IRB_SLAVE_CONTROL_REG       = IRB_SLAVE_BASE_ADDRESS + 2
CONTROL_REG_READ_OP         = 1 << 0
CONTROL_REG_WRITE_OP        = 1 << 1
CONTROL_REG_DELETE_OP       = 1 << 2
CONTROL_REG_DUMP_OP         = 1 << 3
IRB_SLAVE_STATUS_REG        = IRB_SLAVE_BASE_ADDRESS + 3
STATUS_REG_OUT_BOUND_ADDR   = 1 << 0
STATUS_REG_BAD_ADDR         = 1 << 1 # Address that not exist
STATUS_REG_NOTHING_TO_WRITE = 1 << 2

################################################################################
# Read specs from sim_params.txt
# tb : top level testbench object
# file_name : path to sim_params.txt
################################################################################
def read_spec(file_name):
  HIGH_ADDR = 0
  DATA_WIDTH = 0
  ADDR_WIDTH = 0
  BASE_ADDR = 0
  with open(file_name, 'r') as params:
    line = params.readline()
    while line:
      param_list = line.split()
      if param_list[0] == "HIGH_ADDR":
        HIGH_ADDR = int(param_list[1])
      elif param_list[0] == "DATA_WIDTH":
        DATA_WIDTH = int(param_list[1])
      elif param_list[0] == "ADDR_WIDTH":
        ADDR_WIDTH = int(param_list[1])  
      elif param_list[0] == "BASE_ADDR":
        BASE_ADDR = int(param_list[1])
      line = params.readline()
  
  return HIGH_ADDR, DATA_WIDTH, ADDR_WIDTH, BASE_ADDR

################################################################################
# Generate init memory file
################################################################################
def gen_mem_init_file(file_name, ADDR_WIDTH, DATA_WIDTH, BASE_ADDR, HIGH_ADDR):
  ADDR_BYTE_CNT = math.ceil(ADDR_WIDTH/4)
  DATA_BYTE_CNT = math.ceil(DATA_WIDTH/4)
  with open(file_name, 'w') as init_file:
    for i in range (BASE_ADDR, HIGH_ADDR + 1):
      init_file.write('{0:0{1}x}'.format(i,ADDR_BYTE_CNT))
      init_file.write(' ')
      init_file.write('{0:0{1}x}\n'.format(0,DATA_BYTE_CNT))

################################################################################
# Test method #1
# Write from BASE_ADDR to HIGH_ADDR then read from BASE_ADDR to HIGH_ADDR
# tb        : top level testbench object
# HIGH_ADDR : High address
# BASE_ADDR : Base address
################################################################################
def test_method_1 (tb, HIGH_ADDR, BASE_ADDR = 0):
  # Loop and write MEM from TCON interface
  for i in range(BASE_ADDR, HIGH_ADDR+1):
    tb.tcon.write(REQ_IRB_SLAVE, i, i)

  # Loop and read MEM from TCON interface
  for i in range(BASE_ADDR, HIGH_ADDR+1):
    temp = tb.tcon.read(REQ_IRB_SLAVE, i)
    if temp != i:
      print("Error : Data is not correct!")

################################################################################
# Test method #2
# Write from HIGH_ADDR down to BASE_ADDR then read from HIGH_ADDR down to
# BASE_ADDR.
# tb        : top level testbench object
# HIGH_ADDR : High address
# BASE_ADDR : Base address
################################################################################
def test_method_2 (tb, HIGH_ADDR, BASE_ADDR = 0):

  # Loop and write MEM from TCON interface
  i = HIGH_ADDR
  while i >= BASE_ADDR:
    tb.tcon.write(REQ_IRB_SLAVE, i, i)
    i -= 1

  # Loop and read MEM from TCON interface
  i = HIGH_ADDR
  while i >= BASE_ADDR:
    temp = tb.tcon.read(REQ_IRB_SLAVE, i)
    if temp != i:
      print("Error : Data is not correct!")
    i -= 1

################################################################################
# Test method #3
# Write from BASE_ADDR to HIGH_ADDR then read from BASE_ADDR to HIGH_ADDR using 
# the IRB interface.
# tb        : top level testbench object
# HIGH_ADDR : High address
# BASE_ADDR : Base address
################################################################################
def test_method_3 (tb, HIGH_ADDR, BASE_ADDR = 0):
  # Loop and write MEM from TCON interface
  for i in range(BASE_ADDR, HIGH_ADDR + 1):
    tb.irb_master.write(i, i)

  # Loop and read MEM from TCON interface
  for i in range(BASE_ADDR, HIGH_ADDR + 1):
    temp = tb.irb_master.read(i)
    if temp != i:
      print("Error : Data is not correct!")

# ################################################################################
# # Component IRB read
# ################################################################################
# def irb_read (irb_obj, irb_addr):
#   irb_obj.tcon.write(irb_obj.req, IRB_SLAVE_ADDRESS_REG, irb_addr)
#   irb_obj.tcon.write(irb_obj.req, IRB_SLAVE_CONTROL_REG, CONTROL_REG_READ_OP)
#   return irb_obj.tcon.read(irb_obj.req, IRB_SLAVE_DATA_REG)

# ################################################################################
# # Component IRB write
# ################################################################################
# def irb_write (irb_obj, irb_addr, irb_data):
#   irb_obj.tcon.write(irb_obj.req, IRB_SLAVE_ADDRESS_REG, irb_addr)
#   irb_obj.tcon.write(irb_obj.req, IRB_SLAVE_DATA_REG, irb_data)
#   irb_obj.tcon.write(irb_obj.req, IRB_SLAVE_CONTROL_REG, CONTROL_REG_WRITE_OP)

################################################################################
# TCON GPIO mapping
################################################################################
GPIO_RESET            = (1 << 0)


class TconIRBSlave(object):
  """Custom Tcon Slave under test"""
  def __init__(self, tcon_inst: pytcon.Tcon, req_no: int):
    self.req = req_no
    self.tcon = tcon_inst

  def read(self, irb_addr: int) -> int:
    """Perform an IRB read.

    Args:
        irb_addr: IRB address; self.bar will be added to this value.

    Returns:
        Read value as integer
    """
    self.tcon.write(self.req, IRB_SLAVE_ADDRESS_REG, irb_addr)
    self.tcon.write(self.req, IRB_SLAVE_CONTROL_REG, CONTROL_REG_READ_OP)
    return self.tcon.read(self.req, IRB_SLAVE_DATA_REG)

  def write(self, irb_addr: int, irb_data: int) -> None:
    """Perform an IRB write.

    Args:
        irb_addr: IRB address; self.bar will be added to this value.
        irb_data: IRB data

    Returns:
        None
    """
    self.tcon.write(self.req, IRB_SLAVE_ADDRESS_REG, irb_addr)
    self.tcon.write(self.req, IRB_SLAVE_DATA_REG, irb_data)
    self.tcon.write(self.req, IRB_SLAVE_CONTROL_REG, CONTROL_REG_WRITE_OP)

  def update_addr(self,NEW_BASE_ADDR : int):
    """Update with new base address"""
    global IRB_SLAVE_BASE_ADDRESS
    global IRB_SLAVE_ADDRESS_REG
    global IRB_SLAVE_DATA_REG
    global IRB_SLAVE_CONTROL_REG
    global IRB_SLAVE_STATUS_REG

    IRB_SLAVE_BASE_ADDRESS  = NEW_BASE_ADDR
    IRB_SLAVE_ADDRESS_REG   = IRB_SLAVE_BASE_ADDRESS + 0
    IRB_SLAVE_DATA_REG      = IRB_SLAVE_BASE_ADDRESS + 1
    IRB_SLAVE_CONTROL_REG   = IRB_SLAVE_BASE_ADDRESS + 2
    IRB_SLAVE_STATUS_REG    = IRB_SLAVE_BASE_ADDRESS + 3

  def dump_mem(self):
    """Dump memory to file"""
    self.tcon.write(self.req, IRB_SLAVE_CONTROL_REG, CONTROL_REG_DUMP_OP)

class TopLevelTB(object):
  """This is a representation of my big top-level TB"""
  def __init__(self, tcon_inst: pytcon.Tcon):
    # Store it for ourselves
    self.tcon = tcon_inst
    
    #Make tcon objects
    self.clocker = TconClocker(tcon_inst, req_no=REQ_CLOCKER)

    self.irb_master = TconIRBMaster(tcon_inst, req_no=REQ_IRB_MASTER)

    self.irb_slave = TconIRBSlave(tcon_inst, req_no=REQ_IRB_SLAVE)

  def setup_environment(self):
    # Get the simulation going
    # 1 - make and start the clocks
    #125Mhz clock
    self.clocker.add_clock(0, 'clk', 8000)
    self.clocker.enable(0)
    
    #GPIO outputs
    self.tcon.gpio_set_as_outputs(GPIO_RESET)

  def do_reset(self, duration: int):
    self.tcon.gpio_set(GPIO_RESET)
    self.tcon.sync(duration)
    self.tcon.gpio_clr(GPIO_RESET)

  def print_banner(self, test_dir: str, test_name: str, sections: str) -> None:
    print('*' * 40)
    print('* {} - {}'.format(test_dir, test_name))
    print('* Section(s) {} of testplan'.format(sections))
    print('*' * 40)

  def print_complete(self):
    x = self.tcon.now()
    if x == 0:
        print('*' * 40)
        print('* ERROR - The simulation exited abnormally at t=0 !')
        print('*' * 40)
    else:
        print('*' * 40)
        print('* Testbench Completed Successfully at t={}us'.format(x / 1000.0))
        print('*' * 40)