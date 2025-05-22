#pragma once

#include <array>
#include <cassert>

#include "Cartridge/Cartridge.hpp"
#include "types.hpp"

#define KILOBYTES(n) (n << 10)

class Bus final {
   public:
    explicit Bus(const Cartridge& cart) : cartridge(cart), RAM() {
        assert(cart.header.mapper() == 0x0 &&
               "only supporting mapper 0 for now");
    }
    Byte read(Address address) const {
        if (address >= 0x8000) {
            return cartridge.read(address);
        }
        return {};
    }
    void write(Address address, Byte data) const {}

   private:
    /*
      0000h-07FFh   Internal 2K Work RAM (mirrored to 800h-1FFFh)
      2000h-2007h   Internal PPU Registers (mirrored to 2008h-3FFFh)
      4000h-4017h   Internal APU Registers
      4018h-5FFFh   Cartridge Expansion Area almost 8K
      6000h-7FFFh   Cartridge SRAM Area 8K
      8000h-FFFFh   Cartridge PRG-ROM Area 32K
     */
    Byte& at(Address address) {
        if (address < 0x2000) {
            // CPU WRAM
            const Address actual_address =
                address & 0x07FF;  // only keep first 12 bits
            return RAM.at(actual_address);
        } else if (address >= 0x2000 && address < 0x4000) {
            // PPU registers
        } else if (address >= 0x4000 && address < 0x4018) {
            // APU registers
        } else if (address >= 0x4018 && address < 0x6000) {
            // Cartridge expansion
        } else if (address >= 0x6000 && address < 0x8000) {
            // Cartridge SRAM
        } else {
            // [0x8000-0xFFFF]
            // Cartridge PRG-ROM
        }

        assert("havent mapped this address yet" && false);
    }

    std::array<Byte, KILOBYTES(2)> RAM;
    const Cartridge& cartridge;
};