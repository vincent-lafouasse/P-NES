#pragma once

#include <memory>

#include "Header.hpp"
#include "types.hpp"

#define KILOBYTES(n) (n << 10)

template <usize N>
struct Bank {
    static Bank read(std::istream& stream) {
        Bank out{};

        for (usize i = 0; i < size; ++i) {
            int byte = stream.get();  // might be worth checking for EOFs
            out.data[i] = static_cast<Byte>(byte);
        }

        return out;
    }

    [[nodiscard]]
    Byte at(usize index) const {
        return data.at(index);
    }

    static constexpr usize size = N;
    std::array<Byte, size> data;
};

using TrainerBank = Bank<512>;
using PrgBank = Bank<KILOBYTES(16)>;
using ChrBank = Bank<KILOBYTES(8)>;

struct Cartridge {
    Header header;
    std::unique_ptr<TrainerBank> trainer;
    std::vector<std::unique_ptr<PrgBank>> prg;
    std::vector<std::unique_ptr<ChrBank>> chr;

    static Cartridge load(const std::string& path);
    void dump_prg() const;
};
