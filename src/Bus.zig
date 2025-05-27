const std = @import("std");
const ByteList = std.ArrayList(u8);
const Allocator = std.mem.Allocator;
const log = std.log.debug;

const inRed = "\x1b[31m";
const inBlue = "\x1b[0;34m";
const inPurple = "\x1b[0;35m";
const resetFormatting = "\x1b[0m";

const Cartridge = @import("Cartridge.zig").Cartridge;

const BusInitError = error{
    AllocationFailure,
    UnsupportedMapper,
    NoPrgDataSomehow,
};

pub const Bus = struct {
    const cpuRamSize = 0x800; // $0000-$$0800, mirrored up to $2000
    cpuRam: [Bus.cpuRamSize]u8,

    ppuRegisters: [8]u8, // $2000-$2007, mirrored up to $4000
    apuRegisters: [16]u8, // $4000-$4015
    joystick1: u8, // $4016
    joystick2: u8, // $4017
    apuExtension: [8]u8, // $4018-$401f

    unmapped: [0xbfe0]u8, // $4020 up to $6000
    cartridgeRam: [0x2000]u8, // $6000 up to $8000

    lowBank: []const u8, // $8000 up to $c000.
    highBank: []const u8, // $c000 - $ffff

    cartridge: *const Cartridge,

    const Self = @This();

    pub fn init(cartridge: *const Cartridge) BusInitError!Self {
        const cpuRam = std.mem.zeroes([Bus.cpuRamSize]u8);
        const ppuRegisters = std.mem.zeroes([8]u8);
        const apuRegisters = std.mem.zeroes([16]u8);
        const apuExtension = std.mem.zeroes([8]u8);
        const unmapped = std.mem.zeroes([0xbfe0]u8);
        const cartridgeRam = std.mem.zeroes([0x2000]u8);

        var lowBank: []const u8 = undefined;
        var highBank: []const u8 = undefined;
        try Bus.initPrgRom(cartridge, &lowBank, &highBank);

        return Self{
            .cartridge = cartridge,
            .cpuRam = cpuRam,
            .ppuRegisters = ppuRegisters,
            .apuRegisters = apuRegisters,
            .joystick1 = 0x00,
            .joystick2 = 0x00,
            .apuExtension = apuExtension,
            .unmapped = unmapped,
            .cartridgeRam = cartridgeRam,
            .lowBank = lowBank,
            .highBank = highBank,
        };
    }

    fn initPrgRom(cartridge: *const Cartridge, lowBank: *[]const u8, highBank: *[]const u8) BusInitError!void {
        if (cartridge.mapper != 0) {
            return BusInitError.UnsupportedMapper;
        }

        if (cartridge.nPrgBanks == 0) {
            return BusInitError.NoPrgDataSomehow;
        }

        lowBank.* = cartridge.prg.items[0..Cartridge.prgBankSize];
        highBank.* = switch (cartridge.nPrgBanks) {
            1 => lowBank.*,
            else => cartridge.prg.items[Cartridge.prgBankSize..(2 * Cartridge.prgBankSize)],
        };
    }

    pub fn read(self: *const Self, address: u16) u8 {
        switch (address) {
            0x0000...0x1fff => {
                const effectiveAddress = address % 0x800;
                const value: u8 = self.cpuRam[effectiveAddress];
                log("reading {x:02} from CPU RAM at address {x:04}", .{ value, address });
                return value;
            },
            0x2000...0x3fff => {
                const effectiveAddress = (address - 0x2000) % 8;
                const value: u8 = self.ppuRegisters[effectiveAddress];
                log("{s}reading {x:02} from PPU registers at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x4000...0x4015 => {
                const effectiveAddress = address - 0x4000;
                const value: u8 = self.apuRegisters[effectiveAddress];
                log("{s}reading {x:02} from APU registers at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x4016 => {
                const value: u8 = self.joystick1;
                log("{s}reading {x:02} from Joystick 1 at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x4017 => {
                const value: u8 = self.joystick2;
                log("{s}reading {x:02} from Joystick 2 at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x4018...0x401f => {
                const effectiveAddress = address - 0x4018;
                const value: u8 = self.apuExtension[effectiveAddress];
                log("{s}reading {x:02} from APU extension at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x4020...0x5fff => {
                const effectiveAddress = address - 0x4020;
                const value: u8 = self.unmapped[effectiveAddress];
                log("{s}reading {x:02} from unmapped memory at address {x:04}{s}", .{ inBlue, value, address, resetFormatting });
                return value;
            },
            0x6000...0x7fff => {
                const effectiveAddress = address - 0x6000;
                const value: u8 = self.cartridgeRam[effectiveAddress];
                log("reading {x:02} from cartridge RAM at address {x:04}", .{ value, address });
                return value;
            },
            0x8000...0xbfff => {
                const effectiveAddress = address - 0x8000;
                const value: u8 = self.lowBank[effectiveAddress];
                log("reading {x:02} from cartridge ROM at address {x:04}", .{ value, address });
                return value;
            },
            0xc000...0xffff => {
                const effectiveAddress = address - 0xc000;
                const value: u8 = self.highBank[effectiveAddress];
                log("reading {x:02} from cartridge ROM at address {x:04}", .{ value, address });
                return value;
            },
        }
    }

    pub fn write(self: *Self, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x1fff => {
                const effectiveAddress = address % 0x800;
                self.cpuRam[effectiveAddress] = value;
                log("writing {x:02} in CPU RAM at address {x:04}", .{ value, address });
            },
            0x2000...0x3fff => {
                const effectiveAddress = (address - 0x2000) % 8;
                self.ppuRegisters[effectiveAddress] = value;
                log("{s}writing {x:02} in PPU registers at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x4000...0x4015 => {
                const effectiveAddress = address - 0x4000;
                self.apuRegisters[effectiveAddress] = value;
                log("{s}writing {x:02} in APU registers at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x4016 => {
                self.joystick1 = value;
                log("{s}writing {x:02} in Joystick 1 at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x4017 => {
                self.joystick1 = value;
                log("{s}writing {x:02} in Joystick 2 at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x4018...0x401f => {
                const effectiveAddress = address - 0x4018;
                self.apuExtension[effectiveAddress] = value;
                log("{s}writing {x:02} in APU extension at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x4020...0x5fff => {
                const effectiveAddress = address - 0x4020;
                self.unmapped[effectiveAddress] = value;
                log("{s}writing {x:02} in unmapped memory at address {x:04}{s}", .{ inPurple, value, address, resetFormatting });
            },
            0x6000...0x7fff => {
                const effectiveAddress = address - 0x6000;
                self.cartridgeRam[effectiveAddress] = value;
                log("writing {x:02} in cartridge RAM at address {x:04}", .{ value, address });
            },
            0x8000...0xffff => {
                std.log.warn("Attempting to write in cartridge ROM at address {x:04}", .{address});
            },
        }
    }
};
