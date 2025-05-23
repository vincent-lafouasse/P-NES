const std = @import("std");

pub const Cartridge = struct {
    const prgBankSize: usize = 16 * 1024;
    const chrBankSize: usize = 8 * 1024;
    nPrgBanks: u8,
    nChrBanks: u8,

    videoFormat: VideoFormat,
    mapper: u8,

    const This = @This();

    pub fn load(path: []const u8) !This {
        const rom = try std.fs.cwd().openFile(path, .{});
        const reader = rom.reader();

        const header = try iNesHeader.read(&reader);
        header.log();

        const videoFormat = switch (header.flag9 & 1) {
            1 => VideoFormat.Pal,
            0 => VideoFormat.Ntsc,
            else => unreachable,
        };

        const hasTrainerData = (header.flag6 & (1 << 2)) == 1;
        _ = hasTrainerData;

        const mapper: u8 = (header.flag6 >> 4) | (header.flag7 & 0b11110000);

        return This{
            .nPrgBanks = header.nPrgBanks,
            .nChrBanks = header.nChrBanks,
            .videoFormat = videoFormat,
            .mapper = mapper,
        };
    }

    pub fn log(this: This) void {
        std.log.info("Cartridge {{", .{});
        std.log.info("\tnumber of PRG banks:\t {}", .{this.nPrgBanks});
        std.log.info("\tnumber of CHR banks:\t {}", .{this.nChrBanks});
        std.log.info("\tVideo format:\t\t {s}", .{this.videoFormat.str()});
        std.log.info("\tMapper ID:\t\t {}", .{this.mapper});
        std.log.info("}}\n", .{});
    }
};

const RomFormat = enum {
    Archaic,
    iNes,
    iNes2,

    const This = @This();

    const nameTable = [@typeInfo(This).@"enum".fields.len][:0]const u8{
        "Archaic iNes",
        "Standard iNes",
        "iNes 2.0",
    };

    pub fn str(this: This) [:0]const u8 {
        return nameTable[@intFromEnum(this)];
    }
};

const VideoFormat = enum {
    Ntsc,
    Pal,

    const This = @This();

    const nameTable = [@typeInfo(This).@"enum".fields.len][:0]const u8{
        "NTSC", "PAL",
    };

    pub fn str(this: This) [:0]const u8 {
        return nameTable[@intFromEnum(this)];
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
    flag11: u8,
    flag12: u8,
    flag13: u8,
    flag14: u8,
    flag15: u8,

    const This = @This();

    fn read(reader: anytype) !This {
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
        const flag11 = bytes[11];
        const flag12 = bytes[12];
        const flag13 = bytes[13];
        const flag15 = bytes[14];
        const flag10 = bytes[15];

        return This{
            .nPrgBanks = nPrgBanks,
            .nChrBanks = nChrBanks,
            .flag6 = flag6,
            .flag7 = flag7,
            .flag8 = flag8,
            .flag9 = flag9,
            .flag10 = flag10,
            .flag11 = flag11,
            .flag12 = flag12,
            .flag13 = flag13,
            .flag14 = flag14,
            .flag15 = flag15,
        };
    }

    fn log(this: This) void {
        std.log.info("Header {{", .{});
        std.log.info("\tnumber of PRG banks:\t {}", .{this.nPrgBanks});
        std.log.info("\tnumber of CHR banks:\t {}", .{this.nChrBanks});
        std.log.info("", .{});
        std.log.info("\tflag 6:\t\t {b:08}", .{this.flag6});
        std.log.info("\tflag 7:\t\t {b:08}", .{this.flag7});
        std.log.info("\tflag 8:\t\t {b:08}", .{this.flag8});
        std.log.info("\tflag 9:\t\t {b:08}", .{this.flag9});
        std.log.info("\tflag 10:\t {b:08}", .{this.flag10});
        std.log.info("}}\n", .{});
    }
};
