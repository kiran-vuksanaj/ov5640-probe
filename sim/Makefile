
# defaults
SIM ?= icarus
WAVES ?= 1
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(PWD)/../hdl/dvp_receiver.sv

TOPLEVEL = dvp_receiver

MODULE = test_cocotb

# include coctb make rules to set up simulator?
include $(shell cocotb-config --makefiles)/Makefile.sim
