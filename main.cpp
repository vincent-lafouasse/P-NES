#include <cassert>
#include <cstdint>
#include <fstream>
#include <iostream>

#define PATH "./dq1.nes"

#define LOGGING 1

#if LOGGING
#define LOG(expr) std::clog << #expr << ":\n\t" << expr << std::endl;
#else
#define LOG(expr) ;
#endif

using Byte = char;
using u32 = uint32_t;
using ByteStream = std::basic_ifstream<Byte>;

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

        assert(out.id[0] == 'N');
        assert(out.id[1] == 'E');
        assert(out.id[2] == 'S');
        assert(out.id[3] == 0x1a);

        LOG(out.format());
        LOG(+out.prg_size);
        LOG(out.prg_size_bytes());
        LOG(+out.chr_size);
        LOG(out.chr_size_bytes());
        LOG(out.arrangement());
        LOG(out.has_persistent_memory());
        LOG(out.has_trainer_data());
        LOG(+out.mapper_lower_nibble());
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

    u32 prg_size_bytes() const {
        // 16kB = 2^14 B
        return this->prg_size * (1 << 14);
    }

    u32 chr_size_bytes() const {
        // 8kB
        return this->chr_size * (1 << 13);
    }

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

    constexpr Byte mapper_lower_nibble() const { return this->flag6 >> 4; }

    constexpr bool is_pc10() const { return flag7 | (1 << 1); }
};

struct Game {
    Header header;
    std::vector<Byte> trainer;
    std::vector<Byte> prg;
    std::vector<Byte> chr;
    std::vector<Byte> pc10_inst;

    static Game read(ByteStream& s) {
        Header h = Header::read(s);

        Game out;
        out.header = h;

        if (h.has_trainer_data()) {
            out.trainer.reserve(512);
        }

        u32 prg_size = h.prg_size_bytes();
        out.prg.reserve(prg_size);
        for (u32 i = 0; i < prg_size; ++i) {
            Byte b = s.get();
            out.prg.push_back(b);
        }

        u32 chr_size = h.chr_size_bytes();
        out.chr.reserve(chr_size);
        for (u32 i = 0; i < chr_size; ++i) {
            Byte b = s.get();
            out.chr.push_back(b);
        }

        if (h.is_pc10()) {
            out.pc10_inst.reserve(1 << 13);  // 8kB
            for (u32 i = 0; i < chr_size; ++i) {
                Byte b = s.get();
                out.pc10_inst.push_back(b);
            }
        }

        return out;
    }
};

int main() {
    ByteStream stream(PATH);

    Game g = Game::read(stream);
    LOG(sizeof(g));
}
