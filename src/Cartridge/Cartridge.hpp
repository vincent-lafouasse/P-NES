#pragma once

#include <cassert>
#include <string>

#include "Header.hpp"

#define KILOBYTES(n) (n << 10)

using Bank = std::vector<Byte>;

struct Cartridge {
    Header header;
    Bank trainer;
    Bank prg;
    Bank chr;

    Byte read(Address address) const {
        constexpr Address start = 0x8000;
        assert(address >= start);
        assert(header.mapper() == 0x00);

        return prg.at(address - start);
    }

    static Cartridge load(const std::string& path);
    void dump_prg() const;
};
