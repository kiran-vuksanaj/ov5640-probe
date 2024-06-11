import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def my_first_test(dut):


    dut.clk_in.value = 0
    dut.rst_in.value = 1
    await Timer(5, units="ns")
    dut.clk_in.value = 1
    await Timer(5, units="ns")
    dut.clk_in.value = 0
    dut.rst_in.value = 0

    print(dir(dut))
    
    for cycle in range(10):
        dut.clk_in.value = 0
        await Timer(5, units="ns")
        dut.clk_in.value = 1
        await Timer(5, units="ns")

    dut._log.info("hsync_out is %s",dut.hcount_out.value)
    assert dut.valid_out.value == 0, "came up with a valid out somehow??"



