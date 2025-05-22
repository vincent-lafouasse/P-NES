#pragma once

#include "types.hpp"

class Cpu final {
    [[maybe_unused]] Byte A;
    [[maybe_unused]] Byte X;
    [[maybe_unused]] Byte Y;
    [[maybe_unused]] Byte SP;
    [[maybe_unused]] Address PC;
    [[maybe_unused]] Byte P;

    /*
        namespace Status {
        bool
        N	Negative
        V	Overflow
        -	ignored
        B	Break
        D	Decimal (use BCD for arithmetics)
        I	Interrupt (IRQ disable)
        Z	Zero
        C	Carry
        }
        */
};
