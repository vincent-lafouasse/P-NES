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
            self.execute();
        }
    }

    fn execute(self: *Self) void {
        const data: u8 = self.bus.read(self.pc);
        const instruction = Instruction.decode(data);
        const O = Instruction.Opcode;

        std.log.debug("Executing instruction {s} in {s} mode", .{ @tagName(instruction.opcode), @tagName(instruction.mode) });

        switch (instruction.opcode) {
            O.XXX => {
                std.log.debug("Ignoring opcode {x:02}", .{data});
            },
            O.CLC => {
                self.p.carry = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.CLD => {
                self.p.decimalMode = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.CLI => {
                self.p.interruptDisable = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.CLV => {
                self.p.overflowFlag = false;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.SEC => {
                self.p.carry = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.SED => {
                self.p.decimalMode = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.SEI => {
                self.p.interruptDisable = true;
                std.log.debug("Status flag is now {b:08}", .{self.p.toByte()});
            },
            O.LDA => {
                self.lda(instruction.mode);
            },
            else => {
                std.log.err("Unmapped instruction:\n{any}", .{instruction});
                @panic("");
            },
        }
        self.pc += instruction.size;
    }

    fn lda(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const M = Instruction.AddressingMode;

        const op1: u8 = self.bus.read(self.pc + 1);

        if (addressingMode == M.Immediate) {
            std.log.debug("Writing {x:02} in accumulator", .{op1});
        }

        const address: u16 = switch (addressingMode) {
            M.ZeroPage => op1,
            M.ZeroPage_XIndexed => op1 +% self.x,
            M.ZeroPage_YIndexed => op1 +% self.y,
            M.Absolute, M.Absolute_XIndexed, M.Absolute_YIndexed => out: {
                const lowByte: u16 = op1;
                const highByte: u16 = self.bus.read(self.pc + 2);
                const a: u16 = lowByte + 256 * highByte;

                switch (addressingMode) {
                    M.Absolute => break :out a,
                    M.Absolute_XIndexed => break :out a + self.y,
                    M.Absolute_YIndexed => break :out a + self.x,
                    else => unreachable,
                }
            },
            M.XIndexed_Indirect => out: {
                const lookupAddress: u8 = op1 +% self.x;

                const lowByte: u16 = self.bus.read(lookupAddress);
                const highByte: u16 = self.bus.read(lookupAddress + 1);
                break :out lowByte + 256 * highByte;
            },
            M.Indirect_YIndexed => out: {
                const lookupAddress: u8 = op1;

                const lowByte: u16 = self.bus.read(lookupAddress);
                const highByte: u16 = self.bus.read(lookupAddress + 1);
                break :out lowByte + 256 * highByte + @as(u16, self.y);
            },
            M.Immediate => unreachable,
            else => unreachable,
        };

        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in accumulator from address {x:04}", .{ value, address });
        self.a = value;
    }

    fn readAddress(bus: *const Bus, address: u16) u16 {
        const lowByte: u16 = bus.read(address);
        const highByte: u16 = bus.read(address + 1);
        return lowByte + 256 * highByte;
    }
};
