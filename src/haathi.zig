const std = @import("std");
const c = @import("interface.zig");
const Inputs = @import("inputs.zig").Inputs;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;

/// Haathi will have all the info about the inputs and things like that.
/// It will also be the one who collates all the render calls, and then
/// passes them on.
pub const Haathi = struct {
    const Self = @This();
    space_down: bool = false,
    mouse_down: bool = true,
    inputs: Inputs = .{},
    ticks: u64 = 0,
    drawables: std.ArrayList(Drawable),
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init() Self {
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var allocator = std.heap.page_allocator;
        return .{
            .drawables = std.ArrayList(Drawable).init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
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

    pub fn update(self: *Self, ticks: u64) void {
        self.ticks = ticks;
    }

    pub fn render(self: *Self) void {
        c.clearCanvas(colors.solarized_base3_str);
        var color_buffer: [10]u8 = undefined;
        for (self.drawables.items) |drawable| {
            switch (drawable) {
                .rect => |rect| {
                    rect.color.toHexRgba(color_buffer[0..]);
                    c.fillStyle(color_buffer[0..].ptr);
                    if (rect.radius) |radius| {
                        c.beginPath();
                        c.roundRect(rect.position.x, rect.position.y, rect.size.x, rect.size.y, radius);
                        c.fill();
                    } else {
                        c.fillRect(rect.position.x, rect.position.y, rect.size.x, rect.size.y);
                    }
                },
                .path => |path| {
                    path.color.toHexRgba(color_buffer[0..]);
                    c.strokeStyle(color_buffer[0..].ptr);
                    c.lineWidth(path.width);
                    c.beginPath();
                    for (path.points) |point| {
                        c.lineTo(point.x, point.y);
                    }
                    c.stroke();
                },
                .text => |text| {
                    text.color.toHexRgba(color_buffer[0..]);
                    c.fillStyle(color_buffer[0..].ptr);
                    c.font(text.style.ptr);
                    c.textAlign(@tagName(text.alignment).ptr);
                    c.fillText(text.text.ptr, text.position.x, text.position.y, text.width);
                },
            }
        }
        self.drawables.clearRetainingCapacity();
    }

    pub fn drawRect(self: *Self, rect: DrawRectOptions) void {
        self.drawables.append(.{ .rect = rect }) catch unreachable;
    }
    pub fn drawPath(self: *Self, path: DrawPathOptions) void {
        self.drawables.append(.{ .path = path }) catch unreachable;
    }
    pub fn drawText(self: *Self, text: DrawTextOptions) void {
        self.drawables.append(.{ .text = text }) catch unreachable;
    }
};

pub const Drawable = union(enum) {
    rect: DrawRectOptions,
    path: DrawPathOptions,
    text: DrawTextOptions,
};

pub const DrawRectOptions = struct {
    position: Vec2,
    size: Vec2,
    color: Vec4,
    radius: ?f32 = null,
};

pub const DrawPathOptions = struct {
    points: []Vec2,
    color: Vec4,
    width: f32 = 5,
};

const TextAlignment = enum {
    start,
    end,
    left,
    right,
    center,
};

pub const DrawTextOptions = struct {
    text: []const u8,
    position: Vec2,
    color: Vec4,
    style: []const u8,
    width: f32 = 1280,
    alignment: TextAlignment = .center,
};
