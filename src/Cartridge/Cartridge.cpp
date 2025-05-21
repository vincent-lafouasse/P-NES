#include "Cartridge.hpp"

#include <cassert>
#include <cstdlib>
#include <fstream>
#include <iostream>

namespace {
template <typename T>
T kiloBytes(T n) {
    return n * (1 << 10);
}

Bank read_bank(std::ifstream& s, usize sz) {
    Bank bank;

    bank.reserve(sz);
    for (usize i = 0; i < sz; ++i) {
        Byte b = static_cast<Byte>(s.get());
        bank.push_back(b);
    }
    return bank;
}
}  // namespace

Cartridge Cartridge::read(const std::string& path) {
    std::ifstream s(path);
    if (!s.good()) {
        std::cerr << "Failed to open file " << std::quoted(path) << '\n';
        std::exit(1);
    }

    Header h = Header::read(s);
    assert(s.good() && "Failed to read iNes header");

    Cartridge out;
    out.header = h;

    if (h.has_trainer_data()) {
        usize sz = 512;
        out.trainer = read_bank(s, sz);
        assert(s.good() && "Failed to read trainer data");
    }

    {
        usize sz = h.prg_size * kiloBytes(16);
        out.prg = read_bank(s, sz);
        assert(s.good() && "Failed to read prg data");
    }

    {
        usize sz = h.chr_size * kiloBytes(8);
        out.chr = read_bank(s, sz);
        assert(s.good() && "Failed to read chr data");
    }

    return out;
}

void Cartridge::dump_prg() const {
    std::ofstream of("./build/prg.out", std::ios::out | std::ios::binary);

    for (Byte b : prg) {
        of << static_cast<unsigned char>(b);
    }
}
