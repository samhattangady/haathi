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
const INTERSECTION_MIDPOINT = Vec2{ .x = (SCREEN_SIZE.y * 0.5), .y = SCREEN_SIZE.y * 0.5 };

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
    slots: [3]Rect = undefined,

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

    pub fn reset(self: *Self, intersection: *const Intersection) void {
        self.moved = false;
        self.done = false;
        self.progress = 0;
        self.target_position = null;
        self.setup(intersection);
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
    sensors: std.ArrayList(LaneSensor),
    signals: std.ArrayList(Signal),
    connections: std.ArrayList(Connection),
    cars: std.ArrayList(Car),
    signal_states: std.ArrayList(SignalState),
    ticks: u64 = 0,
    steps: u8 = 0,
    crashed: bool = false,
    show_crash: bool = false,
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
        self.setSignalStates();
        // cars
        self.cars.append(.{
            .source_lane_index = 0,
            .destination_lane_index = 1,
            .position_in_lane = 0,
        }) catch unreachable;
        self.cars.append(.{
            .source_lane_index = 4,
            .destination_lane_index = 5,
            .position_in_lane = 0,
        }) catch unreachable;
        self.cars.append(.{
            .source_lane_index = 0,
            .destination_lane_index = 5,
            .position_in_lane = 1,
        }) catch unreachable;
        for (self.cars.items) |*car| car.setup(self);
        for (self.lanes.items, 0..) |_, i| {
            var sensor = LaneSensor{ .lane_index = @intCast(u8, i) };
            sensor.setup(self);
            self.sensors.append(sensor) catch unreachable;
        }
        // // connections
        // self.connections.append(.{
        //     .effect = .set_green,
        //     .sensor_index = 0,
        //     .signal_index = 1,
        // }) catch unreachable;
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
        const target_lane = self.lanes.items[car.destination_lane_index];
        car.target_position = .{
            .start = car.position,
            .midpoint = INTERSECTION_MIDPOINT,
            .endpoint = INTERSECTION_MIDPOINT.add(target_lane.toward.scale(-500)),
        };
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

    fn resetLevel(self: *Self) void {
        self.resetCars();
        self.resetSignals();
        self.show_crash = false;
        self.steps = 0;
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
        if (self.haathi.inputs.getKey(.r).is_clicked) self.intersection.resetLevel();
        if (self.haathi.inputs.getKey(.num_1).is_clicked) self.dev_mode = !self.dev_mode;
        self.intersection.update(ticks, self.arena);
        self.updateMouse();
    }

    fn updateMouse(self: *Self) void {
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        switch (self.state) {
            .idle => |_| {
                self.state.idle.hovered_sensor = null;
                for (self.intersection.sensors.items, 0..) |sensor, sensor_index| {
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
        for (self.intersection.sensors.items) |sensor| {
            self.haathi.drawRect(.{
                .position = sensor.rect.position,
                .size = sensor.rect.size,
                .radius = 0,
                .color = colors.solarized_base3,
            });
            for (sensor.slots_memory[0..sensor.num_slots]) |slot| {
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
                .size = .{ .x = 30, .y = 30 },
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
        if (self.dev_mode) {
            self.haathi.drawText(.{
                .text = "dev mode",
                .position = .{ .x = 60, .y = 30 },
                .color = colors.solarized_blue,
                .style = FONT_1,
            });
        }
    }
};
