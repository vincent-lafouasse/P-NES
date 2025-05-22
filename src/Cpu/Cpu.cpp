#include "Cpu.hpp"

#include "log.hpp"

Cpu::Cpu(Bus& mem) : memory(mem) {
    instructionSet.fill(Instruction::Unknown());

    instructionSet[0x78] = Instruction::Set_Interrupt();
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
    Byte opcode = memory.read(PC());
    Instruction instruction = instructionSet[opcode];
    LOG(instruction.kind_repr());
}
