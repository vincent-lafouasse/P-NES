#pragma once

#include "types.hpp"

class Bus final {
    Byte read(Address address) const;
    void write(Address address, Byte data) const;
};