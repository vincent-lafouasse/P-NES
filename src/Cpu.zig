const std = @import("std");
const Bus = @import("Bus.zig").Bus;
const Instruction = @import("Instruction.zig").Instruction;

const CpuStatus = packed struct(u8) {
    carry: bool,
    zero: bool,
    interruptDisable: bool,
    decimalMode: bool, // set
    unused1: bool, // set
    unused2: bool,
    overflowFlag: bool,
    negative: bool,

    pub fn init() CpuStatus {
        return CpuStatus.fromByte(0x04);
    }

    pub fn fromByte(byte: u8) CpuStatus {
        return @bitCast(byte);
    }

    pub fn toByte(self: CpuStatus) u8 {
        var copy = self;
        copy.unused1 = false; // convention for unused flags
        copy.unused2 = true;
        return @bitCast(copy);
    }

    fn log(self: CpuStatus) void {
        std.log.info("--- {any}", .{self});
        std.log.info("--- {b:08}", .{self.toByte()});
        std.log.info("--- {x:02}", .{self.toByte()});
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
    const resetVector: u16 = 0xfffc;

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

        const pc = (Self{
            .bus = bus,
            .pc = undefined,
            .a = undefined,
            .x = undefined,
            .y = undefined,
            .s = undefined,
            .p = undefined,
            .cycles = undefined,
            .logFile = undefined,
        }).resetAddress();

        return Self{
            .bus = bus,
            .pc = pc,
            .a = 0x00,
            .x = 0x00,
            .y = 0x00,
            .s = 0xfd,
            .p = CpuStatus.init(),
            .cycles = 7,
            .logFile = outfile,
        };
    }

    pub fn deinit(self: *Self) void {
        self.logFile.close();
    }

    fn pushOntoStack(self: *Self, value: u8) void {
        const actualAddress: u16 = 0x0100 + @as(u16, self.s);
        self.write(actualAddress, value);
        self.s -= 1;
    }

    fn popFromStack(self: *Self) u8 {
        const actualAddress: u16 = 0x0100 + @as(u16, self.s);
        const value = self.read(actualAddress + 1);
        self.s += 1;
        return value;
    }

    pub fn reset(self: *Self) void {
        self.pc = self.resetAddress();
        self.s = 0xff;
    }

    pub fn start(self: *Self) void {
        //@breakpoint();
        self.pc = 0xC000;
        self.p.log();
        while (true) {
            self.execute();
        }
    }

    fn execute(self: *Self) void {
        self.p.log();

        const data: u8 = self.read(self.pc);
        const instruction = Instruction.decode(data);
        const O = Instruction.Opcode;

        std.log.debug("\x1b[31m ------ {x:04} Executing instruction {s} in {s} mode \x1b[0m", .{ self.pc, @tagName(instruction.opcode), @tagName(instruction.mode) });

        defer self.log("\n", .{});
        self.log("{X:04}  ", .{self.pc});
        switch (instruction.size) {
            1 => self.log("{X:02} {s:2} {s:2}  ", .{ data, "", "" }),
            2 => self.log("{X:02} {X:02} {s:2}  ", .{ data, self.read(self.pc + 1), "" }),
            3 => self.log("{X:02} {X:02} {X:02}  ", .{ data, self.read(self.pc + 1), self.read(self.pc + 2) }),
            else => unreachable,
        }

        var buffer: [100]u8 = undefined;
        const cpuState = std.fmt.bufPrint(&buffer, "A:{X:02} X:{X:02} Y:{X:02} P:{X:02} SP:{X:02}", .{
            self.a,
            self.x,
            self.y,
            self.p.toByte(),
            self.s,
        }) catch unreachable;
        defer self.log("{s}", .{cpuState});

        switch (instruction.opcode) {
            O.JMP => self.jmp(instruction),
            O.JSR => self.jsr(instruction),
            O.RTS => self.rts(instruction),
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
            O.PHP => self.php(instruction),
            O.PLA => self.pla(instruction),
            O.PHA => self.pha(instruction),
            O.PLP => self.plp(instruction),
            O.AND => self.andInstruction(instruction),
            O.ORA => self.ora(instruction),
            O.CMP => self.cmp(instruction),
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
            O.BEQ => self.beq(instruction),
            O.BNE => self.bne(instruction),
            O.BCS => self.bcs(instruction),
            O.BCC => self.bcc(instruction),
            O.BVS => self.bvs(instruction),
            O.BVC => self.bvc(instruction),
            O.BPL => self.bpl(instruction),
            O.BMI => self.bmi(instruction),
            O.BIT => self.bit(instruction),
            O.NOP => self.nop(instruction),
            O.XXX => {
                std.log.debug("Ignoring opcode {x:02}", .{data});
                self.pc += instruction.size;
            },
            else => {
                std.log.debug("-- Unmapped instruction: {s} in {s} mode", .{ @tagName(instruction.opcode), @tagName(instruction.mode) });
                @panic("");
            },
        }
    }

    fn bne(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (!self.p.zero) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn beq(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (self.p.zero) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bmi(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (self.p.negative) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bpl(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (!self.p.negative) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bcs(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (self.p.carry) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bcc(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (!self.p.carry) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bvs(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (self.p.overflowFlag) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn bvc(self: *Self, i: Instruction) void {
        const op: u8 = self.read(self.pc + 1);
        self.pc += i.size;

        const offset: i8 = @bitCast(op);
        const dest: u16 = shiftU16(self.pc, offset);

        if (!self.p.overflowFlag) {
            self.pc = dest;
        }

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), dest, "" });
    }

    fn lda(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.a);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.a = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        std.log.debug("Writing {x:02} in register A from address {x:04}", .{ value, address });
        self.a = value;
    }

    fn ldx(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.x);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.x = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        std.log.debug("Writing {x:02} in register X from address {x:04}", .{ value, address });
        self.x = value;
    }

    fn andInstruction(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.a);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.a &= value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        self.a &= value;
    }

    fn ora(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.a);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.a |= value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        self.a |= value;
    }

    fn cmp(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            if (self.a < value) {
                self.updateStatusOnArithmetic(self.a);
                self.p.zero = false;
                self.p.carry = false;
            } else if (self.a > value) {
                self.updateStatusOnArithmetic(self.a);
                self.p.zero = false;
                self.p.carry = true;
            } else {
                self.p.negative = false;
                self.p.zero = true;
                self.p.carry = true;
            }
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        self.a &= value;
    }

    fn jmp(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        const operand = self.readAddress(self.pc + 1);

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
                self.pc = self.readAddress(operand);
                self.cycles += 5;
            },
            else => unreachable,
        }
    }

    fn jsr(self: *Self, i: Instruction) void {
        // where to go
        const adl: u16 = self.read(self.pc + 1);
        const adh: u16 = self.read(self.pc + 2);
        const jumpTo: u16 = adl + 256 * adh;

        self.pc += 2;
        // where to come back to
        const pcl: u8 = @intCast(self.pc & 0xff);
        const pch: u8 = @intCast(self.pc >> 8);
        // const comeBackTo: u16 = @as(u16, pcl) + 256 * @as(u16, pcl);

        self.pushOntoStack(pch);
        self.pushOntoStack(pcl);

        self.log("{s} ${X:04}{s:23}", .{ @tagName(i.opcode), jumpTo, "" });

        self.pc = jumpTo;
    }

    fn rts(self: *Self, i: Instruction) void {
        const pcl: u16 = self.popFromStack();
        const pch: u16 = self.popFromStack();
        self.pc = 1 + pcl + 256 * pch;
        self.log("{s:<32}", .{@tagName(i.opcode)});
    }

    fn pha(self: *Self, i: Instruction) void {
        self.pushOntoStack(self.a);
        self.log("{s:<32}", .{@tagName(i.opcode)});
        self.pc += i.size;
    }

    fn php(self: *Self, i: Instruction) void {
        const status: u8 = self.p.toByte() | 0x10;
        self.pushOntoStack(status);
        self.log("{s:<32}", .{@tagName(i.opcode)});
        self.pc += i.size;
    }

    fn pla(self: *Self, i: Instruction) void {
        const newAccumulator: u8 = self.popFromStack();
        self.a = newAccumulator;
        self.updateStatusOnArithmetic(self.a);
        self.log("{s:<32}", .{@tagName(i.opcode)});
        self.pc += i.size;
    }

    fn plp(self: *Self, i: Instruction) void {
        const newStatus: u8 = self.popFromStack();
        self.p = CpuStatus.fromByte(newStatus);
        self.p.unused1 = false;
        self.log("{s:<32}", .{@tagName(i.opcode)});
        self.pc += i.size;
    }

    fn ldy(self: *Self, i: Instruction) void {
        const M = Instruction.AddressingMode;

        defer self.updateStatusOnArithmetic(self.y);
        defer self.pc += i.size;

        if (i.mode == M.Immediate) {
            const value: u8 = self.read(self.pc + 1);
            self.y = value;
            self.log("{s} #${X:02}{s:24}", .{ @tagName(i.opcode), value, "" });
            return;
        }

        const address: u16 = self.effectiveAddress(i.mode);
        const value: u8 = self.read(address);
        std.log.debug("Writing {x:02} in register Y from address {x:04}", .{ value, address });
        self.y = value;
    }

    fn sta(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        const overwrittenValue: u8 = self.read(address);
        self.write(address, self.a);

        if (i.size == 2) {
            self.log("{s} ${X:02} = {X:02}{s:20}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        } else {
            self.log("{s} ${X:04} = {X:02}{s:18}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        }
    }

    fn stx(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        const overwrittenValue: u8 = self.read(address);
        self.write(address, self.x);

        if (i.size == 2) {
            self.log("{s} ${X:02} = {X:02}{s:20}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        } else {
            self.log("{s} ${X:04} = {X:02}{s:18}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        }

        if (i.mode == Instruction.AddressingMode.ZeroPage) {
            self.cycles += 3;
        } else {
            self.cycles += 4;
        }
    }

    fn sty(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        const overwrittenValue: u8 = self.read(address);
        self.write(address, self.y);

        if (i.size == 2) {
            self.log("{s} ${X:02} = {X:02}{s:20}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        } else {
            self.log("{s} ${X:04} = {X:02}{s:18}", .{ @tagName(i.opcode), address, overwrittenValue, "" });
        }

        if (i.mode == Instruction.AddressingMode.ZeroPage) {
            self.cycles += 3;
        } else {
            self.cycles += 4;
        }
    }

    fn bit(self: *Self, i: Instruction) void {
        defer self.pc += i.size;
        const address: u16 = self.effectiveAddress(i.mode);
        const valueThere: u8 = self.read(address);
        self.updateStatusOnArithmetic(valueThere | self.a);
        self.p.overflowFlag = (valueThere & 0b01000000) != 0;

        if (i.size == 2) {
            self.log("{s} ${X:02} = {X:02}{s:20}", .{ @tagName(i.opcode), address, valueThere, "" });
        } else {
            self.log("{s} ${X:04} = {X:02}{s:18}", .{ @tagName(i.opcode), address, valueThere, "" });
        }
    }

    fn nop(self: *Self, i: Instruction) void {
        self.pc += 1;
        self.log("{s:<32}", .{@tagName(i.opcode)});
    }

    fn effectiveAddress(self: *Self, mode: Instruction.AddressingMode) u16 {
        const M = Instruction.AddressingMode;

        switch (mode) {
            M.Absolute, M.Absolute_XIndexed, M.Absolute_YIndexed => {
                const address = self.readAddress(self.pc + 1);
                switch (mode) {
                    M.Absolute => return address,
                    M.Absolute_XIndexed => return address + @as(u16, self.x),
                    M.Absolute_YIndexed => return address + @as(u16, self.y),
                    else => unreachable,
                }
            },
            M.ZeroPage, M.ZeroPage_XIndexed, M.ZeroPage_YIndexed => {
                const address: u8 = self.read(self.pc + 1);
                switch (mode) {
                    M.ZeroPage => return address,
                    M.ZeroPage_XIndexed => return address +% self.x,
                    M.ZeroPage_YIndexed => return address +% self.y,
                    else => unreachable,
                }
            },
            M.Indirect => {
                const address = self.readAddress(self.pc + 1);
                return self.readAddress(address);
            },
            M.XIndexed_Indirect, M.Indirect_XIndexed, M.YIndexed_Indirect, M.Indirect_YIndexed => {
                const operand: u8 = self.read(self.pc + 1);
                const address: u8 = switch (mode) {
                    M.XIndexed_Indirect => operand +% self.x,
                    M.YIndexed_Indirect => operand +% self.x,
                    M.Indirect_XIndexed, M.Indirect_YIndexed => operand,
                    else => unreachable,
                };

                const actualAddress = self.readAddress(address);
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

    fn read(self: *const Self, address: u16) u8 {
        return self.bus.read(address);
    }

    fn write(self: *const Self, address: u16, value: u8) void {
        self.bus.write(address, value);
    }

    fn updateStatusOnArithmetic(self: *Self, register: u8) void {
        self.p.zero = register == 0;
        self.p.negative = (register >> 7) != 0;
    }

    fn readAddress(self: *const Self, address: u16) u16 {
        const lowByte: u16 = self.read(address);
        const highByte: u16 = self.read(address + 1);
        return lowByte + 256 * highByte;
    }

    fn shiftProgramCounter(self: *Self, offset: i8) void {
        if (offset >= 0) {
            const offset_also: u8 = @intCast(offset);
            self.pc += offset_also;
        } else {
            const offset_also: u8 = @intCast(-offset);
            self.pc -= offset_also;
        }
    }

    pub fn log(self: Self, comptime format: []const u8, args: anytype) void {
        self.logFile.writer().print(format, args) catch {};
    }

    fn resetAddress(self: Self) u16 {
        return self.readAddress(Cpu.resetVector);
    }
};

fn shiftU16(pc: u16, offset: i8) u16 {
    if (offset >= 0) {
        const offset_also: u8 = @intCast(offset);
        return pc + offset_also;
    } else {
        const offset_also: u8 = @intCast(-offset);
        return pc - offset_also;
    }
}
