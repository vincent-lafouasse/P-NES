const std = @import("std");
const ArrayList = std.ArrayList;
const AnyReader = std.io.AnyReader;
const Allocator = std.mem.Allocator;

fn str_eq(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

fn str_in(x: []const u8, haystack: []const []const u8) bool {
    for (haystack) |s| {
        if (str_eq(x, s)) {
            return true;
        }
    }
    return false;
}

fn readBytes(reader: anytype, allocator: Allocator, size: usize) !ArrayList(u8) {
    var bytes = try ArrayList(u8).initCapacity(allocator, size);

    // yes im doing it byte by byte, sue me
    for (0..size) |_| {
        const byte: u8 = try reader.readByte();
        bytes.appendAssumeCapacity(byte);
    }

    return bytes;
}

pub const Cartridge = struct {
    pub const trainerSize: usize = 512;
    pub const prgBankSize: usize = 16 * 1024;
    pub const chrBankSize: usize = 8 * 1024;
    nPrgBanks: u8,
    nChrBanks: u8,

    trainer: ?ArrayList(u8),
    prg: ArrayList(u8),
    chr: ArrayList(u8),

    videoFormat: VideoFormat,
    mapper: u8,

    const Self = @This();

    pub fn load(path: []const u8, allocator: std.mem.Allocator) !Self {
        const rom = try std.fs.cwd().openFile(path, .{});
        defer rom.close();
        const reader = rom.reader();

        const header = try iNesHeader.read(&reader);
        header.log();

        const hasTrainerData = header.hasTrainerData();
        const trainer: ?ArrayList(u8) = switch (hasTrainerData) {
            true => try readBytes(reader, allocator, Self.trainerSize),
            false => null,
        };
        const prg = try readBytes(reader, allocator, header.nPrgBanks * Self.prgBankSize);
        const chr = try readBytes(reader, allocator, header.nChrBanks * Self.chrBankSize);

        return Self{
            .nPrgBanks = header.nPrgBanks,
            .nChrBanks = header.nChrBanks,
            .trainer = trainer,
            .prg = prg,
            .chr = chr,
            .videoFormat = header.videoFormat(),
            .mapper = header.mapper(),
        };
    }

    pub fn free(self: Self) void {
        if (self.trainer) |data| data.deinit();
        self.prg.deinit();
        self.chr.deinit();
    }

    pub fn log(self: Self) void {
        const log_fn = std.log.info;

        log_fn("Cartridge {{", .{});
        inline for (std.meta.fields(@TypeOf(self))) |f| {
            if (str_eq(f.name, "chr")) {
                log_fn("    {s:<8}:\t size {any} aka {x}", .{ "CHR Banks", self.chr.items.len, self.chr.items.len });
            } else if (str_eq(f.name, "prg")) {
                log_fn("    {s:<8}:\t size {any} aka {x}", .{ "PRG Banks", self.prg.items.len, self.prg.items.len });
            } else {
                log_fn("    {s:<8}:\t {any}", .{ f.name, @as(f.type, @field(self, f.name)) });
            }
        }
        log_fn("}}\n", .{});
    }

    pub fn dump_prg(self: Self, path: []const u8) !void {
        const outfile = try std.fs.cwd().createFile(path, .{});
        defer outfile.close();
        const writer = outfile.writer();

        for (self.prg.items) |byte| {
            try writer.writeByte(byte);
        }
    }
};

const RomFormat = enum {
    Archaic,
    iNes,
    iNes2,

    const Self = @This();

    const nameTable = [@typeInfo(Self).@"enum".fields.len][:0]const u8{
        "Archaic iNes",
        "Standard iNes",
        "iNes 2.0",
    };

    pub fn str(self: Self) [:0]const u8 {
        return nameTable[@intFromEnum(self)];
    }
};

const VideoFormat = enum {
    Ntsc,
    Pal,

    const Self = @This();

    const nameTable = [@typeInfo(Self).@"enum".fields.len][:0]const u8{
        "NTSC", "PAL",
    };

    pub fn str(self: Self) [:0]const u8 {
        return nameTable[@intFromEnum(self)];
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

    const Self = @This();

    fn read(reader: anytype) !Self {
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
        const flag14 = bytes[14];
        const flag15 = bytes[15];

        return Self{
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

    fn hasTrainerData(self: Self) bool {
        return (self.flag6 & (1 << 2)) == 1;
    }

    fn videoFormat(self: Self) VideoFormat {
        const isNtsc = (self.flag9 & 1) == 0;

        if (isNtsc) {
            return VideoFormat.Ntsc;
        } else {
            return VideoFormat.Pal;
        }
    }

    fn mapper(self: Self) u8 {
        return (self.flag6 >> 4) | (self.flag7 & 0xf0);
    }

    fn log(self: Self) void {
        const log_fn = std.log.info;
        log_fn("Header {{", .{});
        log_fn("    number of PRG banks:\t {}", .{self.nPrgBanks});
        log_fn("    number of CHR banks:\t {}", .{self.nChrBanks});
        log_fn("", .{});
        log_fn("    flag 6:\t {b:08}", .{self.flag6});
        log_fn("    flag 7:\t {b:08}", .{self.flag7});
        log_fn("    flag 8:\t {b:08}", .{self.flag8});
        log_fn("    flag 9:\t {b:08}", .{self.flag9});
        log_fn("    flag 10:\t {b:08}", .{self.flag10});
        log_fn("}}\n", .{});
    }
};
