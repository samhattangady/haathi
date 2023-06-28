const std = @import("std");
const c = @import("interface.zig");

pub const Vec2 = struct {
    const Self = @This();
    x: f32 = 0,
    y: f32 = 0,

    pub fn fromInts(x: anytype, y: anytype) Vec2 {
        return Vec2{
            .x = @floatFromInt(f32, x),
            .y = @floatFromInt(f32, y),
        };
    }

    pub fn distance(v1: *const Self, v2: Self) f32 {
        return @sqrt(((v2.x - v1.x) * (v2.x - v1.x)) + ((v2.y - v1.y) * (v2.y - v1.y)));
    }

    pub fn distanceSqr(v1: *const Self, v2: Self) f32 {
        return ((v2.x - v1.x) * (v2.x - v1.x)) + ((v2.y - v1.y) * (v2.y - v1.y));
    }

    pub fn length(v: *const Self) f32 {
        return @sqrt((v.x * v.x) + (v.y * v.y));
    }

    pub fn lengthSqr(v: *const Self) f32 {
        return (v.x * v.x) + (v.y * v.y);
    }

    pub fn normalize(v: *const Self) Self {
        return v.scale(1 / v.length());
    }

    pub fn xVec(v: *const Self) Self {
        return .{ .x = v.x };
    }

    pub fn yVec(v: *const Self) Self {
        return .{ .y = v.y };
    }

    pub fn toVec3(v: *const Self) Vec3 {
        return .{ .x = v.x, .y = v.y };
    }

    pub fn add(v1: *const Self, v2: Vec2) Self {
        return .{ .x = v1.x + v2.x, .y = v1.y + v2.y };
    }

    pub fn subtract(v1: *const Self, v2: Self) Self {
        return .{ .x = v1.x - v2.x, .y = v1.y - v2.y };
    }

    pub fn scale(v: *const Self, t: f32) Self {
        return .{ .x = v.x * t, .y = v.y * t };
    }

    pub fn scaleVec2(v: *const Self, v2: Vec2) Self {
        return .{ .x = v.x * v2.x, .y = v.y * v2.y };
    }

    /// Strict equals check. Does not account for float imprecision
    pub fn equal(v1: *const Self, v2: Self) bool {
        return v1.x == v2.x and v1.y == v2.y;
    }

    pub fn zero(v: *const Self) bool {
        return v.x == 0 and v.y == 0;
    }

    pub fn rotate(v: *const Self, rad: f32) Self {
        const cosa = @cos(rad);
        const sina = @sin(rad);
        return .{
            .x = (cosa * v.x) - (sina * v.y),
            .y = (sina * v.x) + (cosa * v.y),
        };
    }

    pub fn alignTo(v: *const Self, src: Self, target: Self) Self {
        _ = v;
        var vec = target.add(src.scale(-1)).normalize();
        return vec;
    }

    pub fn round(v: *const Self) Vec2i {
        return .{
            .x = @intFromFloat(i32, @round(v.x)),
            .y = @intFromFloat(i32, @round(v.y)),
        };
    }

    pub fn dot(v1: *const Self, v2: Self) f32 {
        return (v1.x * v2.x) + (v1.y * v2.y);
    }

    pub fn perpendicular(v: *const Self) Self {
        return .{ .x = v.y, .y = -v.x };
    }

    pub fn ease(v1: *const Vec2, v2: Vec2, t: f32) Vec2 {
        return .{
            .x = easeinoutf(v1.x, v2.x, t),
            .y = easeinoutf(v1.y, v2.y, t),
        };
    }
};

pub const Vec2i = struct {
    const Self = @This();
    x: i32 = 0,
    y: i32 = 0,

    pub fn toVec2(v: *const Self) Vec2 {
        return .{
            .x = @floatFromInt(f32, v.x),
            .y = @floatFromInt(f32, v.y),
        };
    }

    pub fn add(v1: *const Self, v2: Self) Self {
        return .{ .x = v1.x + v2.x, .y = v1.y + v2.y };
    }

    pub fn length(v: *const Self) f32 {
        return v.toVec2().length();
    }

    pub fn lengthSqr(v: *const Self) f32 {
        return v.toVec2().lengthSqr();
    }
};

pub const Vec3 = struct {
    const Self = @This();
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn toVec2(v: *const Self) Vec2 {
        return .{ .x = v.x, .y = v.y };
    }
};

pub const Vec4 = struct {
    const Self = @This();
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    w: f32 = 0,

    /// Converts hex rgba to Vec4. Expects in format "#rrggbbaa"
    pub fn fromHexRgba(hex: []const u8) Vec4 {
        std.debug.assert(hex[0] == '#'); // hex_rgba needs to be in "#rrggbbaa" format
        std.debug.assert(hex.len == 9); // hex_rgba needs to be in "#rrggbbaa" format
        var self = Vec4{};
        self.x = @floatFromInt(f32, std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable) / 255.0;
        self.y = @floatFromInt(f32, std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable) / 255.0;
        self.z = @floatFromInt(f32, std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable) / 255.0;
        self.w = @floatFromInt(f32, std.fmt.parseInt(u8, hex[7..9], 16) catch unreachable) / 255.0;
        return self;
    }

    /// Converts hex rgb to Vec4. Expects in format "#rrggbb"
    pub fn fromHexRgb(hex: []const u8) Vec4 {
        std.debug.assert(hex[0] == '#'); // hex_rgba needs to be in "#rrggbb" format
        std.debug.assert(hex.len == 7); // hex_rgba needs to be in "#rrggbb" format
        var self = Vec4{};
        self.x = @floatFromInt(f32, std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable) / 255.0;
        self.y = @floatFromInt(f32, std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable) / 255.0;
        self.z = @floatFromInt(f32, std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable) / 255.0;
        self.w = 1.0;
        return self;
    }

    pub fn toHexRgba(self: *const Self, buffer: []u8) void {
        std.debug.assert(buffer.len >= 10);
        buffer[0] = '#';
        buffer[9] = 0;
        _ = std.fmt.bufPrint(buffer[1..9], "{x:0>2}", .{@intFromFloat(u8, self.x * 255)}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[3..5], "{x:0>2}", .{@intFromFloat(u8, self.y * 255)}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[5..7], "{x:0>2}", .{@intFromFloat(u8, self.z * 255)}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[7..9], "{x:0>2}", .{@intFromFloat(u8, self.w * 255)}) catch unreachable;
    }

    pub fn alpha(self: *const Vec4, a: f32) Vec4 {
        var col = self.*;
        col.w = a;
        return col;
    }
};

pub const Rect = struct {
    const Self = @This();
    position: Vec2,
    size: Vec2,

    pub fn contains(self: *const Self, pos: Vec2) bool {
        return (pos.x > self.position.x) and
            (pos.x < self.position.x + self.size.x) and
            (pos.y > self.position.y) and
            (pos.y < self.position.y + self.size.y);
    }
};

pub fn easeinoutf(start: f32, end: f32, t: f32) f32 {
    // Bezier Blend as per StackOverflow : https://stackoverflow.com/a/25730573/5453127
    // t goes between 0 and 1.
    const x = t * t * (3.0 - (2.0 * t));
    return start + ((end - start) * x);
}

pub fn milliTimestamp() u64 {
    return @intCast(u64, c.milliTimestamp());
}

pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const message = std.fmt.bufPrintZ(buffer[0..], fmt, args) catch {
        c.debugPrint("message was too long to print");
        return;
    };
    c.debugPrint(message.ptr);
}
