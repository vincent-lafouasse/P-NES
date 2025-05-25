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
            0b00 => Instruction.decode_group3(aaa, bbb),
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
            O.AND => {
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
            O.EOR => {
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
            O.ADC => {
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
            O.STA => {
                switch (mode) {
                    M.ZeroPage => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(3) },
                    M.ZeroPage_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(4) },
                    M.Absolute => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(4) },
                    M.Absolute_XIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(5) },
                    M.Absolute_YIndexed => return .{ .opcode = opcode, .mode = mode, .size = 3, .duration = Duration.exactly(5) },
                    M.XIndexed_Indirect => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Indirect_YIndexed => return .{ .opcode = opcode, .mode = mode, .size = 2, .duration = Duration.exactly(6) },
                    M.Immediate => return Instruction.unknown(),
                    else => unreachable,
                }
            },
            O.LDA => {
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
            O.CMP => {
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
            O.SBC => {
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
                    M.Absolute => return .{ .opcode = O.JMP, .mode = M.Indirect, .size = 3, .duration = Duration.exactly(5) },

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

// ---------- ADC-like instructions

test "ADC Immediate" {
    const opcode: u8 = 0x69;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Zero Page" {
    const opcode: u8 = 0x65;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Zero Page X Indexed" {
    const opcode: u8 = 0x75;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Absolute" {
    const opcode: u8 = 0x6D;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Absolute X Indexed" {
    const opcode: u8 = 0x7D;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Absolute Y Indexed" {
    const opcode: u8 = 0x79;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC X Indexed Indirect" {
    const opcode: u8 = 0x61;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ADC Indirect Y Indexed" {
    const opcode: u8 = 0x71;
    const expected = Instruction{
        .opcode = Opcode.ADC,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Immediate" {
    const opcode: u8 = 0x29;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Zero Page" {
    const opcode: u8 = 0x25;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Zero Page X Indexed" {
    const opcode: u8 = 0x35;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Absolute" {
    const opcode: u8 = 0x2D;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Absolute X Indexed" {
    const opcode: u8 = 0x3D;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Absolute Y Indexed" {
    const opcode: u8 = 0x39;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND X Indexed Indirect" {
    const opcode: u8 = 0x21;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "AND Indirect Y Indexed" {
    const opcode: u8 = 0x31;
    const expected = Instruction{
        .opcode = Opcode.AND,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Immediate" {
    const opcode: u8 = 0xC9;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Zero Page" {
    const opcode: u8 = 0xC5;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Zero Page X Indexed" {
    const opcode: u8 = 0xD5;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Absolute" {
    const opcode: u8 = 0xCD;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Absolute X Indexed" {
    const opcode: u8 = 0xDD;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Absolute Y Indexed" {
    const opcode: u8 = 0xD9;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP X Indexed Indirect" {
    const opcode: u8 = 0xC1;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CMP Indirect Y Indexed" {
    const opcode: u8 = 0xD1;
    const expected = Instruction{
        .opcode = Opcode.CMP,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Immediate" {
    const opcode: u8 = 0x49;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Zero Page" {
    const opcode: u8 = 0x45;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Zero Page X Indexed" {
    const opcode: u8 = 0x55;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Absolute" {
    const opcode: u8 = 0x4D;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Absolute X Indexed" {
    const opcode: u8 = 0x5D;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Absolute Y Indexed" {
    const opcode: u8 = 0x59;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR X Indexed Indirect" {
    const opcode: u8 = 0x41;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "EOR Indirect Y Indexed" {
    const opcode: u8 = 0x51;
    const expected = Instruction{
        .opcode = Opcode.EOR,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Immediate" {
    const opcode: u8 = 0xa9;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Zero Page" {
    const opcode: u8 = 0xa5;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Zero Page X Indexed" {
    const opcode: u8 = 0xb5;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Absolute" {
    const opcode: u8 = 0xaD;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Absolute X Indexed" {
    const opcode: u8 = 0xbD;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Absolute Y Indexed" {
    const opcode: u8 = 0xb9;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA X Indexed Indirect" {
    const opcode: u8 = 0xa1;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDA Indirect Y Indexed" {
    const opcode: u8 = 0xb1;
    const expected = Instruction{
        .opcode = Opcode.LDA,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Immediate" {
    const opcode: u8 = 0x09;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Zero Page" {
    const opcode: u8 = 0x05;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Zero Page X Indexed" {
    const opcode: u8 = 0x15;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Absolute" {
    const opcode: u8 = 0x0D;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Absolute X Indexed" {
    const opcode: u8 = 0x1D;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Absolute Y Indexed" {
    const opcode: u8 = 0x19;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA X Indexed Indirect" {
    const opcode: u8 = 0x01;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ORA Indirect Y Indexed" {
    const opcode: u8 = 0x11;
    const expected = Instruction{
        .opcode = Opcode.ORA,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Immediate" {
    const opcode: u8 = 0xe9;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Zero Page" {
    const opcode: u8 = 0xe5;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Zero Page X Indexed" {
    const opcode: u8 = 0xf5;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Absolute" {
    const opcode: u8 = 0xeD;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Absolute X Indexed" {
    const opcode: u8 = 0xfD;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Absolute Y Indexed" {
    const opcode: u8 = 0xf9;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC X Indexed Indirect" {
    const opcode: u8 = 0xe1;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SBC Indirect Y Indexed" {
    const opcode: u8 = 0xf1;
    const expected = Instruction{
        .opcode = Opcode.SBC,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.pageAware(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- ASL-like instructions

test "ASL Accumulator" {
    const opcode: u8 = 0x0a;
    const expected = Instruction{
        .opcode = Opcode.ASL,
        .mode = AddressingMode.Accumulator,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ASL Zero Page" {
    const opcode: u8 = 0x06;
    const expected = Instruction{
        .opcode = Opcode.ASL,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ASL Zero Page X Indexed" {
    const opcode: u8 = 0x16;
    const expected = Instruction{
        .opcode = Opcode.ASL,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ASL Absolute" {
    const opcode: u8 = 0x0e;
    const expected = Instruction{
        .opcode = Opcode.ASL,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ASL Absolute X Indexed" {
    const opcode: u8 = 0x1e;
    const expected = Instruction{
        .opcode = Opcode.ASL,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LSR Accumulator" {
    const opcode: u8 = 0x4a;
    const expected = Instruction{
        .opcode = Opcode.LSR,
        .mode = AddressingMode.Accumulator,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LSR Zero Page" {
    const opcode: u8 = 0x46;
    const expected = Instruction{
        .opcode = Opcode.LSR,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LSR Zero Page X Indexed" {
    const opcode: u8 = 0x56;
    const expected = Instruction{
        .opcode = Opcode.LSR,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LSR Absolute" {
    const opcode: u8 = 0x4e;
    const expected = Instruction{
        .opcode = Opcode.LSR,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LSR Absolute X Indexed" {
    const opcode: u8 = 0x5e;
    const expected = Instruction{
        .opcode = Opcode.LSR,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROL Accumulator" {
    const opcode: u8 = 0x2a;
    const expected = Instruction{
        .opcode = Opcode.ROL,
        .mode = AddressingMode.Accumulator,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROL Zero Page" {
    const opcode: u8 = 0x26;
    const expected = Instruction{
        .opcode = Opcode.ROL,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROL Zero Page X Indexed" {
    const opcode: u8 = 0x36;
    const expected = Instruction{
        .opcode = Opcode.ROL,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROL Absolute" {
    const opcode: u8 = 0x2e;
    const expected = Instruction{
        .opcode = Opcode.ROL,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROL Absolute X Indexed" {
    const opcode: u8 = 0x3e;
    const expected = Instruction{
        .opcode = Opcode.ROL,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROR Accumulator" {
    const opcode: u8 = 0x6a;
    const expected = Instruction{
        .opcode = Opcode.ROR,
        .mode = AddressingMode.Accumulator,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROR Zero Page" {
    const opcode: u8 = 0x66;
    const expected = Instruction{
        .opcode = Opcode.ROR,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROR Zero Page X Indexed" {
    const opcode: u8 = 0x76;
    const expected = Instruction{
        .opcode = Opcode.ROR,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROR Absolute" {
    const opcode: u8 = 0x6e;
    const expected = Instruction{
        .opcode = Opcode.ROR,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "ROR Absolute X Indexed" {
    const opcode: u8 = 0x7e;
    const expected = Instruction{
        .opcode = Opcode.ROR,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- CPX-like instructions

test "CPX Immediate" {
    const opcode: u8 = 0xe0;
    const expected = Instruction{
        .opcode = Opcode.CPX,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CPX Zero Page" {
    const opcode: u8 = 0xe4;
    const expected = Instruction{
        .opcode = Opcode.CPX,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CPX Absolute" {
    const opcode: u8 = 0xec;
    const expected = Instruction{
        .opcode = Opcode.CPX,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CPY Immediate" {
    const opcode: u8 = 0xc0;
    const expected = Instruction{
        .opcode = Opcode.CPY,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CPY Zero Page" {
    const opcode: u8 = 0xc4;
    const expected = Instruction{
        .opcode = Opcode.CPY,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CPY Absolute" {
    const opcode: u8 = 0xcc;
    const expected = Instruction{
        .opcode = Opcode.CPY,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- Branches

test "BCC" {
    const opcode: u8 = 0x90;
    const expected = Instruction{
        .opcode = Opcode.BCC,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BCS" {
    const opcode: u8 = 0xb0;
    const expected = Instruction{
        .opcode = Opcode.BCS,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BEQ" {
    const opcode: u8 = 0xf0;
    const expected = Instruction{
        .opcode = Opcode.BEQ,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BMI" {
    const opcode: u8 = 0x30;
    const expected = Instruction{
        .opcode = Opcode.BMI,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BNE" {
    const opcode: u8 = 0xd0;
    const expected = Instruction{
        .opcode = Opcode.BNE,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BPL" {
    const opcode: u8 = 0x10;
    const expected = Instruction{
        .opcode = Opcode.BPL,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BVC" {
    const opcode: u8 = 0x50;
    const expected = Instruction{
        .opcode = Opcode.BVC,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BVS" {
    const opcode: u8 = 0x70;
    const expected = Instruction{
        .opcode = Opcode.BVS,
        .mode = AddressingMode.Relative,
        .size = 2,
        .duration = Instruction.Duration.branchAware(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- Status flag operations

test "CLC" {
    const opcode: u8 = 0x18;
    const expected = Instruction{
        .opcode = Opcode.CLC,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CLD" {
    const opcode: u8 = 0xd8;
    const expected = Instruction{
        .opcode = Opcode.CLD,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CLI" {
    const opcode: u8 = 0x58;
    const expected = Instruction{
        .opcode = Opcode.CLI,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "CLV" {
    const opcode: u8 = 0xb8;
    const expected = Instruction{
        .opcode = Opcode.CLV,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SEC" {
    const opcode: u8 = 0x38;
    const expected = Instruction{
        .opcode = Opcode.SEC,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SED" {
    const opcode: u8 = 0xf8;
    const expected = Instruction{
        .opcode = Opcode.SED,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "SEI" {
    const opcode: u8 = 0x78;
    const expected = Instruction{
        .opcode = Opcode.SEI,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- LDX-like instructions

test "LDX Immediate" {
    const opcode: u8 = 0xa2;
    const expected = Instruction{
        .opcode = Opcode.LDX,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDX Zero Page" {
    const opcode: u8 = 0xa6;
    const expected = Instruction{
        .opcode = Opcode.LDX,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDX Zero Page Y Indexed" {
    const opcode: u8 = 0xb6;
    const expected = Instruction{
        .opcode = Opcode.LDX,
        .mode = AddressingMode.ZeroPage_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDX Absolute" {
    const opcode: u8 = 0xae;
    const expected = Instruction{
        .opcode = Opcode.LDX,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDX Absolute Y Indexed" {
    const opcode: u8 = 0xbe;
    const expected = Instruction{
        .opcode = Opcode.LDX,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDY Immediate" {
    const opcode: u8 = 0xa0;
    const expected = Instruction{
        .opcode = Opcode.LDY,
        .mode = AddressingMode.Immediate,
        .size = 2,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDY Zero Page" {
    const opcode: u8 = 0xa4;
    const expected = Instruction{
        .opcode = Opcode.LDY,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDY Zero Page X Indexed" {
    const opcode: u8 = 0xb4;
    const expected = Instruction{
        .opcode = Opcode.LDY,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDY Absolute" {
    const opcode: u8 = 0xac;
    const expected = Instruction{
        .opcode = Opcode.LDY,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "LDY Absolute X Indexed" {
    const opcode: u8 = 0xbc;
    const expected = Instruction{
        .opcode = Opcode.LDY,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.pageAware(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- STX/STY/STA

test "STX Zero Page" {
    const opcode: u8 = 0x86;
    const expected = Instruction{
        .opcode = Opcode.STX,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STX Zero Page Y Indexed" {
    const opcode: u8 = 0x96;
    const expected = Instruction{
        .opcode = Opcode.STX,
        .mode = AddressingMode.ZeroPage_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STX Absolute" {
    const opcode: u8 = 0x8e;
    const expected = Instruction{
        .opcode = Opcode.STX,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STY Zero Page" {
    const opcode: u8 = 0x84;
    const expected = Instruction{
        .opcode = Opcode.STY,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STY Zero Page X Indexed" {
    const opcode: u8 = 0x94;
    const expected = Instruction{
        .opcode = Opcode.STY,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STY Absolute" {
    const opcode: u8 = 0x8c;
    const expected = Instruction{
        .opcode = Opcode.STY,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA ZeroPage" {
    const opcode: u8 = 0x85;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA ZeroPage_XIndexed" {
    const opcode: u8 = 0x95;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA Absolute" {
    const opcode: u8 = 0x8d;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA Absolute_XIndexed" {
    const opcode: u8 = 0x9d;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA Absolute_YIndexed" {
    const opcode: u8 = 0x99;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.Absolute_YIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA X_Indexed Indirect" {
    const opcode: u8 = 0x81;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.XIndexed_Indirect,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "STA Indirect Y Indexed" {
    const opcode: u8 = 0x91;
    const expected = Instruction{
        .opcode = Opcode.STA,
        .mode = AddressingMode.Indirect_YIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- INC/DEC

test "DEC Zero Page" {
    const opcode: u8 = 0xc6;
    const expected = Instruction{
        .opcode = Opcode.DEC,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "DEC Zero Page X Indexed" {
    const opcode: u8 = 0xd6;
    const expected = Instruction{
        .opcode = Opcode.DEC,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "DEC Absolute" {
    const opcode: u8 = 0xce;
    const expected = Instruction{
        .opcode = Opcode.DEC,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "DEC Absolute X Indexed" {
    const opcode: u8 = 0xde;
    const expected = Instruction{
        .opcode = Opcode.DEC,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INC Zero Page" {
    const opcode: u8 = 0xe6;
    const expected = Instruction{
        .opcode = Opcode.INC,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INC Zero Page X Indexed" {
    const opcode: u8 = 0xf6;
    const expected = Instruction{
        .opcode = Opcode.INC,
        .mode = AddressingMode.ZeroPage_XIndexed,
        .size = 2,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INC Absolute" {
    const opcode: u8 = 0xee;
    const expected = Instruction{
        .opcode = Opcode.INC,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INC Absolute X Indexed" {
    const opcode: u8 = 0xfe;
    const expected = Instruction{
        .opcode = Opcode.INC,
        .mode = AddressingMode.Absolute_XIndexed,
        .size = 3,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "DEX" {
    const opcode: u8 = 0xca;
    const expected = Instruction{
        .opcode = Opcode.DEX,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "DEY" {
    const opcode: u8 = 0x88;
    const expected = Instruction{
        .opcode = Opcode.DEY,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INX" {
    const opcode: u8 = 0xe8;
    const expected = Instruction{
        .opcode = Opcode.INX,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "INY" {
    const opcode: u8 = 0xc8;
    const expected = Instruction{
        .opcode = Opcode.INY,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- Stack instructions

test "PHA" {
    const opcode: u8 = 0x48;
    const expected = Instruction{
        .opcode = Opcode.PHA,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "PHP" {
    const opcode: u8 = 0x08;
    const expected = Instruction{
        .opcode = Opcode.PHP,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "PLA" {
    const opcode: u8 = 0x68;
    const expected = Instruction{
        .opcode = Opcode.PLA,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "PLP" {
    const opcode: u8 = 0x28;
    const expected = Instruction{
        .opcode = Opcode.PLP,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// ---------- Register transfers

test "TAX" {
    const opcode: u8 = 0xaa;
    const expected = Instruction{
        .opcode = Opcode.TAX,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "TAY" {
    const opcode: u8 = 0xa8;
    const expected = Instruction{
        .opcode = Opcode.TAY,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "TSX" {
    const opcode: u8 = 0xba;
    const expected = Instruction{
        .opcode = Opcode.TSX,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "TXA" {
    const opcode: u8 = 0x8a;
    const expected = Instruction{
        .opcode = Opcode.TXA,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "TXS" {
    const opcode: u8 = 0x9a;
    const expected = Instruction{
        .opcode = Opcode.TXS,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "TYA" {
    const opcode: u8 = 0x98;
    const expected = Instruction{
        .opcode = Opcode.TYA,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// stuff

test "JSR" {
    const opcode: u8 = 0x20;
    const expected = Instruction{
        .opcode = Opcode.JSR,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BIT ZeroPage" {
    const opcode: u8 = 0x24;
    const expected = Instruction{
        .opcode = Opcode.BIT,
        .mode = AddressingMode.ZeroPage,
        .size = 2,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BIT Absolute" {
    const opcode: u8 = 0x2c;
    const expected = Instruction{
        .opcode = Opcode.BIT,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(4),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "RTI" {
    const opcode: u8 = 0x40;
    const expected = Instruction{
        .opcode = Opcode.RTI,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "RTS" {
    const opcode: u8 = 0x60;
    const expected = Instruction{
        .opcode = Opcode.RTS,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(6),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "JMP Absolute" {
    const opcode: u8 = 0x4c;
    const expected = Instruction{
        .opcode = Opcode.JMP,
        .mode = AddressingMode.Absolute,
        .size = 3,
        .duration = Instruction.Duration.exactly(3),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "JMP Indirect" {
    const opcode: u8 = 0x6c;
    const expected = Instruction{
        .opcode = Opcode.JMP,
        .mode = AddressingMode.Indirect,
        .size = 3,
        .duration = Instruction.Duration.exactly(5),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "NOP" {
    const opcode: u8 = 0xea;
    const expected = Instruction{
        .opcode = Opcode.NOP,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(2),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

test "BRK" {
    const opcode: u8 = 0x00;
    const expected = Instruction{
        .opcode = Opcode.BRK,
        .mode = AddressingMode.Implicit,
        .size = 1,
        .duration = Instruction.Duration.exactly(7),
    };
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(expected, actual);
}

// col 0
test "0x80" {
    const opcode: u8 = 0x80;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col 2
test "0x02" {
    const opcode: u8 = 0x02;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x12" {
    const opcode: u8 = 0x12;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x22" {
    const opcode: u8 = 0x22;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x32" {
    const opcode: u8 = 0x32;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x42" {
    const opcode: u8 = 0x42;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x52" {
    const opcode: u8 = 0x52;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x62" {
    const opcode: u8 = 0x62;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x72" {
    const opcode: u8 = 0x72;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x82" {
    const opcode: u8 = 0x82;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x92" {
    const opcode: u8 = 0x92;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xb2" {
    const opcode: u8 = 0xb2;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xc2" {
    const opcode: u8 = 0xc2;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xd2" {
    const opcode: u8 = 0xd2;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xe2" {
    const opcode: u8 = 0xe2;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xf2" {
    const opcode: u8 = 0xf2;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col 3
test "0x03" {
    const opcode: u8 = 0x03;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x13" {
    const opcode: u8 = 0x13;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x23" {
    const opcode: u8 = 0x23;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x33" {
    const opcode: u8 = 0x33;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x43" {
    const opcode: u8 = 0x43;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x53" {
    const opcode: u8 = 0x53;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x63" {
    const opcode: u8 = 0x63;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x73" {
    const opcode: u8 = 0x73;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x83" {
    const opcode: u8 = 0x83;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x93" {
    const opcode: u8 = 0x93;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xa3" {
    const opcode: u8 = 0xa3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xb3" {
    const opcode: u8 = 0xb3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xc3" {
    const opcode: u8 = 0xc3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xd3" {
    const opcode: u8 = 0xd3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xe3" {
    const opcode: u8 = 0xe3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xf3" {
    const opcode: u8 = 0xf3;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col 4
test "0x04" {
    const opcode: u8 = 0x04;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x14" {
    const opcode: u8 = 0x14;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x34" {
    const opcode: u8 = 0x34;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x44" {
    const opcode: u8 = 0x44;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x54" {
    const opcode: u8 = 0x54;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x64" {
    const opcode: u8 = 0x64;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x74" {
    const opcode: u8 = 0x74;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xd4" {
    const opcode: u8 = 0xd4;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xf4" {
    const opcode: u8 = 0xf4;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col 7
test "0x07" {
    const opcode: u8 = 0x07;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x17" {
    const opcode: u8 = 0x17;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x27" {
    const opcode: u8 = 0x27;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x37" {
    const opcode: u8 = 0x37;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x47" {
    const opcode: u8 = 0x47;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x57" {
    const opcode: u8 = 0x57;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x67" {
    const opcode: u8 = 0x67;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x77" {
    const opcode: u8 = 0x77;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x87" {
    const opcode: u8 = 0x87;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x97" {
    const opcode: u8 = 0x97;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xa7" {
    const opcode: u8 = 0xa7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xb7" {
    const opcode: u8 = 0xb7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xc7" {
    const opcode: u8 = 0xc7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xd7" {
    const opcode: u8 = 0xd7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xe7" {
    const opcode: u8 = 0xe7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xf7" {
    const opcode: u8 = 0xf7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col 9
test "0x89" {
    const opcode: u8 = 0x89;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col a
test "0x1a" {
    const opcode: u8 = 0x1a;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x3a" {
    const opcode: u8 = 0x3a;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x5a" {
    const opcode: u8 = 0x5a;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x7a" {
    const opcode: u8 = 0x7a;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xda" {
    const opcode: u8 = 0xda;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xfa" {
    const opcode: u8 = 0xfa;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col b
test "0x0b" {
    const opcode: u8 = 0x0b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x1b" {
    const opcode: u8 = 0x1b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x2b" {
    const opcode: u8 = 0x2b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x3b" {
    const opcode: u8 = 0x3b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x4b" {
    const opcode: u8 = 0x4b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x5b" {
    const opcode: u8 = 0x5b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x6b" {
    const opcode: u8 = 0x6b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x7b" {
    const opcode: u8 = 0x7b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x8b" {
    const opcode: u8 = 0x8b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x9b" {
    const opcode: u8 = 0x9b;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xab" {
    const opcode: u8 = 0xab;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xbb" {
    const opcode: u8 = 0xbb;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xcb" {
    const opcode: u8 = 0xcb;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xdb" {
    const opcode: u8 = 0xdb;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xeb" {
    const opcode: u8 = 0xeb;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xfb" {
    const opcode: u8 = 0xfb;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col c
test "0x0c" {
    const opcode: u8 = 0x0c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x1c" {
    const opcode: u8 = 0x1c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x3c" {
    const opcode: u8 = 0x3c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x5c" {
    const opcode: u8 = 0x5c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x7c" {
    const opcode: u8 = 0x7c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x9c" {
    const opcode: u8 = 0x9c;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xdc" {
    const opcode: u8 = 0xdc;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xfc" {
    const opcode: u8 = 0xfc;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col e
test "0x9e" {
    const opcode: u8 = 0x9e;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

// col f
test "0x0f" {
    const opcode: u8 = 0x0f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x1f" {
    const opcode: u8 = 0x1f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x2f" {
    const opcode: u8 = 0x2f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x3f" {
    const opcode: u8 = 0x3f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x4f" {
    const opcode: u8 = 0x4f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x5f" {
    const opcode: u8 = 0x5f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x6f" {
    const opcode: u8 = 0x6f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x7f" {
    const opcode: u8 = 0xf7;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x8f" {
    const opcode: u8 = 0x8f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0x9f" {
    const opcode: u8 = 0x9f;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xaf" {
    const opcode: u8 = 0xaf;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xbf" {
    const opcode: u8 = 0xbf;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xcf" {
    const opcode: u8 = 0xcf;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xdf" {
    const opcode: u8 = 0xdf;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xef" {
    const opcode: u8 = 0xef;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}

test "0xff" {
    const opcode: u8 = 0xff;
    const actual = Instruction.decode(opcode);

    try expectInstructionEqual(Instruction.unknown(), actual);
}
