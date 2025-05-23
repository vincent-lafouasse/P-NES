const std = @import("std");

pub const Cartridge = struct {
    const prgBankSize: usize = 16 * 1024;
    const chrBankSize: usize = 8 * 1024;
    nPrgBanks: u8,
    nChrBanks: u8,

    videoFormat: VideoFormat,

    pub fn load(path: []const u8) !Cartridge {
        const rom = try std.fs.cwd().openFile(path, .{});
        const reader = rom.reader();

        const header = try iNesHeader.read(&reader);
        header.log();

        const videoFormat = switch (header.flag9 & 1) {
            1 => VideoFormat.Pal,
            0 => VideoFormat.Ntsc,
            else => unreachable,
        };

        return Cartridge{
            .nPrgBanks = header.nPrgBanks,
            .nChrBanks = header.nChrBanks,
            .videoFormat = videoFormat,
        };
    }

    pub fn log(self: Cartridge) void {
        std.log.info("Cartridge {{", .{});
        std.log.info("\tnumber of PRG banks:\t {}", .{self.nPrgBanks});
        std.log.info("\tnumber of CHR banks:\t {}", .{self.nChrBanks});
        const videoFormatRepr = self.videoFormat.repr();
        std.log.info("\tVideo format:\t {s}", .{videoFormatRepr[0.. :0]});
        std.log.info("}}\n", .{});
    }
};

const RomFormat = enum {
    Archaic,
    iNes,
    iNes2,

    fn repr(self: RomFormat) [:0]const u8 {
        switch (self) {
            .Archaic => "Archaic iNes",
            .iNes => "Standard iNes",
            .iNes2 => "iNes 2.0",
        }
    }
};

const VideoFormat = enum {
    Ntsc,
    Pal,

    fn repr(self: VideoFormat) [:0]const u8 {
        switch (self) {
            .Ntsc => "NTSC",
            .Pal => "PAL",
        }
    }
};

const iNesHeader = struct {
    nPrgBanks: u8,
    nChrBanks: u8,
    flag6: u8,
    flag7: u8,
    flag8: u8,
    flag9: u8,
    flag10: u8,

    fn read(reader: anytype) !iNesHeader {
        var bytes: [16]u8 = undefined;
        _ = try reader.read(&bytes);

        // an iNes file must always start with those 4 bytes
        const expectedID = [4]u8{ 'N', 'E', 'S', 0x1a };
        try std.testing.expect(std.mem.eql(u8, &expectedID, bytes[0..4]));

        const nPrgBanks = bytes[4];
        const nChrBanks = bytes[5];
        const flag6 = bytes[6];
        const flag7 = bytes[7];
        const flag8 = bytes[8];
        const flag9 = bytes[9];
        const flag10 = bytes[10];

        return iNesHeader{
            .nPrgBanks = nPrgBanks,
            .nChrBanks = nChrBanks,
            .flag6 = flag6,
            .flag7 = flag7,
            .flag8 = flag8,
            .flag9 = flag9,
            .flag10 = flag10,
        };
    }

    fn log(self: iNesHeader) void {
        std.log.info("Header {{", .{});
        std.log.info("\tnumber of PRG banks:\t {}", .{self.nPrgBanks});
        std.log.info("\tnumber of CHR banks:\t {}", .{self.nChrBanks});
        std.log.info("", .{});
        std.log.info("\tflag 6:\t\t {b:08}", .{self.flag6});
        std.log.info("\tflag 7:\t\t {b:08}", .{self.flag7});
        std.log.info("\tflag 8:\t\t {b:08}", .{self.flag8});
        std.log.info("\tflag 9:\t\t {b:08}", .{self.flag9});
        std.log.info("\tflag 10:\t {b:08}", .{self.flag10});
        std.log.info("}}\n", .{});
    }
};
