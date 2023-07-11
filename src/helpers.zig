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

    pub fn equal(v: *const Self, v1: Self) bool {
        return v.x == v1.x and v.y == v1.y;
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

/// Checks if a ray in +ve x direction from point intersects with line v0-v1
pub fn xRayIntersects(point: Vec2, v0: Vec2, v1: Vec2) bool {
    // if point.y is not between v0.y and v1.y, no intersection
    if (!((point.y >= @min(v0.y, v1.y)) and (point.y <= @max(v0.y, v1.y)))) return false;
    // if point.x is greater than both verts, no intersection
    if (point.x > v0.x and point.x > v1.x) return false;
    // if point.x is less than both verts, intersection
    if (point.x <= v0.x and point.x <= v1.x) return true;
    // point.x is between v0.x and v1.x
    // get the point of intersection
    const y_fract = (point.y - v0.y) / (v1.y - v0.y);
    const x_intersect = lerp(v0.x, v1.x, y_fract);
    // if intersection point is more than point.x, intersection
    return x_intersect >= point.x;
}

pub fn polygonContainsPoint(verts: []const Vec2, point: Vec2, bbox: ?Rect) bool {
    if (bbox) |box| {
        if (!box.contains(point)) return false;
    }
    // counts the number of intersections between edges and a line from point towards +x
    var count: usize = 0;
    for (verts, 0..) |v0, i| {
        // var v1 = verts[0];
        // if (i < verts.len - 1) {
        //     v1 = verts[i + 1];
        // }
        const v1 = if (i < verts.len - 1) verts[i + 1] else verts[0];
        // const v1 = if (i == verts.len - 1) verts[0] else verts[i + i];
        if (xRayIntersects(point, v0, v1)) count += 1;
    }
    return @mod(count, 2) == 1;
}

/// t varies from 0 to 1. (Can also be outside the range for extrapolation)
pub fn lerp(start: f32, end: f32, t: f32) f32 {
    return (start * (1.0 - t)) + (end * t);
}
