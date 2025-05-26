const std = @import("std");
const ByteList = std.ArrayList(u8);
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig").Cartridge;

const PpuRegisters = struct {
    ctrl: u8,
    mask: u8,
    status: u8,
    oamAddress: u8,
    oamData: u8,
    scroll: u8,
    address: u8,
    data: u8,
};

const BusInitError = error{
    AllocationFailure,
    UnsupportedMapper,
    NoPrgDataSomehow,
};

pub const Bus = struct {
    const cpuRamSize = 0x800; // 2kB
    cpuRam: [Bus.cpuRamSize]u8,

    ppuRegisters: PpuRegisters,

    lowBank: []const u8,
    highBank: []const u8,

    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(cartridge: *const Cartridge) BusInitError!Self {
        const cpuRam = std.mem.zeroes([Bus.cpuRamSize]u8);
        const ppuRegisters = std.mem.zeroes(PpuRegisters);

        var lowBank: []const u8 = undefined;
        var highBank: []const u8 = undefined;
        try Bus.initPrgRom(cartridge, &lowBank, &highBank);

        return Self{
            .cartridge = cartridge,
            .cpuRam = cpuRam,
            .ppuRegisters = ppuRegisters,
            .lowBank = lowBank,
            .highBank = highBank,
        };
    }

    fn initPrgRom(cartridge: *const Cartridge, lowBank: *[]const u8, highBank: *[]const u8) BusInitError!void {
        if (cartridge.mapper != 0) {
            return BusInitError.UnsupportedMapper;
        }

        if (cartridge.nPrgBanks == 0) {
            return BusInitError.NoPrgDataSomehow;
        }

        lowBank.* = cartridge.prg.items[0..0x2000];
        highBank.* = switch (cartridge.nPrgBanks) {
            1 => lowBank.*,
            else => cartridge.prg.items[0x2000..0x4000],
        };
    }

    pub fn read(self: *const Self, address: u16) u8 {
        _ = self;
        _ = address;
        return 0x00;
    }

    pub fn write(self: *const Self, address: u16, value: u8) void {
        _ = self;
        _ = address;
        _ = value;
    }
};
