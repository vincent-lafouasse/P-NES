const Cartridge = @import("Cartridge.zig").Cartridge;

const DisassemblyError = error{
    UnsupportedMapper,
    NoPrgDataSomehow,
};

pub const Disassembler = struct {
    lowBank: []const u8,
    highBank: []const u8,

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

        return Self{
            .lowBank = lowBank,
            .highBank = highBank,
        };
    }
};
