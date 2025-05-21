#include "GameData.hpp"

#include <cassert>

namespace {
template <typename T>
T kiloBytes(T n) {
    return n * (1 << 10);
}

Bank read_bank(ByteStream& s, std::size_t sz) {
    Bank bank;

    bank.reserve(sz);
    for (std::size_t i = 0; i < sz; ++i) {
        Byte b = static_cast<Byte>(s.get());
        bank.push_back(b);
    }
    return bank;
}
}  // namespace

GameData GameData::read(ByteStream& s) {
    Header h = Header::read(s);
    assert(s.good() && "Failed to read iNes header");

    GameData out;
    out.header = h;

    if (h.has_trainer_data()) {
        std::size_t trainer_sz = 512;
        out.trainer = read_bank(s, trainer_sz);
        assert(s.good() && "Failed to read trainer data");
    }

    std::size_t n_prg = h.prg_size;
    for (std::size_t i = 0; i < n_prg; i++) {
        Bank prg = read_bank(s, kiloBytes(16));
        assert(s.good() && "Failed to read prg data");
        out.prg.push_back(std::move(prg));
    }

    std::size_t n_chr = h.chr_size;
    for (std::size_t i = 0; i < n_chr; i++) {
        Bank chr = read_bank(s, kiloBytes(8));
        assert(s.good() && "Failed to read prg data");
        out.chr.push_back(std::move(chr));
    }

    return out;
}

void GameData::dump_prg() const {
    std::ofstream of("./build/prg.out", std::ios::out | std::ios::binary);

    for (const Bank& bank : this->prg) {
        for (Byte b : bank) {
            of << static_cast<unsigned char>(b);
        }
    }
}
