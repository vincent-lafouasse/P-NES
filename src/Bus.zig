const std = @import("std");
const ByteList = std.ArrayList(u8);
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig").Cartridge;

const BusInitError = error{
    AllocationFailure,
    UnsupportedMapper,
};

pub const Bus = struct {
    const cpuRamSize = 0x800; // 2kB
    cpuRam: [Bus.cpuRamSize]u8,

    // lowBank: []const u8,
    // highBank: []const u8,

    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(cartridge: *const Cartridge) Self {
        const cpuRam = std.mem.zeroes([Bus.cpuRamSize]u8);

        return Self{
            .cartridge = cartridge,
            .cpuRam = cpuRam,
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
