const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;
const Bus = @import("Bus.zig").Bus;
const Cpu = @import("Cpu.zig").Cpu;

const raylib = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cartridge = try Cartridge.load("roms/s9/s9.nes", allocator);
    defer cartridge.free();

    cartridge.log();
    try cartridge.dump_prg();
    try cartridge.dump_chr();

    var disassembler = try Disassembler.init(cartridge, allocator);
    defer disassembler.deinit();
    try disassembler.disassemble();

    var bus = try Bus.init(&cartridge);

    var cpu = try Cpu.init(&bus, cartridge.name);
    defer cpu.deinit();
    cpu.start();

    // const args = try std.process.ArgIterator.initWithAllocator(allocator);
    // defer args.deinit();
    // std.log.info("{any}", .{args});
}
