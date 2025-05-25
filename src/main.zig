const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cartridge = try Cartridge.load("roms/s9.nes", allocator);
    defer cartridge.free();

    cartridge.log();
    try cartridge.dump_prg("data.prg");

    const disassembler = try Disassembler.init(cartridge);
    _ = disassembler;

    const args = try std.process.ArgIterator.initWithAllocator(allocator);
    defer args.deinit();
    std.log.info("{any}", .{args});
}
