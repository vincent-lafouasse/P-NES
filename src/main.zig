const std = @import("std");
const Cartridge = @import("Cartridge.zig").Cartridge;
const Disassembler = @import("Disassembler.zig").Disassembler;
const Bus = @import("Bus.zig").Bus;
const Cpu = @import("Cpu.zig").Cpu;

const c = @cImport({
    @cInclude("X11/Xlib.h");
});

const X11Ctx = struct {
    display: *c.Display,
    root_window: c.Window,
    window: c.Window,

    const Self = @This();

    const X11Error = error{
        FailedConnection,
    };

    pub fn init() X11Error!Self {
        const display: *c.Display = c.XOpenDisplay(@as(?*u8, null)) orelse
            return X11Error.FailedConnection;

        const root_window: c.Window = c.XDefaultRootWindow(display);
        const window: c.Window = c.XCreateSimpleWindow(display, root_window, 0, 0, 1600, 800, 0, 0, 0x202040);

        return Self{
            .display = display,
            .root_window = root_window,
            .window = window,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = c.XCloseDisplay(self.display);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;

    const x11Ctx = try X11Ctx.init();
    defer x11Ctx.deinit();

    _ = c.XMapWindow(x11Ctx.display, x11Ctx.window);
    _ = c.XSync(x11Ctx.display, 0);

    while (true) {}

    ////@breakpoint();

    //const cartridge = try Cartridge.load("roms/tutor.nes", allocator);
    //defer cartridge.free();

    //cartridge.log();
    //try cartridge.dump_prg();
    //try cartridge.dump_chr();

    //var disassembler = try Disassembler.init(cartridge, allocator);
    //defer disassembler.deinit();
    //try disassembler.disassemble();

    //var bus = try Bus.init(&cartridge);

    //var cpu = Cpu.init(&bus);
    //cpu.start();

    //// const args = try std.process.ArgIterator.initWithAllocator(allocator);
    //// defer args.deinit();
    //// std.log.info("{any}", .{args});
}
