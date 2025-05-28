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

    cycles: usize,

    const Self = @This();
    const resetAddress: u16 = 0xfffc;

    pub fn init(bus: *Bus) Self {
        return Self{
            .bus = bus,
            .pc = Cpu.readAddress(bus, Cpu.resetAddress),
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .s = 0xff,
            .p = std.mem.zeroes(CpuStatus),
            .cycles = 0,
        };
    }

    fn pushOntoStack(self: *Self, value: u8) void {
        const actualAddress: u16 = 0x0100 + @as(u16, self.s);
        self.bus.write(actualAddress, value);
        self.s -= 1;
    }

    fn popFromStack(self: *Self) u8 {
        const actualAddress: u16 = 0x0100 + @as(u16, self.s);
        const value = self.bus.read(actualAddress + 1);
        self.s += 1;
        return value;
    }

    pub fn reset(self: *Self) void {
        self.pc = Cpu.readAddress(self.bus, Cpu.resetAddress);
        self.s = 0xff;
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

        std.log.debug("\x1b[31m ------ {x:04} Executing instruction {s} in {s} mode \x1b[0m", .{ self.pc, @tagName(instruction.opcode), @tagName(instruction.mode) });

        switch (instruction.opcode) {
            O.JSR => {
                // where to go
                const adl: u16 = self.bus.read(self.pc + 1);
                const adh: u16 = self.bus.read(self.pc + 2);
                const jumpTo: u16 = adl + 256 * adh;
                self.pc += 2;
                // where to come back to
                const pcl: u8 = self.bus.read(self.pc);
                const pch: u8 = self.bus.read(self.pc + 1);
                const comeBackTo: u16 = @as(u16, pcl) + 256 * @as(u16, pcl);
                self.pushOntoStack(pch);
                self.pushOntoStack(pcl);
                std.log.debug("Caching address {x:04} on the stack", .{comeBackTo});
                std.log.debug("Jumping to {x:04}", .{jumpTo});
                self.pc = jumpTo;
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
            O.LDY => {
                self.ldy(instruction.mode);
            },
            O.LDX => {
                self.ldx(instruction.mode);
            },
            O.STA => {
                self.sta(instruction.mode);
            },
            O.STY => {
                self.sty(instruction.mode);
            },
            O.STX => {
                self.stx(instruction.mode);
            },
            O.TAX => {
                std.log.debug("Writing {x:02} from A to X", .{self.a});
                self.x = self.a;
                self.updateStatusOnArithmetic(self.x);
            },
            O.TAY => {
                std.log.debug("Writing {x:02} from A to Y", .{self.a});
                self.y = self.a;
                self.updateStatusOnArithmetic(self.y);
            },
            O.TSX => {
                std.log.debug("Writing {x:02} from S to X", .{self.s});
                self.x = self.s;
                self.updateStatusOnArithmetic(self.x);
            },
            O.TXA => {
                std.log.debug("Writing {x:02} from X to A", .{self.x});
                self.a = self.x;
                self.updateStatusOnArithmetic(self.a);
            },
            O.TXS => {
                std.log.debug("Writing {x:02} from X to S", .{self.x});
                self.s = self.x;
            },
            O.TYA => {
                std.log.debug("Writing {x:02} from Y to A", .{self.y});
                self.a = self.y;
                self.updateStatusOnArithmetic(self.a);
            },
            O.INX => {
                self.x +%= 1;
                std.log.debug("Writing {x:02} in X", .{self.x});
                self.updateStatusOnArithmetic(self.x);
            },
            O.INY => {
                self.y +%= 1;
                std.log.debug("Writing {x:02} in Y", .{self.y});
                self.updateStatusOnArithmetic(self.y);
            },
            O.DEX => {
                self.x -%= 1;
                std.log.debug("Writing {x:02} in X", .{self.x});
                self.updateStatusOnArithmetic(self.x);
            },
            O.DEY => {
                self.y -%= 1;
                std.log.debug("Writing {x:02} in Y", .{self.y});
                self.updateStatusOnArithmetic(self.y);
            },
            O.XXX => {
                std.log.debug("Ignoring opcode {x:02}", .{data});
            },
            O.BNE => {
                switch (self.p.zero) {
                    false => {
                        const op: u8 = self.bus.read(self.pc + 1);
                        const offset: i8 = @bitCast(op);
                        std.log.debug("Z is cleared, branch by {}", .{offset});
                        if (offset >= 0) {
                            const offset_also: u8 = @intCast(offset);
                            self.pc += offset_also;
                        } else {
                            const offset_also: u8 = @intCast(-offset);
                            self.pc -= offset_also;
                        }
                        std.log.debug("Branching to {x:04}", .{self.pc});
                    },
                    true => {
                        std.log.debug("Z is set, no branch", .{});
                    },
                }
            },
            else => {
                std.log.debug("-- Unmapped instruction: {s} in {s} mode", .{ @tagName(instruction.opcode), @tagName(instruction.mode) });
                @panic("");
            },
        }
        self.pc += instruction.size;
    }

    fn lda(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.a);

        if (addressingMode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            std.log.debug("Writing {x:02} in register A", .{value});
            self.a = value;
            return;
        }

        const address: u16 = self.effectiveAddress(addressingMode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register A from address {x:04}", .{ value, address });
        self.a = value;
    }

    fn ldx(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.x);

        if (addressingMode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            std.log.debug("Writing {x:02} in register X", .{value});
            self.x = value;
            return;
        }

        const address: u16 = self.effectiveAddress(addressingMode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register X from address {x:04}", .{ value, address });
        self.x = value;
    }

    fn ldy(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.y);

        if (addressingMode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            std.log.debug("Writing {x:02} in register Y", .{value});
            self.y = value;
            return;
        }

        const address: u16 = self.effectiveAddress(addressingMode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register Y from address {x:04}", .{ value, address });
        self.y = value;
    }

    fn sta(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const address: u16 = self.effectiveAddress(addressingMode);
        self.bus.write(address, self.a);
    }

    fn stx(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const address: u16 = self.effectiveAddress(addressingMode);
        self.bus.write(address, self.x);
    }

    fn sty(self: *Self, addressingMode: Instruction.AddressingMode) void {
        const address: u16 = self.effectiveAddress(addressingMode);
        self.bus.write(address, self.y);
    }

    fn effectiveAddress(self: *Self, mode: Instruction.AddressingMode) u16 {
        const M = Instruction.AddressingMode;

        switch (mode) {
            M.Absolute, M.Absolute_XIndexed, M.Absolute_YIndexed => {
                const address = Cpu.readAddress(self.bus, self.pc + 1);
                switch (mode) {
                    M.Absolute => return address,
                    M.Absolute_XIndexed => return address + @as(u16, self.x),
                    M.Absolute_YIndexed => return address + @as(u16, self.y),
                    else => unreachable,
                }
            },
            M.ZeroPage, M.ZeroPage_XIndexed, M.ZeroPage_YIndexed => {
                const address: u8 = self.bus.read(self.pc + 1);
                switch (mode) {
                    M.ZeroPage => return address,
                    M.ZeroPage_XIndexed => return address +% self.x,
                    M.ZeroPage_YIndexed => return address +% self.y,
                    else => unreachable,
                }
            },
            M.Indirect => {
                const address = Cpu.readAddress(self.bus, self.pc + 1);
                return Cpu.readAddress(self.bus, address);
            },
            M.XIndexed_Indirect, M.Indirect_XIndexed, M.YIndexed_Indirect, M.Indirect_YIndexed => {
                const operand: u8 = self.bus.read(self.pc + 1);
                const address: u8 = switch (mode) {
                    M.XIndexed_Indirect => operand +% self.x,
                    M.YIndexed_Indirect => operand +% self.x,
                    M.Indirect_XIndexed, M.Indirect_YIndexed => operand,
                    else => unreachable,
                };

                const actualAddress = Cpu.readAddress(self.bus, address);
                switch (mode) {
                    M.XIndexed_Indirect, M.YIndexed_Indirect => return actualAddress,
                    M.Indirect_XIndexed => return actualAddress + self.x,
                    M.Indirect_YIndexed => return actualAddress + self.y,
                    else => unreachable,
                }
            },
            M.Relative, M.Accumulator, M.Immediate, M.Implicit => unreachable, // non-sensical
        }
    }

    fn updateStatusOnArithmetic(self: *Self, register: u8) void {
        defer if (register == 0) {
            self.p.zero = true;
            std.log.debug("Setting zero flag", .{});
        };
        defer if ((register >> 7) != 0) {
            self.p.negative = true;
            std.log.debug("Setting negative flag", .{});
        };
    }

    fn readAddress(bus: *const Bus, address: u16) u16 {
        const lowByte: u16 = bus.read(address);
        const highByte: u16 = bus.read(address + 1);
        return lowByte + 256 * highByte;
    }
};
