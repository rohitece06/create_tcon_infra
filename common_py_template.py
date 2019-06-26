import os
import logging
import sys
import pytcon
import pytcon_objects

# Setup logging
log = logging.getLogger()  # 'root' Logger
console = logging.StreamHandler()
format_str = '%(levelname)s -- %(filename)s:%(lineno)s -- %(message)s: '
console.setFormatter(logging.Formatter(format_str))
log.addHandler(console)  # prints to console.
log.setLevel(logging.ERROR)  # anything ERROR or above

################################################################################
#
#    Functions/constants common to all tests
#
################################################################################

# Initialize TCON 2.0
from zeromq_manager import ZeromqManager
print(f"TCON instance '{sys.argv[-2]}' connecting to"
      f"FA at tcp://127.0.0.1:{sys.argv[-1]}")
tcon = pytcon.Tcon(ZeromqManager("tcp://127.0.0.1:" + sys.argv[-1]))
tcon.resolution = tcon.NANOSECONDS

##########################################################
# System Definitions
##########################################################

CLEAR = 0
SET = 1
ONES = 0xFFFFFFFF
GPIO_RESET = (1 << 0)  # Output


def do_reset(num_clocks):
    """Asserts reset for number of cycles to reset, if implemented, the
    tb/UUT. Reset is de-asserted after given number of clock cycles

    Args:
        num_clocks (int): Number of clock cycles to assert the GPIO_RESET
        line on TCON master's GPIO bus

    Returns:
        None

    Example:
        >>> do_reset(10)

    """
    # Asert the reset
    tcon.gpio_set(GPIO_RESET)

    # Idle for a bit (to allow the reset to take affect)
    tcon.sync(num_clocks)

    # Clear the reset
    tcon.gpio_clr(GPIO_RESET)

    tcon.sync(2)


def verify_gpio(name, exp, mask):
    """Check TCON master's GPIO(s) for assertion/deassertion

    Args:
        name (str): Name to represent GPIO lines
        exp  (int): Expected value of GPIO lines
        mask (int): Bitmask to indicate which GPIO line should be checked for
                    expected value

    Returns:
        None

    Example:
        Check 6th GPIO line, which represents a "Begin Pulses", for assertion
        and 5th GPIO line, which represents end pulse, for deassertion:
        >>> verify_gpio("Begin and End Pulse", 0x40, 0x60)

    """
    # Read tcon gpio value
    val = tcon.gpio_get() & mask

    if val == 0:
        output = 0
    else:
        output = 1

    if output != exp:
        log.error(f"{tcon.now()}ns :"
                  f"{name} signal value is {output}, expects {exp}")


def verify_signal(name, sig, exp):
    """Check an internal 1 bit RTL signal for assertion/deassertion

    Args:
        name (str) = name of the signal to be printed in message
        sig  (str) = signal identifier
        exp  (int/str) = expected value of "sig". Valid values are
                         0, 1, "0", "1", "0", "1"

    Returns:
        boolean: True if successful, False otherwise

    Example:
        Check internal signal .tb.uut.begin_counting for assertion
        (assuming it is asserted)

        >>> verify_signal("Begin Counting", ".tb.uut.begin_counting ", 1)
        True

    """
    # Read tcon gpio value
    output = tcon.get_signal(sig)
    if isinstance(exp, str):
        result = output == exp
    elif isinstance(exp, int):
        result = int(output, 2) == exp
    else:
        result = False

    if not result:
        log.error(f"{tcon.now()}ns : "
                  f"{name} output value is {output}, expects {exp}")

    return result


def print_banner(test_dir, testplan_no):
    """Print starting banner for a test

    Args:
        test_dir (str)    : Test directory name
        testplan_no (str) : Testplan number. This should match the number from
                            the testplan.

    Returns:
        None

    Example:
        >>> print_banner("001_reset", "1.1")

    """
    print("*"*80)
    log.info(f"***  {test_dir.upper()} :  Test {testplan_no}")


def print_complete():
    """Print a message after a test has completed (successfully or otherwise).
    This function also checks if test has actually run for non-zero time. This
    function should be called at the end of every tcon.py, right before
    simulation is halted with tcon.halt()

    Args:
        None

    Returns:
        None

    """
    if tcon.now() == 0:
        log.error(f"\n Test Not Executed!\n")
    else:
        log.info(f"\n************ Time {tcon.now()}ns: "
                 f"Testbench Completed ******************")


def read_reg(req, addr, mask=0xFFFFFFFF, name=None, expected=None):
    """Read (and check) a register value in TCON address map

    Args:
        req (int): TCON request line number at which the component, with the
                   read register, is mapped
        addr (int): Address offset of the register
        mask (int): Bitmask to represent which register bit(s) are read/checked
        name (str): Name to represent the register
        expected (int): Expected value of the register

    Returns:
        int: Register value masked with "mask"

    Example:
        Check all 16 bits of "frame count" register (address = 4) inside the
        component mapped to first TCON request line (req=0) for a value of 5
        (assuming the value is inded 5)
        >>> read_reg(0, 4, 0xFFFF, "frame count", 5)
        5

    """
    read_val = 0

    read_val = tcon.read(req, addr)
    read_val = read_val & mask

    if name is not None:
        if read_val != expected:
            log.error(f"({tcon.now()} ns) read value of {name} = "
                      f"{read_val:#0x}, expected = {expected:#0x}")
    return read_val


def write_reg(req, addr, val, mask=0xFFFFFFFF):
    """Write a register in TCON address map

    Args:
        req (int): TCON request line number of the component where the register
                   resides
        addr (int): Address offset of the register
        val (int) : Value to be written
        mask (int): Bitmask to represent which register bit(s) are written

    Returns:
        int: Read-after-write register value
    """
    write_val = val & mask
    read_val = tcon.write(req, addr, write_val)
    return read_val


def wait_on_reg(name, req, addr, expected, timeout=10000):
    """Wait for a value to occur on a register

    Args:
        name     (str): Name to represent the register
        req      (int): TCON request line number at which the component, with
                        the checked register resides, is mapped
        addr     (int): Address offset of the register
        expected (int): Expected value of the register
        timeout  (int): Number of clock cycles to wait before timeout

    Returns:
        str: "OK" if register reached the desired value before timeout otherwise
             "TIMEOUT"

    Example:
        Wait until "frame count" register (address = 4) inside the
        component mapped to first TCON request line (req=0) reached a value of 5
        (assuming frame count successfully reaches 5)
        >>> wait_on_reg("frame count", 0, 4, 5)
        "OK"

    """
    cnt = 0
    status = "OK"
    val = tcon.read(req, addr)
    while val != expected and cnt < timeout:
        tcon.sync(1)
        val = tcon.read(req, addr)
        cnt = cnt + 1

    if cnt == timeout:
        status = "TIMEOUT"
        log.error(f"{tcon.now()}ns : Timed-out waiting for {name}={expected}")
    return status


def wait_on_signal(name, sig, expected, timeout=100):
    """Wait for a signal to assume an expected value

    Args:
        name     (str): Name to represent the register
        sig      (int): Internal signal name with full RTL hierarchy
        expected (int): Expected value of the register
        timeout  (int): Number of clock cycles to wait before timeout

    Returns:
        str: "OK" if register reached the desired value before timeout otherwise
             "TIMEOUT"

    Example:
        Wait for internal signal .tb.uut.begin_counting for assertion;
        timeout if it does not occur within 5 clock cycles:

        >>> wait_on_signal("Begin Counting", ".tb.uut.begin_counting ", 1, 5)
        "OK"

    """

    cnt = 0
    signal_value = int(tcon.get_signal(sig))
    start_time = str(tcon.now())
    status = "OK"
    while (signal_value != expected and (cnt < timeout or timeout <= 0)):
        tcon.sync(1)
        signal_value = int(tcon.get_signal(sig))
        cnt = cnt + 1

    if cnt == timeout:
        status = "TIMEOUT"
        if expected == CLEAR:
            log.error(f"wait_on_signal() timed-out: {name} "
                      f"never went LOW since {start_time}")
        else:
            log.error(f"wait_on_signal() timed-out: {name} "
                      f"never went HIGH since {start_time}")

    return status


def conv_val_str(val):
    """Convert a VHDL data type to the corresponding Python data type.
    NOTE: only supports integer, boolean, string, and hexadecimal SLV types.

    Args:
        val (str): The VHDL data type as a String

    Return:
        boolean/str/int type based on the input string

    Raises:
        ValueError: If "val" is not a valie VHDL type as mentioned in the NOTE
                    above

    Example:
        >>> conv_val_str("x"ABC123"")
        11256099

    """
    # Boolean.
    if val.lower() == "true":
        return True
    # Boolean.
    elif val.lower() == "false":
        return False
    # String.
    elif val[0] == '"':
        return val.strip('"').upper() # Remove the quotes.
    # Hexadecimal string.
    elif val[0] == "x":
        return int(val[2:-1], 16)  # Remove the quotes, convert to int.
    # Integer.
    elif val.isdigit():
        return int(val)
    # Unsupported.
    else:
        raise ValueError(f"Unsupported generic value: {val}.")


def get_generics(sim_dir):
    """Returns VHDL generic values for this simulation.
    NOTE: only supports integer, boolean, string, and hexadecimal SLV types.
    If sim.params exists, generic values will be pulled from there first. The
    expected format in that file looks like:
        GENERIC_INT 0
        GENERIC_STR "00001111"
        GENERIC_HEX x"ABC123"
        GENERIC_BOOL TRUE

    Args:
        sim_dir (str): Test directory name with respect to "sim" directory

    Returns:
        dict: Python dictionary type with following format:
                {generic name: value}

    Example:
        Get generics from test "001_reset" and a sim_params.txt with content
        shown above in notes.
        >>> get_generics("001_reset")
        {"GENERIC_INT" : 0, "GENERIC_STR": "00001111", "GENERIC_HEX": 11256099,
         "GENERIC_BOOL": True}

    """
    generics = {}
    fname = (sim_dir + "/sim_params.txt").replace("\\", "/")
    # Use what's in sim.params if it exists.
    if os.path.exists(fname):

        with open(fname) as sim_params:
            for line in sim_params:
                # Split the generic/value pair into separate variables.
                key, val = (" ".join(line.strip().split())).split(" ")

                # Store the generic/value pair.
                generics[key] = conv_val_str(val)
        return generics
    else:
        log.error("sim_params.txt path does not exist")
        return None

################################################################################
#
#                      UUT/TB-specific functions starts below
#
################################################################################
