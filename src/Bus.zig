const std = @import("std");
const ByteList = std.ArrayList(u8);
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig").Cartridge;

const BusInitError = error{
    AllocationFailure,
    UnsupportedMapper,
    NoPrgDataSomehow,
};

pub const Bus = struct {
    const cpuRamSize = 0x800; // $0000-$$0800, mirrored up to $2000
    cpuRam: [Bus.cpuRamSize]u8,

    ppuRegisters: [8]u8, // $2000-$2007, mirrored up to $4000
    apuRegisters: [16]u8, // $4000-$4015
    joystick1: u8, // $4016
    joystick2: u8, // $4017
    apuExtension: [8]u8, // $4018-$401f

    unmapped: [0xbfe0]u8, // $4020 up to $6000
    cartridgeRam: [0x2000]u8, // $6000 up to $8000

    lowBank: []const u8, // $8000 up to $c000.
    highBank: []const u8, // $c000 - $ffff

    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(cartridge: *const Cartridge) BusInitError!Self {
        const cpuRam = std.mem.zeroes([Bus.cpuRamSize]u8);
        const ppuRegisters = std.mem.zeroes([8]u8);
        const apuRegisters = std.mem.zeroes([16]u8);
        const apuExtension = std.mem.zeroes([8]u8);
        const unmapped = std.mem.zeroes([0xbfe0]u8);
        const cartridgeRam = std.mem.zeroes([0x2000]u8);

        var lowBank: []const u8 = undefined;
        var highBank: []const u8 = undefined;
        try Bus.initPrgRom(cartridge, &lowBank, &highBank);

        return Self{
            .cartridge = cartridge,
            .cpuRam = cpuRam,
            .ppuRegisters = ppuRegisters,
            .apuRegisters = apuRegisters,
            .joystick1 = 0x00,
            .joystick2 = 0x00,
            .apuExtension = apuExtension,
            .unmapped = unmapped,
            .cartridgeRam = cartridgeRam,
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
