const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
var haathi: Haathi = undefined;

// var web_allocator = std.heap.GeneralPurposeAllocator(.{}){};

export fn init() void {
    haathi = Haathi.init();
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
export fn render() void {
    c.clearCanvas("#ddd");
    if (haathi.space_down) c.fillRect(110, 120, 50, 30, "#f00");
    c.fillRect(haathi.inputs.mouse.current_pos.x, haathi.inputs.mouse.current_pos.y, 50, 30, "#f00");
}
