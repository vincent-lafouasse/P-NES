#pragma once

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
        LogicalShift_Right,
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

    static Instruction Unknown();
    static Instruction Set_Interrupt();
    static Instruction Clear_Decimal();
    static Instruction Load_A(Mode mode);

    const char* kind_repr() const;
};