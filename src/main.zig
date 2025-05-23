const std = @import("std");
const lib = @import("nes_lib");

const iNesHeader = struct {
    nPrgBanks: u8,
    nChrBanks: u8,
    flag6: u8,
    flag7: u8,

    fn read(reader: anytype) !iNesHeader {
        var bytes: [16]u8 = undefined;
        _ = try reader.read(&bytes);

        const expectedID = [4]u8{ 'N', 'E', 'S', 0x1a };
        try std.testing.expect(std.mem.eql(u8, &expectedID, bytes[0..4]));

        const nPrgBanks = bytes[4];
        const nChrBanks = bytes[5];
        const flag6 = bytes[6];
        const flag7 = bytes[7];

        return iNesHeader{
            .nPrgBanks = nPrgBanks,
            .nChrBanks = nChrBanks,
            .flag6 = flag6,
            .flag7 = flag7,
        };
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    const rom = try std.fs.cwd().openFile("roms/s9.nes", .{});
    const reader = rom.reader();

    const header = try iNesHeader.read(&reader);

    try stdout.print("number of PRG banks:\t {}\n", .{header.nPrgBanks});
    try stdout.print("number of CHR banks:\t {}\n", .{header.nChrBanks});
    try stdout.print("flag 6:\t {b:08}\n", .{header.flag6});
    try stdout.print("flag 7:\t {b:08}\n", .{header.flag7});
}
