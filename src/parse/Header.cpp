#include "Header.hpp"

#include <cassert>

#include "log.hpp"

namespace {
bool bit_is_set(Byte b, u32 i) {
    return b & (1 << i);
}
}  // namespace

Header Header::read(ByteStream& s) {
    Header out{};

    s.read(reinterpret_cast<char*>(&out), 16);

    assert(s.good() && "Failed to read iNes header");

    constexpr Byte id[4] = {'N', 'E', 'S', 0x1a};
    assert(std::memcmp(out.id, id, 4) == 0 && "Invalid iNes header");
    assert(out.rom_format() != RomFormat::VersionTwo && "iNes 2.0 unsupported");

    LOG(out.rom_format());
    LOG_NUM(out.prg_size);
    LOG_NUM(out.chr_size);
    LOG(out.arrangement());
    LOG_BOOL(out.has_persistent_memory());
    LOG_BOOL(out.has_trainer_data());
    LOG_HEX(out.mapper());
    LOG_NUM(out.number_of_8kB_RAM_banks());
    LOG(out.video_format());

    assert(out.rom_format() != RomFormat::VersionTwo && "iNes 2.0 unsupported");
    if (out.rom_format() != RomFormat::VersionTwo) {
        out.verify_reserved_zeros();
    }
    return out;
}

Byte Header::byte(std::size_t offset) const {
    return reinterpret_cast<const Byte*>(this)[offset];
}

RomFormat Header::rom_format() const {
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

// flag 6:

Arrangement Header::arrangement() const {
    if (bit_is_set(flag6, 0)) {
        return {Arrangement::Vertical};
    } else {
        return {Arrangement::Horizontal};
    }
}

bool Header::has_persistent_memory() const {
    return bit_is_set(flag6, 1);
}

bool Header::has_trainer_data() const {
    return bit_is_set(flag6, 2);
}

bool Header::alternative_nametable_layout() const {
    return bit_is_set(flag6, 3);
}

Byte Header::mapper() const {
    const Byte lower = this->flag6 >> 4;
    const Byte upper = this->flag7 >> 4;

    return upper << 4 | lower;
}

u32 Header::number_of_8kB_RAM_banks() const {
    return byte(8) ? byte(8) : 1;
}

VideoFormat Header::video_format() const {
    if (bit_is_set(byte(9), 0)) {
        return {VideoFormat::Pal};
    } else {
        return {VideoFormat::Ntsc};
    }
}

void Header::verify_reserved_zeros() const {
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

const char* RomFormat::repr() const {
    switch (self) {
        case Archaic:
            return "Archaic iNes";
        case Standard:
            return "iNes";
        case VersionTwo:
            return "iNes 2.0";
    }
    return "Unreachable";
}

std::ostream& operator<<(std::ostream& stream, const RomFormat& a) {
    stream << a.repr();
    return stream;
}
bool RomFormat::operator==(const RomFormat& o) const {
    return self == o.self;
}
bool RomFormat::operator!=(const RomFormat& o) const {
    return self != o.self;
}

const char* Arrangement::repr() const {
    switch (self) {
        case Horizontal:
            return "Horizontal";
        case Vertical:
            return "Vertical";
    }
}

std::ostream& operator<<(std::ostream& stream, const Arrangement& a) {
    stream << a.repr();
    return stream;
}

const char* VideoFormat::repr() const {
    switch (self) {
        case Ntsc:
            return "NTSC";
        case Pal:
            return "Pal";
    }
}

std::ostream& operator<<(std::ostream& stream, const VideoFormat& a) {
    stream << a.repr();
    return stream;
}
