const std = @import("std");
const Allocator = std.mem.Allocator;

const Cartridge = @import("Cartridge.zig").Cartridge;

pub const Bus = struct {
    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(allocator: Allocator, cartridge: *const Cartridge) !Self {
        _ = allocator;

        return Self{
            .cartridge = cartridge,
        };
    }

    pub fn free(self: Self) void {
        _ = self;
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
