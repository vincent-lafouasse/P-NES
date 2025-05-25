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
        const aaa: u3 = byte >> 5;
        const bbb: u3 = (byte >> 2) & 0b111;
        const cc: u2 = byte & 0b11;

        switch (cc) {
            0b00 => unreachable, //todo group 3
            0b01 => Instruction.decode_group1(aaa, bbb),
            0b10 => unreachable, //todo group 2
            0b11 => Instruction.unknown(), // no instructions
        }
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
            0b000 => M.Absolute,
            0b001 => M.Absolute,
            0b010 => M.Absolute,
            0b011 => M.Absolute,
            0b100 => M.Absolute,
            0b101 => M.Absolute,
            0b110 => M.Absolute,
            0b111 => M.Absolute,
        };

        _ = opcode;
        _ = mode;

        unreachable;
    }

    fn unknown() Instruction {
        return .{ .opcode = Opcode.XXX, .size = 1, .duration = .{ .cycles = 1, .penalty = Instruction.Duration.Penalty.None } };
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

    cycles: u8,
    penalty: Penalty,
};
