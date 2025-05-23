const std = @import("std");
const lib = @import("nes_lib");

const iNesHeader = struct {
    nPrgBanks: u8,
    nChrBanks: u8,
    flag6: u8,
    flag7: u8,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const rom = try std.fs.cwd().openFile("roms/s9.nes", .{});
    const reader = rom.reader();

    var header_data: [16]u8 = undefined;

    _ = try reader.read(&header_data);

    const header = iNesHeader{
        .nPrgBanks = header_data[4],
        .nChrBanks = header_data[5],
        .flag6 = header_data[6],
        .flag7 = header_data[7],
    };

    try stdout.print("number of PRG banks:\t {}\n", .{header.nPrgBanks});
    try stdout.print("number of CHR banks:\t {}\n", .{header.nChrBanks});
    try stdout.print("flag 6:\t {b:08}\n", .{header.flag6});
    try stdout.print("flag 7:\t {b:08}\n", .{header.flag7});
}
