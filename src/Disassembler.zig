const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;

const DisassemblyError = error{
    UnsupportedMapper,
    NoPrgDataSomehow,
};

// should keep track of jumps and branches
pub const Disassembler = struct {
    lowBank: []const u8,
    highBank: []const u8,
    head: u16,

    const Self = @This();

    pub fn init(cart: Cartridge) DisassemblyError!Self {
        if (cart.mapper != 0) {
            return DisassemblyError.UnsupportedMapper;
        }

        if (cart.nPrgBanks == 0) {
            return DisassemblyError.NoPrgDataSomehow;
        }

        const bankSize = Cartridge.prgBankSize;
        const lowBank = cart.prg.items[0..bankSize];
        const highBank = switch (cart.nPrgBanks) {
            1 => lowBank,
            else => cart.prg.items[bankSize .. 2 * bankSize],
        };

        const out = Self{
            .lowBank = lowBank,
            .highBank = highBank,
            .head = undefined,
        };

        const lowByte: u16 = out.at(0xFFFC);
        const highByte: u16 = out.at(0xFFFD);
        const head: u16 = lowByte | highByte << 8;

        std.log.info("Disassembler head: {x}", .{head});

        return Self{
            .lowBank = lowBank,
            .highBank = highBank,
            .head = head,
        };
    }

    pub fn disassemble(self: *Self) !void {
        const stdout = std.io.getStdOut().writer();

        const n = 9;
        for (0..n) |_| {
            const instruction = Instruction.decode(self.at(self.head));
            const sz = instruction.size;

            const op1: ?u8 = if (sz >= 2) self.at(self.head + 1) else null;
            const op2: ?u8 = if (sz == 3) self.at(self.head + 1) else null;

            try stdout.print("{x:04}\t", .{self.head});
            try stdout.print("{x:02} ", .{self.at(self.head)});
            switch (sz) {
                1 => try stdout.print("      ", .{}),
                2 => try stdout.print("{x:02}    ", .{op1.?}),
                3 => try stdout.print("{x:02} {x:02} ", .{ op1.?, op2.? }),
                else => unreachable,
            }
            try stdout.print("\t", .{});
            try instruction.write(stdout, op1, op2);
            try stdout.print("\n", .{});

            self.head += instruction.size;
        }
    }

    fn map(address: u16) u16 {
        return (address - 0x8000);
    }

    fn at(self: Self, address: u16) u8 {
        if (address < 0x8000) {
            unreachable;
        } else if (address < 0xC000) {
            return self.lowBank[address - 0x8000];
        } else {
            return self.highBank[address - 0xC000];
        }
    }
};

const Instruction = struct {
    const Duration = InstructionDuration;

    opcode: Opcode,
    mode: AddressingMode,
    size: u8,
    duration: Duration,

    const Self = @This();

    fn decode(byte: u8) Self {
        if (Instruction.decode_special_cases(byte)) |instruction| {
            return instruction;
        }

        const aaa: u3 = @intCast(byte >> 5);
        const bbb: u3 = @intCast((byte >> 2) & 0b111);
        const cc: u2 = @intCast(byte & 0b11);

        return switch (cc) {
            0b00 => unreachable, //todo group 3
            0b01 => Instruction.decode_group1(aaa, bbb),
            0b10 => Instruction.decode_group2(aaa, bbb),
            0b11 => Instruction.unknown(), // no instructions
        };
    }

    fn decode_group1(aaa: u3, bbb: u3) Instruction {
        const O = Opcode;
        const M = AddressingMode;

        const opcode = switch (aaa) {
            0b000 => O.ORA,
            0b001 => O.AND,
            0b010 => O.EOR,
            0b011 => O.ADC,
            0b100 => O.STA,
            0b101 => O.LDA,
            0b110 => O.CMP,
            0b111 => O.SBC,
        };

        const mode = switch (bbb) {
            0b000 => M.XIndexed_Indirect,
            0b001 => M.ZeroPage,
            0b010 => M.Immediate,
            0b011 => M.Absolute,
            0b100 => M.Indirect_YIndexed,
            0b101 => M.ZeroPage_XIndexed,
            0b110 => M.Absolute_YIndexed,
            0b111 => M.Absolute_XIndexed,
        };

        _ = switch (opcode) {
            O.ORA => {
                switch (mode) {
                    M.Immediate => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.pageAware(4) },
                    M.Absolute_YIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.pageAware(4) },
                    M.XIndexed_Indirect => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Indirect_YIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.pageAware(5) },
                    else => unreachable,
                }
            },
            O.AND => {},
            O.EOR => {},
            O.ADC => {},
            O.STA => {},
            O.LDA => {},
            O.CMP => {},
            O.SBC => {},
            else => unreachable,
        };

        unreachable;
    }

    fn decode_group2(aaa: u3, bbb: u3) Instruction {
        const O = Opcode;
        const M = AddressingMode;

        const opcode = switch (aaa) {
            0b000 => O.ASL,
            0b001 => O.ROL,
            0b010 => O.LSR,
            0b011 => O.ROR,
            0b100 => O.STX,
            0b101 => O.LDX,
            0b110 => O.DEC,
            0b111 => O.INC,
        };

        const mode = switch (bbb) {
            0b000 => M.Immediate,
            0b001 => M.ZeroPage,
            0b010 => M.Accumulator,
            0b011 => M.Absolute,
            0b100 => return Instruction.unknown(),
            0b101 => M.ZeroPage_XIndexed,
            0b110 => return Instruction.unknown(),
            0b111 => M.Absolute_XIndexed,
        };

        switch (opcode) {
            O.ASL => {
                switch (mode) {
                    M.Accumulator => return .{ .opcode = opcode, .mode = mode, .size = 1, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.ROL => {
                switch (mode) {
                    M.Accumulator => return .{ .opcode = opcode, .mode = mode, .size = 1, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.LSR => {
                switch (mode) {
                    M.Accumulator => return .{ .opcode = opcode, .mode = mode, .size = 1, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.ROR => {
                switch (mode) {
                    M.Accumulator => return .{ .opcode = opcode, .mode = mode, .size = 1, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.LDX => {
                switch (mode) {
                    M.Immediate => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = M.ZeroPage_YIndexed, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = M.Absolute_YIndexed, .size = 3, .duration = Duration.pageAware(4) },
                    M.Accumulator => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.STX => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = M.ZeroPage_YIndexed, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },

                    M.Immediate, M.Absolute_XIndexed, M.Accumulator => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.DEC => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate, M.Accumulator => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.INC => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(5) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(6) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(7) },
                    M.Immediate, M.Accumulator => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            else => unreachable,
        }
        unreachable;
    }

    fn decode_group3(aaa: u3, bbb: u3) Instruction {
        const O = Opcode;
        const M = AddressingMode;

        const opcode = switch (aaa) {
            0b000 => return Instruction.unknown(),
            0b001 => O.BIT,
            0b010 => O.JMP,
            0b011 => O.JMP_Indirect,
            0b100 => O.STY,
            0b101 => O.LDY,
            0b110 => O.CPY,
            0b111 => O.CPX,
        };

        const mode = switch (bbb) {
            0b000 => M.Immediate,
            0b001 => M.ZeroPage,
            0b010 => return Instruction.unknown(),
            0b011 => M.Absolute,
            0b100 => return Instruction.unknown(),
            0b101 => M.ZeroPage_XIndexed,
            0b110 => return Instruction.unknown(),
            0b111 => M.Absolute_XIndexed,
        };

        switch (opcode) {
            O.LDY => {
                switch (mode) {
                    M.Immediate => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.pageAware(4) },
                    else => unreachable,
                }
            },
            O.STY => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },

                    M.Immediate, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.CPY => {
                switch (mode) {
                    M.Immediate => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },

                    M.ZeroPage_XIndexed, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.CPX => {
                switch (mode) {
                    M.Immediate => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(2) },
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },

                    M.ZeroPage_XIndexed, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.BIT => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },

                    M.Immediate, M.ZeroPage_XIndexed, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.JMP => {
                switch (mode) {
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(3) },

                    M.Immediate, M.ZeroPage, M.ZeroPage_XIndexed, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.JMP_Indirect => {
                switch (mode) {
                    M.Absolute => return .{ .opcode = opcode, .mode = M.Indirect, .size = 3, .duration = Duration.exactly(5) },

                    M.Immediate, M.ZeroPage, M.ZeroPage_XIndexed, M.Absolute_XIndexed => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            else => unreachable,
        }
        unreachable;
    }

    fn decode_special_cases(opcode: u8) ?Instruction {
        const O = Opcode;
        const M = AddressingMode;

        switch (opcode) {
            0x10 => return .{ .opcode = O.BPL, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0x30 => return .{ .opcode = O.BMI, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0x50 => return .{ .opcode = O.BVC, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0x70 => return .{ .opcode = O.BVS, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0x90 => return .{ .opcode = O.BCC, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0xB0 => return .{ .opcode = O.BCS, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0xD0 => return .{ .opcode = O.BNE, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },
            0xF0 => return .{ .opcode = O.BEQ, .mode = M.Relative, .size = 2, .duration = Duration.branchAware(2) },

            0x00 => return .{ .opcode = O.BRK, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(7) },
            0x20 => return .{ .opcode = O.JSR, .mode = M.Absolute, .size = 3, .duration = Duration.exactly(6) },
            0x40 => return .{ .opcode = O.RTI, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(6) },
            0x60 => return .{ .opcode = O.RTS, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(6) },

            0x48 => return .{ .opcode = O.PHA, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(3) },
            0x08 => return .{ .opcode = O.PHP, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(3) },
            0x68 => return .{ .opcode = O.PLA, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(4) },
            0x28 => return .{ .opcode = O.PLP, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(4) },

            0xCA => return .{ .opcode = O.DEX, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x88 => return .{ .opcode = O.DEY, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xE8 => return .{ .opcode = O.INX, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xC8 => return .{ .opcode = O.INY, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },

            0xAA => return .{ .opcode = O.TAX, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xA8 => return .{ .opcode = O.TAY, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xBA => return .{ .opcode = O.TSX, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x8A => return .{ .opcode = O.TXA, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x9A => return .{ .opcode = O.TXS, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x98 => return .{ .opcode = O.TYA, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },

            0x18 => return .{ .opcode = O.CLC, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xD8 => return .{ .opcode = O.CLD, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x58 => return .{ .opcode = O.CLI, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xB8 => return .{ .opcode = O.CLV, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x38 => return .{ .opcode = O.SEC, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0xF8 => return .{ .opcode = O.SED, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },
            0x78 => return .{ .opcode = O.SEI, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },

            0xEA => return .{ .opcode = O.NOP, .mode = M.Implicit, .size = 1, .duration = Duration.exactly(2) },

            else => return null,
        }
    }

    fn unknown() Instruction {
        return .{ .opcode = Opcode.XXX, .mode = AddressingMode.Implicit, .size = 1, .duration = Duration.exactly(1) };
    }

    fn write(self: Self, writer: anytype, op1: ?u8, op2: ?u8) !void {
        const name = @tagName(self.opcode);
        const M = AddressingMode;

        try writer.print("{s} ", .{name});

        switch (self.mode) {
            M.Accumulator, M.Implicit => {},
            M.Absolute => try writer.print("${x:02}{x:02}", .{ op2.?, op1.? }),
            M.Absolute_XIndexed => try writer.print("${x:02}{x:02},X", .{ op2.?, op1.? }),
            M.Absolute_YIndexed => try writer.print("${x:02}{x:02},Y", .{ op2.?, op1.? }),
            M.Immediate => try writer.print("#${x:02}", .{op1.?}),
            M.Indirect => try writer.print("(${x:02}{x:02})", .{ op2.?, op1.? }),
            M.XIndexed_Indirect => try writer.print("(${x:02},X)", .{op1.?}),
            M.YIndexed_Indirect => try writer.print("(${x:02},Y)", .{op1.?}),
            M.Indirect_XIndexed => try writer.print("(${x:02}),X", .{op1.?}),
            M.Indirect_YIndexed => try writer.print("(${x:02}),Y", .{op1.?}),
            M.Relative, M.ZeroPage => try writer.print("${x:02}", .{op1.?}),
            M.ZeroPage_XIndexed => try writer.print("${x:02},X", .{op1.?}),
            M.ZeroPage_YIndexed => try writer.print("${x:02},Y", .{op1.?}),
        }
    }
};

const Opcode = enum {
    // Load/Stores
    LDA,
    LDX,
    LDY,
    STA,
    STX,
    STY,
    // Register transfers
    TAX,
    TAY,
    TXA,
    TYA,
    // Stack operations
    TSX,
    TXS,
    PHA,
    PHP,
    PLA,
    PLP,
    // Logical
    AND,
    EOR,
    ORA,
    BIT,
    // Arithmetic
    ADC,
    SBC,
    CMP,
    CPX,
    CPY,
    // Increments/Decrements
    INC,
    INX,
    INY,
    DEC,
    DEX,
    DEY,
    // Shifts
    ASL,
    LSR,
    ROL,
    ROR,
    // Jumps/Calls
    JMP,
    JMP_Indirect, // here for parsing purposes
    JSR,
    RTS,
    // Branches
    BCC,
    BCS,
    BEQ,
    BNE,
    BVC,
    BVS,
    BMI,
    BPL,
    // Status register
    CLC,
    CLD,
    CLI,
    CLV,
    SEC,
    SED,
    SEI,
    // System
    BRK,
    NOP,
    RTI,
    // garbage
    XXX,
};

const AddressingMode = enum {
    Implicit,
    Accumulator,
    Immediate,
    ZeroPage,
    ZeroPage_XIndexed,
    ZeroPage_YIndexed,
    Relative,
    Absolute,
    Absolute_XIndexed,
    Absolute_YIndexed,
    Indirect, // (b1 b2)
    XIndexed_Indirect, // (op,X)
    Indirect_XIndexed, // (op),X
    YIndexed_Indirect, // (op,X)
    Indirect_YIndexed, // (op),X
};

const InstructionDuration = struct {
    const Penalty = enum {
        None,
        OnPageCrossing,
        OnBranch,
    };

    fn exactly(cycles: u8) InstructionDuration {
        return InstructionDuration{ .cycles = cycles, .penalty = Penalty.None };
    }

    fn pageAware(cycles: u8) InstructionDuration {
        return InstructionDuration{ .cycles = cycles, .penalty = Penalty.OnPageCrossing };
    }

    fn branchAware(cycles: u8) InstructionDuration {
        return InstructionDuration{ .cycles = cycles, .penalty = Penalty.OnBranch };
    }

    cycles: u8,
    penalty: Penalty,
};

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn expectInstructionEqual(expected: Instruction, actual: Instruction) !void {
    try expectEqual(expected.opcode, actual.opcode);
    try expectEqual(expected.mode, actual.mode);
    try expectEqual(expected.size, actual.size);
    try expectEqual(expected.duration, actual.duration);
}

test "BRK" {
    const opcode: u8 = 0x00;
    const brk = Instruction.decode(opcode);
    const expected = Instruction{
        .opcode = Opcode.BRK,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(7),
    };

    try expectInstructionEqual(expected, brk);
}
