const std = @import("std");
const ByteList = std.ArrayList(u8);
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig").Cartridge;

pub const Bus = struct {
    const cpuRamSize = 0x800; // 2kB
    cpuRam: ByteList,

    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(allocator: Allocator, cartridge: *const Cartridge) !Self {
        var cpuRam = try ByteList.initCapacity(allocator, Bus.cpuRamSize);
        cpuRam.appendNTimesAssumeCapacity(0, Bus.cpuRamSize);

        return Self{
            .cartridge = cartridge,
            .cpuRam = cpuRam,
        };
    }

    pub fn free(self: Self) void {
        self.cpuRam.deinit();
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
