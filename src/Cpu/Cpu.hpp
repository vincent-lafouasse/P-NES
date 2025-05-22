#pragma once

#include "Bus/Bus.hpp"
#include "Instruction.hpp"
#include "log.hpp"
#include "types.hpp"

class Cpu final {
   public:
    explicit Cpu(Bus& mem);
    void reset();
    void start();

   private:
    Byte accumulator{};
    Byte x_register{};
    Byte y_register{};
    Byte stack_pointer{};
    Address program_counter{};
    struct Status {
        // this whole thing should take up a byte
        unsigned char carry : 1;
        unsigned char zero_flag : 1;
        unsigned char interrupt_flag : 1;
        unsigned char decimal_flag : 1;
        unsigned char break_flag : 1;
        unsigned char padding : 1;
        unsigned char overflow_flag : 1;
        unsigned char negative_flag : 1;
    } status{};

    Bus& memory;
    std::array<Instruction, 256> instructionSet{};

    auto& A() { return accumulator; }
    auto& X() { return x_register; }
    auto& Y() { return y_register; }
    auto& S() { return stack_pointer; }
    auto& PC() { return program_counter; }
    auto& P() { return status; }

    static constexpr Address reset_vector = 0xFFFC;
    [[nodiscard]] Address reset_address() const {
        return memory.read(reset_vector) | memory.read(reset_vector + 1) << 8;
    }
};
