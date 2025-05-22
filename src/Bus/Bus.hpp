#pragma once

#include <vector>

#include "types.hpp"

class Bus final {
   public:
    Byte read(Address address) const;
    void write(Address address, Byte data) const;

   private:
    std::vector<Byte> RAM;
};