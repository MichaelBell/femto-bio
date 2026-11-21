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

async def load_program(dut, addr, hex_file):
    even = False
    with open(hex_file, "r") as f:
        for line in f:
            if even:
                data = data | (int(line.strip(), 16) << 16)
                await apb_write(dut, addr, data, 2)
                addr += 4
            else:
                data = int(line.strip(), 16)
            even = not even

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

    # Disable the core
    await apb_write(dut, 0x0, 0x0)

    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        assert dut.gpio_out.value == 0

    # Edit program on core 1 so it toggles pin 12
    await apb_write(dut, 0xb000, 0x00001537, 2)

    # Enable core 1
    await apb_write(dut, 0x0, 0x2)

    for _ in range(10):
        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0x1000:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0x2000"
    
        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0:
                break
        else:
            assert False, "Timeout waiting for gpio_out to become 0"


    # Enable core 0
    await apb_write(dut, 0x0, 0x3)

    for _ in range(10):
        for _ in range(100):
            await ClockCycles(dut.clk, 1)
            if dut.gpio_out.value == 0x3000:
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

    assert await apb_read(dut, 0x0) == 0
    assert await apb_read(dut, 0x4) == 0x04000280
    assert await apb_read(dut, 0xc) == 0
    assert await apb_read(dut, 0x40) == 0x55000000

    await apb_write(dut, 0x38, 0x1)
    assert await apb_read(dut, 0x40) == 0x55000001
    await apb_write(dut, 0x3c, 0x1)
    assert await apb_read(dut, 0x40) == 0x55000000
    await apb_write(dut, 0x38, 0xFFFFFF)
    assert await apb_read(dut, 0x40) == 0x55FFFFFF
    await apb_write(dut, 0x3c, 0xFFF000)
    assert await apb_read(dut, 0x40) == 0x55000FFF
    await apb_write(dut, 0x3c, 0xFFF)
    assert await apb_read(dut, 0x40) == 0x55000000

    await apb_write(dut, 0x9100, 0x12345678, 2)
    assert await apb_read(dut, 0x9100, 2) == 0x12345678

    # Start program
    await apb_write(dut, 0x0, 0x1)
    assert await apb_read(dut, 0x0) == 1

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

async def expect_byte(dut, uart_byte, tx_pin=None, bit_time=8680):
    if tx_pin is None:
        tx_pin = dut.uart_tx

    await Timer(bit_time // 2, "ns")
    assert tx_pin.value == 0
    for i in range(8):
        await Timer(bit_time, "ns")
        assert tx_pin.value == (uart_byte & 1)
        uart_byte >>= 1
    await Timer(bit_time, "ns")
    assert tx_pin.value == 1
    await Timer(bit_time // 2, "ns")
    assert tx_pin.value == 1

async def send_byte(dut, val, rx_pin=None, bit_time=8680):
    if rx_pin is None:
        rx_pin = dut.uart_rx

    rx_pin.value = 0
    await Timer(bit_time, "ns")
    for i in range(8):
        rx_pin.value = val & 1
        await Timer(bit_time, "ns")
        val >>= 1
    rx_pin.value = 1
    await Timer(bit_time, "ns")

@cocotb.test()
async def test_uart_tx_program(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 5)

    # Load UART TX program into core 0
    await load_program(dut, 0x9000, "../bioasm/uart_tx.hex")

    # Set quantum for core 0 to 115200 baud assuming 50MHz clock
    await apb_write(dut, 0x50, ((50_000_000 * 256) // 115200) << 8)

    # Start core 0
    await apb_write(dut, 0x0, 0x1)

    # Wait for GPIO 3 to go high
    for _ in range(100):
        await ClockCycles(dut.clk, 1)
        if dut.gpio_out.value == 0x8:  # GPIO 3 corresponds to bit 3
            break
    else:
        assert False, "Timeout waiting for GPIO 3 to go high"

    # Push data to UART TX FIFO
    await apb_write(dut, 0x10, 0x5A)

    # Wait for GPIO 3 to go low
    for _ in range(1000):
        await ClockCycles(dut.clk, 1)
        if dut.gpio_out.value == 0:  # GPIO 3 corresponds to bit 3
            break
    else:
        assert False, "Timeout waiting for GPIO 3 to go low"

    # Expect UART TX to transmit the byte 0x5A
    await expect_byte(dut, 0x5A)

@cocotb.test()
async def test_uart_rx_program(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    dut.gpio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 5)

    # Load UART RX program into core 0
    await load_program(dut, 0x9000, "../bioasm/uart_rx.hex")

    # Set quantum for core 0 to 115200 baud assuming 50MHz clock
    await apb_write(dut, 0x50, ((50_000_000 * 256) // (115200 * 5)) << 8)

    # Start core 0
    await apb_write(dut, 0x0, 0x1)

    # Wait for core to init
    await ClockCycles(dut.clk, 50)

    # Send byte 0x5A to UART RX
    await send_byte(dut, 0x5A)

    # Read byte from FIFO
    assert await apb_read(dut, 0x24) == 0x5A  # Read from UART RX FIFO
