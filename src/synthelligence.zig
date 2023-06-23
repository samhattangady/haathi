const std = @import("std");
const c = @import("interface.zig");

/// Haathi will have all the info about the inputs and things like that.
/// It will also be the one who collates all the render calls, and then
/// passes them on.
const Haathi = struct {
    const Self = @This();
    space_down: bool = false,
    mouse_down: bool = false,
    //allocator: std.mem.Allocator,

    pub fn init() Self {
        return .{
            // .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn set_key_down(self: *Self, code: c_uint) void {
        _ = self;
        _ = code;
    }
    pub fn set_key_up(self: *Self, code: c_uint) void {
        _ = self;
        _ = code;
    }
    pub fn set_mouse_down(self: *Self, code: c_int) void {
        _ = code;
        self.mouse_down = true;
    }
    pub fn set_mouse_up(self: *Self, code: c_int) void {
        _ = code;
        self.mouse_down = false;
    }
    pub fn set_mouse(self: *Self, x: c_int, y: c_int) void {
        _ = self;
        _ = x;
        _ = y;
    }
};

var haathi: Haathi = undefined;

// var web_allocator = std.heap.GeneralPurposeAllocator(.{}){};

export fn another_init() void {}
export fn onInit() void {
    haathi = Haathi.init();
}

export fn key_down(code: c_uint) void {
    haathi.set_key_down(code);
}
export fn key_up(code: c_uint) void {
    haathi.set_key_up(code);
}
export fn mouse_down(code: c_int) void {
    haathi.set_mouse_down(code);
}
export fn mouse_up(code: c_int) void {
    haathi.set_mouse_up(code);
}
export fn mouse_motion(x: c_int, y: c_int) void {
    haathi.set_mouse(x, y);
}
export fn render() void {
    c.fillRect(10, 20, 50, 30, "#f00");
}
