const std = @import("std");
const Bus = @import("Bus.zig").Bus;
const Instruction = @import("Instruction.zig").Instruction;

const CpuStatus = packed struct(u8) {
    c: bool,
    z: bool,
    i: bool,
    d: bool,
    b: bool,
    unused: bool,
    o: bool,
    n: bool,
};

pub const Cpu = struct {
    bus: *Bus,

    pc: u16,
    a: u8,
    x: u8,
    y: u8,
    s: u8,
    p: CpuStatus,

    const Self = @This();

    pub fn init(bus: *Bus) Self {
        const resetAddress = 0xfffc;
        const pc: u16 = readAddress(bus, resetAddress);

        return Self{
            .bus = bus,
            .pc = pc,
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .s = 0x00,
            .p = std.mem.zeroes(CpuStatus),
        };
    }

    fn readAddress(bus: *const Bus, address: u16) u16 {
        const lowByte: u16 = bus.read(address);
        const highByte: u16 = bus.read(address + 1);
        return lowByte + 256 * highByte;
    }
};
