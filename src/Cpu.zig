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
    v: bool,
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
    const resetAddress: u16 = 0xfffc;

    pub fn init(bus: *Bus) Self {
        return Self{
            .bus = bus,
            .pc = Cpu.readAddress(bus, Cpu.resetAddress),
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .s = 0x00,
            .p = std.mem.zeroes(CpuStatus),
        };
    }

    pub fn reset(self: *Self) void {
        self.pc = Cpu.readAddress(self.bus, Cpu.resetAddress);
    }

    pub fn start(self: *Self) void {
        while (true) {
            self.pc += self.execute();
        }
    }

    fn execute(self: *Self) u8 {
        const instruction = Instruction.decode(self.bus.read(self.pc));
        const O = Instruction.Opcode;

        switch (instruction.opcode) {
            O.XXX => {
                return instruction.duration.cycles;
            },
            O.CLC => {
                self.p.c = false;
                return instruction.duration.cycles;
            },
            O.CLD => {
                self.p.d = false;
                return instruction.duration.cycles;
            },
            O.CLI => {
                self.p.i = false;
                return instruction.duration.cycles;
            },
            O.CLV => {
                self.p.v = false;
                return instruction.duration.cycles;
            },
            O.SEC => {
                self.p.c = true;
                return instruction.duration.cycles;
            },
            O.SED => {
                self.p.d = true;
                return instruction.duration.cycles;
            },
            O.SEI => {
                self.p.i = true;
                return instruction.duration.cycles;
            },
            else => {
                std.log.err("Unmapped instruction:\n{any}", .{instruction});
                @panic("");
            },
        }
    }

    fn readAddress(bus: *const Bus, address: u16) u16 {
        const lowByte: u16 = bus.read(address);
        const highByte: u16 = bus.read(address + 1);
        return lowByte + 256 * highByte;
    }
};
