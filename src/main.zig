const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;

pub fn main() !void {
    const allocator = std.heap.page_allocator; // should be fine

    const cartridge = try Cartridge.load("roms/s9.nes", allocator);
    defer cartridge.free();

    cartridge.log();
    try cartridge.dump_prg("data.prg");

    const disassembler = try Disassembler.init(cartridge);
    _ = disassembler;
}
