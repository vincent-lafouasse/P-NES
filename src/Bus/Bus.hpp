#pragma once

#include <array>

#include "types.hpp"

#define KILOBYTES(n) (n << 10)

class Bus final {
   public:
    Byte read(Address address) const;
    void write(Address address, Byte data) const;

   private:
    std::array<Byte, KILOBYTES(2)> RAM;
};