[//]: # (Copyright 2018, Schweitzer Engineering Laboratories, Inc.)
[//]: # (SEL Confidential)
# tb_tcon_clocker
## Introduction
This module provides the ability to generate an arbitrary number
of clocks with varying phase and frequency relationships.

Each clock is individually controllable configurable and
can be started and stopped at any time.

## Application Information
The tb_tcon_clocker modules creates clocks of the shape shown below.

![Clock Timing](clock-timing.svg)

Individual clocks can be configured and controlled through banks
of 4 registers each.  The first bank (offset 0 through offset 3)
controls `clks[0]`, the second bank (offset 5 through offset 7)
controls `clks[1]`, etc.  The banks of registers only exist for
the number of clocks configured via the `NUM_CLOCKS` generic.

The `DELAY_*` registers sets the initial delay before the
clock begins to operate. Until that time has elapsed for a given
clock, the output will be held at '0'. The `HIGH_*` registers set
the high time, and `LOW_*` sets the low time.  The clock repeats
the high and low times.

Clocks begin "paused."  That is, the `clks[n]` output remains idle
until the corresponding `CON_*` register is written to unpause
the clock.  A write of '0' to the `CON_*` unpauses the clock.
A clock may be paused at any time by writing a '1' to `CON_*`.

Note that changing the `DELAY_*`, `HIGH_*`, or `LOW_*` registers
while the clock is unpaused may cause undefined or
erratic behavior.  Always ensure a clock is paused
before changing any of the parameters.

## Generics
**Name**   |**Range**| **Description**
:----------|:-------:|:--------------
NUM_CLOCKS | natural | Number of clocks

## Signals
**Name**  |**Width**   |**Direction**|**Description**
:---------|:----------:|:------------|:--------------
tcon_req  | 1          | in          | Tcon request
tcon_ack  | 1          | out         | Tcon acknowledge
tcon_err  | 1          | out         | Tcon error
tcon_addr | 32         | in          | Tcon address
tcon_data | 32         | inout       | Tcon data
tcon_rwn  | 1          | in          | Tcon read/not write
clks      | NUM_CLOCKS | out         | Clock output; defaults to '0' until unpaused and DELAY time elapses.

## Internal Registers
**Offset**|**Name**  |**Description**              | **Dir**
:---------|:---------|:----------------------------|:---:
N*4+0x0000| DELAY_N  | Clock N Delay               | RW
N*4+0x0001| HIGH_N   | Clock N High Time           | RW
N*4+0x0002| LOW_N    | Clock N Low Time            | RW
N*4+0x0003| CON_N    | Clock N Control             | RW

Where N is the clock number corresponding to the bit in `clks`.

## Register Descriptions

### DELAY_\*; (Offset N\*4 + 0)
**Bits**|**Field**|**RW**| **Reset**  |**Description**
:------:|:------:|:----:|:----------:|:--------------------
31:0    | DELAY  | RW   | 0x00000000 | Delay time.  This number of picoseconds to delay before starting the clock after being enabled.

### HIGH_\*; (Offset N\*4 + 1)
**Bits**|**Field**|**RW**| **Reset**  |**Description**
:------:|:------:|:----:|:----------:|:--------------------
31:0    | HIGH   | RW   | 0x00000000 | High time.  The number of picoseconds of high time.

### LOW_\*; (Offset N\*4 + 2)
**Bits**|**Field**|**RW**| **Reset**  |**Description**
:------:|:------:|:----:|:----------:|:--------------------
31:0    | LOW    | RW   | 0x00000000 | Low time.  The number of picoseconds of low time.

### CON_\*; (Offset N\*4 + 3)
**Bits**| **Field**     |**RW**| **Reset**  |**Description**
:------:|:-------------:|:----:|:----------:|:--------------------
0       | PAUSE         | RW   | 0          | Writing a '1' pauses the clock.  Writing a '0' unpauses the clock.  Reads return the current pause state.
31:1    | *Reserved*    | N/A  |  N/A       | Reserved.  Must write to 0.  Reads are undefined.
