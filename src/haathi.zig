const std = @import("std");
const c = @import("interface.zig");
const Inputs = @import("inputs.zig").Inputs;

/// Haathi will have all the info about the inputs and things like that.
/// It will also be the one who collates all the render calls, and then
/// passes them on.
pub const Haathi = struct {
    const Self = @This();
    space_down: bool = false,
    mouse_down: bool = true,
    inputs: Inputs = .{},
    ticks: u64 = 0,
    //allocator: std.mem.Allocator,

    pub fn init() Self {
        return .{
            // .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn keyDown(self: *Self, code: u32) void {
        if (code == 0) self.space_down = true;
        self.inputs.handleKeyDown(code, self.ticks);
    }
    pub fn keyUp(self: *Self, code: u32) void {
        if (code == 0) self.space_down = false;
        self.inputs.handleKeyUp(code, self.ticks);
    }
    pub fn mouseDown(self: *Self, code: c_int) void {
        self.mouse_down = true;
        self.inputs.handleMouseDown(code, self.ticks);
    }
    pub fn mouseUp(self: *Self, code: c_int) void {
        self.mouse_down = false;
        self.inputs.handleMouseUp(code, self.ticks);
    }
    pub fn mouseMove(self: *Self, x: c_int, y: c_int) void {
        self.inputs.handleMouseMove(x, y);
    }
};
