// ReSharper disable CppNonExplicitConvertingConstructor
#pragma once

#include "types.hpp"

struct RomFormat {
    enum Kind {
        Archaic,
        Standard,
        VersionTwo,
    } self;

    constexpr RomFormat(Kind k) : self(k) {}
    const char* repr() const;
    friend std::ostream& operator<<(std::ostream& stream, const RomFormat& a);
    bool operator==(const RomFormat& o);
    bool operator!=(const RomFormat& o);
};

struct Arrangement {
    enum Kind {
        Horizontal,
        Vertical,
    } self;

    constexpr Arrangement(Kind k) : self(k) {}

    const char* repr() const;
    friend std::ostream& operator<<(std::ostream& stream, const Arrangement& a);
};

struct VideoFormat {
    enum Kind {
        Ntsc,
        Pal,
    } self;

    constexpr VideoFormat(Kind k) : self(k) {}

    const char* repr() const;
    friend std::ostream& operator<<(std::ostream& stream, const VideoFormat& a);
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

    static Header read(ByteStream& s);

    RomFormat rom_format() const;
    Arrangement arrangement() const;
    bool has_persistent_memory() const;
    bool has_trainer_data() const;
    bool alternative_nametable_layout() const;
    Byte mapper() const;
    u32 number_of_8kB_RAM_banks() const;
    VideoFormat video_format() const;

   private:
    Byte byte(std::size_t offset) const;

    // flag 6:

    void verify_reserved_zeros() const;
};
