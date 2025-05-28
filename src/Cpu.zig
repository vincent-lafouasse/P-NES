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

    logFile: std.fs.File,

    const Self = @This();
    const resetAddress: u16 = 0xfffc;

    pub fn init(bus: *Bus, name: []const u8) !Self {
        const bufferSize = 100;
        var buffer: [bufferSize]u8 = undefined;
        const maybe_truncated_name = name[0..@min(name.len, bufferSize - 4)];
        const path = std.fmt.bufPrint(&buffer, "{s}.log", .{maybe_truncated_name}) catch unreachable;

        std.fs.cwd().makeDir("artefacts") catch |err| {
            switch (err) {
                std.posix.MakeDirError.PathAlreadyExists => {},
                else => return err,
            }
        };
        const outdir = try std.fs.cwd().openDir("artefacts", .{});
        const outfile = try outdir.createFile(path, .{});

        return Self{
            .bus = bus,
            .pc = Cpu.readAddress(bus, Cpu.resetAddress),
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .s = 0xff,
            .p = std.mem.zeroes(CpuStatus),
            .cycles = 7,
            .logFile = outfile,
        };
    }

    pub fn deinit(self: *Self) void {
        self.logFile.close();
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
        self.pc = 0xC000;
        while (true) {
            self.execute();
        }
    }

    fn execute(self: *Self) void {
        const data: u8 = self.bus.read(self.pc);
        const instruction = Instruction.decode(data);
        const O = Instruction.Opcode;

        std.log.debug("\x1b[31m ------ {x:04} Executing instruction {s} in {s} mode \x1b[0m", .{ self.pc, @tagName(instruction.opcode), @tagName(instruction.mode) });

        const nCyclesStart = self.cycles;
        defer self.log(" CYC:{d}\n", .{nCyclesStart});

        self.log("{X:04}  ", .{self.pc});
        switch (instruction.size) {
            1 => self.log("{X:02} {s:2} {s:2}  ", .{ data, "", "" }),
            2 => self.log("{X:02} {X:02} {s:2}  ", .{ data, self.bus.read(self.pc + 1), "" }),
            3 => self.log("{X:02} {X:02} {X:02}  ", .{ data, self.bus.read(self.pc + 1), self.bus.read(self.pc + 2) }),
            else => unreachable,
        }

        var buffer: [100]u8 = undefined;
        const cpuState = std.fmt.bufPrint(&buffer, "A:{X:02} X:{X:02} Y:{X:02} P:{X:02} SP:{X:02} PPU:{d:3},{d:3}", .{
            self.a,
            self.x,
            self.y,
            self.p.toByte(),
            self.s,
            0,
            0,
        }) catch unreachable;
        defer self.log("{s}", .{cpuState});

        switch (instruction.opcode) {
            O.JMP => self.jmp(instruction),
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
                defer self.pc += instruction.size;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
                self.p.carry = false;
            },
            O.CLD => {
                defer self.pc += instruction.size;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
                self.p.decimalMode = false;
            },
            O.CLI => {
                defer self.pc += instruction.size;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
                self.p.interruptDisable = false;
            },
            O.CLV => {
                defer self.pc += instruction.size;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
                self.p.overflowFlag = false;
            },
            O.SEC => {
                defer self.pc += instruction.size;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
                self.p.carry = true;
            },
            O.SED => {
                defer self.pc += instruction.size;
                self.p.decimalMode = true;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
            },
            O.SEI => {
                defer self.pc += instruction.size;
                self.p.interruptDisable = true;
                self.log("{s:<32}", .{@tagName(instruction.opcode)});
            },
            O.LDA => self.lda(instruction),
            O.LDY => self.ldy(instruction),
            O.LDX => self.ldx(instruction),
            O.STA => self.sta(instruction),
            O.STY => self.sty(instruction),
            O.STX => self.stx(instruction),
            O.TAX => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from A to X", .{self.a});
                self.x = self.a;
                self.updateStatusOnArithmetic(self.x);
            },
            O.TAY => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from A to Y", .{self.a});
                self.y = self.a;
                self.updateStatusOnArithmetic(self.y);
            },
            O.TSX => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from S to X", .{self.s});
                self.x = self.s;
                self.updateStatusOnArithmetic(self.x);
            },
            O.TXA => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from X to A", .{self.x});
                self.a = self.x;
                self.updateStatusOnArithmetic(self.a);
            },
            O.TXS => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from X to S", .{self.x});
                self.s = self.x;
            },
            O.TYA => {
                defer self.pc += instruction.size;
                std.log.debug("Writing {x:02} from Y to A", .{self.y});
                self.a = self.y;
                self.updateStatusOnArithmetic(self.a);
            },
            O.INX => {
                defer self.pc += instruction.size;
                self.x +%= 1;
                std.log.debug("Writing {x:02} in X", .{self.x});
                self.updateStatusOnArithmetic(self.x);
            },
            O.INY => {
                defer self.pc += instruction.size;
                self.y +%= 1;
                std.log.debug("Writing {x:02} in Y", .{self.y});
                self.updateStatusOnArithmetic(self.y);
            },
            O.DEX => {
                defer self.pc += instruction.size;
                self.x -%= 1;
                std.log.debug("Writing {x:02} in X", .{self.x});
                self.updateStatusOnArithmetic(self.x);
            },
            O.DEY => {
                defer self.pc += instruction.size;
                self.y -%= 1;
                std.log.debug("Writing {x:02} in Y", .{self.y});
                self.updateStatusOnArithmetic(self.y);
            },
            O.XXX => {
                std.log.debug("Ignoring opcode {x:02}", .{data});
                self.pc += instruction.size;
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
                        self.pc += instruction.size;
                    },
                }
            },
            else => {
                std.log.debug("-- Unmapped instruction: {s} in {s} mode", .{ @tagName(instruction.opcode), @tagName(instruction.mode) });
                @panic("");
            },
        }
    }

    fn lda(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.a);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            self.a = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register A from address {x:04}", .{ value, address });
        self.a = value;
    }

    fn ldx(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.x);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            self.x = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register X from address {x:04}", .{ value, address });
        self.x = value;
    }

    fn jmp(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        const operand = Cpu.readAddress(self.bus, self.pc + 1);

        switch (i.mode) {
            M.Absolute => self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), operand, "" }),
            M.Indirect => self.log("{s} (${X:04}){s:21}", .{ @tagName(i.opcode), operand, "" }),
            else => unreachable,
        }

        switch (i.mode) {
            M.Absolute => {
                self.pc = operand;
                self.cycles += 3;
            },
            M.Indirect => {
                self.pc = Cpu.readAddress(self.bus, operand);
                self.cycles += 5;
            },
            else => unreachable,
        }
    }

    fn ldy(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.y);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.bus.read(self.pc + 1);
            self.y = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.bus.read(address);
        std.log.debug("Writing {x:02} in register Y from address {x:04}", .{ value, address });
        self.y = value;
    }

    fn sta(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        self.bus.write(address, self.a);
    }

    fn stx(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        self.bus.write(address, self.x);
    }

    fn sty(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
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

    pub fn log(self: Self, comptime format: []const u8, args: anytype) void {
        self.logFile.writer().print(format, args) catch {};
    }
};
