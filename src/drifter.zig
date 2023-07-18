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

const FONT_1 = "18px JetBrainsMono";
const INTERSECTION_MIDPOINT = Vec2{ .x = (SCREEN_SIZE.x * 0.5), .y = SCREEN_SIZE.y * 0.5 };

const CAR_SPACING = 50;
const LaneType = enum {
    incoming,
    outgoing,
};

const Direction = enum {
    leftward,
    rightward,
    downward,
    upward,
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

const LaneTrigger = struct {
    const Self = @This();
    lane_index: u8,
    rect: Rect = undefined,
    num_slots: u8 = 2,
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
        std.debug.assert(self.num_slots == 2); // have to make this dynamic if we have 3 or 4
    }

    pub fn slots(self: *const Self) []const Rect {
        return self.slots_memory[0..self.num_slots];
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

    pub fn setup(self: *Self, intersection: *const Intersection) void {
        const lane = intersection.lanes.items[self.lane_index];
        self.rect.size = (Vec2{}).add(lane.perp.scale(60)).add(lane.toward.scale(20));
        const offset = lane.toward.scale(25);
        self.rect.position = lane.head.add(self.rect.size.scale(-0.5)).add(offset);
        const v0 = self.rect.position.add(lane.toward.scale(10));
        const v1 = v0.add(lane.perp.scale(60));
        self.positions[0] = v0.lerp(v1, (1.0 / 3.0));
        self.positions[1] = v0.lerp(v1, (2.0 / 3.0));
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
};

const ConnectionEffect = enum {
    toggle,
    set_red,
    set_green,
};

const Connection = struct {
    effect: ConnectionEffect,
    trigger_index: u8,
    signal_index: u8,
};

const Path = struct {
    const Self = @This();
    start: Vec2,
    midpoint: Vec2,
    endpoint: Vec2,

    pub fn progress(self: *const Self, amount: f32) Vec2 {
        if (amount < 0.5) {
            const val = amount * 2;
            return self.start.lerp(self.midpoint, val);
        } else if (amount < 1) {
            const val = (amount - 0.5) * 2;
            return self.midpoint.lerp(self.endpoint, val);
        } else {
            return self.endpoint;
        }
    }
};

const Car = struct {
    const Self = @This();
    source_lane_index: u8,
    destination_lane_index: u8,
    position_in_lane: u8,
    position: Vec2 = undefined,
    target_position: ?Path = null,
    moved: bool = false,
    done: bool = false,
    progress: f32 = 0,

    pub fn setup(self: *Self, intersection: *const Intersection) void {
        self.position = intersection.getCarPosition(self);
    }

    pub fn update(self: *Self) void {
        self.progress += 0.005;
        if (self.target_position) |tpos| self.position = tpos.progress(self.progress);
        if (self.moved and self.progress >= 1) self.done = true;
    }
};

const Intersection = struct {
    const Self = @This();
    lanes: std.ArrayList(Lane),
    triggers: std.ArrayList(LaneTrigger),
    signals: std.ArrayList(Signal),
    connections: std.ArrayList(Connection),
    cars: std.ArrayList(Car),
    ticks: u64 = 0,
    crashed: bool = false,
    show_crash: bool = false,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .lanes = std.ArrayList(Lane).init(allocator),
            .triggers = std.ArrayList(LaneTrigger).init(allocator),
            .signals = std.ArrayList(Signal).init(allocator),
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
        // signals
        self.signals.append(.{
            .signal = .green,
            .lane_index = 0,
        }) catch unreachable;
        self.signals.append(.{
            .signal = .red,
            .lane_index = 2,
        }) catch unreachable;
        self.signals.append(.{
            .signal = .red,
            .lane_index = 4,
        }) catch unreachable;
        self.signals.append(.{
            .signal = .red,
            .lane_index = 6,
        }) catch unreachable;
        for (self.signals.items) |*signal| signal.setup(self);
        // // cars
        // self.cars.append(.{
        //     .source_lane_index = 0,
        //     .destination_lane_index = 1,
        //     .position_in_lane = 0,
        // }) catch unreachable;
        // self.cars.append(.{
        //     .source_lane_index = 2,
        //     .destination_lane_index = 3,
        //     .position_in_lane = 0,
        // }) catch unreachable;
        // self.cars.append(.{
        //     .source_lane_index = 0,
        //     .destination_lane_index = 3,
        //     .position_in_lane = 1,
        // }) catch unreachable;
        // for (self.cars.items) |*car| car.setup(self);
        for (self.lanes.items, 0..) |_, i| {
            var trigger = LaneTrigger{ .lane_index = @intCast(u8, i) };
            trigger.setup(self);
            self.triggers.append(trigger) catch unreachable;
        }
        // // connections
        // self.connections.append(.{
        //     .effect = .set_green,
        //     .trigger_index = 0,
        //     .signal_index = 1,
        // }) catch unreachable;
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

    pub fn update(self: *Self, ticks: u64, arena: std.mem.Allocator) void {
        self.ticks = ticks;
        self.arena = arena;
        for (self.cars.items) |*car| car.update();
        self.checkForCollision();
    }

    fn getCarPosition(self: *const Self, car: *const Car) Vec2 {
        const lane = self.lanes.items[car.source_lane_index];
        const offset_amount: f32 = 1 + @floatFromInt(f32, car.position_in_lane);
        const offset = lane.toward.scale(-1 * CAR_SPACING * offset_amount);
        return lane.head.add(offset);
    }

    /// for now there is a collision if 2 cars move together. Later on, we can
    /// adjust this.
    fn checkForCollision(self: *Self) void {
        var count: usize = 0;
        for (self.cars.items) |*car| {
            if (car.done) continue;
            if (car.moved) count += 1;
        }
        if (count > 1) {
            self.crashed = true;
            for (self.cars.items) |*car| {
                if (car.done) continue;
                car.progress = @min(car.progress, 0.45);
                if (car.progress == 0.45) self.show_crash = true;
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
        const target_lane = self.lanes.items[car.destination_lane_index];
        car.target_position = .{
            .start = car.position,
            .midpoint = INTERSECTION_MIDPOINT,
            .endpoint = INTERSECTION_MIDPOINT.add(target_lane.toward.scale(-500)),
        };
        if (self.triggerAt(car.source_lane_index)) |trig| {
            if (self.connectionAt(trig.lane_index)) |conn| {
                self.signals.items[conn.signal_index].setEffect(conn.effect);
            }
        }
        if (self.triggerAt(car.destination_lane_index)) |trig| {
            if (self.connectionAt(trig.lane_index)) |conn| {
                self.signals.items[conn.signal_index].setEffect(conn.effect);
            }
        }
        for (self.cars.items) |*other_car| {
            if (other_car.moved) continue;
            if (other_car.source_lane_index == car.source_lane_index) {
                other_car.position_in_lane -= 1;
                other_car.progress = 0;
                other_car.target_position = .{
                    .start = other_car.position,
                    .midpoint = self.getCarPosition(other_car),
                    .endpoint = self.getCarPosition(other_car),
                };
            }
        }
    }

    fn signalAt(self: *Self, lane_index: u8) ?*Signal {
        for (self.signals.items) |*signal| {
            if (signal.lane_index == lane_index) return signal;
        }
        return null;
    }

    fn connectionAt(self: *Self, trigger_index: u8) ?*Connection {
        for (self.connections.items) |*conn| {
            if (conn.trigger_index == trigger_index) return conn;
        }
        return null;
    }

    fn triggerAt(self: *Self, lane_index: u8) ?*LaneTrigger {
        for (self.triggers.items) |*trig| {
            if (trig.lane_index == lane_index) return trig;
        }
        return null;
    }
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    intersection: Intersection,
    cursor: CursorStyle = .default,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        return .{
            .haathi = haathi,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
            .intersection = Intersection.init(allocator, arena_handle.allocator()),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.cursor = .default;
        if (self.haathi.inputs.getKey(.space).is_clicked) self.intersection.step();
        self.intersection.update(ticks, self.arena);
        self.updateMouse();
    }

    fn updateMouse(self: *Self) void {
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        for (self.intersection.triggers.items) |trigger| {
            if (trigger.rect.contains(mouse_pos)) {
                for (trigger.slots()) |slot| {
                    if (slot.contains(mouse_pos)) {
                        self.cursor = .pointer;
                    }
                }
            }
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.setCursor(self.cursor);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.solarized_base3,
        });
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
        for (self.intersection.triggers.items) |trigger| {
            self.haathi.drawRect(.{
                .position = trigger.rect.position,
                .size = trigger.rect.size,
                .radius = 0,
                .color = colors.solarized_base3,
            });
            for (trigger.slots_memory[0..trigger.num_slots]) |slot| {
                self.haathi.drawRect(.{
                    .position = slot.position,
                    .size = slot.size,
                    .radius = 2,
                    .color = colors.solarized_base2,
                });
                self.haathi.drawRect(.{
                    .position = slot.center(),
                    .size = .{ .x = 10, .y = 10 },
                    .radius = 10,
                    .color = colors.solarized_base1,
                    .centered = true,
                });
            }
        }
        for (self.intersection.cars.items) |car| {
            self.haathi.drawRect(.{
                .position = car.position,
                .size = .{ .x = 30, .y = 30 },
                .radius = 8,
                .color = colors.solarized_base01,
                .centered = true,
            });
        }
        for (self.intersection.signals.items) |signal| {
            self.haathi.drawRect(.{
                .position = signal.rect.position,
                .size = signal.rect.size,
                .color = colors.solarized_base03,
                .radius = 8,
            });
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
        if (self.intersection.show_crash) {
            var crash = std.ArrayList(Vec2).init(self.arena);
            var rng = std.rand.DefaultPrng.init(42);
            var ang: f32 = 0;
            var inside: bool = true;
            while (ang < 2.0 * std.math.pi) : (ang += (2.0 * std.math.pi / 16.0)) {
                const size: f32 = if (inside) 20 else 60;
                const rand = 0.4 + (rng.random().float(f32) * 0.6);
                inside = !inside;
                const first = Vec2{ .x = 1 };
                crash.append(INTERSECTION_MIDPOINT.add(first.scale(size * rand).rotate(ang))) catch unreachable;
            }
            self.haathi.drawPoly(.{
                .points = crash.items[0..],
                .color = colors.solarized_red,
            });
        }
    }
};
