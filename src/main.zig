const std = @import("std");
const lib = @import("nes_lib");

const iNesHeader = struct {
    id: [4]u8,
    nPrgBanks: u8,
    nChrBanks: u8,
    flag6: u8,
    flag7: u8,
    flag8: u8,
    flag9: u8,
    flag10: u8,
    padding: [5]u8,
};

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("hello\n", .{});

    try bw.flush(); // Don't forget to flush!
}
