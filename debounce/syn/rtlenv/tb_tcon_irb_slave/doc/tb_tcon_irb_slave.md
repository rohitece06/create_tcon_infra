<!---
  Copyright (c) 2018 Schweitzer Engineering Laboratories, Inc.
  SEL Confidential
-->
# Name
IRB Slave Testbench Controller

# Main Features
* Testbench component used for testing a component that has an IRB Master Interface
* IRB RSI Compliant (byte enables are not supported)
* TCON Compliant
  - TCON 1.0
  - TCON 2.0

# Block Diagram
![](./tb_tcon_irb_slave.svg)

## Application Information
The user of this component can interact with this component in the following:
- Initialize the internal IRB Slave Memory Space using a file (INIT_MEM generic)
- All IRB master-requested transactions will be logged to a text file (LOG_FILE generic)
- Internal Memory can be read from and written to during the simulation using this component's internal registers.
- Internal Memory can be dumped to a file at any time (FIN_MEM generic)

### FILE Format
The INIT_MEM and FIN_MEM file formats are identical, so they will be outlined
the same. Memory outlined in these files may have gaps in them.
For memory initialization, duplicates will be observed by overwriting
the old location with the new location.

Example for an INIT_MEM file:
```
ADDR DATA (Do not include this header as part of the file)
0x00 0x0000
0x01 0x0001
0x02 0x0002
0x04 0x0006 *NOTE* Address 3 is not required to be there
0x04 0x0005 *NOTE* This will overwrite the previous location
```

Example for a FIN_MEM file:
```
ADDR DATA (Do not include this header as part of the file)
0x00 0x0000
0x01 0x0001
0x02 0x0002
```

**Note** The address and data hex lengths must match the IRB_ADDR_WIDTH and
IRB_DATA_WIDTH generics' length, respectively. If not, bad data is read.

The LOG_FILE looks like the following:
```
ADDR DATA   IRB_RD IRB_WR (Not part of file)
0x00 0x0000 0      1      *NOTE* Write Transaction request by IRB Master
0x01 0x0005 1      0      *NOTE* Read Transaction request by IRB Master
```

# Interface
Generic           | Type     | Range         | Description
:-----------------|----------|---------------|---------------
IRB_ADDR_WIDTH    | positive | 1 to 32       | IRB Address Width
IRB_DATA_WIDTH    | positive | 1 to 512      | IRB Data Width (defaults to 32)
DELAY_CLKS        | natural  | unconstrained | Number of clocks between the request and completion of an IRB transaction (defaults to 0)
USE_BUSY          | boolean  | true/false    | Enables the irb_busy signal (defaults to true)
FLOP_DELAY        | time     | unconstrained | The delay it takes for an output to change (defaults to 1 ps)
BASE_ADDR         | natural  | unconstrained | The IRB Base Address for this component (defaults to 0)
HIGH_ADDR         | natural  | unconstrained | The high address provided by the component; anything higher than this space is ignored (defaults to 32)
VERBOSE           | boolean  | true/false    | Display verbose information when true (defaults to false)
IDENTIFIER        | string   | unconstrained | Identifies the specific instantiation of a component (defaults to "irb_slave")
INIT_MEM          | string   | unconstrained | Filename for initialization of the IRB memory space (defaults to "init_memory.txt")
FIN_MEM           | string   | unconstrained | Filename for the location of the TCON-requested memory space dump (defaults to "final_memory.txt")
LOG_FILE          | string   | unconstrained | Filename for the location of the IRB Master requested transactions (defaults to "irb_slave.log")

## Ports
Port       | Direction | Width          | Description
:----------|-----------|----------------|--------------
tcon_req   | in        |   1            | TCON Request Signal
tcon_ack   | out       |   1            | TCON Acknowledgement Signal
tcon_err   | out       |   1            | TCON Error Signal
tcon_addr  | in        |  32            | TCON Address Signal
tcon_data  | inout     |  32            | TCON Bi-directional Data Bus
tcon_rwn   | in        |   1            | TCON Read Write Signal
irb_clk    | in        |   1            | System clock
irb_addr   | in        | IRB_ADDR_WIDTH | IRB Address
irb_di     | in        | IRB_DATA_WIDTH | IRB Data In
irb_do     | out       | IRB_DATA_WIDTH | IRB Data Out
irb_rd     | in        |   1            | IRB Read
irb_wr     | in        |   1            | IRB Write
irb_ack    | out       |   1            | IRB Acknowledge
irb_busy   | out       |   1            | IRB Busy

# Timing Specifications and Diagrams
[IRB RSI Compliant](https://bitbucket.metro.ad.selinc.com/projects/CCRTL/repos/rtl_standard_interfaces/browse/doc/irb_rsi.doc) (byte enables are not supported)

# Internal Registers
Address | Description
:-------|---------------------
0       | IRB Address Register
1       | IRB Data Register
2       | IRB Control Register
3       | IRB Status Register

## TCON Interface
The TCON interface exposes four registers that can be used to read from and
write to the internal memory of the IRB Slave. See the IRB Control Register
(address 2) for descriptions on how to use the registers.

### IRB Address Register
This register is the address for an internal IRB read/write transaction.

### IRB Data Register
This register is the data for an internal IRB read/write transaction.

### IRB Control Register
This register houses the control interfaces. The IRB Control Register has four
relevant indices, which are all self-clearing. Reading from this register will
return all zeros.

Bit | Description
:---|--------------------------------------------------------------------------
0   | Read Operation. Writing '1' to this bit will use the contents of the IRB Address Register to read from the corresponding address in the internal memory. The result of the read will be in the IRB Data Register
1   | Write Operation. Writing '1' to this bit will use the contents of the IRB Address Register to write the content of the IRB Data Register to the corresponding address in the internal memory
2   | Delete Operation. Writing '1' to this bit will use the contents of the IRB Address Register to delete the corresponding memory location in the internal memory
3   | Dump Operation. Writing '1' to this bit will dump the contents of the internal memory to a text file, as specified by the FIN_MEM generic

The user should refrain from requesting all operations at once (writing a '1'
to each bit in the IRB Control Register within one TCON transaction). This
action may result in undefined behavior.

### IRB Status Register
This register provides statuses of operations executed from the IRB Control
Register. Reading from this register clears all indices. Writes are ignored.

Bit | Description
:---|--------------------------------------------------------------------------
0   | Requested operation resulted in an out-of-address-bound request
1   | Requested Read or Delete Operation resulted in a non-existent-address request
2   | Requested Dump Operation returned an empty file because there is nothing to write
