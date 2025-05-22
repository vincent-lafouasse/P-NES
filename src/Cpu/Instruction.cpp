#include "Instruction.hpp"

#include <sstream>

Instruction Instruction::Unknown() {
    return {Kind::Unknown, Mode::Implied, 1, 1};
}

Instruction Instruction::Set_Interrupt() {
    return {Kind::Set_Interrupt, Mode::Implied, 1, 2};
}

Instruction Instruction::Clear_Decimal() {
    return {Kind::Clear_Decimal, Mode::Implied, 1, 2};
}

Instruction Instruction::Load_A(Mode mode) {
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

std::string Instruction::repr(Byte op1, Byte op2) const {
    std::stringstream out{};

    out << this->kind_repr();

    if (this->size == 1) {
        return out.str();
    }

    out << '\t';

    using K = Kind;
    using M = Mode;

    const Address address = op1 | op2 << 8;

    if (kind == K::Load_A) {
        if (mode == M::Immediate) {
            out << "#" << std::hex << op1;
        } else if (mode == M::ZeroPage) {
            out << std::hex << op1;
        } else if (mode == M::ZeroPage_X) {
            out << std::hex << op1 << ",X";
        } else if (mode == M::Absolute) {
            out << std::hex << address;
        } else if (mode == M::Absolute_X) {
            out << std::hex << address << ",X";
        } else if (mode == M::Absolute_Y) {
            out << std::hex << address << ",X";
        } else if (mode == M::X_Indirect) {
            out << "("<< std::hex << address << ",X)";
        } else if (mode == M::Indirect_Y) {
            out << "("<< std::hex << address << "),Y";
        }
    }

    return out.str();
}

const char* Instruction::kind_repr() const {
    switch (kind) {
        case Kind::Load_A:
            return "lda";
        case Kind::Load_X:
            return "ldx";
        case Kind::Load_Y:
            return "ldy";
        case Kind::Store_A:
            return "sta";
        case Kind::Store_X:
            return "stx";
        case Kind::Store_Y:
            return "sty";
        case Kind::Transfer_A2X:
            return "tax";
        case Kind::Transfer_A2Y:
            return "tay";
        case Kind::Transfer_S2X:
            return "tsx";
        case Kind::Transfer_X2A:
            return "txa";
        case Kind::Transfer_X2S:
            return "txs";
        case Kind::Transfer_Y2A:
            return "tya";
        case Kind::Push_A:
            return "pha";
        case Kind::Push_P:
            return "php";
        case Kind::Pull_A:
            return "pla";
        case Kind::Pull_P:
            return "plp";
        case Kind::Decrement_Mem:
            return "dec";
        case Kind::Decrement_X:
            return "dex";
        case Kind::Decrement_Y:
            return "dey";
        case Kind::Increment_Mem:
            return "inc";
        case Kind::Increment_X:
            return "inx";
        case Kind::Increment_Y:
            return "iny";
        case Kind::AddWithCarry:
            return "adc";
        case Kind::SubtractWithCarry:
            return "sbc";
        case Kind::And_A:
            return "and";
        case Kind::Xor_A:
            return "eor";
        case Kind::Or_A:
            return "ora";
        case Kind::ArithmeticShift_Left:
            return "asl";
        case Kind::LogicalShift_Right:
            return "lsr";
        case Kind::Rotate_Left:
            return "rol";
        case Kind::Rotate_Right:
            return "ror";
        case Kind::Clear_Carry:
            return "clc";
        case Kind::Clear_Decimal:
            return "cld";
        case Kind::Clear_Interrupt:
            return "cli";
        case Kind::Clear_Overflow:
            return "clv";
        case Kind::Set_Carry:
            return "sec";
        case Kind::Set_Decimal:
            return "sed";
        case Kind::Set_Interrupt:
            return "sei";
        case Kind::Compare_A:
            return "cmp";
        case Kind::Compare_X:
            return "cpx";
        case Kind::Compare_Y:
            return "cpy";
        case Kind::Branch_CarryClear:
            return "bcc";
        case Kind::Branch_CarrySet:
            return "bcs";
        case Kind::Branch_Equal:
            return "beq";
        case Kind::Branch_NotEqual:
            return "bne";
        case Kind::Branch_Minus:
            return "bmi";
        case Kind::Branch_Plus:
            return "bpl";
        case Kind::Branch_OverflowClear:
            return "bvc";
        case Kind::Branch_OverflowSet:
            return "bvs";
        case Kind::Jump:
            return "jmp";
        case Kind::Jump_Subroutine:
            return "jsr";
        case Kind::Return_Subroutine:
            return "rts";
        case Kind::Return_Interrupt:
            return "rti";
        case Kind::Break:
            return "brk";
        case Kind::BitTest:
            return "bit";
        case Kind::NoOp:
            return "nop";
        case Kind::Unknown:
            return "???";
    }
}
