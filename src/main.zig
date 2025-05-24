const Cartridge = @import("Cartridge.zig").Cartridge;

pub fn main() !void {
    const cartridge = try Cartridge.load("roms/s9.nes");
    cartridge.log();
}
