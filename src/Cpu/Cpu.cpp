#include "Cpu.hpp"

#include <fstream>

#include "log.hpp"

Cpu::Cpu(Bus& mem) : memory(mem) {
    instructionSet.fill(Instruction::Unknown());

    instructionSet[0x78] = Instruction::Set_Interrupt();
    instructionSet[0xd8] = Instruction::Clear_Decimal();
    instructionSet[0xa9] = Instruction::Load_A(Instruction::Mode::Immediate);
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
        LOG(instruction.kind_repr());

        if (instruction.kind == Instruction::Kind::Set_Interrupt) {
            this->status.interrupt_flag = true;
        } else if (instruction.kind == Instruction::Kind::Clear_Decimal) {
            this->status.decimal_flag = false;
        }

        logs << instruction.repr(op1, op2) << std::endl;
        PC() += instruction.size;
    }
}
