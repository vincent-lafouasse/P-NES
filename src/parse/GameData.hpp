#pragma once

#include <string>

#include "Header.hpp"

using Bank = std::vector<Byte>;

struct GameData {
    Header header;
    Bank trainer;
    Bank prg;
    Bank chr;

    static GameData read(const std::string& path);
    void dump_prg() const;
};
