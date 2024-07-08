const std = @import("std");
const c = @import("interface.zig");
const Inputs = @import("inputs.zig").Inputs;
const Key = @import("inputs.zig").Key;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;

pub const SCREEN_HEIGHT = 720;
pub const SCREEN_WIDTH = 1280;
pub const SCREEN_SIZE = Vec2{ .x = SCREEN_WIDTH, .y = SCREEN_HEIGHT };
pub const FONT_1 = "18px JetBrainsMono";
pub const FONT_2 = "36px WhiteStorm";
pub const FONT_3 = "80px MedevialSharp";

pub const CursorStyle = enum {
    auto,
    default,
    none,
    context_menu,
    help,
    pointer,
    progress,
    wait,
    cell,
    crosshair,
    text,
    vertical_text,
    alias,
    copy,
    move,
    no_drop,
    not_allowed,
    grab,
    grabbing,
    all_scroll,
    col_resize,
    row_resize,
    n_resize,
    e_resize,
    s_resize,
    w_resize,
    ne_resize,
    nw_resize,
    se_resize,
    sw_resize,
    ew_resize,
    ns_resize,
    nesw_resize,
    nwse_resize,
    zoom_in,
    zoom_out,
};

/// Haathi will have all the info about the inputs and things like that.
/// It will also be the one who collates all the render calls, and then
/// passes them on.
pub const Haathi = struct {
    const Self = @This();
    inputs: Inputs = .{},
    ticks: u64 = 0,
    drawables: std.ArrayList(Drawable),
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init() Self {
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        const allocator = std.heap.page_allocator;
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
        self.inputs.handleKeyDown(code, self.ticks);
    }
    pub fn keyUp(self: *Self, code: u32) void {
        self.inputs.handleKeyUp(code, self.ticks);
    }
    pub fn mouseDown(self: *Self, code: c_int) void {
        self.inputs.handleMouseDown(code, self.ticks);
    }
    pub fn mouseUp(self: *Self, code: c_int) void {
        self.inputs.handleMouseUp(code, self.ticks);
    }
    pub fn mouseMove(self: *Self, x: c_int, y: c_int) void {
        self.inputs.handleMouseMove(x, y);
    }
    pub fn mouseWheelY(self: *Self, y: c_int) void {
        self.inputs.handleMouseWheel(y);
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
                    const position = if (rect.centered) rect.position.add(rect.size.scale(-0.5)) else rect.position;
                    if (rect.radius) |radius| {
                        c.beginPath();
                        c.roundRect(position.x, position.y, rect.size.x, rect.size.y, radius);
                        c.fill();
                    } else {
                        c.fillRect(position.x, position.y, rect.size.x, rect.size.y);
                    }
                },
                .path => |path| {
                    path.color.toHexRgba(color_buffer[0..]);
                    c.strokeStyle(color_buffer[0..].ptr);
                    c.lineWidth(path.width);
                    c.beginPath();
                    c.moveTo(path.points[0].x, path.points[0].y);
                    for (path.points) |point| {
                        c.lineTo(point.x, point.y);
                    }
                    if (path.closed) c.closePath();
                    c.stroke();
                },
                .poly => |poly| {
                    poly.color.toHexRgba(color_buffer[0..]);
                    c.fillStyle(color_buffer[0..].ptr);
                    c.beginPath();
                    c.moveTo(poly.points[0].x, poly.points[0].y);
                    for (poly.points) |point| {
                        c.lineTo(point.x, point.y);
                    }
                    c.closePath();
                    c.fill();
                },
                .text => |text| {
                    text.color.toHexRgba(color_buffer[0..]);
                    c.fillStyle(color_buffer[0..].ptr);
                    c.font(text.style.ptr);
                    c.textAlign(@tagName(text.alignment).ptr);
                    c.fillText(text.text.ptr, text.position.x, text.position.y, text.width);
                },
                .sprite => |sprite| {
                    const sx = sprite.sprite.anchor.x;
                    c.drawImage(sprite.sprite.path[0..].ptr, sx, sprite.sprite.anchor.y, sprite.sprite.size.x, sprite.sprite.size.y, sprite.position.x, sprite.position.y, sprite.sprite.size.x * sprite.scale.x, sprite.sprite.size.y * sprite.scale.y);
                },
            }
        }
        self.drawables.clearRetainingCapacity();
        self.inputs.reset();
    }

    pub fn drawRect(self: *Self, rect: DrawRectOptions) void {
        self.drawables.append(.{ .rect = rect }) catch unreachable;
    }
    pub fn drawPath(self: *Self, path: DrawPathOptions) void {
        self.drawables.append(.{ .path = path }) catch unreachable;
    }
    pub fn drawPoly(self: *Self, poly: DrawPolyOptions) void {
        self.drawables.append(.{ .poly = poly }) catch unreachable;
    }
    pub fn drawText(self: *Self, text: DrawTextOptions) void {
        self.drawables.append(.{ .text = text }) catch unreachable;
    }
    pub fn drawSprite(self: *Self, sprite: DrawSpriteOptions) void {
        self.drawables.append(.{ .sprite = sprite }) catch unreachable;
    }
    pub fn setCursor(self: *Self, cursor: CursorStyle) void {
        _ = self;
        c.setCursor(@tagName(cursor).ptr);
    }

    pub fn loadSound(self: *Self, sound_path: []const u8, looping: bool) void {
        _ = self;
        c.loadSound(sound_path[0..].ptr, looping);
    }
    pub fn playSound(self: *Self, sound_path: []const u8, restart: bool) void {
        _ = self;
        c.playSound(sound_path[0..].ptr, restart);
    }
    pub fn pauseSound(self: *Self, sound_path: []const u8) void {
        _ = self;
        c.pauseSound(sound_path[0..].ptr);
    }
    pub fn setSoundVolume(self: *Self, sound_path: []const u8, volume: f32) void {
        _ = self;
        c.setSoundVolume(sound_path[0..].ptr, volume);
    }
};

pub const Drawable = union(enum) {
    rect: DrawRectOptions,
    path: DrawPathOptions,
    text: DrawTextOptions,
    poly: DrawPolyOptions,
    sprite: DrawSpriteOptions,
};

pub const DrawRectOptions = struct {
    position: Vec2,
    size: Vec2,
    color: Vec4,
    radius: ?f32 = null,
    /// centers the rect at position.
    centered: bool = false,
};

pub const DrawPathOptions = struct {
    points: []const Vec2,
    color: Vec4,
    width: f32 = 5,
    closed: bool = false,
};

pub const DrawPolyOptions = struct {
    points: []const Vec2,
    color: Vec4,
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
    style: []const u8 = FONT_2,
    width: f32 = 1280,
    alignment: TextAlignment = .center,
};

const SpriteAnchor = enum {
    top_left,
    center,
};

pub const Sprite = struct {
    path: []const u8,
    anchor: Vec2,
    size: Vec2,
};

pub const DrawSpriteOptions = struct {
    sprite: Sprite,
    position: Vec2,
    scale: Vec2 = .{ .x = 1, .y = 1 },
    anchor: SpriteAnchor = .top_left,
};
