#pragma once

#include "Bus/Bus.hpp"
#include "types.hpp"

struct Instruction {
    enum class Kind {
        // Transfer instructions
        Load_A,
        Load_X,
        Load_Y,
        Store_A,
        Store_X,
        Store_Y,
        Transfer_A2X,
        Transfer_A2Y,
        Transfer_S2X,
        Transfer_X2A,
        Transfer_X2S,
        Transfer_Y2A,
        // Stack instructions
        Push_A,
        Push_P,
        Pull_A,
        Pull_P,
        // Decrements/Increments
        Decrement_Mem,
        Decrement_X,
        Decrement_Y,
        Increment_Mem,
        Increment_X,
        Increment_Y,
        // Arithmetic
        AddWithCarry,
        SubtractWithCarry,
        // Logic
        And_A,
        Xor_A,
        Or_A,
        // Shift/Rotate
        ArithmeticShift_Left,
        LogicalShift_Left,
        Rotate_Left,
        Rotate_Right,
        // Flags
        Clear_Carry,
        Clear_Decimal,
        Clear_Interrupt,
        Clear_Overflow,
        Set_Carry,
        Set_Decimal,
        Set_Interrupt,
        // Comparison
        Compare_A,
        Compare_X,
        Compare_Y,
        // Branches
        Branch_CarryClear,
        Branch_CarrySet,
        Branch_Equal,
        Branch_NotEqual,
        Branch_Minus,
        Branch_Plus,
        Branch_OverflowClear,
        Branch_OverflowSet,
        // Jumps/Subroutines
        Jump,
        Jump_Subroutine,
        Return_Subroutine,
        // Breaks/Interrupts
        Break,
        Return_Interrupt,
        // Other
        BitTest,
        NoOp,
        // Unrecognized opcode
        Unknown,
    } kind;
    enum class Mode {
        Accumulator,
        Absolute,
        Absolute_X,
        Absolute_Y,
        Immediate,
        Implied,
        Indirect,
        X_Indirect,
        Indirect_Y,
        Relative,
        ZeroPage,
        ZeroPage_X,
        ZeroPage_Y,
    } mode;
    usize size;
    usize cycles;

    static Instruction decode(Byte opcode) {
        switch (opcode) {
            case 0x78:
                return SEI();
            default:
                return Unknown();
        }
    }

    static Instruction SEI() {
        return {Kind::Set_Interrupt, Mode::Implied, 1, 2};
    }
    static Instruction Unknown() { return {Kind::Unknown}; }
};

class Cpu final {
   public:
    explicit Cpu(Bus& mem) : memory(mem) {}
    void reset();

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

    auto& A() { return accumulator; }
    auto& X() { return x_register; }
    auto& Y() { return y_register; }
    auto& S() { return stack_pointer; }
    auto& PC() { return program_counter; }
    auto& P() { return status; }

    static constexpr Address reset_vector = 0xFFFC;
    [[nodiscard]]
    Address reset_address() const {
        return memory.read(reset_vector) | memory.read(reset_vector + 1) << 8;
    }
};
