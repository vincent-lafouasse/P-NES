#pragma once

#include "types.hpp"

struct RomFormat {
    enum Kind {
        Archaic,
        Standard,
        VersionTwo,
    } self;

    constexpr RomFormat(Kind k) : self(k) {}  // NOLINT(*-explicit-constructor)

    [[nodiscard]]
    const char* repr() const;

    friend std::ostream& operator<<(std::ostream& stream, const RomFormat& a);
    bool operator==(const RomFormat& o) const;
    bool operator!=(const RomFormat& o) const;
};

struct Arrangement {
    enum Kind {
        Horizontal,
        Vertical,
    } self;

    constexpr Arrangement(Kind k)  // NOLINT(*-explicit-constructor)
        : self(k) {}

    [[nodiscard]]
    const char* repr() const;

    friend std::ostream& operator<<(std::ostream& stream, const Arrangement& a);
};

struct VideoFormat {
    enum Kind {
        Ntsc,
        Pal,
    } self;

    constexpr VideoFormat(Kind k)  // NOLINT(*-explicit-constructor)
        : self(k) {}

    [[nodiscard]]
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

    [[nodiscard]]
    RomFormat rom_format() const;
    [[nodiscard]]
    Arrangement arrangement() const;
    [[nodiscard]]
    bool has_persistent_memory() const;
    [[nodiscard]]
    bool has_trainer_data() const;
    [[nodiscard]]
    bool alternative_nametable_layout() const;
    [[nodiscard]]
    Byte mapper() const;
    [[nodiscard]]
    u32 number_of_8kB_RAM_banks() const;
    [[nodiscard]]
    VideoFormat video_format() const;

   private:
    [[nodiscard]]
    Byte byte(std::size_t offset) const;

    // flag 6:

    void verify_reserved_zeros() const;
};
