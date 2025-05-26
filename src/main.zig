const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;
const Bus = @import("Bus.zig").Bus;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cartridge = try Cartridge.load("roms/s9.nes", allocator);
    defer cartridge.free();

    cartridge.log();
    try cartridge.dump_prg("data.prg");

    var disassembler = try Disassembler.init(cartridge);
    try disassembler.disassemble();

    var bus = Bus.init(&cartridge);
    bus.write(0x420, 0x69);

    // const args = try std.process.ArgIterator.initWithAllocator(allocator);
    // defer args.deinit();
    // std.log.info("{any}", .{args});
}
