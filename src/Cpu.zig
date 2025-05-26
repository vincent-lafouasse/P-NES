const std = @import("std");
const Bus = @import("Bus.zig").Bus;
const Instruction = @import("Instruction.zig").Instruction;

const CpuStatus = packed struct(u8) {
    carry: bool,
    zero: bool,
    interruptDisable: bool,
    decimalMode: bool,
    breakFlag: bool,
    unused: bool,
    overflowFlag: bool,
    negative: bool,

    pub fn fromByte(byte: u8) CpuStatus {
        return @bitCast(byte);
    }

    pub fn toByte(self: CpuStatus) u8 {
        return @bitCast(self);
    }
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
        //@breakpoint();
        while (true) {
            const cycles: u8 = self.execute();
            _ = cycles;
        }
    }

    fn execute(self: *Self) u8 {
        const data: u8 = self.bus.read(self.pc);
        const instruction = Instruction.decode(data);
        const O = Instruction.Opcode;

        var cycles: u8 = undefined;

        switch (instruction.opcode) {
            O.XXX => {
                std.log.debug("Ignoring opcode {x:02}", .{data});
                cycles = instruction.duration.cycles;
            },
            O.CLC => {
                self.p.carry = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.CLD => {
                self.p.decimalMode = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.CLI => {
                self.p.interruptDisable = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.CLV => {
                self.p.overflowFlag = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.SEC => {
                self.p.carry = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.SED => {
                self.p.decimalMode = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            O.SEI => {
                self.p.interruptDisable = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
                cycles = instruction.duration.cycles;
            },
            else => {
                std.log.err("Unmapped instruction:\n{any}", .{instruction});
                @panic("");
            },
        }
        self.pc += instruction.size;
        return cycles;
    }

    fn readAddress(bus: *const Bus, address: u16) u16 {
        const lowByte: u16 = bus.read(address);
        const highByte: u16 = bus.read(address + 1);
        return lowByte + 256 * highByte;
    }
};
