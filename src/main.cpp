#include "parse/GameData.hpp"
#include "types.hpp"

#define PATH "./roms/dq1.nes"

int main() {
    ByteStream stream(PATH);

    GameData g = GameData::read(stream);
    g.dump_prg();
}
