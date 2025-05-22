#include "Cpu.hpp"

#include "log.hpp"

void Cpu::reset() {
    this->A() = 0;
    this->X() = 0;
    this->Y() = 0;
    this->S() = 0;
    this->P() = {};

    this->PC() = this->reset_address();
    LOG(this->PC());
    LOG(this->memory.read(this->PC()));
}
