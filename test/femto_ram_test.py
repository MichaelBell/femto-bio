import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
from cocotb.utils import get_sim_time
from cocotb.types import LogicArray

@cocotb.test()
async def test_linear(dut):
    dut._log.info("Start")
    
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.rstrb.value = 0
    dut.rinstr.value = 0
    dut.wstrb.value = 0
    dut.mask.value = 0
    dut.data_in.value = 0
    dut.addr.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    RAM_SIZE = 2**10  # Assuming RAM_BITS=10

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.wstrb.value = 1
        dut.mask.value = 0b1111
        dut.data_in.value = addr
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1
        dut.wstrb.value = 0
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.rstrb.value = 1
        await ClockCycles(dut.clk, 1)
        assert dut.rbusy.value == 1
        dut.rstrb.value = 0
        await ClockCycles(dut.clk, 1)
        assert dut.rbusy.value == 1
        await ClockCycles(dut.clk, 1)
        assert dut.rbusy.value == 0
        assert dut.data_out.value == addr

async def write_random_word(dut, ram_data):
    addr = random.randint(0, len(ram_data)-4) & ~3
    dut.addr.value = addr
    dut.wstrb.value = 1
    dut.mask.value = 0b1111
    data_in = random.randint(0, 2**32-1)
    dut.data_in.value = data_in
    ram_data[addr] = data_in & 0xff
    ram_data[addr+1] = (data_in >> 8) & 0xff
    ram_data[addr+2] = (data_in >> 16) & 0xff
    ram_data[addr+3] = (data_in >> 24) & 0xff
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 1
    dut.wstrb.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 1

async def read_random_word(dut, ram_data):
    addr = random.randint(0, len(ram_data)-4) & ~3
    dut.addr.value = addr
    dut.rstrb.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    dut.rstrb.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 0
    expected_data = (ram_data[addr+3] << 24) | (ram_data[addr+2] << 16) | (ram_data[addr+1] << 8) | ram_data[addr]
    assert dut.data_out.value == expected_data

async def write_random_hword(dut, ram_data):
    addr = random.randint(0, len(ram_data)-2) & ~1
    dut.addr.value = addr
    dut.wstrb.value = 1
    dut.mask.value = (0b11 if (addr & 2) == 0 else 0b1100)
    dut.half.value = 1
    data_in = random.randint(0, 2**16-1)
    ram_data[addr] = data_in & 0xff
    ram_data[addr+1] = (data_in >> 8) & 0xff
    if (addr & 2) != 0:
        data_in <<= 16
    dut.data_in.value = data_in
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 1
    dut.wstrb.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 0

async def write_random_byte(dut, ram_data):
    addr = random.randint(0, len(ram_data)-1)
    dut.addr.value = addr
    dut.wstrb.value = 1
    dut.mask.value = 1 << (addr & 3)
    dut.half.value = 1
    data_in = random.randint(0, 2**8-1)
    ram_data[addr] = data_in & 0xff
    dut.data_in.value = data_in << (8 * (addr & 3))
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 1
    dut.wstrb.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.wbusy.value == 0

async def read_random_hword(dut, ram_data):
    addr = random.randint(0, len(ram_data)-2) & ~1
    dut.addr.value = addr
    dut.rstrb.value = 1
    dut.half.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    dut.rstrb.value = 0
    await ClockCycles(dut.clk, 1)
    dut.half.value = 0
    assert dut.rbusy.value == 0
    expected_data = (ram_data[addr+1] << 8) | ram_data[addr]
    recv_data = dut.data_out.value.to_unsigned()
    if addr & 2: recv_data >>= 16
    else: recv_data &= 0xffff
    assert recv_data == expected_data

async def read_random_byte(dut, ram_data):
    addr = random.randint(0, len(ram_data)-1)
    dut.addr.value = addr
    dut.rstrb.value = 1
    dut.half.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    dut.rstrb.value = 0
    await ClockCycles(dut.clk, 1)
    dut.half.value = 0
    assert dut.rbusy.value == 0
    expected_data = ram_data[addr]
    recv_data = dut.data_out.value.to_unsigned()
    recv_data = (recv_data >> (8 * (addr & 3))) & 0xff
    assert recv_data == expected_data

@cocotb.test()
async def test_random(dut):
    dut._log.info("Start")
    
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.rstrb.value = 0
    dut.rinstr.value = 0
    dut.wstrb.value = 0
    dut.mask.value = 0
    dut.data_in.value = 0
    dut.addr.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    RAM_SIZE = 2**10  # Assuming RAM_BITS=10

    ram_data = [0] * RAM_SIZE

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.wstrb.value = 1
        dut.mask.value = 0b1111
        data_in = random.randint(0, 2**32-1)
        dut.data_in.value = data_in
        ram_data[addr] = data_in & 0xff
        ram_data[addr+1] = (data_in >> 8) & 0xff
        ram_data[addr+2] = (data_in >> 16) & 0xff
        ram_data[addr+3] = (data_in >> 24) & 0xff
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1
        dut.wstrb.value = 0
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1

    for _ in range(500):
        await read_random_word(dut, ram_data)

    for _ in range(500):
        await write_random_word(dut, ram_data)
        await read_random_word(dut, ram_data)

    access_funcs = [write_random_word, read_random_word, write_random_hword, read_random_hword, write_random_byte, read_random_byte]
    for _ in range(2000):
        func = random.choice(access_funcs)
        await func(dut, ram_data)

@cocotb.test()
async def test_prefetch(dut):
    dut._log.info("Start")
    
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.rstrb.value = 0
    dut.rinstr.value = 0
    dut.wstrb.value = 0
    dut.mask.value = 0
    dut.data_in.value = 0
    dut.addr.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    RAM_SIZE = 2**10  # Assuming RAM_BITS=10

    ram_data = [0] * RAM_SIZE

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.wstrb.value = 1
        dut.mask.value = 0b1111
        data_in = random.randint(0, 2**32-1)
        dut.data_in.value = data_in
        ram_data[addr] = data_in & 0xff
        ram_data[addr+1] = (data_in >> 8) & 0xff
        ram_data[addr+2] = (data_in >> 16) & 0xff
        ram_data[addr+3] = (data_in >> 24) & 0xff
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1
        dut.wstrb.value = 0
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1

    dut.addr.value = 0
    dut.rstrb.value = 1
    dut.rinstr.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    dut.rstrb.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 0
    expected_data = (ram_data[3] << 24) | (ram_data[2] << 16) | (ram_data[1] << 8) | ram_data[0]
    assert dut.data_out.value == expected_data
    await ClockCycles(dut.clk, 1)

    for addr in range(4, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.rstrb.value = 1
        dut.rinstr.value = 1
        await Timer(5, unit="ns")
        assert dut.rbusy.value == 0
        expected_data = (ram_data[addr+3] << 24) | (ram_data[addr+2] << 16) | (ram_data[addr+1] << 8) | ram_data[addr]
        assert dut.data_out.value == expected_data
        await ClockCycles(dut.clk, 1)
        dut.rstrb.value = 0
        await ClockCycles(dut.clk, 1)

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.rstrb.value = 1
        dut.rinstr.value = 1
        await Timer(5, unit="ns")
        assert dut.rbusy.value == 0
        expected_data = (ram_data[addr+3] << 24) | (ram_data[addr+2] << 16) | (ram_data[addr+1] << 8) | ram_data[addr]
        assert dut.data_out.value == expected_data
        await ClockCycles(dut.clk, 1)
        dut.rstrb.value = 0
        await ClockCycles(dut.clk, random.randint(1, 3))

@cocotb.test()
async def test_mix(dut):
    dut._log.info("Start")
    
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    dut.rst_n.value = 0
    dut.rstrb.value = 0
    dut.rinstr.value = 0
    dut.wstrb.value = 0
    dut.mask.value = 0
    dut.data_in.value = 0
    dut.addr.value = 0
    dut.half.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    RAM_SIZE = 2**10  # Assuming RAM_BITS=10

    ram_data = [0] * RAM_SIZE

    for addr in range(0, RAM_SIZE, 4):
        dut.addr.value = addr
        dut.wstrb.value = 1
        dut.mask.value = 0b1111
        data_in = random.randint(0, 2**32-1)
        dut.data_in.value = data_in
        ram_data[addr] = data_in & 0xff
        ram_data[addr+1] = (data_in >> 8) & 0xff
        ram_data[addr+2] = (data_in >> 16) & 0xff
        ram_data[addr+3] = (data_in >> 24) & 0xff
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1
        dut.wstrb.value = 0
        await ClockCycles(dut.clk, 1)
        assert dut.wbusy.value == 1

    dut.addr.value = 0
    dut.rstrb.value = 1
    dut.rinstr.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    dut.rstrb.value = 0
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 1
    await ClockCycles(dut.clk, 1)
    assert dut.rbusy.value == 0
    expected_data = (ram_data[3] << 24) | (ram_data[2] << 16) | (ram_data[1] << 8) | ram_data[0]
    assert dut.data_out.value == expected_data
    await ClockCycles(dut.clk, 1)

    access_funcs = [write_random_word, read_random_word, write_random_hword, read_random_hword, write_random_byte, read_random_byte]
    interrupted = False
    for i in range(4, RAM_SIZE * 20, 4):
        addr = i % RAM_SIZE
        dut.addr.value = addr
        dut.rstrb.value = 1
        dut.rinstr.value = 1
        await Timer(5, unit="ns")
        if interrupted:
            interrupted = False
            if dut.rbusy.value == 1:
                await ClockCycles(dut.clk, 1)
                assert dut.rbusy.value == 1
                dut.rstrb.value = 0
                await ClockCycles(dut.clk, 1)
                assert dut.rbusy.value == 1
                await ClockCycles(dut.clk, 1)
        assert dut.rbusy.value == 0
        expected_data = (ram_data[addr+3] << 24) | (ram_data[addr+2] << 16) | (ram_data[addr+1] << 8) | ram_data[addr]
        assert dut.data_out.value == expected_data
        await ClockCycles(dut.clk, 1)
        dut.rstrb.value = 0
        dut.rinstr.value = 0

        if random.randint(0, 5) == 0:
            func = random.choice(access_funcs)
            await func(dut, ram_data)
            interrupted = True
        else:
            await ClockCycles(dut.clk, 1)
