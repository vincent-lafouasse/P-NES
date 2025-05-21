#include <cstdlib>
#include <fstream>
#include <iostream>

#include "parse/GameData.hpp"
#include "types.hpp"

int main(int ac, char** av) {
    if (ac == 1) {
        std::cerr << "Usage: ./Nes rom.nes\n";
        std::exit(1);
    }

    const char* path = av[1];
    ByteStream stream(path);
    if (!stream.good()) {
        std::cerr << "Failed to open file " << std::quoted(path) << '\n';
        std::exit(1);
    }

    GameData g = GameData::read(stream);
    g.dump_prg();
}
