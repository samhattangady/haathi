const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const build_options = @import("build_options");
const Game = switch (build_options.game) {
    .synthelligence => @import("synthelligence.zig").Game,
    .hiveminder => @import("hiveminder.zig").Game,
    .drifter => @import("drifter.zig").Game,
};
const helpers = @import("helpers.zig");

var haathi: Haathi = undefined;
var game: Game = undefined;
var start_ticks: u64 = 0;

// var web_allocator = std.heap.GeneralPurposeAllocator(.{}){};

export fn init() void {
    start_ticks = helpers.milliTimestamp();
    haathi = Haathi.init();
    game = Game.init(&haathi);
}

export fn keyDown(code: u32) void {
    haathi.keyDown(code);
}
export fn keyUp(code: u32) void {
    haathi.keyUp(code);
}
export fn mouseDown(code: c_int) void {
    haathi.mouseDown(code);
}
export fn mouseUp(code: c_int) void {
    haathi.mouseUp(code);
}
export fn mouseMove(x: c_int, y: c_int) void {
    haathi.mouseMove(x, y);
}
export fn mouseWheelY(y: c_int) void {
    haathi.mouseWheelY(y);
}
export fn render() void {
    const ticks = helpers.milliTimestamp() - start_ticks;
    haathi.update(ticks);
    game.update(ticks);
    game.render();
    haathi.render();
}
