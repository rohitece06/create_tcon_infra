<!---
  Copyright (c) 2019 Schweitzer Engineering Laboratories, Inc.
  SEL Confidential
-->

# Name: *tb_tcon_start_done_slave*

# Main Features

- Testbench component used for testing Start-Done master interface(s) of a component
- Start-Done RSI compliant
- [TCON](https://bitbucket.metro.ad.selinc.com/projects/CCRTL/repos/tb_tcon/browse ) compliant
  - TCON 1.0
  - TCON 2.0

# Application Information

The *tb_tcon_start_done_slave* test component records input data to a file when *start* is pulsed, and then   delays  the *done* pulse by *delay* clock cycles.

The *data* bus can be sized arbitrarily as necessary but only accepts a single *std_logic_vector* at a time.  External processing is needed to convert from any other format.

The *delay* input is an integer so that it can be either static or written as needed.

**Note**: This component will not send back-to-back *done* (i.e., *done* will always de-assert for at least one clock   cycle)

# Interface

## Generics

| Name       | Width    | Description                                                  |
| ---------- | -------- | ------------------------------------------------------------ |
| DATA_WIDTH | positive | Width of the input data. This is the size, in bits, of the data field in the input <br />file, not including flags |
| FLAG_WIDTH | natural  | Number of flags on the input data. This is the  number of bits of additional <br />flags present in the  input file. |
| LOG_FILE   | string   | Name of the file to log data to                              |
| FLOP_DELAY | time     | Delay before assigning signals                               |

## Ports

| Name      | Direction | Width                   | Description                                                  |
| --------- | --------- | ----------------------- | ------------------------------------------------------------ |
| tcon_req  | in        | 1                       | TCON request signal                                          |
| tcon_ack  | out       | 1                       | TCON acknowledgement  signal                                 |
| tcon_err  | out       | 1                       | TCON error signal                                            |
| tcon_addr | in        | 32                      | TCON address signal                                          |
| tcon_data | inout     | *                       | TCON bi-directional data  bus (un-constrained size)          |
| tcon_rwn  | in        | 1                       | TCON read-write signal                                       |
| clk       | in        | 1                       | System clock                                                 |
| reset     | in        | 1                       | *start* pulses are ignored when *reset* is asserted. If  *reset* is <br />asserted during the delay period between *start* and *done* <br />pulses, the delay is aborted. Asserting *reset* resets the <br />delay counter but none of the other TCON-accessible <br />counters, and does not affect the stimulus file pointer. <br />A note is printed if *reset* occurs between a *start* and a <br />*done* pulse.|
| start     | in        | 1                       | This signal is sampled on the rising edge of *clk*. When <br />*start* asserts, the contents of *data* is written to LOG_FILE. If <br />*start* remains asserted or pulses again before *done*<br /> is pulsed, it is ignored. Pulses during *reset* are ignored. |
| delay     | in        |                         | Delay between the *start* pulse and the *done* pulse. Any <br />natural value is permissible. A value of 0 will assert *done* <br />when *start* is detected on the rising edge. Any activity on<br /> *start* during the   delay period is ignored. Asserting <br /> *reset* will abort the delay period. |
| done      | out       | 1                       | Pulsed *delay* clock cycles after *start*.                   |
| data      | in        | DATA_WIDTH + FLAG_WIDTH | Data input from the design under test associated <br /> with the *start* pulse. This data is logged to the log <br /> file. |
| unpause   | in        | 1                       | Un-pauses this component. Currently ignored by <br />the code (added to support future extension) |
| is_paused | out       | 1                       | Provides the pause state (Boolean type) of this<br />component. Currently tied to 'false' by the code (added <br />to support future extension) |

**Note:** The TCON interface (*tcon_*\* signals) need not be mapped if the TCON interface is not used.

# Output File Format

Data is written to LOG_FILE file in hexadecimal format sans radix:

Example when FLAG_WIDTH = 0 and DATA_WIDTH = 10: 

| Input Vector (Binary) | Output File Contents |
| :-------------------- | :------------------- |
| "00_0000_0001"        | 001                  |
| "00_0010_0010"        | 022                  |
| "11_1111_1000"        | 3F8                  |

Example when FLAG_WIDTH = 3 and DATA_WIDTH = 10 : 

| Input Vector (Binary) | Output File Contents |
| :-------------------- | :------------------- |
| "0_0000_0000_0001"    | 001  0 0 0           |
| "1_0000_0010_0010"    | 002  1 0 0           |
| "1_1011_1111_1000"    | 3F8  1 1 0           |

**Note:** First flag in the log file is the most significant bit on the *data* input.

# TCON Interface

The TCON interface has 4 accessible registers 

| Offset | Name        | Width | Description                                                  |
| ------ | ----------- | ----- | ------------------------------------------------------------ |
| 0      | START_COUNT | 32    | The number of *start* pulses received. Reset the counter by writing any value to it. Incremented synchronously.<br />Note: asserting *reset* will not reset the counter. |
| 1      | DONE_COUNT  | 32    | The number of done pulses generated. Reset the counter by writing any value to it. Incremented synchronously. <br />Note: asserting *reset* will not reset the counter. |
| 2      | DELAY_COUNT | 32    | The current number of clock cycles until the delay counter expires. A value of 0 indicates that delay is not in progress. <br />Incremented synchronously. Assert *reset* to clear the counter. |
| 3      | STATUS      | 32    | Status register, read only. Bits 31 down to 1 are undefined and are read as 0. <br />Bit 0 = 1 indicates delay is in progress or that *done* is asserted. |