#include <cstdlib>
#include <iostream>

#include "Cartridge/Cartridge.hpp"
#include "Cpu/Cpu.hpp"

int main(int ac, char** av) {
    if (ac == 1) {
        std::cerr << "Usage: ./Nes rom.nes\n";
        std::exit(1);
    }

    const char* path = av[1];
    Cartridge cartridge = Cartridge::load(path);
    g.dump_prg();

    Cpu cpu{};
    (void)cpu;
}
