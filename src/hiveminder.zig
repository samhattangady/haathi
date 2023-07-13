const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const pi = std.math.pi;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const FONT_1 = "18px JetBrainsMono";
const FONT_2 = "12px JetBrainsMono";
const HEX_SCALE = 30;
const HIVE_SIZE = 7;
const HIVE_ORIGIN = Vec2{ .x = 1280 / 2, .y = 720 / 2 };
const NUM_SLOTS = 6;
const BEE_TRAVEL_SPEED = 0.25;
const BEE_REACH_DISTANCE_SQR = HEX_SCALE * 0.2;
const POLLEN_WAYPOINT = Vec2i{ .x = -8, .y = 16 };
/// number of ticks between reduction of health / rest for bees
const BEE_TICK_RATE = 50;
/// number of ticks between reduction of health for rooms
const ROOM_MAINTENANCE_TICK_RATE = 350;
const BEE_SPEED_VARIATION = 0.2;
const PRINT_F_DEBUG = false;
const BEE_STATUS_BAR_HEIGHT = 5;
const BEE_STATUS_BAR_WIDTH = 80;
const BEE_HEALTH_STATUS_X = 1280 - BEE_STATUS_BAR_WIDTH - BEE_STATUS_BAR_WIDTH - 20;
const BEE_REST_STATUS_X = 1280 - BEE_STATUS_BAR_WIDTH - 10;
const NUM_BEES = 100;
const DELTA_T_CAP = 200;
const BEE_AGE_LIMIT = 900;
const NUM_START_BEES = 2;
const QUEEN_ADDRESS = Vec2i{ .x = 0, .y = 0 };
const BEES_START_ADDRESS = Vec2i{ .x = -5, .y = 5 };
const BEE_BIRTH_TICKS = 20;
const OCCUPIED_HIVE_COLOR = colors.solarized_base1;
const UNOCCUPIED_CELL_COLOR = colors.solarized_base2;
const CELL_OUTLINE_COLOR = colors.solarized_base00;
const BUTTON_ROW_WIDTH = BEE_HEALTH_STATUS_X;
const BUTTON_PADDING = 20;
const BUTTON_HEIGHT = 22;
const BUTTON_ROW_Y = 720 - BUTTON_HEIGHT - BUTTON_PADDING;
const NUM_BUILDERS_REQUIRED_PER_ROOM = 6;
const FULL_CELL_SCALE = 0.95;
const ZERO_CONSTRUCTED_CELL_SCALE = 0.35;
const SLOT_LERP_AMOUNT = 0.6;
const BEE_FALL_ACCELERATION = 0.02;

const Address = Vec2i;

const HEX_OFFSETS = [6]Vec2{
    .{ .x = @cos(2 * pi * (0.0 / 6.0)), .y = @sin(2 * pi * (0.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (1.0 / 6.0)), .y = @sin(2 * pi * (1.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (2.0 / 6.0)), .y = @sin(2 * pi * (2.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (3.0 / 6.0)), .y = @sin(2 * pi * (3.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (4.0 / 6.0)), .y = @sin(2 * pi * (4.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (5.0 / 6.0)), .y = @sin(2 * pi * (5.0 / 6.0)) },
};

const NEIGHBOURS_1 = [6]Vec2i{
    .{ .x = 1, .y = 1 },
    .{ .x = 1, .y = -1 },
    .{ .x = -1, .y = -1 },
    .{ .x = -1, .y = 1 },
    .{ .x = 0, .y = 2 },
    .{ .x = 0, .y = -2 },
};

const NEIGHBOURS_2 = [12]Vec2i{
    .{ .x = 0, .y = 4 },
    .{ .x = 1, .y = 3 },
    .{ .x = 2, .y = 2 },
    .{ .x = 2, .y = 0 },
    .{ .x = 2, .y = -2 },
    .{ .x = 1, .y = -3 },
    .{ .x = 0, .y = -4 },
    .{ .x = -1, .y = -3 },
    .{ .x = -2, .y = -2 },
    .{ .x = -2, .y = 0 },
    .{ .x = -2, .y = 2 },
    .{ .x = -1, .y = 3 },
};

const SELF = [1]Vec2i{.{ .x = 0, .y = 0 }};

const NEIGHBOURS = NEIGHBOURS_1 ++ NEIGHBOURS_2;
const MAINTAINING_NEIGHBOURS = SELF ++ NEIGHBOURS;

// Hex Indexing.
// Our hexes are drawn with one set of parallel edges parallel to the x axis
// The way that we chose to do hex indexing is:
// If y is even, then x is also even
// If y is odd, then x is also odd.
// There is no cell where x is even and y is odd or vice versa
// for a given cell, its neighbors are (1,1), (1,-1), (-1, 1), (-1, -1), (0,2), (0,-2)

pub const Cell = struct {
    const Self = @This();
    points: [6]Vec2,
    address: Address = .{},

    pub fn init(address: Vec2i, scale: f32) Self {
        var self: Self = undefined;
        const center = Cell.addressToPos(address);
        for (HEX_OFFSETS, 0..) |ho, i| {
            self.points[i] = center.add(ho.scale(HEX_SCALE * scale));
        }
        self.address = address;
        return self;
    }

    pub fn initPos(center: Vec2, scale: f32) Self {
        var self: Self = undefined;
        for (HEX_OFFSETS, 0..) |ho, i| {
            self.points[i] = center.add(ho.scale(HEX_SCALE * scale));
        }
        return self;
    }

    pub fn isValidCellAddress(address: Vec2i) bool {
        const x_even = @mod(address.x, 2) == 0;
        const y_even = @mod(address.y, 2) == 0;
        return x_even == y_even;
    }

    pub fn resetScale(self: *Self, scale: f32) void {
        const center = Cell.addressToPos(self.address);
        for (HEX_OFFSETS, 0..) |ho, i| {
            self.points[i] = center.add(ho.scale(HEX_SCALE * scale));
        }
    }

    pub fn containsPoint(self: *const Self, pos: Vec2) bool {
        const bounding_box = Rect{
            .position = .{ .x = self.points[3].x, .y = self.points[5].y },
            .size = .{ .x = self.points[0].x - self.points[3].x, .y = self.points[1].y - self.points[5].y },
        };
        return helpers.polygonContainsPoint(self.points[0..], pos, bounding_box);
    }

    /// returns the center of the cell
    pub fn addressToPos(address: Address) Vec2 {
        const origin = HIVE_ORIGIN;
        const center = origin.add(.{ .x = (HEX_SCALE + (HEX_SCALE * HEX_OFFSETS[5].x - HEX_OFFSETS[4].x)) * @floatFromInt(f32, address.x), .y = (HEX_SCALE * HEX_OFFSETS[5].y) * @floatFromInt(f32, address.y) });
        return center;
    }

    /// returns the points at the center of the edges
    pub fn slotOffsets(self: *const Self) [6]Vec2 {
        const center = Cell.addressToPos(self.address);
        var slots: [6]Vec2 = undefined;
        for (self.points, 0..) |p0, i| {
            const p1 = if (i == 5) self.points[0] else self.points[i + 1];
            slots[i] = center.lerp(p0.lerp(p1, 0.5), SLOT_LERP_AMOUNT);
        }
        return slots;
    }

    pub fn slotPos(location: Location) Vec2 {
        return Cell.init(location.address, FULL_CELL_SCALE).slotOffsets()[location.slot_index];
    }
};

pub const RoomType = enum {
    queen,
    babysitting,
    collection,
    building,
    maintaining,
    rest,
    storage,
    incubator,
};
const NUM_ROOMS = @typeInfo(RoomType).Enum.fields.len;

pub const RoomData = union(RoomType) {
    const Self = @This();
    queen: void,
    babysitting: void,
    collection: void,
    building: void,
    maintaining: void,
    rest: void,
    storage: void,
    /// 0 is empty - request egg
    /// 1 is egg - request food
    /// 2 is has food - request bee
    /// 3+ has everything, needs time to grow
    incubator: u8,

    pub fn fromType(room: RoomType) Self {
        return switch (room) {
            .queen => .queen,
            .babysitting => .babysitting,
            .collection => .collection,
            .building => .building,
            .maintaining => .maintaining,
            .rest => .rest,
            .storage => .storage,
            .incubator => .{ .incubator = 0 },
        };
    }
};

pub const Room = struct {
    const Self = @This();
    room: RoomData,
    /// For each bee that does a construction job, add one to this.
    constructed: u8 = 0,
    address: Vec2i,
    slots_available: [NUM_SLOTS]bool = [_]bool{true} ** NUM_SLOTS,
    /// flag if that slot has already released a signal.
    slots_signals: [NUM_SLOTS]bool = [_]bool{false} ** NUM_SLOTS,
    health: u8 = 255,
    maintenance_signal: bool = false,

    pub fn isConstructed(self: *const Self) bool {
        return self.constructed >= NUM_BUILDERS_REQUIRED_PER_ROOM;
    }

    pub fn isUnusable(self: *const Self) bool {
        return self.health == 0;
    }

    pub fn needsMaintaining(self: *const Self) bool {
        return (self.maintenance_signal == false) and self.health <= 100;
    }

    pub fn needsMoreConstruction(self: *const Self) bool {
        return self.constructed + self.liveSignalCount() < NUM_BUILDERS_REQUIRED_PER_ROOM;
    }

    pub fn initSlots(self: *Self) void {
        self.slots_signals = [_]bool{false} ** NUM_SLOTS;
        self.slots_available = [_]bool{true} ** NUM_SLOTS;
    }

    pub fn tryConsumeSignal(self: *Self, signal: *const Signal) ?Signal {
        if (!self.isConstructed()) return null;
        if (self.isUnusable()) return null;
        if (signal.consumed) return null;
        if (self.room == .collection and signal.signal == .storage_space_available) {
            for (self.slots_available, 0..) |avail, i| {
                if (self.slots_signals[i]) continue;
                if (avail) {
                    self.slots_signals[i] = true;
                    return Signal{
                        .signal = .collection_bee_required,
                        .room = .{ .address = self.address, .slot_index = @intCast(u8, i) },
                        .waypoint = .{ .address = POLLEN_WAYPOINT, .slot_index = 0 },
                        .destination = signal.room,
                    };
                }
            }
        }
        if (self.room == .building and signal.signal == .room_construction_required) {
            for (self.slots_available, 0..) |avail, i| {
                if (self.slots_signals[i]) continue;
                if (avail) {
                    self.slots_signals[i] = true;
                    return Signal{
                        .signal = .building_bee_required,
                        // room is building room
                        .room = .{ .address = self.address, .slot_index = @intCast(u8, i) },
                        .waypoint = undefined,
                        // room to be built
                        .destination = signal.room,
                    };
                }
            }
        }
        if (self.room == .incubator and self.slots_signals[0] == false) { // not yet sent signal
            const stage = self.room.incubator;
            if (stage == 1 and signal.signal == .storage_food_available) {
                self.slots_signals[0] = true;
                return Signal{
                    .signal = .incubator_food_required,
                    // room is the incubator
                    .room = .{ .address = self.address, .slot_index = 0 },
                    // waypoint is location of the food
                    .waypoint = signal.room,
                    // destination is undefined
                    .destination = undefined,
                };
            }
        }
        if (self.room == .babysitting) {
            for (self.slots_available, 0..) |avail, i| {
                if (self.slots_signals[i]) continue;
                if (!avail) continue;
                switch (signal.signal) {
                    .incubator_food_required => {
                        self.slots_signals[i] = true;
                        return Signal{
                            .signal = .babysitting_food_required,
                            // room is the babysitting
                            .room = .{ .address = self.address, .slot_index = @intCast(u8, i) },
                            // waypoint is the location of the food
                            .waypoint = signal.waypoint,
                            // destination is incubator
                            .destination = signal.room,
                        };
                    },
                    .incubator_egg_required => {
                        self.slots_signals[i] = true;
                        return Signal{
                            .signal = .babysitting_egg_required,
                            // room is the babysitting
                            .room = .{ .address = self.address, .slot_index = @intCast(u8, i) },
                            // waypoint is the location of the egg
                            .waypoint = signal.waypoint,
                            // destination is incubator
                            .destination = signal.room,
                        };
                    },
                    .incubator_attention_required => {
                        self.slots_signals[i] = true;
                        return Signal{
                            .signal = .babysitting_attention_required,
                            // room is the babysitting
                            .room = .{ .address = self.address, .slot_index = @intCast(u8, i) },
                            // waypoint is undefined
                            .waypoint = undefined,
                            // destination is incubator
                            .destination = signal.room,
                        };
                    },
                    else => {},
                }
            }
        }
        return null;
    }

    pub fn slotCount(self: *const Self) u8 {
        var count: u8 = 0;
        for (self.slots_available) |slot| {
            if (slot) count += 1;
        }
        return count;
    }

    pub fn liveSignalCount(self: *const Self) u8 {
        var count: u8 = 0;
        for (self.slots_signals) |slot| {
            if (slot) count += 1;
        }
        return count;
    }
};

const Location = struct {
    address: Address,
    slot_index: u8,
};

const JobState = enum {
    to_room,
    room_to_waypoint,
    waypoint_to_destination,
    room_to_destination,
    at_destination,
};

pub const Role = enum {
    const Self = @This();
    babysitting_egg,
    babysitting_food,
    babysitting_attention,
    collection,
    building,
    maintaining,
    eating,
    rest,

    pub fn ticksLength(self: *const Self) u64 {
        return switch (self.*) {
            .collection => 10,
            else => 1000,
        };
    }

    /// A room consumed the initial signal. The bee now needs to close the signal that
    /// was left open by the room
    pub fn shouldCloseDestinationSignals(self: *const Self) bool {
        return switch (self.*) {
            .collection,
            .building,
            .babysitting_egg,
            .babysitting_food,
            .babysitting_attention,
            => true,
            // maintenance will not be using standard signals.
            .maintaining,
            .eating,
            .rest,
            => false,
        };
    }
    /// A room consumed the initial signal. The bee now needs to lost the signal that
    /// was left open by the room
    pub fn shouldCloseWaypointSignals(self: *const Self) bool {
        return switch (self.*) {
            //
            .babysitting_food => true,
            .collection,
            .babysitting_egg,
            .babysitting_attention,
            .building,
            .maintaining,
            .eating,
            .rest,
            => false,
        };
    }
};

pub const Job = struct {
    const Self = @This();
    role: Role,
    /// room is the location where the bee is assigned
    room: Location,
    /// waypoint is a mid location that the bee must visit
    waypoint: ?Location,
    /// destination is the location where the job is done
    /// some jobs may not have destinations.
    destination: ?Location,
    // when the job was created
    ticks_created: u64 = 0,
    ticks_room_reached: u64 = 0,
    ticks_waypoint_reached: u64 = 0,
    ticks_destination_reached: u64 = 0,

    pub fn started(self: *const Self) bool {
        return self.ticks_room_reached > 0;
    }

    /// the job is either
    pub fn getCurrentStage(self: *const Self) JobState {
        if (self.ticks_room_reached == 0) return .to_room;
        if (self.waypoint == null and self.destination == null) return .at_destination;
        if (self.waypoint) |_| {
            if (self.ticks_waypoint_reached == 0) return .room_to_waypoint;
            if (self.ticks_destination_reached == 0) return .waypoint_to_destination;
        }
        if (self.destination) |_| {
            if (self.ticks_destination_reached == 0) return .room_to_destination;
            return .at_destination;
        }
        c.debugPrint("could not getCurrentStage for job");
        unreachable;
    }

    /// address of where the bee should be going now
    pub fn getCurrentTargetLocation(self: *const Self) Location {
        return switch (self.getCurrentStage()) {
            .to_room => self.room,
            .room_to_waypoint => self.waypoint.?,
            .waypoint_to_destination, .room_to_destination => self.destination.?,
            .at_destination => {
                c.debugPrint("try to getCurrentTargetLocation of .at_destination");
                unreachable;
            },
        };
    }

    /// the bee has just reached its target cell. what now.
    pub fn nextStage(old_job: *const Self, bee: *Bee, ticks: u64) Self {
        var self = old_job.*;
        // update the appropriate tick_counter
        switch (self.getCurrentStage()) {
            .to_room => self.ticks_room_reached = ticks,
            .room_to_waypoint => self.ticks_waypoint_reached = ticks,
            .waypoint_to_destination, .room_to_destination => self.ticks_destination_reached = ticks,
            .at_destination => {
                c.debugPrint("job is already at final stage. Can't go next.");
                unreachable;
            },
        }
        // see if bee has to keep moving.
        switch (self.getCurrentStage()) {
            .to_room => {
                c.debugPrint("job cannot still be in first stage");
                unreachable;
            },
            // TODO (11 Jul 2023 sam): depending on the waypoint, we might need to do more hive things here.
            .room_to_waypoint,
            .waypoint_to_destination,
            .room_to_destination,
            => bee.moving = Cell.slotPos(self.getCurrentTargetLocation()),
            .at_destination => bee.moving = null,
        }
        return self;
    }

    /// how many ticks the job has been performed for.
    /// if not at_destination, then 0
    /// otherwise appropriately, ticks-dest or ticks-room
    pub fn jobTicksPerformed(self: *const Self, ticks: u64) u64 {
        if (self.getCurrentStage() != .at_destination) return 0;
        if (self.destination != null) return ticks - self.ticks_destination_reached;
        return ticks - self.ticks_room_reached;
    }
};

pub const Bee = struct {
    const Self = @This();
    /// bee will only be moving to job room or job destination
    moving: ?Vec2 = null,
    job: ?Job = null,
    /// slowly goes up, eventually bee will die.
    age: u16 = 0,
    /// health goes up and down based on food consumption
    health: u8 = 255,
    /// rest goes up and down based on time spent on job and rest
    rest: u8 = 255,
    speed: f32 = 1,
    position: Vec2 = HIVE_ORIGIN,
    fall_speed: f32 = 0,
    address: Address = .{},

    pub fn tryConsumeSignal(self: *Self, signal: *const Signal) bool {
        if (signal.consumed) return false;
        if (self.job != null) return false;
        switch (signal.signal) {
            .storage_food_available => {
                if (self.health > 128) return false;
                self.job = .{
                    .role = .eating,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = null,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .collection_bee_required => {
                self.job = .{
                    .role = .collection,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .rest_slot_available => {
                if (self.rest > 128) return false;
                self.job = .{
                    .role = .rest,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = null,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .babysitting_food_required => {
                self.job = .{
                    .role = .babysitting_food,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .babysitting_egg_required => {
                self.job = .{
                    .role = .babysitting_egg,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .babysitting_attention_required => {
                self.job = .{
                    .role = .babysitting_attention,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .building_bee_required => {
                self.job = .{
                    .role = .building,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            .maintenance_bee_required => {
                self.job = .{
                    .role = .maintaining,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = signal.destination,
                };
                self.moving = Cell.slotPos(signal.room);
                return true;
            },
            else => {
                return false;
            },
        }
    }

    pub fn dead(self: *const Self) bool {
        return self.age >= BEE_AGE_LIMIT;
    }
};

const SignalType = enum {
    const Self = @This();
    storage_food_available,
    storage_space_available,
    rest_slot_available,
    room_maintenance_required,
    room_construction_required,
    building_bee_required,
    maintenance_bee_required,
    incubator_food_required,
    incubator_attention_required,
    incubator_egg_required,
    queen_egg_available,
    queen_attention_required,
    babysitting_food_required,
    babysitting_egg_required,
    babysitting_attention_required,
    collection_bee_required,

    pub fn isBeeWork(self: *const Self) bool {
        return switch (self.*) {
            .storage_space_available,
            .storage_food_available,
            .rest_slot_available,
            .room_maintenance_required,
            .room_construction_required,
            .incubator_food_required,
            .incubator_attention_required,
            .incubator_egg_required,
            .queen_egg_available,
            .queen_attention_required,
            => false,
            .babysitting_food_required,
            .babysitting_egg_required,
            .babysitting_attention_required,
            .collection_bee_required,
            .building_bee_required,
            .maintenance_bee_required,
            => true,
        };
    }
};

pub const Signal = struct {
    signal: SignalType,
    room: Location,
    waypoint: Location,
    destination: Location,
    consumed: bool = false,
};

pub const Hive = struct {
    const Self = @This();
    rng: std.rand.Xoshiro256,
    food: usize = 0,
    ticks: u64 = 0,
    bees: std.ArrayList(Bee),
    rooms: std.ArrayList(Room),
    jobs: std.ArrayList(Job),
    cells: std.ArrayList(Cell),
    signals: std.ArrayList(Signal),
    food_queue: std.ArrayList(usize),
    work_queue: std.ArrayList(usize),
    rest_queue: std.ArrayList(usize),
    room_map: std.AutoHashMap(Address, usize),
    /// the previous time that health rest etc was reduced
    prev_bee_tick_down: u64 = 0,
    prev_room_tick_down: u64 = 0,
    working_bees: usize = 0,
    speed_up: f32 = 1,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .rng = std.rand.DefaultPrng.init(42),
            .bees = std.ArrayList(Bee).init(allocator),
            .jobs = std.ArrayList(Job).init(allocator),
            .cells = std.ArrayList(Cell).init(allocator),
            .rooms = std.ArrayList(Room).initCapacity(allocator, 512) catch unreachable,
            .room_map = std.AutoHashMap(Address, usize).init(allocator),
            .food_queue = std.ArrayList(usize).init(allocator),
            .work_queue = std.ArrayList(usize).init(allocator),
            .rest_queue = std.ArrayList(usize).init(allocator),
            .signals = std.ArrayList(Signal).init(allocator),
            .arena = arena,
        };
        self.setupHive();
        // self.debugRooms();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.bees.deinit();
        self.food_queue.deinit();
        self.work_queue.deinit();
        self.rest_queue.deinit();
        self.jobs.deinit();
        self.rooms.deinit();
        self.cells.deinit();
        self.signals.deinit();
        self.room_map.deinit();
    }

    // HIVEUPDATE
    pub fn update(self: *Self, raw_delta_t: u64, arena: std.mem.Allocator) void {
        const delta_t = @intFromFloat(u64, (@floatFromInt(f32, raw_delta_t) * self.speed_up));
        self.ticks += delta_t;
        const f_delta_t = @floatFromInt(f32, delta_t);
        self.arena = arena;
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_0");
        // iterate through all bees. move them if required. check if job is complete
        for (self.bees.items, 0..) |*bee, b| {
            if (bee.dead()) {
                bee.position.y += bee.fall_speed;
                bee.fall_speed += BEE_FALL_ACCELERATION * f_delta_t;
                continue;
            }
            if (bee.job) |*job| {
                if (bee.moving) |target_pos| {
                    // bee is either moving to job room or job destination
                    const travel = target_pos.subtract(bee.position).normalize().scale(f_delta_t * BEE_TRAVEL_SPEED * bee.speed);
                    // we don't want the bee to overshoot when sped up.
                    if (bee.position.distanceSqr(target_pos) < travel.lengthSqr()) {
                        bee.position = target_pos;
                    } else {
                        bee.position = bee.position.add(travel);
                    }
                    const old_stage = job.getCurrentStage();
                    if (target_pos.distanceSqr(bee.position) < BEE_REACH_DISTANCE_SQR) {
                        bee.job = job.nextStage(bee, self.ticks);
                    }
                    const new_stage = bee.job.?.getCurrentStage();
                    if (job.role.shouldCloseWaypointSignals() and old_stage == .room_to_waypoint and new_stage == .waypoint_to_destination) {
                        self.roomAt(job.waypoint.?.address).?.slots_available[job.waypoint.?.slot_index] = true;
                        self.roomAt(job.waypoint.?.address).?.slots_signals[job.waypoint.?.slot_index] = false;
                    }
                } else {
                    // bee is not moving. bee is doing job.
                    if (job.jobTicksPerformed(self.ticks) > job.role.ticksLength()) {
                        // job is complete. mark bee as free, and the room that emplyed it also
                        self.markJobComplete(bee, job);
                        self.work_queue.append(b) catch unreachable;
                    }
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_1");
        // iterate through all the hungry bees, and see if there is a signal to feed them
        {
            var fed = std.ArrayList(usize).init(self.arena);
            for (self.food_queue.items, 0..) |bi, i| {
                var bee = &self.bees.items[bi];
                if (bee.job != null) continue;
                if (bee.dead()) continue;
                for (self.signals.items) |*signal| {
                    if (signal.consumed) continue;
                    if (signal.signal != .storage_food_available) continue;
                    if (bee.tryConsumeSignal(signal)) {
                        // TODO (11 Jul 2023 sam): Check distance also
                        fed.append(i) catch unreachable;
                        signal.consumed = true;
                        std.debug.assert(bee.job != null);
                        break;
                    }
                }
            }
            // remove fed bees from list
            if (fed.items.len > 0) {
                var i: usize = fed.items.len - 1;
                while (i >= 0) : (i -= 1) {
                    _ = self.food_queue.orderedRemove(fed.items[i]);
                    if (i == 0) break;
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_2");
        // iterate through all the rooms that emit signals.
        for (self.rooms.items) |*room| {
            if (!room.isConstructed()) {
                if (!room.needsMoreConstruction()) continue;
                for (room.slots_available, 0..) |avail, i| {
                    if (!avail) continue;
                    if (room.slots_signals[i]) continue;
                    const signal = Signal{
                        .signal = .room_construction_required,
                        .room = .{
                            .address = room.address,
                            .slot_index = @intCast(u8, i),
                        },
                        .waypoint = undefined,
                        .destination = undefined,
                    };
                    self.signals.append(signal) catch unreachable;
                    room.slots_signals[i] = true;
                }
                break;
            }
            if (room.isUnusable()) continue;
            switch (room.room) {
                .storage => {
                    for (room.slots_available, 0..) |avail, i| {
                        if (room.slots_signals[i]) continue;
                        if (avail) {
                            // space is available
                            const signal = Signal{
                                .signal = .storage_space_available,
                                .room = .{
                                    .address = room.address,
                                    .slot_index = @intCast(u8, i),
                                },
                                .waypoint = undefined,
                                .destination = undefined,
                            };
                            self.signals.append(signal) catch unreachable;
                            room.slots_signals[i] = true;
                        } else {
                            // food is available
                            const signal = Signal{
                                .signal = .storage_food_available,
                                .room = .{
                                    .address = room.address,
                                    .slot_index = @intCast(u8, i),
                                },
                                .waypoint = undefined,
                                .destination = undefined,
                            };
                            self.signals.append(signal) catch unreachable;
                            room.slots_signals[i] = true;
                        }
                    }
                },
                .rest => {
                    for (room.slots_available, 0..) |avail, i| {
                        if (room.slots_signals[i]) continue;
                        if (avail) {
                            const signal = Signal{
                                .signal = .rest_slot_available,
                                .room = .{
                                    .address = room.address,
                                    .slot_index = @intCast(u8, i),
                                },
                                .waypoint = undefined,
                                .destination = undefined,
                            };
                            self.signals.append(signal) catch unreachable;
                            room.slots_signals[i] = true;
                        }
                    }
                },
                .incubator => |stage| {
                    // incubator only uses slot 0
                    if (room.slots_signals[0]) continue;
                    if (stage == 0) {
                        const signal = Signal{
                            .signal = .incubator_egg_required,
                            .room = .{
                                .address = room.address,
                                .slot_index = 0,
                            },
                            .waypoint = .{
                                .address = QUEEN_ADDRESS,
                                .slot_index = 0,
                            },
                            .destination = undefined,
                        };
                        self.signals.append(signal) catch unreachable;
                        room.slots_signals[0] = true;
                    }
                    // stage 1 is taken care of by room consuming signals
                    if (stage == 2) {
                        const signal = Signal{
                            .signal = .incubator_attention_required,
                            .room = .{
                                .address = room.address,
                                .slot_index = 0,
                            },
                            .waypoint = undefined,
                            .destination = undefined,
                        };
                        self.signals.append(signal) catch unreachable;
                        room.slots_signals[0] = true;
                    }
                },
                // maintaining is a special case. It checks all the rooms around it, and if they
                // need maintaining, it will mark it so
                .maintaining => {
                    for (MAINTAINING_NEIGHBOURS) |n| {
                        if (self.roomAt(room.address.add(n))) |neighboring_room| {
                            if (neighboring_room.needsMaintaining()) {
                                for (room.slots_available, 0..) |avail, i| {
                                    if (room.slots_signals[i]) continue;
                                    if (avail) {
                                        const signal = Signal{
                                            .signal = .maintenance_bee_required,
                                            .room = .{
                                                .address = room.address,
                                                .slot_index = @intCast(u8, i),
                                            },
                                            .waypoint = undefined,
                                            .destination = .{
                                                .address = neighboring_room.address,
                                                .slot_index = 0,
                                            },
                                        };
                                        self.signals.append(signal) catch unreachable;
                                        room.slots_signals[i] = true;
                                        neighboring_room.maintenance_signal = true;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                },
                else => {},
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_3");
        // iterate through all the signals, and see if they can be consumed by nearby rooms
        for (self.signals.items) |*signal| {
            if (signal.consumed) continue;
            const center = signal.room.address;
            for (NEIGHBOURS) |n| {
                const address = center.add(n);
                if (self.roomAt(address)) |room| {
                    if (room.tryConsumeSignal(signal)) |new_signal| {
                        signal.consumed = true;
                        self.signals.append(new_signal) catch unreachable;
                        break;
                    }
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_3_1");
        // iterate through all the work queue and assign tasks.
        {
            var assigned = std.ArrayList(usize).init(self.arena);
            for (self.work_queue.items, 0..) |bi, i| {
                var bee = &self.bees.items[bi];
                if (bee.dead()) continue;
                if (bee.job != null) continue;
                for (self.signals.items) |*signal| {
                    if (signal.consumed) continue;
                    if (!signal.signal.isBeeWork()) continue;
                    if (bee.tryConsumeSignal(signal)) {
                        // TODO (11 Jul 2023 sam): Check distance also
                        signal.consumed = true;
                        std.debug.assert(bee.job != null);
                        assigned.append(i) catch unreachable;
                        break;
                    }
                }
            }
            // remove fed bees from list
            if (assigned.items.len > 0) {
                var i: usize = assigned.items.len - 1;
                while (i >= 0) : (i -= 1) {
                    _ = self.work_queue.orderedRemove(assigned.items[i]);
                    if (i == 0) break;
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_3_2");
        // iterate through all the tired bees, and see if there is a signal to rest them
        {
            var rested = std.ArrayList(usize).init(self.arena);
            for (self.rest_queue.items, 0..) |bi, i| {
                var bee = &self.bees.items[bi];
                if (bee.job != null) continue;
                if (bee.dead()) continue;
                for (self.signals.items) |*signal| {
                    if (signal.consumed) continue;
                    if (signal.signal != .rest_slot_available) continue;
                    if (bee.tryConsumeSignal(signal)) {
                        // TODO (11 Jul 2023 sam): Check distance also
                        rested.append(i) catch unreachable;
                        signal.consumed = true;
                        std.debug.assert(bee.job != null);
                        break;
                    }
                }
            }
            // remove rested bees from list
            if (rested.items.len > 0) {
                var i: usize = rested.items.len - 1;
                while (i >= 0) : (i -= 1) {
                    _ = self.rest_queue.orderedRemove(rested.items[i]);
                    if (i == 0) break;
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_4");
        if (self.signals.items.len > 0) {
            // remove consumed signals
            var i: usize = self.signals.items.len - 1;
            while (i >= 0) : (i -= 1) {
                if (self.signals.items[i].consumed) {
                    _ = self.signals.orderedRemove(i);
                }
                if (i == 0) break;
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_5");
        // tick down health and rest every 300 ticks?
        while (self.ticks - self.prev_bee_tick_down > BEE_TICK_RATE) {
            self.prev_bee_tick_down += BEE_TICK_RATE;
            for (self.bees.items, 0..) |*bee, i| {
                if (bee.health > 0) {
                    bee.health -= 1;
                    if (bee.health == 128) self.food_queue.append(i) catch unreachable;
                }
                if (bee.rest > 0) {
                    bee.rest -= 1;
                    if (bee.rest == 128) self.rest_queue.append(i) catch unreachable;
                }
                if (bee.age < BEE_AGE_LIMIT) {
                    bee.age += 1;
                    if (bee.age == BEE_AGE_LIMIT) {
                        // mark job as complete.
                        if (bee.job) |*job| self.forceMarkJobComplete(bee, job);
                    }
                }
            }
            for (self.rooms.items) |*room| {
                if (room.room == .incubator) {
                    if (room.room.incubator >= 3) room.room.incubator += 1;
                    if (room.room.incubator >= BEE_BIRTH_TICKS) {
                        room.room.incubator = 0;
                        self.addBee(room.address);
                    }
                }
            }
        }
        while (self.ticks - self.prev_room_tick_down > ROOM_MAINTENANCE_TICK_RATE) {
            self.prev_room_tick_down += ROOM_MAINTENANCE_TICK_RATE;
            for (self.rooms.items) |*room| {
                if (room.health > 0) room.health -= 1;
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_6");
    }

    fn forceMarkJobComplete(self: *Self, bee: *Bee, job: *Job) void {
        while (bee.moving) |_| {
            // bee is either moving to job room or job destination
            const old_stage = job.getCurrentStage();
            bee.job = job.nextStage(bee, self.ticks);
            const new_stage = bee.job.?.getCurrentStage();
            if (job.role.shouldCloseWaypointSignals() and old_stage == .room_to_waypoint and new_stage == .waypoint_to_destination) {
                self.roomAt(job.waypoint.?.address).?.slots_available[job.waypoint.?.slot_index] = true;
                self.roomAt(job.waypoint.?.address).?.slots_signals[job.waypoint.?.slot_index] = false;
            }
        }
        self.markJobComplete(bee, job);
    }

    fn markJobComplete(self: *Self, bee: *Bee, job: *Job) void {
        self.roomAt(job.room.address).?.slots_available[job.room.slot_index] = true;
        self.roomAt(job.room.address).?.slots_signals[job.room.slot_index] = false;
        // if the job needs to update the room do that.
        if (job.role.shouldCloseDestinationSignals()) {
            const av = if (job.role == .collection) false else true;
            self.roomAt(job.destination.?.address).?.slots_available[job.destination.?.slot_index] = av;
            self.roomAt(job.destination.?.address).?.slots_signals[job.destination.?.slot_index] = false;
        }
        switch (job.role) {
            .babysitting_egg, .babysitting_food, .babysitting_attention => {
                self.roomAt(job.destination.?.address).?.room.incubator += 1;
            },
            .building => {
                var room = self.roomAt(job.destination.?.address).?;
                room.constructed += 1;
                if (room.isConstructed()) {
                    room.initSlots();
                }
            },
            .eating => {
                bee.health = 255;
            },
            .rest => {
                bee.rest = 255;
            },
            .maintaining => {
                var room = self.roomAt(job.destination.?.address).?;
                room.health = 255;
                room.maintenance_signal = false;
            },
            else => {},
        }
        bee.job = null;
    }

    fn addBee(self: *Self, address: Address) void {
        var bee = Bee{};
        bee.position = Cell.addressToPos(address);
        bee.speed = (1 - BEE_SPEED_VARIATION) + (self.rng.random().float(f32) * 2 * BEE_SPEED_VARIATION);
        self.work_queue.insert(0, self.bees.items.len) catch unreachable;
        self.bees.append(bee) catch unreachable;
    }

    fn addRoom(self: *Self, room: Room) void {
        if (self.room_map.get(room.address) != null) return;
        const index = self.rooms.items.len;
        self.rooms.append(room) catch unreachable;
        self.room_map.put(room.address, index) catch unreachable;
        self.resetCells();
    }

    fn deleteRoom(self: *Self, address: Address) void {
        if (self.room_map.get(address) == null) return;
        // all the bees that were doing a job involving this address, close those signals
        for (self.bees.items, 0..) |*bee, b| {
            if (bee.job) |*job| {
                self.forceMarkJobComplete(bee, job);
                self.work_queue.append(b) catch unreachable;
            }
        }
        // all the signals that involve the room, mark as consumed
        for (self.signals.items) |*signal| {
            if (signal.room.address.equal(address)) signal.consumed = true;
            if (signal.waypoint.address.equal(address)) signal.consumed = true;
            if (signal.destination.address.equal(address)) signal.consumed = true;
        }
        const index = self.room_map.get(address).?;
        _ = self.rooms.orderedRemove(index);
        self.resetCells();
    }

    /// we only want to draw cells where they are neighbors to existing rooms.
    /// so we just reset the whole list, and then recreate it.
    fn resetCells(self: *Self) void {
        self.cells.clearRetainingCapacity();
        self.room_map.clearRetainingCapacity();
        var all_addresses = std.AutoHashMap(Address, void).init(self.arena);
        for (self.rooms.items, 0..) |room, i| {
            self.room_map.put(room.address, i) catch unreachable;
            for (NEIGHBOURS_1) |n| {
                all_addresses.put(room.address.add(n), {}) catch unreachable;
            }
        }
        var ad = all_addresses.keyIterator();
        while (ad.next()) |address| {
            self.cells.append(Cell.init(address.*, 0.85)) catch unreachable;
        }
    }

    fn roomAt(self: *Self, address: Vec2i) ?*Room {
        if (self.room_map.get(address)) |ri| return &self.rooms.items[ri];
        return null;
    }

    fn setupHive(self: *Self) void {
        for (0..NUM_START_BEES) |_| {
            self.addBee(BEES_START_ADDRESS);
        }
        self.addRoom(.{ .room = .queen, .address = QUEEN_ADDRESS });
        self.addRoom(.{ .room = .storage, .address = .{ .x = -1, .y = -1 }, .slots_available = [_]bool{false} ** NUM_SLOTS });
        self.addRoom(.{ .room = .collection, .address = .{ .x = 1, .y = -1 } });
        self.addRoom(.{ .room = .babysitting, .address = .{ .x = -1, .y = 1 } });
        // self.addRoom(.{ .room = .{ .incubator = 0 }, .address = .{ .x = 1, .y = 1 } });
        self.addRoom(.{ .room = .maintaining, .address = .{ .x = 0, .y = -2 } });
        self.addRoom(.{ .room = .rest, .address = .{ .x = -1, .y = -3 } });
        self.addRoom(.{ .room = .building, .address = .{ .x = 0, .y = 2 } });
        for (self.rooms.items) |*room| room.constructed = NUM_BUILDERS_REQUIRED_PER_ROOM;
        self.addRoom(.{ .room = .{ .incubator = 0 }, .address = .{ .x = 1, .y = 1 } });
        self.resetCells();
    }

    pub fn debugRooms(self: *Self) void {
        for (self.rooms.items, 0..) |room, i| {
            helpers.debugPrint("room{d}, {s} - available_slots={d}, live_signals={d}", .{ i, @tagName(room.room), room.slotCount(), room.liveSignalCount() });
        }
    }

    pub fn debugLists(self: *Self) void {
        var hungry = std.ArrayList(u8).init(self.arena);
        {
            const num = std.fmt.allocPrintZ(self.arena, "hungry ({d} items) ->", .{self.food_queue.items.len}) catch unreachable;
            hungry.appendSlice(num) catch unreachable;
        }
        for (self.food_queue.items) |fi| {
            const num = std.fmt.allocPrintZ(self.arena, "{d}, ", .{fi}) catch unreachable;
            hungry.appendSlice(num) catch unreachable;
        }
        hungry.append(0) catch unreachable;
        c.debugPrint(hungry.items.ptr);
    }

    pub fn debugSignals(self: *Self) void {
        for (self.signals.items, 0..) |signal, i| {
            helpers.debugPrint("signal{d} - {s}", .{ i, @tagName(signal.signal) });
        }
    }

    pub fn beeJobsCount(self: *Self) usize {
        var count: u8 = 0;
        for (self.signals.items) |signal| {
            if (signal.signal.isBeeWork()) count += 1;
        }
        return count;
    }
};

const StateData = union(enum) {
    idle: struct {
        hovered_button: ?usize,
    },
    idle_drag: void,
    dragging: struct {
        room: RoomType,
        address: ?Address,
    },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{ .hovered_button = null } },

    hive: Hive,
    highlighted: ?usize = null,
    buttons: std.ArrayList(Button),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .hive = Hive.init(allocator, arena_handle.allocator()),
            .buttons = std.ArrayList(Button).init(allocator),
            .haathi = haathi,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.hive.deinit();
        self.buttons.deinit();
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        const raw_delta_t = ticks - self.ticks;
        const delta_t = @min(raw_delta_t, DELTA_T_CAP);
        self.ticks = ticks;
        self.hive.update(delta_t, self.arena);
        self.highlighted = null;
        for (self.hive.cells.items, 0..) |cell, i| {
            if (cell.containsPoint(self.haathi.inputs.mouse.current_pos)) {
                self.highlighted = i;
                break;
            }
        }
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        self.updateMouseInputs();
        if (self.haathi.inputs.getKey(.num_9).is_clicked) self.hive.speed_up *= 1.1;
        if (self.haathi.inputs.getKey(.num_0).is_clicked) self.hive.speed_up /= 1.1;
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            // self.hive.debugRooms();
            // self.hive.debugLists();
            self.hive.debugSignals();
        }
    }

    fn setup(self: *Self) void {
        self.setupButtons();
    }

    fn setupButtons(self: *Self) void {
        const button_width: f32 = (BUTTON_ROW_WIDTH - (BUTTON_PADDING * (NUM_ROOMS + 1))) / (NUM_ROOMS);
        for (0..NUM_ROOMS) |i| {
            const fi = @floatFromInt(f32, i);
            const room_type = @enumFromInt(RoomType, i);
            const position = Vec2{
                .x = ((BUTTON_PADDING * (fi + 1)) + (fi * button_width)),
                .y = BUTTON_ROW_Y,
            };
            const button = Button{
                .rect = .{
                    .position = position,
                    .size = .{ .x = button_width, .y = BUTTON_HEIGHT },
                },
                .value = @intCast(u8, i),
                .text = @tagName(room_type),
            };
            self.buttons.append(button) catch unreachable;
        }
    }

    fn updateMouseInputs(self: *Self) void {
        switch (self.state) {
            .idle => |_| {
                self.state.idle.hovered_button = null;
                for (self.buttons.items, 0..) |button, i| {
                    if (button.contains(self.haathi.inputs.mouse.current_pos)) {
                        self.state.idle.hovered_button = i;
                        break;
                    }
                }
                if (self.haathi.inputs.mouse.l_button.is_clicked) {
                    if (self.state.idle.hovered_button) |button_index| {
                        const button = self.buttons.items[button_index];
                        self.state = .{ .dragging = .{
                            .room = @enumFromInt(RoomType, button.value),
                            .address = null,
                        } };
                        return;
                    }
                    self.state = .idle_drag;
                    return;
                }
                if (self.haathi.inputs.mouse.r_button.is_clicked) {
                    if (self.highlighted) |hi| {
                        self.hive.deleteRoom(self.hive.cells.items[hi].address);
                    }
                }
            },
            .idle_drag => {
                if (self.haathi.inputs.mouse.l_button.is_released) {
                    c.debugPrint("releasing idle mouse");
                    self.state = .{ .idle = .{ .hovered_button = null } };
                }
            },
            .dragging => |data| {
                c.debugPrint("dragging room");
                self.state.dragging.address = null;
                for (self.hive.cells.items) |cell| {
                    if (cell.containsPoint(self.haathi.inputs.mouse.current_pos)) {
                        self.state.dragging.address = cell.address;
                        break;
                    }
                }
                if (self.haathi.inputs.mouse.l_button.is_released) {
                    c.debugPrint("releasing mouse");
                    if (self.state.dragging.address) |address| {
                        helpers.debugPrint("adding room {s} to {d},{d}", .{ @tagName(data.room), address.x, address.y });
                        self.hive.addRoom(.{ .room = RoomData.fromType(data.room), .address = address });
                    }
                    self.state = .{ .idle = .{ .hovered_button = null } };
                }
            },
        }
    }

    fn drawCell(self: *Self, cell: *Cell, color_override: ?Vec4) void {
        const color = UNOCCUPIED_CELL_COLOR;
        self.haathi.drawPoly(.{ .points = cell.points[0..], .color = color_override orelse color });
        //if (cell.draw_path) {
        //    self.haathi.drawPath(.{
        //        .points = cell.points[0..],
        //        .color = CELL_OUTLINE_COLOR,
        //        .closed = true,
        //        .width = 3,
        //    });
        //}
    }

    fn drawRoomCell(self: *Self, room: Room) void {
        var cell = self.arena.create(Cell) catch unreachable;
        const scale = ZERO_CONSTRUCTED_CELL_SCALE + ((FULL_CELL_SCALE - ZERO_CONSTRUCTED_CELL_SCALE) * (@floatFromInt(f32, room.constructed) / NUM_BUILDERS_REQUIRED_PER_ROOM));
        cell.* = Cell.init(room.address, scale);
        {
            const color = OCCUPIED_HIVE_COLOR;
            self.haathi.drawPoly(.{ .points = cell.points[0..], .color = color });
            if (room.health < 100) {
                const col = if (room.isUnusable()) colors.solarized_red else colors.solarized_orange;
                self.haathi.drawPath(.{ .points = cell.points[0..], .color = col, .closed = true, .width = 3 });
            }
        }
        if (room.room != .incubator and room.isConstructed()) {
            var slots = self.arena.alloc(Cell, 6) catch unreachable;
            for (cell.slotOffsets(), room.slots_available, room.slots_signals, 0..) |pos, avail, signal, i| {
                slots[i] = Cell.initPos(pos, 0.25);
                const color = if (avail) colors.solarized_base00 else colors.solarized_base02;
                self.haathi.drawPoly(.{ .points = slots[i].points[0..], .color = color });
                const color2 = if (signal) colors.solarized_base3 else colors.solarized_base1;
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = .{ .x = 5, .y = 5 },
                    .color = color2,
                    .radius = 10,
                    .centered = true,
                });
            }
        }
        //if (cell.draw_path) {
        //    self.haathi.drawPath(.{
        //        .points = cell.points[0..],
        //        .color = CELL_OUTLINE_COLOR,
        //        .closed = true,
        //        .width = 3,
        //    });
        //}
    }

    pub fn render(self: *Self) void {
        self.haathi.drawText(.{
            .text = "hiveminder",
            .position = .{ .x = 1280 / 2, .y = 720 / 4 },
            .color = colors.solarized_base2.alpha(0.7),
            .style = FONT_1,
        });
        for (self.hive.cells.items) |*cell| {
            self.drawCell(cell, null);
        }
        if (self.highlighted) |cell_index| {
            self.drawCell(&self.hive.cells.items[cell_index], colors.solarized_base03);
        }
        for (self.buttons.items) |button| {
            const button_color = if (button.hovered or button.triggered) colors.solarized_base01 else colors.solarized_base1;
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = button_color,
                .radius = 5,
            });
            self.haathi.drawText(.{
                .position = button.rect.position.add(.{ .x = button.rect.size.x / 2, .y = (button.rect.size.y / 2) + 5 }),
                .text = button.text,
                .color = colors.solarized_base3,
                .style = FONT_1,
            });
        }
        for (self.hive.rooms.items) |room| {
            self.drawRoomCell(room);
            self.haathi.drawText(.{
                .text = @tagName(room.room),
                .position = Cell.addressToPos(room.address),
                .color = colors.solarized_base03,
                .style = FONT_1,
            });
            if (room.room == .storage) {
                const storage = std.fmt.allocPrintZ(self.arena, "{d}/6", .{NUM_SLOTS - room.slotCount()}) catch unreachable;
                self.haathi.drawText(.{
                    .text = storage,
                    .position = Cell.addressToPos(room.address).add(.{ .x = 0, .y = 20 }),
                    .color = colors.solarized_base03,
                    .style = FONT_1,
                });
            }
            if (room.room == .incubator) {
                const storage = std.fmt.allocPrintZ(self.arena, "{d}", .{room.room.incubator}) catch unreachable;
                self.haathi.drawText(.{
                    .text = storage,
                    .position = Cell.addressToPos(room.address).add(.{ .y = 20 }),
                    .color = colors.solarized_base03,
                    .style = FONT_1,
                });
            }
        }
        {
            // jobs queued:
            const job_count = std.fmt.allocPrintZ(self.arena, "{d} jobs queued", .{self.hive.beeJobsCount()}) catch unreachable;
            self.haathi.drawText(.{
                .text = job_count,
                .position = Cell.addressToPos(.{}).add(.{ .x = 0, .y = 90 }),
                .color = colors.solarized_base03,
                .style = FONT_1,
            });
        }
        const y_padding: f32 = (720.0 - (BEE_STATUS_BAR_HEIGHT * NUM_BEES)) / (NUM_BEES + 1.0);
        for (self.hive.bees.items, 0..) |bee, i| {
            const bee_color = if (bee.dead()) colors.solarized_red else colors.solarized_base03;
            self.haathi.drawRect(.{
                .position = bee.position,
                .size = .{ .x = 10, .y = 10 },
                .color = bee_color,
                .radius = 10,
                .centered = true,
            });
            const bee_text = std.fmt.allocPrintZ(self.arena, "{d}", .{i}) catch unreachable;
            self.haathi.drawText(.{
                .text = bee_text,
                .position = bee.position.add(.{ .y = 4 }),
                .color = colors.solarized_base2,
                .style = FONT_2,
            });
            // draw the status of the bee
            const y: f32 = (y_padding * @floatFromInt(f32, i + 1)) + (BEE_STATUS_BAR_HEIGHT * @floatFromInt(f32, i));
            const health = @floatFromInt(f32, bee.health) / 255.0;
            const rest = @floatFromInt(f32, bee.rest) / 255.0;
            self.haathi.drawRect(.{
                .position = .{ .x = BEE_HEALTH_STATUS_X, .y = y },
                .size = .{ .x = BEE_STATUS_BAR_WIDTH, .y = BEE_STATUS_BAR_HEIGHT },
                .color = colors.solarized_base2,
                .centered = false,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = BEE_REST_STATUS_X, .y = y },
                .size = .{ .x = BEE_STATUS_BAR_WIDTH, .y = BEE_STATUS_BAR_HEIGHT },
                .color = colors.solarized_base2,
                .centered = false,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = BEE_HEALTH_STATUS_X, .y = y },
                .size = .{ .x = health * BEE_STATUS_BAR_WIDTH, .y = BEE_STATUS_BAR_HEIGHT },
                .color = colors.solarized_base1,
                .centered = false,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = BEE_REST_STATUS_X, .y = y },
                .size = .{ .x = rest * BEE_STATUS_BAR_WIDTH, .y = BEE_STATUS_BAR_HEIGHT },
                .color = colors.solarized_base1,
                .centered = false,
            });
        }
        if (false) { // draw the addresses of cells
            var x: isize = -10;
            while (x <= HIVE_SIZE + 1) : (x += 1) {
                var y: isize = -10;
                while (y <= HIVE_SIZE + 1) : (y += 1) {
                    const address = Vec2i{ .x = x, .y = y };
                    if (Cell.isValidCellAddress(address)) {
                        const address_str = std.fmt.allocPrintZ(self.arena, "{d},{d}", .{ address.x, address.y }) catch unreachable;
                        self.haathi.drawText(.{
                            .text = address_str,
                            .position = Cell.addressToPos(address),
                            .color = colors.solarized_base03,
                            .style = FONT_2,
                        });
                    }
                }
            }
        }
    }
};
