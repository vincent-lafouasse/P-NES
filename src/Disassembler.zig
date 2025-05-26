const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Instruction = @import("Instruction.zig").Instruction;

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

        while (true) {
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

            if (instruction.opcode == Instruction.Opcode.BRK) {
                break;
            }
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
