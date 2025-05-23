#include "Instruction.hpp"

#include <cassert>
#include <format>

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
    Kind k = Kind::Load_A;
    switch (mode) {
        case M::Immediate:
            return {k, mode, 2, 2};
        case M::ZeroPage:
            return {k, mode, 2, 3};
        case M::ZeroPage_X:
            return {k, mode, 2, 4};
        case M::Absolute:
            return {k, mode, 3, 4};
        case M::Absolute_X:
            return {k, mode, 3, 4};
        case M::Absolute_Y:
            return {k, mode, 3, 4};
        case M::Indirect_X:
            return {k, mode, 2, 6};
        case M::Indirect_Y:
            return {k, mode, 2, 5};
        default:
            return Unknown();
    }
}

Instruction Instruction::Load_X(Mode mode) {
    using M = Mode;
    Kind k = Kind::Load_X;
    switch (mode) {
        case M::Immediate:
            return {k, mode, 2, 2};
        case M::ZeroPage:
            return {k, mode, 2, 3};
        case M::ZeroPage_Y:
            return {k, mode, 2, 4};
        case M::Absolute:
            return {k, mode, 3, 4};
        case M::Absolute_Y:
            return {k, mode, 3, 4};
        default:
            return Unknown();
    }
}

Instruction Instruction::Store_A(Mode mode) {
    using M = Mode;
    Kind k = Kind::Store_A;
    switch (mode) {
        case M::ZeroPage:
            return {k, mode, 2, 3};
        case M::ZeroPage_X:
            return {k, mode, 2, 4};
        case M::Absolute:
            return {k, mode, 3, 4};
        case M::Absolute_X:
            return {k, mode, 3, 5};
        case M::Absolute_Y:
            return {k, mode, 3, 5};
        case M::Indirect_X:
            return {k, mode, 2, 6};
        case M::Indirect_Y:
            return {k, mode, 2, 6};
        default:
            return Unknown();
    }
}

Instruction Instruction::Store_X(Mode mode) {
    using M = Mode;
    Kind k = Kind::Store_X;
    switch (mode) {
        case M::ZeroPage:
            return {k, mode, 2, 3};
        case M::ZeroPage_Y:
            return {k, mode, 2, 4};
        case M::Absolute:
            return {k, mode, 3, 4};
        default:
            return Unknown();
    }
}

Instruction Instruction::Store_Y(Mode mode) {
    using M = Mode;
    Kind k = Kind::Store_Y;
    switch (mode) {
        case M::ZeroPage:
            return {k, mode, 2, 3};
        case M::ZeroPage_X:
            return {k, mode, 2, 4};
        case M::Absolute:
            return {k, mode, 3, 4};
        default:
            return Unknown();
    }
}

std::string Instruction::repr(Byte op1, Byte op2) const {
    std::string out = this->opcode_repr();

    if (this->size == 1) {
        return out;
    }

    using K = Kind;
    using M = Mode;

    const std::string b1 = std::format("{:x}", op1);
    const std::string b2 = std::format("{:x}", op2);
    const std::string address = std::format("{:x}", op1 | op2 << 8);

    const std::string commaX = ",X";
    const std::string commaY = ",Y";

    auto paren = [](const std::string s) { return "(" + s + ")"; };

    out += '\t';

    if (kind == K::Load_A) {
        switch (mode) {
            case M::Immediate:
                return out + "#" + b1;
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_X:
                return out + b1 + commaX;
            case M::Absolute:
                return out + address;
            case M::Absolute_X:
                return out + address + commaX;
            case M::Absolute_Y:
                return out + address + commaY;
            case M::Indirect_X:
                return out + paren(b1 + commaX);
            case M::Indirect_Y:
                return out + paren(b1) + commaY;
            default:
                return out + "???";
        }
    } else if (kind == K::Load_X) {
        switch (mode) {
            case M::Immediate:
                return out + "#" + b1;
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_Y:
                return out + b1 + commaY;
            case M::Absolute:
                return out + address;
            case M::Absolute_Y:
                return out + address + commaY;
            default:
                return out + "???";
        }
    } else if (kind == K::Load_Y) {
        switch (mode) {
            case M::Immediate:
                return out + "#" + b1;
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_X:
                return out + b1 + commaX;
            case M::Absolute:
                return out + address;
            case M::Absolute_X:
                return out + address + commaX;
            default:
                return out + "???";
        }
    }

    if (kind == K::Store_A) {
        switch (mode) {
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_X:
                return out + b1 + commaX;
            case M::Absolute:
                return out + address;
            case M::Absolute_X:
                return out + address + commaX;
            case M::Absolute_Y:
                return out + address + commaY;
            case M::Indirect_X:
                return out + paren(b1 + commaX);
            case M::Indirect_Y:
                return out + paren(b1) + commaY;
            default:
                return out + "???";
        }
    } else if (kind == K::Store_X) {
        switch (mode) {
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_Y:
                return out + b1 + commaY;
            case M::Absolute:
                return out + address;
            default:
                return out + "???";
        }
    } else if (kind == K::Store_Y) {
        switch (mode) {
            case M::ZeroPage:
                return out + b1;
            case M::ZeroPage_X:
                return out + b1 + commaX;
            case M::Absolute:
                return out + address;
            default:
                return out + "???";
        }
    }

    return out + "???";
}

const char* Instruction::opcode_repr() const {
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

    assert(!"Unreachable");
}
