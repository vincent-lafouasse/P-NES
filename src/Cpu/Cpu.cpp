#include "Cpu.hpp"

#include <fstream>

#include "log.hpp"

Cpu::Cpu(Bus& mem) : memory(mem) {
    using M = Instruction::Mode;
    using I = Instruction;

    instructionSet.fill(I::Unknown());

    instructionSet[0x78] = I::Set_Interrupt();
    instructionSet[0xd8] = I::Clear_Decimal();

    instructionSet[0xa9] = I::Load_A(M::Immediate);
    instructionSet[0xa5] = I::Load_A(M::ZeroPage);
    instructionSet[0xb5] = I::Load_A(M::ZeroPage_X);
    instructionSet[0xad] = I::Load_A(M::Absolute);
    instructionSet[0xbd] = I::Load_A(M::Absolute_X);
    instructionSet[0xb9] = I::Load_A(M::Absolute_Y);
    instructionSet[0xa1] = I::Load_A(M::X_Indirect);
    instructionSet[0xb1] = I::Load_A(M::Indirect_Y);

    instructionSet[0xa2] = I::Load_X(M::Immediate);
    instructionSet[0xa6] = I::Load_X(M::ZeroPage);
    instructionSet[0xb6] = I::Load_X(M::ZeroPage_Y);
    instructionSet[0xae] = I::Load_X(M::Absolute);
    instructionSet[0xbe] = I::Load_X(M::Absolute_Y);

    instructionSet[0x85] = I::Store_A(M::ZeroPage);
    instructionSet[0x95] = I::Store_A(M::ZeroPage_X);
    instructionSet[0x8d] = I::Store_A(M::Absolute);
    instructionSet[0x9d] = I::Store_A(M::Absolute_X);
    instructionSet[0x99] = I::Store_A(M::Absolute_Y);
    instructionSet[0x81] = I::Store_A(M::X_Indirect);
    instructionSet[0x91] = I::Store_A(M::Indirect_Y);

    instructionSet[0x86] = I::Store_X(M::ZeroPage);
    instructionSet[0x96] = I::Store_X(M::ZeroPage_Y);
    instructionSet[0x8e] = I::Store_X(M::Absolute);

    instructionSet[0x84] = I::Store_Y(M::ZeroPage);
    instructionSet[0x94] = I::Store_Y(M::ZeroPage_X);
    instructionSet[0x8c] = I::Store_Y(M::Absolute);
}

void Cpu::reset() {
    this->A() = 0;
    this->X() = 0;
    this->Y() = 0;
    this->S() = 0;
    this->P() = {};

    this->PC() = this->reset_address();
    LOG_HEX(this->PC());
}

void Cpu::start() {
    std::ofstream logs("build/asm.s");

    for (int i = 0; i < 10; i++) {
        Byte opcode = memory.read(PC());
        Byte op1 = memory.read(PC() + 1);
        Byte op2 = memory.read(PC() + 2);

        Instruction instruction = instructionSet[opcode];
        LOG_HEX(opcode);
        LOG(instruction.opcode_repr());

        if (instruction.kind == Instruction::Kind::Set_Interrupt) {
            this->status.interrupt_flag = true;
        } else if (instruction.kind == Instruction::Kind::Clear_Decimal) {
            this->status.decimal_flag = false;
        }

        logs << instruction.repr(op1, op2) << std::endl;
        PC() += instruction.size;
    }
}
