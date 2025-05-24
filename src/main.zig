const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;

pub fn main() !void {
    const allocator = std.heap.page_allocator; // should be fine

    const cartridge = try Cartridge.load("roms/s9.nes", allocator);
    defer cartridge.free();

    cartridge.log();
}
