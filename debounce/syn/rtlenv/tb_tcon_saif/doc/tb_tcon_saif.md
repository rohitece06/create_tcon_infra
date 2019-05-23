[//]: # (Copyright 2018, Schweitzer Engineering Laboratories, Inc.)
[//]: # (SEL Confidential)
# tb_tcon_saif SAIF TCON Component

## Application Information
The tb_tcon_saif component is intended as a generic testbench module for
transmitting and receiving data via SAIF.  It can be used as either a master
or slave (or both).  This readme gives an overview of operation.

## Interface
#### Generics
|Name|Type|Description|
|:---------|:-------:|:--------|
DATA_WIDTH | integer | Width of the data.  This is the size, in bits, of the data field in the input and output files.
FLAG_WIDTH | integer | Number of flags.  This is the number of bits of additional flags present in the input and output files.
COMMAND_FILE | string | Name of the command file.  Must be present.
LOG_FILE | string | Logging filename.  Data recieved via SAIF is logged to this file.
FLOP_DELAY | time | Output delay on output signals

#### Ports
_Note: If TCON port is unused, tie inputs to '0' and leave outputs
             open. Otherwise, connect to a TCON bus for control._

| Port | Width | Description|
|------|:-----:|:-----------|
|tcon_req  | 1 | TCON Interface
|tcon_ack  | 1 | TCON Interface
|tcon_err  | 1 | TCON Interface
|tcon_addr | 32 | TCON Interface
|tcon_data | 32 | TCON Interface
|tcon_rwn  | 1 | TCON Interface
|paused    | 1 | TCON interface
|unpause   | 1 | Unpause component if TRUE, and component is currently paused
|clk       | 1 |  Clock for SAIF transactions
|rts_rtr   | 1 | For a SAIF Master, this is rts.  For SAIF slaves, this is rtr.
|cts_ctr   | 1 | For a SAIF Master, this is cts.  For SAIF slaves, this is ctr.
|data      | any | For a SAIF master, this is an output.  For a SAIF slave, this is an input.

The data is on the DATA_WIDTH-1:0 bits of the bus and the flags are on
DATA_WIDTH+FLAG_WIDTH-1:DATA_WIDTH bits of the bus.  See below
for a description of the data and flag bits.


##  File formats and commands
The COMMAND_FILE format is a line by line list of commands.  Depending upon
the command, the tb_tcon_saif module operates as either a slave or a master.  The
command file is processed until the file is exhausted.  Once exhausted, the
component will restart at the beginning of the file.

The following commands are available:

Note: For any number or data field, if no leading '0x' or '0b' is
specified, a decimal is assumed. Otherwise, add a leading '0x' or
'0b' to ensure the proper base.

`pause`

Pauses the component.  Can only be unpaused via the TCON interface, or by
asserting the 'unpause' input.

When paused, the processing of the command file is paused, rts_rtr is
deasserted, and data is set to 'Z'.

`idle N`

Idles the component for N clock cycles.

During an idle, rts_rtr is deasserted and data is an input until the idle is
complete.

`seed N`

Set the seed for all random number generation to the number N.

`burst min [max]`

Sets the burst count for transfers.  Must be greater than 0.  If only
min is given, sets the burst to a fixed value of 'min'.  If min and max
are given, each burst is randomized in the interval `[min, max]`.

A burst is the number of transfers that occur prior to a delay.  Bursts are
interrupted by another burst command or pausing the component.  During a burst
rts_rtr is asserted until the burst is complete.

Default:  1

`delay min [max]`

Sets the delay count between burst transfers.  May be 0.  If only min is given,
sets the delay to a fixed value of 'min'.  If min and max are given, each delay
is randomized in the interval `[min, max]`.

A delay is the number of idle clock cycles between bursts.  This is identical
to a idle(N) command which is automatically inserted after every burst completes.  During a
delay, rts_rtr is deasserted until the delay is complete.

Default: 0

`read [N]`

Read.  Reads N values via SAIF transfers.  If N is not present, then tb_tcon_saif
will do natural'high reads (2**31, essentially forever).  If present, must be
greater than 0.  This operates the tb_tcon_saif component as a SAIF slave.  Data is
an input.  A burst immediately begins followed by any delays.

The data input is output to the LOG_FILE in the following format:

  D F F ... F

Where D is the data portion and each F is a flag.
For example, for a DATA_WIDTH of 8
and a FLAG_WIDTH of 3, and data="11010010101", the output would be:

  95 1 1 0

Note that the most significant flag is the first flag output to the file.

`data`

Any line not matching any of the earlier commands is assumed to be data.
The 'data' is a the data to write via a SAIF transfer.  The format of
the data is:

  D F F ... F

Where D is the data portion and each F is a flag.
For example, for a DATA_WIDTH of 8
and FLAG_WIDTH of 3, the format would be:

  0xFF 0 1 1

This would be output onto the data output as "01111111111".  Note that the
first flag in the input file is the most signficant bit on the data output.


##  TCON Interface
The TCON interface exposes 8 registers to control and configure the tb_tcon_saif
component.

| Name | Offset|
|------|-------|
|control    |0 |
|min. burst | 1|
|max. burst | 2|
|min. delay | 3|
|max. delay | 4|
|seed       | 5|
|read count | 6|
|write count| 7|

They are described below.

#### Control (Address 0)
Bit 0 is the paused status.  If a 1, the component is paused.  If paused,
it may be written to a 1 to unpause the component.  A write of 0 is ignored.

#### Minimum Burst (Address 1)
Sets the minimum burst.  Must be less than or equal to the Maximum Burst
register, and larger than 0 if being used.  This can be changed while the
component is unpaused, but may cause the component to operate
unpredictably.  If Minimum Burst and Maximum Burst are unequal, the
the burst is randomized.

#### Maximum Burst (Address 2)
Sets the maximum burst.  Must be greater than or equal to the Minimum Burst
register.  This can be changed while the component is unpaused, but may cause
the component to operate unpredictably.  If Minimum Burst and Maximum Burst
are unequal, the the burst is randomized.

#### Minimum Delay (Address 3)
Sets the minimum delay (in clock cycles).  Must be less than or equal to the Maximum Delay
register.  This can be changed while the component is unpaused, but may cause
the component to operate unpredictably.  If Minimum Delay and Maximum Delay
are unequal, the the delay is randomized.

#### Maximum Delay (Address 4)
Sets the maximum delay (in clock cycles).  Must be greater than or equal to the Minimum Delay
register.  This can be changed while the component is unpaused, but may cause
the component to operate unpredictably.  If Minimum Delay and Maximum Delay
are unequal, the the delay is randomized.

#### Seed (Address 5)
Sets/gets the random seed used for generating all random numbers
(e.g. delay, burst, etc.).  This can be changed while the component
is unpaused, but may cause the component to operate unpredictably.
This register value may also be set using the `seed` command in
stimulus files.

#### Read Count (Address 6)
Read only.  Returns the number of transfers into the SAIF interface.

#### Write Count (Address 7)
Read only.  Returns the number of transfers out of the SAIF interface.
