import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
from cocotb.utils import get_sim_time
from cocotb.types import LogicArray

@cocotb.test()
async def test_start(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        if dut.gpio_oe.value == 0x2000:
            break
    else:
        assert False, "Timeout waiting for gpio_oe to become 0x2000"

    for _ in range(10):
        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0x2000:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0x2000"
    
        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0"
    
