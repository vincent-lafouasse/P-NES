#include "Cartridge.hpp"

#include <cassert>
#include <cstdlib>
#include <fstream>
#include <iostream>

#include "log/log.hpp"

Cartridge Cartridge::load(const std::string& path) {
    std::ifstream s(path);
    if (!s.good()) {
        std::cerr << "Failed to open file " << std::quoted(path) << '\n';
        std::exit(1);
    }

    Header h = Header::read(s);
    assert(s.good() && "Failed to read iNes header");

    Cartridge out;
    out.header = h;

    out.trainer = nullptr;
    if (h.has_trainer_data()) {
        TrainerBank bank = TrainerBank::read(s);
        assert(s.good() && "Failed to read trainer data");
        std::unique_ptr<TrainerBank> trainer(new TrainerBank(bank));
        out.trainer = std::move(trainer);
    }

    for (usize _ = 0; _ < h.prg_size; _++) {
        PrgBank bank = PrgBank::read(s);
        assert(s.good() && "Failed to read prg data");
        std::unique_ptr<PrgBank> prg(new PrgBank(bank));
        out.prg.push_back(std::move(prg));
    }

    for (usize _ = 0; _ < h.chr_size; _++) {
        ChrBank bank = ChrBank::read(s);
        assert(s.good() && "Failed to read chr data");
        std::unique_ptr<ChrBank> chr(new ChrBank(bank));
        out.chr.push_back(std::move(chr));
    }

#if LOGGING
    out.dump_prg();
#endif

    return out;
}

void Cartridge::dump_prg() const {
    std::ofstream of("./build/prg.out", std::ios::out | std::ios::binary);

    for (const auto& bank : prg) {
        for (usize i = 0; i < bank->size; ++i) {
            of << bank->at(i);
        }
    }
}
