const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Instruction = @import("Instruction.zig").Instruction;
const Allocator = std.mem.Allocator;

const DisassemblyError = error{
    UnsupportedMapper,
    NoPrgDataSomehow,
};

// should keep track of jumps and branches
pub const Disassembler = struct {
    lowBank: []const u8,
    highBank: []const u8,
    head: u16,
    cartridge: Cartridge,
    linesEncountered: std.AutoHashMap(u16, void),
    jumpEncountered: std.AutoHashMap(u16, void),

    const Self = @This();

    pub fn init(cart: Cartridge, allocator: Allocator) DisassemblyError!Self {
        if (cart.mapper != 0) {
            return DisassemblyError.UnsupportedMapper;
        }

        if (cart.nPrgBanks == 0) {
            return DisassemblyError.NoPrgDataSomehow;
        }

        const linesEncountered = std.AutoHashMap(u16, void).init(allocator);
        const jumpEncountered = std.AutoHashMap(u16, void).init(allocator);

        const bankSize = Cartridge.prgBankSize;
        const lowBank = cart.prg.items[0..bankSize];
        const highBank = switch (cart.nPrgBanks) {
            1 => lowBank,
            else => cart.prg.items[bankSize .. 2 * bankSize],
        };

        const out = Self{
            .lowBank = lowBank,
            .highBank = highBank,
            .cartridge = undefined,
            .head = undefined,
            .linesEncountered = undefined,
            .jumpEncountered = undefined,
        };

        const lowByte: u16 = out.at(0xFFFC);
        const highByte: u16 = out.at(0xFFFD);
        const head: u16 = lowByte | highByte << 8;

        std.log.info("Disassembler head: {x}", .{head});

        return Self{
            .lowBank = lowBank,
            .highBank = highBank,
            .head = head,
            .cartridge = cart,
            .linesEncountered = linesEncountered,
            .jumpEncountered = jumpEncountered,
        };
    }

    pub fn deinit(self: *Self) void {
        self.linesEncountered.deinit();
        self.jumpEncountered.deinit();
    }

    pub fn disassemble(self: *Self) !void {
        const bufferSize = 100;
        var buffer: [bufferSize]u8 = [_]u8{0} ** bufferSize;
        const maybe_truncated_name = self.cartridge.name[0..@min(self.cartridge.name.len, bufferSize - 4)];
        const path = std.fmt.bufPrint(&buffer, "{s}.asm", .{maybe_truncated_name}) catch unreachable;

        std.log.info("Writing asm to {s}", .{path});

        const outfile = try std.fs.cwd().createFile(path, .{});
        defer outfile.close();
        const writer = outfile.writer();

        while (true) {
            const instruction = Instruction.decode(self.at(self.head));
            const sz = instruction.size;
            try self.linesEncountered.put(self.head, {});

            const op1: ?u8 = if (sz >= 2) self.at(self.head + 1) else null;
            const op2: ?u8 = if (sz == 3) self.at(self.head + 1) else null;

            try writer.print("{x:04}\t", .{self.head});
            try writer.print("{x:02} ", .{self.at(self.head)});
            switch (sz) {
                1 => try writer.print("      ", .{}),
                2 => try writer.print("{x:02}    ", .{op1.?}),
                3 => try writer.print("{x:02} {x:02} ", .{ op1.?, op2.? }),
                else => unreachable,
            }
            try writer.print("\t", .{});
            try instruction.write(writer, op1, op2);
            try writer.print("\n", .{});

            try self.maybeLogJump(instruction, op1, op2);

            self.head += instruction.size;

            if (instruction.opcode == Instruction.Opcode.BRK) {
                break;
            }
        }
    }

    fn maybeLogJump(self: *Self, instruction: Instruction, op1: ?u8, op2: ?u8) !void {
        //const M = Instruction.Mode;
        const O = Instruction.Opcode;

        //const mode = instruction.mode;
        const opcode = instruction.opcode;

        _ = op2;

        if (opcode == O.BCC or opcode == O.BCS) {
            const signed_offset: i8 = @bitCast(op1.?);
            if (signed_offset >= 0) {
                const offset: u16 = @intCast(signed_offset);
                try self.jumpEncountered.put(self.head + offset, {});
            } else {
                const offset: u16 = @intCast(-signed_offset);
                try self.jumpEncountered.put(self.head - offset, {});
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
