#pragma once

#include <string>

#include "Header.hpp"

using Bank = std::vector<Byte>;

struct Cartridge {
    Header header;
    Bank trainer;
    Bank prg;
    Bank chr;

    static Cartridge load(const std::string& path);
    void dump_prg() const;
};
