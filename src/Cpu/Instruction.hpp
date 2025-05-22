#pragma once

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
    static const char* kind_repr(Kind k) {
        switch (k) {
            case Kind::Load_A:
                return "LDA";
            case Kind::Load_X:
                return "LDX";
            case Kind::Load_Y:
                return "LDY";
            case Kind::Store_A:
                return "STA";
            case Kind::Store_X:
                return "STX";
            case Kind::Store_Y:
                return "STY";
            case Kind::Transfer_A2X:
                return "TAX";
            case Kind::Transfer_A2Y:
                return "TAY";
            case Kind::Transfer_S2X:
                return "TSX";
            case Kind::Transfer_X2A:
                return "TXA";
            case Kind::Transfer_X2S:
                return "TXS";
            case Kind::Transfer_Y2A:
                return "TYA";
            case Kind::Push_A:
                return "PHA";
            case Kind::Push_P:
                return "PHP";
            case Kind::Pull_A:
                return "PLA";
            case Kind::Pull_P:
                return "PLP";
            case Kind::Decrement_Mem:
                return "DEC";
            case Kind::Decrement_X:
                return "DEX";
            case Kind::Decrement_Y:
                return "DEY";
            case Kind::Increment_Mem:
                return "INC";
            case Kind::Increment_X:
                return "INX";
            case Kind::Increment_Y:
                return "INY";
            case Kind::AddWithCarry:
                return "ADC";
            case Kind::SubtractWithCarry:
                return "SBC";
            case Kind::And_A:
                return "AND";
            case Kind::Xor_A:
                return "EOR";
            case Kind::Or_A:
                return "ORA";
            case Kind::ArithmeticShift_Left:
                return "ASL";
            case Kind::LogicalShift_Right:
                return "LSR";
            case Kind::Rotate_Left:
                return "ROL";
            case Kind::Rotate_Right:
                return "ROR";
            case Kind::Clear_Carry:
                return "CLC";
            case Kind::Clear_Decimal:
                return "CLD";
            case Kind::Clear_Interrupt:
                return "CLI";
            case Kind::Clear_Overflow:
                return "CLV";
            case Kind::Set_Carry:
                return "SEC";
            case Kind::Set_Decimal:
                return "SED";
            case Kind::Set_Interrupt:
                return "SEI";
            case Kind::Compare_A:
                return "CMP";
            case Kind::Compare_X:
                return "CPX";
            case Kind::Compare_Y:
                return "CPY";
            case Kind::Branch_CarryClear:
                return "BCC";
            case Kind::Branch_CarrySet:
                return "BCS";
            case Kind::Branch_Equal:
                return "BEQ";
            case Kind::Branch_NotEqual:
                return "BNE";
            case Kind::Branch_Minus:
                return "BMI";
            case Kind::Branch_Plus:
                return "BPL";
            case Kind::Branch_OverflowClear:
                return "BVC";
            case Kind::Branch_OverflowSet:
                return "BVS";
            case Kind::Jump:
                return "JMP";
            case Kind::Jump_Subroutine:
                return "JSR";
            case Kind::Return_Subroutine:
                return "RTS";
            case Kind::Return_Interrupt:
                return "RTI";
            case Kind::Break:
                return "BRK";
            case Kind::BitTest:
                return "BIT";
            case Kind::NoOp:
                return "NOP";
            case Kind::Unknown:
                return "???";
        }
    }
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

    static Instruction Unknown() { return {}; }
    static Instruction Load_A(Mode mode) {
        using M = Mode;
        switch (mode) {
            case M::Immediate:
                return {Kind::Load_A, mode, 2, 2};
            case M::ZeroPage:
                return {Kind::Load_A, mode, 2, 3};
            case M::ZeroPage_X:
                return {Kind::Load_A, mode, 2, 4};
            case M::Absolute:
                return {Kind::Load_A, mode, 3, 4};
            case M::Absolute_X:
                return {Kind::Load_A, mode, 3, 4};
            case M::Absolute_Y:
                return {Kind::Load_A, mode, 3, 4};
            default:
                return Unknown();
        }
    }
};
