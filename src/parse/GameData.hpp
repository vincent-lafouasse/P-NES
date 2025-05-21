#pragma once

#include "Header.hpp"

using Bank = std::vector<Byte>;

struct GameData {
    Header header;
    Bank trainer;
    Bank prg;
    Bank chr;

    static GameData read(ByteStream& s);
    void dump_prg() const;
};
