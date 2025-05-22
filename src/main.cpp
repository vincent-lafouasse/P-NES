#include <cstdlib>
#include <iostream>

#include "Bus/Bus.hpp"
#include "Cartridge/Cartridge.hpp"
#include "Cpu/Cpu.hpp"

int main(int ac, char** av) {
    if (ac == 1) {
        std::cerr << "Usage: ./Nes rom.nes\n";
        std::exit(1);
    }

    const char* path = av[1];
    Cartridge cartridge = Cartridge::load(path);

    Bus memory(cartridge);

    Cpu cpu(memory);
    cpu.reset();
    cpu.start();
}
