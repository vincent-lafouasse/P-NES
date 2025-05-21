#include <cstdlib>
#include <iostream>

#include "parse/GameData.hpp"

int main(int ac, char** av) {
    if (ac == 1) {
        std::cerr << "Usage: ./Nes rom.nes\n";
        std::exit(1);
    }

    const char* path = av[1];
    GameData g = GameData::read(path);
    g.dump_prg();
}
