#pragma once

#include <cassert>

#include "log.hpp"
#include "types.hpp"

namespace {
template <typename T>
T kiloBytes(T n) {
    return n * (1 << 10);
}

bool bit_is_set(Byte b, u32 i) {
    return b & (1 << i);
}
}  // namespace

struct RomFormat {
    enum Kind {
        Archaic,
        Standard,
        VersionTwo,
    } self;

    constexpr RomFormat(Kind k) : self(k) {}

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

    friend std::ostream& operator<<(std::ostream& stream, const RomFormat& a) {
        stream << a.repr();
        return stream;
    }
    bool operator==(const RomFormat& o) { return self == o.self; }
    bool operator!=(const RomFormat& o) { return self != o.self; }
};

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
        assert(out.rom_format() != RomFormat::VersionTwo &&
               "iNes 2.0 unsupported");

        LOG(out.rom_format());
        LOG_NUM(out.prg_size);
        LOG_NUM(out.prg_size_bytes());
        LOG_NUM(out.chr_size);
        LOG_NUM(out.chr_size_bytes());
        LOG(out.arrangement());
        LOG_BOOL(out.has_persistent_memory());
        LOG_BOOL(out.has_trainer_data());
        LOG_HEX(out.mapper());
        LOG_NUM(out.number_of_8kB_RAM_banks());

        assert(out.rom_format() != RomFormat::VersionTwo &&
               "iNes 2.0 unsupported");
        if (out.rom_format() != RomFormat::VersionTwo) {
            out.verify_reserved_zeros();
        }
        return out;
    }

    Byte byte(std::size_t offset) const {
        return reinterpret_cast<const Byte*>(this)[offset];
    }

    constexpr RomFormat rom_format() const {
        if (flag7 && byte(0x0C) == 0x08) {
            return {RomFormat::VersionTwo};
        }

        if (flag7 && byte(0x04) == 0x08) {
            return {RomFormat::Archaic};
        }

        if (flag7 && byte(0x04) == 0x00) {
            if (!byte(12) && !byte(13) && !byte(14) && !byte(15)) {
                return {RomFormat::Standard};
            }
        }

        return {RomFormat::Archaic};
    }

    u32 prg_size_bytes() const { return this->prg_size * kiloBytes<u32>(16); }

    u32 chr_size_bytes() const { return this->chr_size * kiloBytes<u32>(8); }

    // flag 6:

    constexpr Arrangement arrangement() const {
        if (bit_is_set(flag6, 0)) {
            return {Arrangement::Vertical};
        } else {
            return {Arrangement::Horizontal};
        }
    }

    // maybe battery-backed PRG-RAM at $6000
    constexpr bool has_persistent_memory() const {
        return bit_is_set(flag6, 1);
    }

    constexpr bool has_trainer_data() const { return bit_is_set(flag6, 2); }

    constexpr bool alternative_nametable_layout() const {
        return bit_is_set(flag6, 3);
    }

    Byte mapper() const {
        const Byte lower = this->flag6 >> 4;
        const Byte upper = this->flag7 >> 4;

        return lower | (upper << 4);
    }

    u32 number_of_8kB_RAM_banks() const { return byte(8) ? byte(8) : 1; }

    void verify_reserved_zeros() const {
        assert(!bit_is_set(byte(7), 1));
        assert(!bit_is_set(byte(7), 2));
        assert(!bit_is_set(byte(7), 3));

        assert((byte(9) >> 1) == 0);
        assert(byte(10) == 0);
        assert(byte(11) == 0);
        assert(byte(12) == 0);
        assert(byte(13) == 0);
        assert(byte(14) == 0);
        assert(byte(15) == 0);
    }
};
