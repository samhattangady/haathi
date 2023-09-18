const std = @import("std");
const c = @import("interface.zig");
const inputs = @import("inputs.zig");
const MouseState = inputs.MouseState;

pub const Vec2 = struct {
    const Self = @This();
    x: f32 = 0,
    y: f32 = 0,

    pub fn fromInts(x: anytype, y: anytype) Vec2 {
        return Vec2{
            .x = @as(f32, @floatFromInt(x)),
            .y = @as(f32, @floatFromInt(y)),
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
        const len = v.length();
        if (len == 0) return v.scale(0);
        return v.scale(1 / len);
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

    pub fn round(v: *const Self) Vec2i {
        return .{
            .x = @as(i32, @intFromFloat(@round(v.x))),
            .y = @as(i32, @intFromFloat(@round(v.y))),
        };
    }

    pub fn dot(v1: *const Self, v2: Self) f32 {
        return (v1.x * v2.x) + (v1.y * v2.y);
    }

    /// to get the sin of the angle between the two vectors.
    pub fn crossZ(v1: *const Self, v2: Self) f32 {
        return (v1.x * v2.y) - (v1.y * v2.x);
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

    /// takes a Vec2 v that is currently aligned to origin. It then rotates it
    /// such that it now has the same relationship with target as it originally
    /// had with origin.
    /// origin and target need to be normalized.
    /// For example, if we have offsets of a polygon, and we want to rotate it,
    /// then the origin will be x axis, and the target will be the rotation.
    pub fn alignTo(v: *const Self, origin: Vec2, target: Vec2) Vec2 {
        // get the angle between origin and target
        const cosa = origin.dot(target);
        const sina = origin.crossZ(target);
        return .{
            .x = (cosa * v.x) - (sina * v.y),
            .y = (sina * v.x) + (cosa * v.y),
        };
    }

    pub fn lerp(v0: *const Vec2, v1: Vec2, t: f32) Vec2 {
        return .{
            .x = lerpf(v0.x, v1.x, t),
            .y = lerpf(v0.y, v1.y, t),
        };
    }
};

pub const Vec2i = struct {
    const Self = @This();
    x: i32 = 0,
    y: i32 = 0,

    pub fn toVec2(v: *const Self) Vec2 {
        return .{
            .x = @as(f32, @floatFromInt(v.x)),
            .y = @as(f32, @floatFromInt(v.y)),
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

    pub fn scale(v: *const Self, t: i32) Self {
        return .{ .x = v.x * t, .y = v.y * t };
    }

    pub fn distancei(v: *const Self, v1: Self) i32 {
        const absx = std.math.absInt(v.x - v1.x) catch unreachable;
        const absy = std.math.absInt(v.y - v1.y) catch unreachable;
        return absx + absy;
    }

    pub fn numSteps(v: *const Self) i32 {
        const absx = std.math.absInt(v.x) catch unreachable;
        const absy = std.math.absInt(v.y) catch unreachable;
        return absx + absy;
    }
    pub fn maxMag(v: *const Self) i32 {
        const absx = std.math.absInt(v.x) catch unreachable;
        const absy = std.math.absInt(v.y) catch unreachable;
        return @max(absx, absy);
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
        self.x = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable)) / 255.0;
        self.y = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable)) / 255.0;
        self.z = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable)) / 255.0;
        self.w = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[7..9], 16) catch unreachable)) / 255.0;
        return self;
    }

    /// Converts hex rgb to Vec4. Expects in format "#rrggbb"
    pub fn fromHexRgb(hex: []const u8) Vec4 {
        std.debug.assert(hex[0] == '#'); // hex_rgba needs to be in "#rrggbb" format
        std.debug.assert(hex.len == 7); // hex_rgba needs to be in "#rrggbb" format
        var self = Vec4{};
        self.x = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[1..3], 16) catch unreachable)) / 255.0;
        self.y = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[3..5], 16) catch unreachable)) / 255.0;
        self.z = @as(f32, @floatFromInt(std.fmt.parseInt(u8, hex[5..7], 16) catch unreachable)) / 255.0;
        self.w = 1.0;
        return self;
    }

    pub fn toHexRgba(self: *const Self, buffer: []u8) void {
        std.debug.assert(buffer.len >= 10);
        buffer[0] = '#';
        buffer[9] = 0;
        _ = std.fmt.bufPrint(buffer[1..9], "{x:0>2}", .{@as(u8, @intFromFloat(self.x * 255))}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[3..5], "{x:0>2}", .{@as(u8, @intFromFloat(self.y * 255))}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[5..7], "{x:0>2}", .{@as(u8, @intFromFloat(self.z * 255))}) catch unreachable;
        _ = std.fmt.bufPrint(buffer[7..9], "{x:0>2}", .{@as(u8, @intFromFloat(self.w * 255))}) catch unreachable;
    }

    pub fn alpha(self: *const Vec4, a: f32) Vec4 {
        var col = self.*;
        col.w = a;
        return col;
    }

    // TODO (26 Jul 2023 sam): Do a hsv based lerp also
    pub fn lerp(self: *const Vec4, other: Vec4, f: f32) Vec4 {
        return .{
            .x = lerpf(self.x, other.x, f),
            .y = lerpf(self.y, other.y, f),
            .z = lerpf(self.z, other.z, f),
            .w = lerpf(self.w, other.w, f),
        };
    }
};

pub const Movement = struct {
    const Self = @This();
    from: Vec2,
    to: Vec2,
    start: u64,
    duration: u64,
    mode: enum {
        linear,
        eased,
    } = .linear,

    pub fn getPos(self: *const Self, ticks: u64) Vec2 {
        if (ticks < self.start) return self.from;
        if (ticks > (self.start + self.duration)) return self.to;
        const t: f32 = @as(f32, @floatFromInt(ticks - self.start)) / @as(f32, @floatFromInt(self.duration));
        switch (self.mode) {
            .linear => return self.from.lerp(self.to, t),
            .eased => return self.from.ease(self.to, t),
        }
    }
};

pub const Rect = struct {
    const Self = @This();
    position: Vec2,
    size: Vec2,

    pub fn contains(self: *const Self, pos: Vec2) bool {
        const minx = @min(self.position.x, self.position.x + self.size.x);
        const maxx = @max(self.position.x, self.position.x + self.size.x);
        const miny = @min(self.position.y, self.position.y + self.size.y);
        const maxy = @max(self.position.y, self.position.y + self.size.y);
        return (pos.x > minx) and
            (pos.x < maxx) and
            (pos.y > miny) and
            (pos.y < maxy);
    }

    pub fn center(self: *const Self) Vec2 {
        return self.position.add(self.size.scale(0.5));
    }
};

pub const Button = struct {
    const Self = @This();
    rect: Rect,
    value: u8,
    text: []const u8,
    text2: []const u8 = "",
    enabled: bool = true,
    // mouse is hovering over button
    hovered: bool = false,
    // the frame that mouse button was down in bounds
    clicked: bool = false,
    // the frame what mouse button was released in bounds (and was also down in bounds)
    released: bool = false,
    // when mouse was down in bounds and is still down.
    triggered: bool = false,

    pub fn contains(self: *const Self, pos: Vec2) bool {
        return self.rect.contains(pos);
    }

    pub fn update(self: *Self, mouse: MouseState) void {
        if (self.enabled) {
            self.hovered = !mouse.l_button.is_down and self.contains(mouse.current_pos);
            self.clicked = mouse.l_button.is_clicked and self.contains(mouse.current_pos);
            self.released = mouse.l_button.is_released and self.contains(mouse.current_pos) and self.contains(mouse.l_down_pos);
            self.triggered = mouse.l_button.is_down and self.contains(mouse.l_down_pos);
        } else {
            self.hovered = false;
            self.clicked = false;
            self.released = false;
            self.triggered = false;
        }
    }
};

pub const Line = struct {
    p0: Vec2,
    p1: Vec2,

    pub fn intersects(self: *const Line, other: Line) ?Vec2 {
        return lineSegmentsIntersect(self.p0, self.p1, other.p0, other.p1);
    }

    /// projects the point onto the line, and then returns the fract of that projected point
    /// along the line, where 0 is p0 and 1 is p1
    pub fn unlerp(self: *const Line, point: Vec2) f32 {
        // TODO (21 Jul 2023 sam): Check if this works. Copied over...
        const l_sqr = self.p0.distanceSqr(self.p1);
        if (l_sqr == 0.0) return 0.0;
        // TODO (02 Feb 2022 sam): Why is this divided by l_sqr and not l? Does dot product
        // return a squared length of projected line length?
        const t = point.subtract(self.p0).dot(self.p1.subtract(self.p0)) / l_sqr;
        return t;
    }
};

pub const TextLine = struct {
    text: []const u8,
    position: Vec2,
};

pub fn easeinoutf(start: f32, end: f32, t: f32) f32 {
    // Bezier Blend as per StackOverflow : https://stackoverflow.com/a/25730573/5453127
    // t goes between 0 and 1.
    const x = t * t * (3.0 - (2.0 * t));
    return start + ((end - start) * x);
}

pub fn milliTimestamp() u64 {
    return @as(u64, @intCast(c.milliTimestamp()));
}

pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    const message = std.fmt.bufPrintZ(buffer[0..], fmt, args) catch {
        c.debugPrint("message was too long to print");
        return;
    };
    c.debugPrint(message.ptr);
}

pub fn debugPrintAlloc(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    const message = std.fmt.allocPrintZ(allocator, fmt, args) catch {
        c.debugPrint("could not alloc print sorry");
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
    const x_intersect = lerpf(v0.x, v1.x, y_fract);
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
pub fn lerpf(start: f32, end: f32, t: f32) f32 {
    return (start * (1.0 - t)) + (end * t);
}

/// When we have an index that we want to toggle through while looping, then we use this.
pub fn applyChangeLooped(value: u8, change: i8, max: u8) u8 {
    return applyChange(value, change, max, true);
}

/// When we have an index that we want to toggle through while looping, then we use this.
pub fn applyChange(value: anytype, change: anytype, max: anytype, loop: bool) @TypeOf(value) {
    const max_return = if (loop) 0 else max;
    const min_return = if (loop) max else 0;
    std.debug.assert(change == 1 or change == -1);
    if (change == 1) {
        if (value == max) return max_return;
        return value + 1;
    }
    if (change == -1) {
        if (value == 0) return min_return;
        return value - 1;
    }
    unreachable;
}

pub fn lineSegmentsIntersect(p1: Vec2, p2: Vec2, p3: Vec2, p4: Vec2) ?Vec2 {
    // sometimes it looks like single points are being passed in
    if (p1.equal(p2) and p2.equal(p3) and p3.equal(p4)) {
        return p1;
    }
    if (p1.equal(p2) or p3.equal(p4)) {
        return null;
    }
    const t = ((p1.x - p3.x) * (p3.y - p4.y)) - ((p1.y - p3.y) * (p3.x - p4.x));
    const u = ((p2.x - p1.x) * (p1.y - p3.y)) - ((p2.y - p1.y) * (p1.x - p3.x));
    const d = ((p1.x - p2.x) * (p3.y - p4.y)) - ((p1.y - p2.y) * (p3.x - p4.x));
    // TODO (24 Apr 2021 sam): There is an performance improvement here where the division is not
    // necessary. Be careful of the negative signs when figuring that all out.  @@Performance
    const td = t / d;
    const ud = u / d;
    if (td >= 0.0 and td <= 1.0 and ud >= 0.0 and ud <= 1.0) {
        var s = t / d;
        if (d == 0) {
            s = 0;
        }
        return Vec2{
            .x = p1.x + s * (p2.x - p1.x),
            .y = p1.y + s * (p2.y - p1.y),
        };
    } else {
        return null;
    }
}

pub fn pointToLineDistanceSqr(point: Vec2, line: Line) f32 {
    // TODO (21 Jul 2023 sam): Check if this works. Copied over...
    const l_sqr = line.p0.distanceSqr(line.p1);
    if (l_sqr == 0.0) return line.p0.distanceSqr(point);
    const t = std.math.clamp(point.subtract(line.p0).dot(line.p1.subtract(line.p0)) / l_sqr, 0.0, 1.0);
    const projected = line.p0.add(line.p1.subtract(line.p0).scale(t));
    return point.distanceSqr(projected);
}

pub fn parseBool(token: []const u8) !bool {
    if (std.mem.eql(u8, token, "true")) return true;
    if (std.mem.eql(u8, token, "false")) return false;
    return error.ParseError;
}

/// given an enum, it gives the next value in the cycle, and loops if required
pub fn enumChange(val: anytype, change: i8, loop: bool) @TypeOf(val) {
    const T = @TypeOf(val);
    const max = @typeInfo(T).Enum.fields.len - 1;
    const index = @intFromEnum(val);
    const new_index = applyChange(@as(u8, @intCast(index)), change, @as(u8, @intCast(max)), loop);
    return @as(T, @enumFromInt(new_index));
}

pub fn assert(condition: bool) void {
    if (!condition) unreachable; // assertion failed.
}
