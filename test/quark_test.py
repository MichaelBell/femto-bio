import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer, FallingEdge, RisingEdge
from cocotb.utils import get_sim_time
from cocotb.types import LogicArray

from riscvmodel.insn import *
from riscvmodel.regnames import x0, x1, x16, x17, x18, x19, x20

from riscvmodel.isa import *
from riscvmodel.variant import *
from riscvmodel.model import Model

# Some riscvmodel fixes
del InstructionSLTIU, InstructionSRAI, InstructionSLTU, InstructionSRL, InstructionJAL, InstructionJALR
@isa("sltiu", RV32I, opcode=0b0010011, funct3=0b011)
class InstructionSLTIU(InstructionIType):
    def execute(self, model: Model):
        if model.state.intreg[self.rs1].unsigned() < int(self.imm) & 0xFFFFFFFF:
            model.state.intreg[self.rd] = 1
        else:
            model.state.intreg[self.rd] = 0

@isa("srai", RV32I, opcode=0b0010011, funct3=0b101, funct7=0b0100000)
class InstructionSRAI(InstructionISType):
    def execute(self, model: Model):
        src = model.state.intreg[self.rs1].unsigned()
        if src & 0x80000000:
            src |= 0xFFFFFFFF00000000
        model.state.intreg[self.rd] = (src >> self.shamt.unsigned()) & 0xFFFFFFFF

@isa("sltu", RV32I, opcode=0b0110011, funct3=0b011, funct7=0b0000000)
class InstructionSLTU(InstructionRType):
    def execute(self, model: Model):
        if model.state.intreg[self.rs1].unsigned() < model.state.intreg[
                self.rs2].unsigned():
            model.state.intreg[self.rd] = 1
        else:
            model.state.intreg[self.rd] = 0

@isa("srl", RV32I, opcode=0b0110011, funct3=0b101, funct7=0b0000000)
class InstructionSRL(InstructionRType):
    def execute(self, model: Model):
        src = model.state.intreg[self.rs1].unsigned()
        shift = int(model.state.intreg[self.rs2] & 0x1f)
        model.state.intreg[self.rd] = src >> shift

@isa("rol", RV32I, opcode=0b0110011, funct3=0b001, funct7=0b0110000)
class InstructionROL(InstructionRType):
    """
    The Rotate Left (ROL) instruction rotates the bits of the first source register (rs1) to the left by the amount
    specified in the second source register (rs2). The result is stored in the destination register (rd).
    """
    def execute(self, model: Model):
        shift = int(model.state.intreg[self.rs2] & 0x1f)
        model.state.intreg[self.rd] = ((model.state.intreg[self.rs1] << shift) | (model.state.intreg[self.rs1] >> (32 - shift))) & 0xFFFFFFFF

@isa("ror", RV32I, opcode=0b0110011, funct3=0b101, funct7=0b0110000)
class InstructionROR(InstructionRType):
    """
    The Rotate Right (ROR) instruction rotates the bits of the first source register (rs1) to the right by the amount
    specified in the second source register (rs2). The result is stored in the destination register (rd).
    """
    def execute(self, model: Model):
        shift = int(model.state.intreg[self.rs2] & 0x1f)
        model.state.intreg[self.rd] = ((model.state.intreg[self.rs1] >> shift) | (model.state.intreg[self.rs1] << (32 - shift))) & 0xFFFFFFFF

@isa("rori", RV32I, opcode=0b0010011, funct3=0b101, funct7=0b0110000)
class InstructionRORI(InstructionISType):
    """
    The Rotate Right Immediate (RORI) instruction rotates the bits of the first source register (rs1) to the right by the immediate
    value specified in the instruction. The result is stored in the destination register (rd).
    """
    def execute(self, model: Model):
        model.state.intreg[self.rd] = ((model.state.intreg[self.rs1] >> self.shamt) | (model.state.intreg[self.rs1] << (32 - self.shamt.unsigned()))) & 0xFFFFFFFF

@isa("andn", RV32I, opcode=0b0110011, funct3=0b111, funct7=0b0100000)
class InstructionANDN(InstructionRType):
    def execute(self, model: Model):
        model.state.intreg[self.rd] = model.state.intreg[self.rs1] & (~model.state.intreg[self.rs2] & 0xFFFFFFFF)

@isa("orn", RV32I, opcode=0b0110011, funct3=0b110, funct7=0b0100000)
class InstructionORN(InstructionRType):
    def execute(self, model: Model):
        model.state.intreg[self.rd] = model.state.intreg[self.rs1] | (~model.state.intreg[self.rs2] & 0xFFFFFFFF)

@isa("xnor", RV32I, opcode=0b0110011, funct3=0b100, funct7=0b0100000)
class InstructionXNOR(InstructionRType):
    def execute(self, model: Model):
        model.state.intreg[self.rd] = model.state.intreg[self.rs1] ^ (~model.state.intreg[self.rs2] & 0xFFFFFFFF)

@isa("rev", RV32I, opcode=0b0010011, funct3=0b101, funct7=0b0110100)
class InstructionREV(InstructionISType):
    def execute(self, model: Model):
        if self.shamt.unsigned() == 0b00111:
            model.state.intreg[self.rd] = int.from_bytes([int('{:08b}'.format(n)[::-1], 2) for n in model.state.intreg[self.rs1].unsigned().to_bytes(4)])
        elif self.shamt.unsigned() == 0b11000:
            model.state.intreg[self.rd] = int.from_bytes(model.state.intreg[self.rs1].unsigned().to_bytes(4, byteorder='big'), byteorder='little')
        elif self.shamt.unsigned() == 0b11111:
            model.state.intreg[self.rd] = int('{:032b}'.format(model.state.intreg[self.rs1].unsigned())[::-1], 2)
        else:
            model.state.intreg[self.rd] = model.state.intreg[self.rs1]

    def randomize(self, variant: Variant):
        self.rd = random.randrange(0, variant.xlen)
        self.rs1 = random.randrange(0, variant.xlen)
        self.shamt.set(random.choice([0b00111, 0b11000, 0b11111]))

@isa("jal", RV32I, opcode=0b1101111)
class InstructionJAL(InstructionJType):
    def execute(self, model: Model):
        model.state.intreg[self.rd] = (model.state.pc.unsigned() + 4) & 0x3FC
        model.state.pc = (model.state.pc + self.imm) & 0x3FC

    def randomize(self, variant: Variant):
        self.rd = randrange(0, variant.xlen)
        self.imm.randomize()
        self.imm.set(self.imm.value & ~3)

@isa("jalr", RV32I, opcode=0b1100111, funct3=0b000)
class InstructionJALR(InstructionIType):
    def execute(self, model: Model):
        model.state.intreg[self.rd] = (model.state.pc.unsigned() + 4) & 0x3FC
        model.state.pc = (model.state.intreg[self.rs1] + self.imm) & 0x3FC

async def run_alu_reg_instruction(dut, inst, rs1_val, rs2_val, delay_cycles=0):
    assert dut.mem_rinstr.value == 1

    dut.rs1_rdata.value = rs1_val
    dut.rs2_rdata.value = rs2_val
    dut.mem_rdata.value = inst(x16, x17, x18).encode()
    if delay_cycles > 0:
        dut.reg_rbusy.value = 1
        await ClockCycles(dut.clk, delay_cycles)
        dut.reg_rbusy.value = 0

    await ClockCycles(dut.clk, 2)

    assert dut.rd_write.value == 1
    assert dut.mem_rstrb.value == 1
    assert dut.mem_rinstr.value == 1
    return dut.rd_wdata.value

async def get_reg_value(dut, reg, delay_cycles=0):
    assert dut.mem_rinstr.value == 1

    dut.mem_rdata.value = InstructionADD(x16, reg, x0).encode()
    if delay_cycles > 0:
        dut.reg_rbusy.value = 1
        await ClockCycles(dut.clk, delay_cycles)
        dut.reg_rbusy.value = 0

    await ClockCycles(dut.clk, 2)

    assert dut.rd_write.value == 1
    assert dut.mem_rstrb.value == 1
    assert dut.mem_rinstr.value == 1
    return dut.rd_wdata.value

async def get_pc_value(dut, delay_cycles=0):
    assert dut.mem_rinstr.value == 1

    dut.mem_rdata.value = InstructionAUIPC(x16, 0).encode()
    if delay_cycles > 0:
        dut.reg_rbusy.value = 1
        await ClockCycles(dut.clk, delay_cycles)
        dut.reg_rbusy.value = 0

    await ClockCycles(dut.clk, 2)

    assert dut.rd_write.value == 1
    assert dut.mem_rstrb.value == 1
    assert dut.mem_rinstr.value == 1
    return dut.rd_wdata.value

async def run_rev_instruction(dut, rs1_val, mode):
    assert dut.mem_rinstr.value == 1

    dut.rs1_rdata.value = rs1_val
    dut.mem_rdata.value = InstructionREV(x16, x17, mode).encode()
    await ClockCycles(dut.clk, 2)

    assert dut.rd_write.value == 1
    assert dut.mem_rstrb.value == 1
    assert dut.mem_rinstr.value == 1
    return dut.rd_wdata.value

async def run_quantum_write(dut, inst, rs1_val, rs2_val, delay_cycles=2):
    assert dut.mem_rinstr.value == 1

    dut.rs1_rdata.value = rs1_val
    dut.rs2_rdata.value = rs2_val
    dut.mem_rdata.value = inst(x20, x17, x18).encode()
    await ClockCycles(dut.clk, 1)
    assert dut.rd_write.value == 0
    await Timer(1, unit="ns")
    assert dut.rd_write.value == 1
    dut.reg_wbusy.value = 1
    await ClockCycles(dut.clk, 1)
    assert dut.mem_rstrb.value == 1
    assert dut.mem_rinstr.value == 1

    await ClockCycles(dut.clk, delay_cycles)
    assert dut.mem_rstrb.value == 0
    dut.reg_wbusy.value = 0
    await ClockCycles(dut.clk, 1)

    return dut.rd_wdata.value

async def reset(dut):
    dut.mem_rdata.value = InstructionNOP().encode()
    dut.mem_rbusy.value = 0
    dut.mem_wbusy.value = 0
    dut.rs1_rdata.value = 0
    dut.rs2_rdata.value = 0
    dut.reg_wbusy.value = 0
    dut.reg_rbusy.value = 0

    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)


@cocotb.test()
async def test_start(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())

    await reset(dut)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionADD, a, b) == (a + b) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionSUB, a, b) == (a - b) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(-0x80000000, 0x7FFFFFFF)
        b = random.randint(-0x80000000, 0x7FFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionSLT, a, b) == (1 if a < b else 0)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionSLTU, a, b) == (1 if a < b else 0)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionAND, a, b) == (a & b)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionOR, a, b) == (a | b)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionXOR, a, b) == (a ^ b)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0x1F)
        assert await run_alu_reg_instruction(dut, InstructionSLL, a, b) == (a << b) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0x1F)
        assert await run_alu_reg_instruction(dut, InstructionSRL, a, b) == (a >> b)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0x1F)
        assert await run_alu_reg_instruction(dut, InstructionSRA, a, b) == ((a & 0xFFFFFFFF) >> b) | (0xFFFFFFFF << (32 - b) if a & 0x80000000 else 0) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0x1F)
        assert await run_alu_reg_instruction(dut, InstructionROL, a, b) == ((a << b) | (a >> (32 - b))) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0x1F)
        assert await run_alu_reg_instruction(dut, InstructionROR, a, b) == ((a >> b) | (a << (32 - b))) & 0xFFFFFFFF

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionANDN, a, b) == (a & (~b & 0xFFFFFFFF))

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionORN, a, b) == (a | (~b & 0xFFFFFFFF))

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        assert await run_alu_reg_instruction(dut, InstructionXNOR, a, b) == (a ^ (~b & 0xFFFFFFFF))

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        assert await run_rev_instruction(dut, a, 0b11000) == ((a & 0xFF) << 24) | ((a & 0xFF00) << 8) | ((a >> 8) & 0xFF00) | ((a >> 24) & 0xFF)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        res = 0
        for i in range(32):
            res |= ((a >> (31 - i)) & 1) << i
        assert await run_rev_instruction(dut, a, 0b00111) == ((res & 0xFF) << 24) | ((res & 0xFF00) << 8) | ((res >> 8) & 0xFF00) | ((res >> 24) & 0xFF)

    for _ in range(10):
        a = random.randint(0, 0xFFFFFFFF)
        res = 0
        for i in range(32):
            res |= ((a >> (31 - i)) & 1) << i
        assert await run_rev_instruction(dut, a, 0b11111) == res

@cocotb.test()
async def test_quantum(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())    

    await reset(dut)

    a = 0x12345678
    b = 0x9ABCDEF0
    assert await run_quantum_write(dut, InstructionADD, a, b) == (a + b) & 0xFFFFFFFF
    assert await run_quantum_write(dut, InstructionADD, a, b, 4) == (a + b) & 0xFFFFFFFF
    assert await run_alu_reg_instruction(dut, InstructionADD, a, b) == (a + b) & 0xFFFFFFFF    
    assert await run_quantum_write(dut, InstructionADD, a, b) == (a + b) & 0xFFFFFFFF

@cocotb.test()
async def test_delayed_read(dut):
    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())    

    await reset(dut)

    a = 0x12345678
    b = 0x9ABCDEF0
    for i in range(11):
        assert await run_alu_reg_instruction(dut, InstructionADD, a + i, b, 0 if (i & 1) != 0 else i+1) == (a + i + b) & 0xFFFFFFFF    

@cocotb.test()
async def test_random_instructions_low_regs(dut):
    insns = [InstructionADDI, InstructionORI, InstructionXORI, InstructionANDI, InstructionSLLI, InstructionSRLI, InstructionSRAI, InstructionSLTI, InstructionSLTIU, InstructionRORI, InstructionREV,  # I type
             InstructionADD, InstructionSUB, InstructionSLL, InstructionSLT, InstructionSLTU, InstructionXOR, InstructionSRL, InstructionSRA, InstructionOR, InstructionAND, InstructionROR, InstructionROL, InstructionANDN, InstructionORN, InstructionXNOR, # R type
             InstructionAUIPC, InstructionLUI,  # U type
             InstructionJAL, InstructionJALR,  # Jumps
             InstructionBEQ, InstructionBNE, InstructionBLT, InstructionBGE, InstructionBLTU, InstructionBGEU]  # B type

    # Hack because randomize incorrectly uses xlen as the number of registers
    RV32E.xlen = 16

    model = Model(RV32E)

    cocotb.start_soon(Clock(dut.clk, 20, unit="ns").start())    

    await reset(dut)

    # Clear all regs
    for reg in range(1, 16):
        val = random.randint(-0x800, 0x7FF)
        model.state.intreg[reg].set(val)
        dut.mem_rdata.value = InstructionADDI(reg, 0, val).encode()
        await ClockCycles(dut.clk, 2)

    model.state.pc.set(15 * 4)

    for _ in range(500):
        for _ in range(20):
            insn = random.choice(insns)()
            insn.randomize(RV32E)
            model.issue(insn)
            #print(f"{insn} = {model.state.intreg[insn.rd].unsigned() if hasattr(insn, 'rd') else 'N/A'}, PC {model.state.pc.unsigned()}")

            dut.mem_rdata.value = insn.encode()
            await ClockCycles(dut.clk, 2)
            model.state.pc.set(model.state.pc.unsigned() & 0x3FC)

        for reg in range(1, 16):
            #print(f"  x{reg} = {model.state.intreg[reg].unsigned()}")
            assert await get_reg_value(dut, reg) == model.state.intreg[reg].unsigned()

        model.state.pc.set((model.state.pc.unsigned() + (15 * 4)) & 0x3FC)
    
        assert await get_pc_value(dut) == model.state.pc.unsigned()
        model.state.pc.set((model.state.pc.unsigned() + 4) & 0x3FC)
