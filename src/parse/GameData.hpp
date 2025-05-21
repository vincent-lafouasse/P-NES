#pragma once

#include <cassert>

#include "Header.hpp"

struct GameData {
    Header header;
    std::vector<Byte> trainer;
    std::vector<Byte> prg;
    std::vector<Byte> chr;
    std::vector<Byte> pc10_inst;

    static GameData read(ByteStream& s) {
        Header h = Header::read(s);
        assert(s.good() && "Failed to read iNes header");

        GameData out;
        out.header = h;

        if (h.has_trainer_data()) {
            constexpr std::size_t trainer_size = 512;
            out.trainer.reserve(trainer_size);
            for (u32 i = 0; i < trainer_size; ++i) {
                Byte b = static_cast<Byte>(s.get());
                out.trainer.push_back(b);
            }
            assert(s.good() && "Failed to read prg data");
        }

        u32 prg_size = h.prg_size_bytes();
        out.prg.reserve(prg_size);
        for (u32 i = 0; i < prg_size; ++i) {
            Byte b = static_cast<Byte>(s.get());
            out.prg.push_back(b);
        }
        assert(s.good() && "Failed to read prg data");

        u32 chr_size = h.chr_size_bytes();
        out.chr.reserve(chr_size);
        for (u32 i = 0; i < chr_size; ++i) {
            Byte b = static_cast<Byte>(s.get());
            out.chr.push_back(b);
        }
        assert(s.good() && "Failed to read chr data");

        // bruh

        /*
        if (h.is_pc10()) {
            out.pc10_inst.reserve(1 << 13);  // 8kB
            for (u32 i = 0; i < chr_size; ++i) {
                Byte b = s.get();
                out.pc10_inst.push_back(b);
            }
        }
        assert(s.good() && "Failed to read pc10 data");
        */

        return out;
    }

    void dump_prg() const {
        std::ofstream of("prg.out", std::ios::out | std::ios::binary);

        for (Byte b : this->prg) {
            of << static_cast<unsigned char>(b);
        }
    }
};
