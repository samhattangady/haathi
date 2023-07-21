const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const Line = helpers.Line;

const FONT_1 = "18px JetBrainsMono";
const FONT_2 = "26px JetBrainsMono";
const INTERSECTION_MIDPOINT = Vec2{ .x = (SCREEN_SIZE.y * 0.5), .y = SCREEN_SIZE.y * 0.5 };
const MID_POINT_INDEX = 16;

const test_1 = "car|0|1 car|0|5 car|2|5 sig|0|green|false sig|2|green|false sig|4|red|false sig|6|red|false sen|0|1|true sen|1|1|false sen|2|2|true sen|3|2|true sen|4|1|true sen|5|2|true sen|6|2|true sen|7|1|true";

const Level = struct {
    name: []const u8,
    data: []const u8,
};
const LEVELS = [_]Level{
    .{
        .data = "car|0|1 car|4|5 sig|0|green|false sig|2|red|true sig|4|red|false sig|6|red|true sen|0|1|true sen|1|1|false sen|2|1|true sen|3|2|true sen|4|1|true sen|5|2|true sen|6|2|true sen|7|1|true",
        .name = "After You",
    },
    .{
        .data = "car|0|1 car|0|7 car|4|5 sig|0|green|false sig|2|red|true sig|4|red|false sig|6|red|true sen|0|1|false sen|1|2|true sen|2|1|true sen|3|2|true sen|4|1|true sen|5|2|true sen|6|2|true sen|7|1|true",
        .name = "Non Interference",
    },
    .{
        .data = "car|0|1 car|0|5 car|4|5 sig|0|green|false sig|2|green|true sig|4|red|false sig|6|red|true sen|0|1|false sen|1|1|false sen|2|2|true sen|3|2|true sen|4|2|true sen|5|1|true sen|6|2|true sen|7|2|true",
        .name = "Double Minded",
    },
    .{
        .data = "car|0|7 car|0|7 car|2|5 car|0|7 car|0|7 car|4|1 car|4|1 car|4|1 car|2|5 car|2|5 car|6|3 car|6|3 sig|0|green|false sig|2|red|false sig|4|red|false sig|6|red|false sen|0|1|true sen|1|1|false sen|2|1|true sen|3|1|true sen|4|1|true sen|5|1|false sen|6|2|true sen|7|1|false",
        .name = "Eventual Synchronisation",
    },
    .{
        .data = "car|4|5 car|0|1 car|4|3 car|2|3 car|0|5 sig|0|green|false sig|2|green|false sig|4|red|false sig|6|red|false sen|0|1|false sen|1|1|true sen|2|2|true sen|3|1|false sen|4|2|true sen|5|1|true sen|6|1|true sen|7|2|true",
        .name = "Incoming",
    },
    .{
        .data = "car|0|5 car|0|5 car|2|5 car|2|5 sig|0|green|false sig|2|red|false sig|4|red|true sig|6|red|true sen|0|1|true sen|1|2|true sen|2|1|true sen|3|2|true sen|4|1|true sen|5|2|false sen|6|2|true sen|7|1|true",
        .name = "Eastward Bound",
    },
    .{
        .data = "car|0|7 car|0|5 car|4|3 car|6|3 sig|0|green|false sig|2|green|true sig|4|red|false sig|6|red|false sen|0|2|false sen|1|1|true sen|2|2|true sen|3|1|false sen|4|1|true sen|5|1|true sen|6|1|false sen|7|2|true",
        .name = "Trafficic",
    },
    .{
        .data = "car|0|7 car|0|7 car|2|7 car|4|1 car|4|5 sig|0|red|false sig|2|red|false sig|4|green|false sig|6|red|true sen|0|1|true sen|1|1|false sen|2|2|true sen|3|2|true sen|4|1|true sen|5|1|true sen|6|2|true sen|7|2|false",
        .name = "Sharing is Car ing",
    },
    .{
        .data = "car|4|7 car|0|3 car|0|5 car|6|7 car|6|3 sig|0|green|false sig|2|green|true sig|4|red|false sig|6|red|false sen|0|1|false sen|1|1|true sen|2|2|true sen|3|1|false sen|4|2|true sen|5|1|true sen|6|1|true sen|7|1|false",
        .name = "Sensomatic",
    },
    .{
        .data = "car|0|1 car|0|5 car|4|5 car|6|1 car|6|1 sig|0|green|false sig|2|green|true sig|4|red|false sig|6|red|false sen|0|1|false sen|1|1|false sen|2|2|true sen|3|2|true sen|4|2|true sen|5|1|false sen|6|1|false sen|7|2|true",
        .name = "Sighetti",
    },
    .{
        .data = "car|0|1 car|0|7 car|0|5 car|0|3 car|4|5 car|2|3 car|6|7 sig|0|green|false sig|2|red|false sig|4|red|false sig|6|red|false sen|0|1|true sen|1|2|false sen|2|1|true sen|3|2|false sen|4|1|true sen|5|2|false sen|6|2|true sen|7|2|false",
        .name = "Complicated != Complex",
    },
};

const PANE_X = SCREEN_SIZE.y;
const PANE_WIDTH = SCREEN_SIZE.x - SCREEN_SIZE.y;
const PANE_PADDING = 30;

const CAR_SPACING = 50;
const CAR_SIZE = Vec2{ .x = 30, .y = 40 };
const CAR_CORNERS = [_]Vec2{
    .{ .x = 15, .y = 20 },
    .{ .x = -15, .y = 20 },
    .{ .x = -15, .y = -20 },
    .{ .x = 15, .y = -20 },
};
const LaneType = enum {
    incoming,
    outgoing,
};

const ButtonAction = enum {
    prev_level,
    next_level,
    reset_level,
    clear_level,
    step_forward,
};

const Direction = enum {
    const Self = @This();
    leftward,
    rightward,
    downward,
    upward,

    pub fn isOpposite(self: *const Self, other: Self) bool {
        return switch (self.*) {
            .leftward => other == .rightward,
            .rightward => other == .leftward,
            .downward => other == .upward,
            .upward => other == .downward,
        };
    }
    pub fn isStraight(self: *const Self, other: Self) bool {
        return self.* == other;
    }
    pub fn isRightTurn(self: *const Self, other: Self) bool {
        return switch (self.*) {
            .leftward => other == .upward,
            .rightward => other == .downward,
            .downward => other == .leftward,
            .upward => other == .rightward,
        };
    }
    pub fn isLeftTurn(self: *const Self, other: Self) bool {
        return switch (self.*) {
            .leftward => other == .downward,
            .rightward => other == .upward,
            .downward => other == .rightward,
            .upward => other == .leftward,
        };
    }
};

const ARROW = [_]Vec2{
    .{ .x = 10 },
    .{ .x = 2, .y = 8 },
    .{ .x = 2, .y = 2 },
    .{ .x = -10, .y = 3 },
    .{ .x = -10, .y = -3 },
    .{ .x = 2, .y = -2 },
    .{ .x = 2, .y = -8 },
};

const Lane = struct {
    const Self = @This();
    lane: LaneType,
    rect: Rect,
    direction: Direction,
    /// Center of the road closest to the intersection. Used for reference
    /// for other elements.
    head: Vec2 = undefined,
    // Vector of size 1 pointing towards the intersection
    toward: Vec2 = undefined,
    /// 90 deg clockwise from toward
    perp: Vec2 = undefined,

    pub fn setup(self: *Self) void {
        const minx = @min(self.rect.position.x, self.rect.position.x + self.rect.size.x);
        const maxx = @max(self.rect.position.x, self.rect.position.x + self.rect.size.x);
        const miny = @min(self.rect.position.y, self.rect.position.y + self.rect.size.y);
        const maxy = @max(self.rect.position.y, self.rect.position.y + self.rect.size.y);
        const avgx = (minx + maxx) / 2;
        const avgy = (miny + maxy) / 2;
        switch (self.lane) {
            .incoming => self.head = switch (self.direction) {
                .leftward => .{ .x = minx, .y = avgy },
                .rightward => .{ .x = maxx, .y = avgy },
                .upward => .{ .x = avgx, .y = miny },
                .downward => .{ .x = avgx, .y = maxy },
            },
            .outgoing => self.head = switch (self.direction) {
                .rightward => .{ .x = minx, .y = avgy },
                .leftward => .{ .x = maxx, .y = avgy },
                .downward => .{ .x = avgx, .y = miny },
                .upward => .{ .x = avgx, .y = maxy },
            },
        }
        switch (self.lane) {
            .incoming => self.toward = switch (self.direction) {
                .leftward => .{ .x = -1 },
                .rightward => .{ .x = 1 },
                .upward => .{ .y = -1 },
                .downward => .{ .y = 1 },
            },
            .outgoing => self.toward = switch (self.direction) {
                .rightward => .{ .x = -1 },
                .leftward => .{ .x = 1 },
                .downward => .{ .y = -1 },
                .upward => .{ .y = 1 },
            },
        }
        switch (self.lane) {
            .incoming => self.perp = switch (self.direction) {
                .leftward => .{ .y = -1 },
                .rightward => .{ .y = 1 },
                .upward => .{ .x = 1 },
                .downward => .{ .x = -1 },
            },
            .outgoing => self.perp = switch (self.direction) {
                .rightward => .{ .y = -1 },
                .leftward => .{ .y = 1 },
                .downward => .{ .x = 1 },
                .upward => .{ .x = -1 },
            },
        }
    }
};

const LaneSensor = struct {
    const Self = @This();
    lane_index: u8,
    rect: Rect = undefined,
    num_slots: u8 = 2,
    disabled: bool = false,
    slots_memory: [4]Rect = undefined,

    pub fn setup(self: *Self, intersection: *const Intersection) void {
        const lane = intersection.lanes.items[self.lane_index];
        self.rect.size = lane.perp.scale(50).add(lane.toward.scale(20));
        const offset = lane.toward.scale(-15);
        self.rect.position = lane.head.add(offset).add(self.rect.size.scale(-0.5));
        const v0 = self.rect.position;
        const v1 = v0.add(lane.perp.scale(50));
        self.slots_memory[0] = .{ .position = v0, .size = lane.perp.scale(20).add(lane.toward.scale(20)) };
        self.slots_memory[1] = .{ .position = v1, .size = lane.perp.scale(-20).add(lane.toward.scale(20)) };
        std.debug.assert(self.num_slots <= 2); // have to make this dynamic if we have 3 or 4
    }

    pub fn slots(self: *const Self) []const Rect {
        return self.slots_memory[0..self.num_slots];
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.lane_index = std.fmt.parseInt(u8, tok, 10) catch unreachable;
            if (count == 3) self.num_slots = std.fmt.parseInt(u8, tok, 10) catch unreachable;
            if (count == 4) self.disabled = helpers.parseBool(tok) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrintZ(arena, "sen|{d}|{d}|{}", .{ self.lane_index, self.num_slots, self.disabled }) catch unreachable;
    }
};

const SignalState = enum {
    green,
    red,
};
const NUM_SIGNAL_STATES = @typeInfo(SignalState).Enum.fields.len;

const Signal = struct {
    const Self = @This();
    signal: SignalState,
    lane_index: u8,
    rect: Rect = undefined,
    positions: [NUM_SIGNAL_STATES]Vec2 = [_]Vec2{.{}} ** NUM_SIGNAL_STATES,
    slots: [3]Rect = undefined,
    disabled: bool = false,

    pub fn setup(self: *Self, intersection: *const Intersection) void {
        const lane = intersection.lanes.items[self.lane_index];
        self.rect.size = (Vec2{}).add(lane.perp.scale(60)).add(lane.toward.scale(20));
        const offset = lane.toward.scale(25);
        self.rect.position = lane.head.add(self.rect.size.scale(-0.5)).add(offset);
        const v0 = self.rect.position.add(lane.toward.scale(10));
        const v1 = v0.add(lane.perp.scale(60));
        self.positions[0] = v0.lerp(v1, (0.8 / 3.0));
        self.positions[1] = v0.lerp(v1, (2.2 / 3.0));
        // red slot
        self.slots[0] = .{
            .position = self.rect.position.add(lane.perp.scale(0)),
            .size = lane.toward.scale(20).add(lane.perp.scale(20)),
        };
        // toggle slot
        self.slots[1] = .{
            .position = self.rect.position.add(lane.perp.scale(20)),
            .size = lane.toward.scale(20).add(lane.perp.scale(20)),
        };
        // green slot
        self.slots[2] = .{
            .position = self.rect.position.add(lane.perp.scale(40)),
            .size = lane.toward.scale(20).add(lane.perp.scale(20)),
        };
    }

    pub fn isGreen(self: *const Self) bool {
        return self.signal == .green;
    }
    pub fn isRed(self: *const Self) bool {
        return self.signal == .red;
    }

    pub fn setEffect(self: *Self, effect: ConnectionEffect) void {
        switch (effect) {
            .toggle => self.signal = if (self.signal == .red) .green else .red,
            .set_red => self.signal = .red,
            .set_green => self.signal = .green,
        }
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.lane_index = std.fmt.parseInt(u8, tok, 10) catch unreachable;
            if (count == 3) self.signal = std.meta.stringToEnum(SignalState, tok).?;
            if (count == 4) self.disabled = helpers.parseBool(tok) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrintZ(arena, "sig|{d}|{s}|{}", .{ self.lane_index, @tagName(self.signal), self.disabled }) catch unreachable;
    }
};

const ConnectionEffect = enum {
    set_red,
    toggle,
    set_green,
};

const Connection = struct {
    effect: ConnectionEffect,
    sensor_slot: SensorSlot,
    signal_slot: SignalSlot,
};

const Path = struct {
    const Self = @This();
    points: [33]Vec2 = undefined,
    cumulative_distance: [33]f32 = undefined,

    pub fn initIntersection(source_lane_index: u8, destination_lane_index: u8, intersection: *const Intersection) Self {
        var self: Self = undefined;
        const car = Car{ .source_lane_index = source_lane_index, .destination_lane_index = destination_lane_index, .position_in_lane = 0 };
        const start = intersection.getCarPosition(&car);
        const start_lane = intersection.lanes.items[source_lane_index];
        const end_lane = intersection.lanes.items[destination_lane_index];
        const start_curve = start_lane.head;
        const end_curve = end_lane.head;
        const end = end_lane.head.add(end_lane.toward.scale(-SCREEN_SIZE.y * 0.6));
        var mid_point = start_curve.lerp(end_curve, 0.5);
        if (start_lane.direction.isOpposite(end_lane.direction))
            mid_point = INTERSECTION_MIDPOINT.add(end_lane.toward.scale(-20));
        if (start_lane.direction.isRightTurn(end_lane.direction))
            mid_point = INTERSECTION_MIDPOINT.add(end_lane.toward.scale(20)).add(start_lane.toward.scale(20));
        self.points[0] = start;
        self.points[1] = start_curve;
        self.points[MID_POINT_INDEX] = mid_point;
        self.points[self.points.len - 2] = end_curve;
        self.points[self.points.len - 1] = end;
        for (2..MID_POINT_INDEX) |i| {
            const fract = @floatFromInt(f32, i - 1) / (MID_POINT_INDEX - 1 - 1);
            self.points[i] = start_curve.lerp(mid_point, fract);
        }
        for (MID_POINT_INDEX + 1..self.points.len - 2) |i| {
            const fract = @floatFromInt(f32, i - MID_POINT_INDEX + 1) / (self.points.len - 2);
            self.points[i] = mid_point.lerp(end_curve, fract);
        }
        self.initDistances();
        return self;
    }

    pub fn initEndpoints(p0: Vec2, p1: Vec2) Self {
        var self: Self = undefined;
        for (0..self.points.len) |i| {
            const fract = @floatFromInt(f32, i) / (self.points.len - 1);
            self.points[i] = p0.lerp(p1, fract);
        }
        self.initDistances();
        return self;
    }

    fn initDistances(self: *Self) void {
        var dist: f32 = 0;
        self.cumulative_distance[0] = 0;
        for (self.points, 0..) |p0, i| {
            if (i == 0) continue;
            const p1 = self.points[i - 1];
            const d = p0.distance(p1);
            dist += d;
            self.cumulative_distance[i] = dist;
        }
    }

    pub fn progress(self: *const Self, amount: f32) Vec2 {
        if (amount >= 1) return self.points[self.points.len - 1];
        if (amount <= 0) return self.points[0];
        const dist = helpers.easeinoutf(0, 1, amount) * self.cumulative_distance[self.points.len - 1];
        for (self.points, self.cumulative_distance, 0..) |p1, d, i| {
            if (i == 0) continue;
            const prev_dist = self.cumulative_distance[i - 1];
            const next_dist = d;
            if (dist >= prev_dist and dist <= next_dist) {
                const p0 = self.points[i - 1];
                const fract = (dist - prev_dist) / (next_dist - prev_dist);
                return p0.lerp(p1, fract);
            }
        }
        return self.points[self.points.len - 1];
    }

    pub fn intersects(self: *const Self, other: Self) ?Vec2 {
        if (self.points[self.points.len - 1].distanceSqr(other.points[self.points.len - 1]) < 10) return self.points[self.points.len - 2];
        const line1 = Line{
            .p0 = self.points[1],
            .p1 = self.points[MID_POINT_INDEX],
        };
        const line2 = Line{
            .p0 = self.points[MID_POINT_INDEX],
            .p1 = self.points[self.points.len - 2],
        };
        const line3 = Line{
            .p0 = other.points[1],
            .p1 = other.points[MID_POINT_INDEX],
        };
        const line4 = Line{
            .p0 = other.points[MID_POINT_INDEX],
            .p1 = other.points[other.points.len - 2],
        };
        if (line1.intersects(line3)) |point| {
            return point;
        }
        if (line1.intersects(line4)) |point| {
            return point;
        }
        if (line2.intersects(line3)) |point| {
            return point;
        }
        if (line2.intersects(line4)) |point| {
            return point;
        }
        return null;
    }
};

const Car = struct {
    const Self = @This();
    source_lane_index: u8,
    destination_lane_index: u8,
    position_in_lane: u8 = undefined,
    position: Vec2 = undefined,
    target_position: ?Path = null,
    moved: bool = false,
    done: bool = false,
    progress: f32 = 0,

    pub fn setup(self: *Self, intersection: *const Intersection) void {
        self.position = intersection.getCarPosition(self);
    }

    pub fn reset(self: *Self, intersection: *const Intersection) void {
        self.moved = false;
        self.done = false;
        self.progress = 0;
        self.target_position = null;
        self.setup(intersection);
    }

    pub fn update(self: *Self) void {
        self.progress += 0.01;
        if (self.target_position) |tpos| {
            self.position = tpos.progress(self.progress);
        }
        if (self.moved and self.progress >= 1) self.done = true;
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.source_lane_index = std.fmt.parseInt(u8, tok, 10) catch unreachable;
            if (count == 3) self.destination_lane_index = std.fmt.parseInt(u8, tok, 10) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrintZ(arena, "car|{d}|{d}", .{ self.source_lane_index, self.destination_lane_index }) catch unreachable;
    }
};

const Intersection = struct {
    const Self = @This();
    lanes: std.ArrayList(Lane),
    sensors: std.ArrayList(LaneSensor),
    signals: std.ArrayList(Signal),
    connections: std.ArrayList(Connection),
    cars: std.ArrayList(Car),
    signal_states: std.ArrayList(SignalState),
    ticks: u64 = 0,
    steps: u8 = 0,
    crash_point: ?Vec2 = null,
    show_crash: bool = false,
    cleared: bool = false,
    paths: [16]Path = undefined,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .lanes = std.ArrayList(Lane).init(allocator),
            .sensors = std.ArrayList(LaneSensor).init(allocator),
            .signals = std.ArrayList(Signal).init(allocator),
            .signal_states = std.ArrayList(SignalState).init(allocator),
            .connections = std.ArrayList(Connection).init(allocator),
            .cars = std.ArrayList(Car).init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    fn setup(self: *Self) void {
        self.setupLanes();
        self.setupPaths();
    }

    fn isUTurn(self: *const Self, l0: u8, l1: u8) bool {
        const lane0 = self.lanes.items[l0];
        const lane1 = self.lanes.items[l1];
        if (lane0.lane == .outgoing and lane1.lane == .incoming) {
            if (lane0.direction.isOpposite(lane1.direction)) return true;
        }
        return false;
    }

    /// to store the initial level start values of all the signals
    fn setSignalStates(self: *Self) void {
        self.signal_states.clearRetainingCapacity();
        for (self.signals.items) |signal| self.signal_states.append(signal.signal) catch unreachable;
    }

    fn setupLanes(self: *Self) void {
        {
            const perp_offset = 20;
            const dir_offset = 150;
            // down to up lanes
            self.lanes.append(.{ .lane = .incoming, .direction = .upward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = -perp_offset, .y = dir_offset }),
                .size = .{ .x = -60, .y = SCREEN_SIZE.y * 0.5 },
            } }) catch unreachable;
            self.lanes.append(.{ .lane = .outgoing, .direction = .upward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = -perp_offset, .y = -dir_offset }),
                .size = .{ .x = -60, .y = SCREEN_SIZE.y * -0.5 },
            } }) catch unreachable;
            // up to down
            self.lanes.append(.{ .lane = .incoming, .direction = .downward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = perp_offset, .y = -dir_offset }),
                .size = .{ .x = 60, .y = SCREEN_SIZE.y * -0.5 },
            } }) catch unreachable;
            self.lanes.append(.{ .lane = .outgoing, .direction = .downward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = perp_offset, .y = dir_offset }),
                .size = .{ .x = 60, .y = SCREEN_SIZE.y * 0.5 },
            } }) catch unreachable;
            // left - right lanes
            self.lanes.append(.{ .lane = .incoming, .direction = .rightward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = -dir_offset, .y = -perp_offset }),
                .size = .{ .x = -SCREEN_SIZE.x, .y = -60 },
            } }) catch unreachable;
            self.lanes.append(.{ .lane = .outgoing, .direction = .rightward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = dir_offset, .y = -perp_offset }),
                .size = .{ .x = SCREEN_SIZE.x, .y = -60 },
            } }) catch unreachable;
            self.lanes.append(.{ .lane = .incoming, .direction = .leftward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = dir_offset, .y = perp_offset }),
                .size = .{ .x = SCREEN_SIZE.x, .y = 60 },
            } }) catch unreachable;
            self.lanes.append(.{ .lane = .outgoing, .direction = .leftward, .rect = .{
                .position = INTERSECTION_MIDPOINT.add(.{ .x = -dir_offset, .y = perp_offset }),
                .size = .{ .x = -SCREEN_SIZE.x, .y = 60 },
            } }) catch unreachable;
        }
        for (self.lanes.items) |*lane| lane.setup();
    }

    /// just set up all the paths to draw;
    fn setupPaths(self: *Self) void {
        self.paths[0] = Path.initIntersection(0, 5, self);
        // self.paths[1] = Path.initIntersection(2, 1, self);
        // self.paths[2] = Path.initIntersection(4, 7, self);
        // self.paths[3] = Path.initIntersection(6, 5, self);
    }

    pub fn update(self: *Self, ticks: u64, arena: std.mem.Allocator) void {
        self.ticks = ticks;
        self.arena = arena;
        for (self.cars.items) |*car| car.update();
        self.checkForCollision();
        self.checkForCleared();
        // if (self.crash_point) |pos| {
        //     if (self.show_crash) {
        //         for (self.cars.items) |*car| {
        //             if (car.done) continue;
        //             if (!car.moved) continue;
        //             car.position = pos;
        //         }
        //     }
        // }
    }

    fn getLanePosition(self: *const Self, lane_index: u8, position: u8) Vec2 {
        const lane = self.lanes.items[lane_index];
        const offset_amount: f32 = 1 + @floatFromInt(f32, position);
        const offset = lane.toward.scale(-1 * CAR_SPACING * offset_amount);
        return lane.head.add(offset);
    }

    fn getCarPosition(self: *const Self, car: *const Car) Vec2 {
        return self.getLanePosition(car.source_lane_index, car.position_in_lane);
    }

    fn checkForCleared(self: *Self) void {
        if (self.crash_point != null) return;
        var cleared = true;
        for (self.cars.items) |*car| {
            if (!car.done) cleared = false;
        }
        self.cleared = cleared;
    }

    /// Check all the paths. If there is an intersection, then there is a collision
    /// also collision if multiple cars are going to same endpoint
    fn checkForCollision(self: *Self) void {
        var paths = std.ArrayList(Path).init(self.arena);
        for (self.cars.items) |*car| {
            if (car.done) continue;
            if (car.target_position) |tpos| paths.append(tpos) catch unreachable;
        }
        var crashed = false;
        collision_check: {
            for (paths.items, 0..) |path, i| {
                for (paths.items[i + 1 ..]) |path2| {
                    if (path.intersects(path2)) |point| {
                        crashed = true;
                        self.crash_point = point;
                        break :collision_check;
                    }
                }
            }
        }
        if (crashed) {
            for (self.cars.items) |*car| {
                if (car.done) continue;
                car.progress = @min(car.progress, 0.25);
                if (car.progress == 0.25) self.show_crash = true;
            }
        }
    }

    fn step(self: *Self) void {
        for (self.cars.items) |*car| {
            if (car.moved) car.progress = 1;
        }
        var cars_to_move = std.ArrayList(usize).init(self.arena);
        defer cars_to_move.deinit();
        for (self.cars.items, 0..) |*car, i| {
            if (self.carCanMove(car)) cars_to_move.append(i) catch unreachable;
        }
        for (cars_to_move.items) |car_index| self.moveCar(car_index);
        if (cars_to_move.items.len > 0) self.steps += 1;
    }

    fn carCanMove(self: *Self, car: *Car) bool {
        if (self.signalAt(car.source_lane_index)) |signal| {
            return !car.moved and car.position_in_lane == 0 and signal.isGreen();
        }
        return false;
    }

    fn moveCar(self: *Self, car_index: usize) void {
        var car = &self.cars.items[car_index];
        if (car.moved) return;
        car.moved = true;
        car.progress = 0;
        car.target_position = Path.initIntersection(car.source_lane_index, car.destination_lane_index, self);
        if (self.sensorAt(car.source_lane_index)) |sensor| {
            var conn_memory: [2]Connection = undefined;
            for (self.connectionsAt(sensor.lane_index, &conn_memory)) |conn| {
                self.signals.items[conn.signal_slot.signal_index].setEffect(conn.effect);
            }
        }
        if (self.sensorAt(car.destination_lane_index)) |sensor| {
            var conn_memory: [2]Connection = undefined;
            for (self.connectionsAt(sensor.lane_index, &conn_memory)) |conn| {
                self.signals.items[conn.signal_slot.signal_index].setEffect(conn.effect);
            }
        }
        for (self.cars.items) |*other_car| {
            if (other_car.moved) continue;
            if (other_car.source_lane_index == car.source_lane_index) {
                other_car.target_position = Path.initEndpoints(self.getLanePosition(car.source_lane_index, other_car.position_in_lane), self.getLanePosition(car.source_lane_index, other_car.position_in_lane - 1));
                other_car.position_in_lane -= 1;
                other_car.progress = 0;
            }
        }
    }

    fn signalAt(self: *Self, lane_index: u8) ?*Signal {
        for (self.signals.items) |*signal| {
            if (signal.lane_index == lane_index) return signal;
        }
        return null;
    }

    fn connectionsAt(self: *Self, sensor_index: u8, conn_memory: *[2]Connection) []Connection {
        var count: usize = 0;
        for (self.connections.items) |*conn| {
            if (conn.sensor_slot.sensor_index == sensor_index) {
                conn_memory[count] = conn.*;
                count += 1;
            }
        }
        return conn_memory[0..count];
    }

    fn sensorAt(self: *Self, lane_index: u8) ?*LaneSensor {
        for (self.sensors.items) |*sensor| {
            if (sensor.lane_index == lane_index) return sensor;
        }
        return null;
    }

    fn removeConnectionAt(self: *Self, sensor_slot: SensorSlot) void {
        if (self.steps > 0) return;
        for (self.connections.items, 0..) |conn, i| {
            if (conn.sensor_slot.equal(sensor_slot)) {
                _ = self.connections.orderedRemove(i);
                break;
            }
        }
    }

    fn addConnection(self: *Self, sensor_slot: SensorSlot, signal_slot: SignalSlot) void {
        if (self.steps > 0) return;
        self.connections.append(.{
            .effect = @enumFromInt(ConnectionEffect, signal_slot.slot_index),
            .sensor_slot = sensor_slot,
            .signal_slot = signal_slot,
        }) catch unreachable;
    }

    fn addCar(self: *Self, src_lane_index: u8, dst_lane_index: u8) void {
        self.cars.append(.{ .source_lane_index = src_lane_index, .destination_lane_index = dst_lane_index }) catch unreachable;
        self.resetCars();
    }

    fn removeCar(self: *Self, lane_index: u8) void {
        var i: usize = self.cars.items.len - 1;
        while (i >= 0) : (i -= 1) {
            const car = self.cars.items[i];
            if (car.source_lane_index == lane_index) {
                _ = self.cars.orderedRemove(i);
                break;
            }
            if (i == 0) break;
        }
        self.resetCars();
    }

    fn resetLevel(self: *Self) void {
        self.resetCars();
        self.resetSignals();
        self.show_crash = false;
        self.crash_point = null;
        self.steps = 0;
        self.cleared = false;
    }

    fn resetSignals(self: *Self) void {
        std.debug.assert(self.signals.items.len == self.signal_states.items.len);
        for (self.signals.items, self.signal_states.items) |*sig, state| sig.signal = state;
    }

    fn resetCars(self: *Self) void {
        var lane_positions = std.ArrayList(u8).init(self.arena);
        for (0..self.lanes.items.len) |_| lane_positions.append(0) catch unreachable;
        defer lane_positions.deinit();
        for (self.cars.items) |*car| {
            car.position_in_lane = lane_positions.items[car.source_lane_index];
            lane_positions.items[car.source_lane_index] += 1;
            car.reset(self);
        }
    }

    fn clearConnections(self: *Self) void {
        self.resetLevel();
        self.connections.clearRetainingCapacity();
    }

    fn deserialize(self: *Self, str: []const u8) void {
        self.cars.clearRetainingCapacity();
        self.signals.clearRetainingCapacity();
        self.sensors.clearRetainingCapacity();
        self.connections.clearRetainingCapacity();
        var tokens = std.mem.split(u8, str, " ");
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, token[0..3], "car")) {
                var car: Car = undefined;
                car.deserialize(token);
                car.setup(self);
                self.cars.append(car) catch unreachable;
            }
            if (std.mem.eql(u8, token[0..3], "sig")) {
                var sig: Signal = undefined;
                sig.deserialize(token);
                sig.setup(self);
                self.signals.append(sig) catch unreachable;
            }
            if (std.mem.eql(u8, token[0..3], "sen")) {
                var sen: LaneSensor = undefined;
                sen.deserialize(token);
                sen.setup(self);
                self.sensors.append(sen) catch unreachable;
            }
        }
        self.setSignalStates();
        self.resetLevel();
    }

    fn serialize(self: *const Self, arena: std.mem.Allocator) []const u8 {
        var str = std.ArrayList(u8).init(arena);
        for (self.cars.items) |car| {
            var tok = car.serialize(arena);
            str.appendSlice(tok) catch unreachable;
            str.append(' ') catch unreachable;
        }
        for (self.signals.items) |sig| {
            var tok = sig.serialize(arena);
            str.appendSlice(tok) catch unreachable;
            str.append(' ') catch unreachable;
        }
        for (self.sensors.items) |sen| {
            var tok = sen.serialize(arena);
            str.appendSlice(tok) catch unreachable;
            str.append(' ') catch unreachable;
        }
        const serialized = std.mem.trimRight(u8, str.items, " ");
        return serialized;
    }
};

const SensorSlot = struct {
    const Self = @This();
    sensor_index: u8,
    slot_index: u8,

    pub fn equal(s1: *const Self, s2: Self) bool {
        return s1.sensor_index == s2.sensor_index and s1.slot_index == s2.slot_index;
    }
};

const SignalSlot = struct {
    const Self = @This();
    signal_index: u8,
    slot_index: u8,

    pub fn equal(s1: *const Self, s2: Self) bool {
        return s1.signal_index == s2.signal_index and s1.slot_index == s2.slot_index;
    }
};

const StateData = union(enum) {
    idle: struct {
        hovered_sensor: ?SensorSlot = null,
    },
    idle_drag: void,
    creating_connection: struct {
        starting_slot: SensorSlot,
        ending_slot: ?SignalSlot = null,
    },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    intersection: Intersection,
    cursor: CursorStyle = .default,
    dev_mode: bool = false,
    levels_complete: [LEVELS.len]bool = [_]bool{false} ** LEVELS.len,
    level_index: u8 = 0,
    buttons: std.ArrayList(Button),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
            .buttons = std.ArrayList(Button).init(allocator),
            .intersection = Intersection.init(allocator, arena_handle.allocator()),
        };
        self.intersection.deserialize(LEVELS[self.level_index].data);
        self.setupButtons();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.buttons.deinit();
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.cursor = .default;
        if (!self.dev_mode) {
            if (self.haathi.inputs.getKey(.space).is_clicked) self.intersection.step();
            if (self.haathi.inputs.getKey(.r).is_clicked) self.intersection.resetLevel();
        }
        if (self.haathi.inputs.getKey(.num_1).is_clicked) self.toggleDevMode();
        if (self.haathi.inputs.getKey(.n).is_clicked) self.setNextLevel();
        if (self.dev_mode and self.haathi.inputs.getKey(.s).is_clicked) helpers.debugPrint("{s}", .{self.intersection.serialize(self.arena)});
        if (self.dev_mode and self.haathi.inputs.getKey(.t).is_clicked) self.intersection.deserialize(test_1);
        self.intersection.update(ticks, self.arena);
        self.updateMouse();
        self.updateCompletions();
    }

    fn toggleDevMode(self: *Self) void {
        self.dev_mode = !self.dev_mode;
        self.intersection.clearConnections();
        self.intersection.resetLevel();
    }

    fn setupButtons(self: *Self) void {
        {
            const button_size = Vec2{ .x = 30, .y = 24 };
            self.buttons.append(.{
                .rect = .{
                    .position = .{ .x = PANE_X + PANE_PADDING, .y = SCREEN_SIZE.y - (PANE_PADDING + button_size.y + 20) },
                    .size = button_size,
                },
                .value = @intCast(u8, @intFromEnum(ButtonAction.prev_level)),
                .text = "<",
            }) catch unreachable;
            self.buttons.append(.{
                .rect = .{
                    .position = .{ .x = SCREEN_SIZE.x - PANE_PADDING - button_size.x, .y = SCREEN_SIZE.y - (PANE_PADDING + button_size.y + 20) },
                    .size = button_size,
                },
                .value = @intCast(u8, @intFromEnum(ButtonAction.next_level)),
                .text = ">",
            }) catch unreachable;
        }
        {
            const button_size = Vec2{ .x = 100, .y = 24 };
            const row_y = SCREEN_SIZE.y - (2 * (PANE_PADDING + button_size.y)) + 20 - PANE_PADDING;
            self.buttons.append(.{
                .rect = .{
                    .position = .{
                        .x = PANE_X + PANE_PADDING,
                        .y = row_y,
                    },
                    .size = button_size,
                },
                .value = @intCast(u8, @intFromEnum(ButtonAction.clear_level)),
                .text = "Clear",
            }) catch unreachable;
            self.buttons.append(.{
                .rect = .{
                    .position = .{
                        .x = SCREEN_SIZE.x - button_size.x - PANE_PADDING,
                        .y = row_y,
                    },
                    .size = button_size,
                },
                .value = @intCast(u8, @intFromEnum(ButtonAction.step_forward)),
                .text = "Step",
            }) catch unreachable;
            self.buttons.append(.{
                .rect = .{
                    .position = .{
                        .x = SCREEN_SIZE.x - (2 * (button_size.x + PANE_PADDING)),
                        .y = row_y,
                    },
                    .size = button_size,
                },
                .value = @intCast(u8, @intFromEnum(ButtonAction.reset_level)),
                .text = "Reset",
            }) catch unreachable;
        }
    }

    fn setNextLevel(self: *Self) void {
        self.level_index = helpers.applyChangeLooped(self.level_index, 1, LEVELS.len - 1);
        self.intersection.deserialize(LEVELS[self.level_index].data);
    }

    fn updateCompletions(self: *Self) void {
        if (self.intersection.cleared) self.levels_complete[self.level_index] = true;
    }

    fn updateMouse(self: *Self) void {
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        if (self.dev_mode) {
            if (self.haathi.inputs.mouse.l_button.is_clicked) {
                // if clicked on sensor toggle sensor enable
                for (self.intersection.sensors.items) |*sensor| {
                    if (sensor.rect.contains(mouse_pos)) {
                        sensor.disabled = !sensor.disabled;
                        return;
                    }
                }
                // if clicked on lane, add car to lane.
                for (self.intersection.lanes.items, 0..) |lane, i| {
                    if (lane.lane == .outgoing) continue;
                    if (lane.rect.contains(mouse_pos)) {
                        self.intersection.addCar(@intCast(u8, i), @intCast(u8, i + 1));
                        return;
                    }
                }
                // if clicked on signal, toggle signal.
                for (self.intersection.signals.items) |*signal| {
                    if (signal.rect.contains(mouse_pos)) {
                        signal.setEffect(.toggle);
                        self.intersection.setSignalStates();
                        return;
                    }
                }
            }
            if (self.haathi.inputs.mouse.r_button.is_clicked) {
                // if clicked on sensor toggle sensor enable
                for (self.intersection.sensors.items) |*sensor| {
                    if (sensor.rect.contains(mouse_pos)) {
                        sensor.disabled = !sensor.disabled;
                        return;
                    }
                }
                // if clicked on lane, remove 1 car from lane.
                for (self.intersection.lanes.items, 0..) |lane, i| {
                    if (lane.lane == .outgoing) continue;
                    if (lane.rect.contains(mouse_pos)) {
                        self.intersection.removeCar(@intCast(u8, i));
                        return;
                    }
                }
                // if clicked on signal, toggle signal enable
                for (self.intersection.signals.items) |*signal| {
                    if (signal.rect.contains(mouse_pos)) {
                        signal.disabled = !signal.disabled;
                        return;
                    }
                }
            }
            if (self.haathi.inputs.mouse.wheel_y != 0) {
                const destination_lanes = [_]u8{ 1, 5, 3, 7 };
                for (self.intersection.cars.items) |*car| {
                    if (car.position.distanceSqr(mouse_pos) < std.math.pow(f32, CAR_SIZE.x, 2)) {
                        const current = std.mem.indexOfScalar(u8, destination_lanes[0..], car.destination_lane_index).?;
                        const next_index = helpers.applyChangeLooped(@intCast(u8, current), @intCast(i8, std.math.sign(self.haathi.inputs.mouse.wheel_y)), destination_lanes.len - 1);
                        car.destination_lane_index = destination_lanes[next_index];
                        return;
                    }
                }
                // if clicked on sensor toggle sensor enable
                for (self.intersection.sensors.items) |*sensor| {
                    if (sensor.rect.contains(mouse_pos)) {
                        sensor.num_slots = if (sensor.num_slots == 2) 1 else 2;
                        return;
                    }
                }
            }
            return;
        }
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.buttons.items) |button| {
            if (button.clicked) self.performAction(@enumFromInt(ButtonAction, button.value));
        }
        switch (self.state) {
            .idle => |_| {
                self.state.idle.hovered_sensor = null;
                for (self.intersection.sensors.items, 0..) |sensor, sensor_index| {
                    if (sensor.disabled) continue;
                    if (sensor.rect.contains(mouse_pos)) {
                        for (sensor.slots(), 0..) |slot, slot_index| {
                            if (slot.contains(mouse_pos)) {
                                self.cursor = .pointer;
                                self.state.idle.hovered_sensor = .{
                                    .sensor_index = @intCast(u8, sensor_index),
                                    .slot_index = @intCast(u8, slot_index),
                                };
                            }
                        }
                    }
                }
                if (!self.interactionsAllowed()) return;
                if (self.haathi.inputs.mouse.l_button.is_clicked) {
                    if (self.intersection.steps == 0) {
                        if (self.state.idle.hovered_sensor) |hovered_sensor| {
                            self.intersection.removeConnectionAt(hovered_sensor);
                            self.state = .{
                                .creating_connection = .{
                                    .starting_slot = hovered_sensor,
                                },
                            };
                        } else {
                            self.state = .idle_drag;
                        }
                    } else {
                        self.state = .idle_drag;
                    }
                }
                if (self.haathi.inputs.mouse.r_button.is_clicked) {
                    if (self.state.idle.hovered_sensor) |hovered_sensor| {
                        self.intersection.removeConnectionAt(hovered_sensor);
                    }
                }
            },
            .idle_drag => {
                if (self.haathi.inputs.mouse.l_button.is_released) {
                    self.state = .{ .idle = .{} };
                }
            },
            .creating_connection => |data| {
                self.cursor = .pointer;
                self.state.creating_connection.ending_slot = null;
                find_signal_slot: {
                    for (self.intersection.signals.items, 0..) |signal, signal_index| {
                        if (signal.disabled) continue;
                        for (signal.slots, 0..) |slot, slot_index| {
                            if (slot.contains(mouse_pos)) {
                                self.state.creating_connection.ending_slot = .{
                                    .signal_index = @intCast(u8, signal_index),
                                    .slot_index = @intCast(u8, slot_index),
                                };
                                break :find_signal_slot;
                            }
                        }
                    }
                }
                if (self.haathi.inputs.mouse.l_button.is_released) {
                    if (self.state.creating_connection.ending_slot) |signal_slot| {
                        self.intersection.addConnection(data.starting_slot, signal_slot);
                    }
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }

    fn performAction(self: *Self, action: ButtonAction) void {
        switch (action) {
            .prev_level => {
                if (self.level_index > 0) {
                    self.level_index -= 1;
                    self.intersection.deserialize(LEVELS[self.level_index].data);
                }
            },
            .next_level => {
                if (self.level_index < LEVELS.len - 1) {
                    self.level_index += 1;
                    self.intersection.deserialize(LEVELS[self.level_index].data);
                }
            },
            .reset_level => self.intersection.resetLevel(),
            .clear_level => self.intersection.clearConnections(),
            .step_forward => self.intersection.step(),
        }
    }

    fn interactionsAllowed(self: *Self) bool {
        return self.intersection.steps == 0;
    }

    pub fn render(self: *Self) void {
        if (self.interactionsAllowed())
            self.haathi.setCursor(self.cursor)
        else
            self.haathi.setCursor(.default);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.solarized_base3,
        });
        for (self.intersection.paths) |path| {
            var points = self.arena.alloc(Vec2, 33) catch unreachable;
            for (path.points, 0..) |point, i| points[i] = point;
            self.haathi.drawPath(.{
                .points = points[0..],
                .color = colors.solarized_base2,
                .width = 60,
            });
        }
        for (self.intersection.lanes.items, 0..) |lane, i| {
            self.haathi.drawRect(.{
                .position = lane.rect.position,
                .size = lane.rect.size,
                .color = colors.solarized_base1,
            });
            if (false) {
                const str = std.fmt.allocPrintZ(self.arena, "{d}", .{i}) catch unreachable;
                self.haathi.drawText(.{
                    .text = str,
                    .position = lane.head,
                    .color = colors.solarized_base03,
                    .style = FONT_1,
                });
            }
        }
        const alpha: f32 = if (self.interactionsAllowed()) 1 else 0.3;
        for (self.intersection.sensors.items) |sensor| {
            if (sensor.disabled) continue;
            self.haathi.drawRect(.{
                .position = sensor.rect.position,
                .size = sensor.rect.size,
                .radius = 0,
                .color = colors.solarized_base3.alpha(alpha),
            });
            for (sensor.slots()) |slot| {
                self.haathi.drawRect(.{
                    .position = slot.position,
                    .size = slot.size,
                    .radius = 2,
                    .color = colors.solarized_base2.alpha(alpha),
                });
                self.haathi.drawRect(.{
                    .position = slot.center(),
                    .size = .{ .x = 10, .y = 10 },
                    .radius = 10,
                    .color = colors.solarized_base1.alpha(alpha),
                    .centered = true,
                });
            }
        }
        for (self.intersection.connections.items) |conn| {
            var points = self.arena.alloc(Vec2, 2) catch unreachable;
            points[0] = self.intersection.sensors.items[conn.sensor_slot.sensor_index].slots()[conn.sensor_slot.slot_index].center();
            points[1] = self.intersection.signals.items[conn.signal_slot.signal_index].slots[conn.signal_slot.slot_index].center();
            self.haathi.drawPath(.{
                .points = points,
                .width = 8,
                .color = colors.solarized_base2,
            });
        }
        for (self.intersection.cars.items) |car| {
            self.haathi.drawRect(.{
                .position = car.position,
                .size = CAR_SIZE,
                .radius = 8,
                .color = colors.solarized_base01,
                .centered = true,
            });
            var points = self.arena.alloc(Vec2, ARROW.len) catch unreachable;
            var target: Vec2 = .{};
            switch (self.intersection.lanes.items[car.destination_lane_index].direction) {
                .upward => target = .{ .y = -1 },
                .downward => target = .{ .y = 1 },
                .leftward => target = .{ .x = -1 },
                .rightward => target = .{ .x = 1 },
            }
            for (ARROW, 0..) |p, i| points[i] = car.position.add(p.alignTo(.{ .x = 1 }, target));
            self.haathi.drawPoly(.{
                .points = points,
                .color = colors.solarized_base02,
            });
        }
        for (self.intersection.signals.items) |signal| {
            if (signal.disabled) continue;
            self.haathi.drawRect(.{
                .position = signal.rect.position,
                .size = signal.rect.size,
                .color = colors.solarized_base03,
                .radius = 8,
            });
            if (self.state == .creating_connection) {
                const signal_slot_colors = [_]Vec4{ colors.solarized_red, colors.solarized_base1, colors.solarized_green };
                for (signal.slots, 0..) |slot, i| {
                    self.haathi.drawRect(.{
                        .position = slot.position,
                        .size = slot.size,
                        .radius = 1,
                        .color = colors.solarized_base03,
                    });
                    self.haathi.drawRect(.{
                        .position = slot.center(),
                        .size = .{ .x = 14, .y = 14 },
                        .radius = 8,
                        .color = signal_slot_colors[i],
                        .centered = true,
                    });
                    self.haathi.drawRect(.{
                        .position = slot.center(),
                        .size = .{ .x = 10, .y = 10 },
                        .radius = 8,
                        .color = colors.solarized_base02,
                        .centered = true,
                    });
                }
            } else {
                for (signal.positions) |pos| {
                    self.haathi.drawRect(.{
                        .position = pos,
                        .size = .{ .x = 14, .y = 14 },
                        .radius = 14,
                        .color = colors.solarized_base01,
                        .centered = true,
                    });
                }
                const color = switch (signal.signal) {
                    .red => colors.solarized_red,
                    .green => colors.solarized_green,
                };
                const position = switch (signal.signal) {
                    .red => signal.positions[0],
                    .green => signal.positions[1],
                };
                self.haathi.drawRect(.{
                    .position = position,
                    .size = .{ .x = 14, .y = 14 },
                    .radius = 12,
                    .color = color,
                    .centered = true,
                });
            }
        }
        if (self.state == .creating_connection) {
            var points = self.arena.alloc(Vec2, 2) catch unreachable;
            const sensor_slot = self.state.creating_connection.starting_slot;
            points[0] = self.intersection.sensors.items[sensor_slot.sensor_index].slots()[sensor_slot.slot_index].center();
            if (self.state.creating_connection.ending_slot) |signal_slot| {
                points[1] = self.intersection.signals.items[signal_slot.signal_index].slots[signal_slot.slot_index].center();
            } else {
                points[1] = self.haathi.inputs.mouse.current_pos;
            }
            self.haathi.drawPath(.{
                .points = points,
                .width = 8,
                .color = colors.solarized_base1,
            });
        }
        if (self.intersection.show_crash) {
            var crash = std.ArrayList(Vec2).init(self.arena);
            const crash_point = self.intersection.crash_point orelse INTERSECTION_MIDPOINT;
            var rng = std.rand.DefaultPrng.init(42);
            var ang: f32 = 0;
            var inside: bool = true;
            while (ang < 2.0 * std.math.pi) : (ang += (2.0 * std.math.pi / 16.0)) {
                const size: f32 = if (inside) 20 else 60;
                const rand = 0.4 + (rng.random().float(f32) * 0.6);
                inside = !inside;
                const first = Vec2{ .x = 1 };
                crash.append(crash_point.add(first.scale(size * rand).rotate(ang))) catch unreachable;
            }
            self.haathi.drawPoly(.{
                .points = crash.items[0..],
                .color = colors.solarized_red,
            });
        }
        if (self.dev_mode) {
            self.haathi.drawText(.{
                .text = "dev mode",
                .position = .{ .x = 60, .y = 30 },
                .color = colors.solarized_blue,
                .style = FONT_1,
            });
        }
        if (self.intersection.cleared) {
            self.haathi.drawText(.{
                .text = "Intersection",
                .position = INTERSECTION_MIDPOINT.add(.{ .y = -10 }),
                .color = colors.solarized_base03,
                .style = FONT_2,
            });
            self.haathi.drawText(.{
                .text = "Cleared",
                .position = INTERSECTION_MIDPOINT.add(.{ .y = 20 }),
                .color = colors.solarized_base03,
                .style = FONT_2,
            });
        }
        self.haathi.drawRect(.{
            .position = .{ .x = PANE_X, .y = 0 },
            .size = .{ .x = PANE_WIDTH, .y = SCREEN_SIZE.y },
            .color = colors.solarized_base03,
        });
        for (self.buttons.items) |button| {
            if (button.hovered) {
                self.haathi.drawRect(.{
                    .position = button.rect.position.add(.{ .x = -4, .y = -4 }),
                    .size = button.rect.size.add(.{ .x = 8, .y = 8 }),
                    .color = colors.solarized_base1,
                    .radius = 4 + 4,
                });
            }
            if (button.triggered) {
                self.haathi.drawRect(.{
                    .position = button.rect.position.add(.{ .x = -4, .y = -4 }),
                    .size = button.rect.size.add(.{ .x = 8, .y = 8 }),
                    .color = colors.solarized_base2,
                    .radius = 4 + 4,
                });
            }
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = colors.solarized_base00,
                .radius = 4,
            });
            self.haathi.drawText(.{
                .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 6 }),
                .text = button.text,
                .style = FONT_1,
                .color = colors.solarized_base03,
            });
        }
        {
            const lev_name = std.fmt.allocPrintZ(self.arena, "{d}: {s}", .{ self.level_index + 1, LEVELS[self.level_index].name }) catch unreachable;
            self.haathi.drawText(.{
                .text = lev_name,
                .position = .{ .x = PANE_WIDTH / 2 + PANE_X, .y = SCREEN_SIZE.y - (PANE_PADDING * 2) + 4 },
                .style = FONT_1,
                .color = colors.solarized_base00,
            });
        }
        // draw level completions
        {
            const indicator_size = Vec2{ .x = 30, .y = 24 };
            const width = PANE_WIDTH - (PANE_PADDING * 2);
            const padding = (width - (indicator_size.x * @floatFromInt(f32, LEVELS.len))) / @floatFromInt(f32, LEVELS.len - 1);
            const start_x = PANE_X + PANE_PADDING;
            const start_y = SCREEN_SIZE.y - PANE_PADDING - 8;
            for (self.levels_complete, 0..) |lev, i| {
                const fi = @floatFromInt(f32, i);
                const x = start_x + (indicator_size.x * fi) + (padding * fi);
                if (i == self.level_index) {
                    self.haathi.drawRect(.{
                        .position = (Vec2{ .x = x, .y = start_y }).add(.{ .x = -3, .y = -3 }),
                        .size = indicator_size.add(.{ .x = 6, .y = 6 }),
                        .color = colors.solarized_base1,
                        .radius = 7,
                    });
                }
                self.haathi.drawRect(.{
                    .position = .{ .x = x, .y = start_y },
                    .size = indicator_size,
                    .color = colors.solarized_base00,
                    .radius = 4,
                });
                if (lev) {
                    self.haathi.drawRect(.{
                        .position = (Vec2{ .x = x, .y = start_y }).add(.{ .x = 6, .y = 6 }),
                        .size = indicator_size.add(.{ .x = -12, .y = -12 }),
                        .color = colors.solarized_base02,
                        .radius = 2,
                    });
                }
            }
        }
    }
};
