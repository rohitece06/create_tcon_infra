@echo off
set arg1=%1
vsim -c -do "do ../syn/rtlenv/rtl_make/RTL_make.tcl simulate testno %arg1% logunits \{ / \} logrecursive"