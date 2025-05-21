#pragma once

#include <cassert>

#include "log.hpp"
#include "types.hpp"

namespace {
template <typename T>
T kiloBytes(T n) {
    return n * (1 << 10);
}
}  // namespace

struct Header {
    Byte id[4];
    Byte prg_size;  // in units of 16kB
    Byte chr_size;  // in units of 8 kB
    Byte flag6;
    Byte flag7;  // vvv not part of official specs
    Byte flag8;
    Byte flag9;
    Byte flag10;  // ΛΛΛΛΛΛ
    Byte padding[5];

    static Header read(ByteStream& s) {
        Header out;

        s.read(reinterpret_cast<Byte*>(&out), 16);

        assert(s.good() && "Failed to read iNes header");

        Byte id[4] = {'N', 'E', 'S', 0x1a};
        assert(std::memcmp(out.id, id, 4) == 0 && "Invalid iNes header");

        LOG(out.format());
        LOG(+out.prg_size);
        LOG(out.prg_size_bytes());
        LOG(+out.chr_size);
        LOG(out.chr_size_bytes());
        LOG(out.arrangement());
        LOG(out.has_persistent_memory());
        LOG(out.has_trainer_data());
        LOG_HEX(out.mapper());
        LOG(out.is_pc10());
        return out;
    }

    Byte byte(std::size_t offset) const {
        return reinterpret_cast<const Byte*>(this)[offset];
    }

    struct Format {
        enum Kind {
            Archaic,
            Standard,
            VersionTwo,
        } self;

        constexpr Format(Kind k) : self(k) {}

        const char* repr() const {
            switch (self) {
                case Archaic:
                    return "Archaic iNes";
                case Standard:
                    return "iNes";
                case VersionTwo:
                    return "iNes 2.0";
            }
        }

        friend std::ostream& operator<<(std::ostream& stream, const Format& a) {
            stream << a.repr();
            return stream;
        }
    };

    constexpr Format format() const {
        if (flag7 && byte(0x0C) == 0x08) {
            return {Format::VersionTwo};
        }

        if (flag7 && byte(0x04) == 0x08) {
            return {Format::Archaic};
        }

        if (flag7 && byte(0x04) == 0x00) {
            if (!byte(12) && !byte(13) && !byte(14) && !byte(15)) {
                return {Format::Standard};
            }
        }

        return {Format::Archaic};
    }

    u32 prg_size_bytes() const { return this->prg_size * kiloBytes(16); }

    u32 chr_size_bytes() const { return this->chr_size * kiloBytes(8); }

    // flag 6:

    struct Arrangement {
        enum Kind {
            Horizontal,
            Vertical,
        } self;

        constexpr Arrangement(Kind k) : self(k) {}

        const char* repr() const {
            switch (self) {
                case Horizontal:
                    return "Horizontal";
                case Vertical:
                    return "Vertical";
            }
        }

        friend std::ostream& operator<<(std::ostream& stream,
                                        const Arrangement& a) {
            stream << a.repr();
            return stream;
        }
    };

    constexpr Arrangement arrangement() const {
        if (this->flag6 & 1) {
            return {Arrangement::Vertical};
        } else {
            return {Arrangement::Horizontal};
        }
    }

    // maybe battery-backed PRG-RAM at $6000
    constexpr bool has_persistent_memory() const {
        return this->flag6 & (1 << 1);
    }

    constexpr bool has_trainer_data() const { return this->flag6 & (1 << 2); }

    constexpr bool alternative_nametable_layout() const {
        return this->flag6 & (1 << 3);
    }

    Byte mapper() const {
        const Byte lower = this->flag6 >> 4;
        const Byte upper = this->flag7 >> 4;

        return lower | (upper << 4);
    }

    constexpr bool is_pc10() const { return flag7 | (1 << 1); }
};
