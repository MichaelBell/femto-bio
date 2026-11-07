import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
from cocotb.utils import get_sim_time
from cocotb.types import LogicArray

async def apb_write(dut, addr, data, max_delay=1):
    dut.paddr.value = addr
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 1
    dut.pwdata.value = data
    await ClockCycles(dut.clk, 1)
    dut.penable.value = 1
    await ClockCycles(dut.clk, 1)
    delay_count = 1
    await Timer(1, unit="ns")
    while not dut.pready.value and delay_count < max_delay:
        await ClockCycles(dut.clk, 1)
        await Timer(1, unit="ns")
        delay_count += 1
    assert dut.pready.value
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0

async def apb_read(dut, addr, max_delay=1):
    dut.paddr.value = addr
    dut.psel.value = 1
    dut.penable.value = 0
    dut.pwrite.value = 0
    await ClockCycles(dut.clk, 1)
    dut.penable.value = 1
    await ClockCycles(dut.clk, 1)
    delay_count = 1
    await Timer(1, unit="ns")
    while not dut.pready.value and delay_count < max_delay:
        await ClockCycles(dut.clk, 1)
        await Timer(1, unit="ns")
        delay_count += 1
    assert dut.pready.value
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    return dut.prdata.value

@cocotb.test()
async def test_start(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 5)

    # Enable the core
    await apb_write(dut, 0x0, 0x1)

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

@cocotb.test()
async def test_mem_access(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 5)

    await apb_write(dut, 0x9100, 0x12345678, 2)
    assert await apb_read(dut, 0x9100, 2) == 0x12345678

    # Start program
    await apb_write(dut, 0x0, 0x1)

    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        if dut.gpio_oe.value == 0x2000:
            break
    else:
        assert False, "Timeout waiting for gpio_oe to become 0x2000"

    for _ in range(10):
        # Check access still works while program is running
        addr = random.randint(0x9100, 0x93FC) & ~0x3  # Align to word boundary
        data = random.randint(0, 0xFFFFFFFF)
        await apb_write(dut, addr, data, 6)

        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0x2000:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0x2000"

        assert await apb_read(dut, addr, 6) == data

        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0"    