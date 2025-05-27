const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;
const Bus = @import("Bus.zig").Bus;
const Cpu = @import("Cpu.zig").Cpu;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    //@breakpoint();

    const cartridge = try Cartridge.load("roms/tutor.nes", allocator);
    defer cartridge.free();

    cartridge.log();
    try cartridge.dump_prg();
    try cartridge.dump_chr();

    var disassembler = try Disassembler.init(cartridge);
    try disassembler.disassemble();

    var bus = try Bus.init(&cartridge);

    var cpu = Cpu.init(&bus);
    cpu.start();

    // const args = try std.process.ArgIterator.initWithAllocator(allocator);
    // defer args.deinit();
    // std.log.info("{any}", .{args});
}
