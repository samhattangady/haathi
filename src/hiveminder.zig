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
const FONT_1 = "18px JetBrainsMono";
const FONT_2 = "12px JetBrainsMono";
const HEX_SCALE = 30;
const HIVE_SIZE = 7;
const HIVE_ORIGIN = Vec2{ .x = 1280 / 2, .y = 720 / 2 };
const NUM_SLOTS = 6;
const BEE_TRAVEL_SPEED = 0.25;
const BEE_REACH_DISTANCE_SQR = HEX_SCALE * 0.2;
const POLLEN_WAYPOINT = Vec2i{ .x = 8, .y = -12 };
/// number of ticks between reduction of health / rest for bees
const BEE_TICK_RATE = 100;
const BEE_SPEED_VARIATION = 0.2;
const PRINT_F_DEBUG = false;
const BEE_STATUS_BAR_HEIGHT = 5;
const BEE_STATUS_BAR_WIDTH = 80;
const BEE_HEALTH_STATUS_X = 1280 - BEE_STATUS_BAR_WIDTH - BEE_STATUS_BAR_WIDTH - 20;
const BEE_REST_STATUS_X = 1280 - BEE_STATUS_BAR_WIDTH - 10;
const NUM_BEES = 100;
const DELTA_T_CAP = 200;
const BEE_AGE_LIMIT = 2550;
const NUM_START_BEES = 2;
const QUEEN_ADDRESS = Vec2i{ .x = 0, .y = 0 };
const BEE_BIRTH_TICKS = 120;

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

const NEIGHBOURS = NEIGHBOURS_1 ++ NEIGHBOURS_2;

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

    pub fn init(address: Vec2i) Self {
        var self: Self = undefined;
        const origin = HIVE_ORIGIN;
        const center = origin.add(.{ .x = (HEX_SCALE + (HEX_SCALE * HEX_OFFSETS[5].x - HEX_OFFSETS[4].x)) * @floatFromInt(f32, address.x), .y = (HEX_SCALE * HEX_OFFSETS[5].y) * @floatFromInt(f32, address.y) });
        for (HEX_OFFSETS, 0..) |ho, i| {
            self.points[i] = center.add(ho.scale(HEX_SCALE));
        }
        return self;
    }

    pub fn isValidCellAddress(address: Vec2i) bool {
        const x_even = @mod(address.x, 2) == 0;
        const y_even = @mod(address.y, 2) == 0;
        return x_even == y_even;
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

    /// corollary of decrementWhenRoomConsumes. The bee now needs to lost the signal that
    /// was left open by the room
    pub fn shouldCloseDestinationSignals(self: *const Self) bool {
        return switch (self.*) {
            .collection,
            .building,
            .maintaining,
            .babysitting_egg,
            .babysitting_food,
            .babysitting_attention,
            => true,
            .eating,
            .rest,
            => false,
        };
    }
    /// corollary of decrementWhenRoomConsumes. The bee now needs to lost the signal that
    /// was left open by the room
    pub fn shouldCloseWaypointSignals(self: *const Self) bool {
        return switch (self.*) {
            .babysitting_food => true,
            .babysitting_egg,
            .babysitting_attention,
            .collection,
            .building,
            .maintaining,
            .eating,
            .rest,
            => false,
        };
    }
};

pub const RoomData = union(enum) {
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

    pub fn canConsume(self: *const Self, signal: SignalType) bool {
        return switch (self.room) {
            .collection => signal == .storage_space_available,
            else => false,
        };
    }

    pub fn tryConsumeSignal(self: *Self, signal: *const Signal) ?Signal {
        if (signal.consumed) return null;
        if (self.room == .collection and signal.signal == .storage_space_available) {
            for (self.slots_available, 0..) |avail, i| {
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
        if (self.room == .incubator and self.slots_signals[0] == false) { // not yet sent signal
            const stage = self.room.incubator;
            if (stage == 1 and signal.signal == .storage_food_available) {
                self.slots_signals[0] = true;
                return Signal{
                    .signal = .incubator_food_required,
                    .room = .{ .address = self.address, .slot_index = 0 },
                    .waypoint = signal.room,
                    .destination = .{ .address = self.address, .slot_index = 0 },
                };
            }
        }
        if (self.room == .babysitting) {
            for (self.slots_available, 0..) |avail, i| {
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
    pub fn getCurrentTargetAddress(self: *const Self) Address {
        return switch (self.getCurrentStage()) {
            .to_room => self.room.address,
            .room_to_waypoint => self.waypoint.?.address,
            .waypoint_to_destination, .room_to_destination => self.destination.?.address,
            .at_destination => {
                c.debugPrint("try to getCurrentTargetAddress of .at_destination");
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
            => bee.moving = Cell.addressToPos(self.getCurrentTargetAddress()),
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
                self.moving = Cell.addressToPos(signal.room.address);
                return true;
            },
            .collection_bee_required => {
                self.job = .{
                    .role = .collection,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.addressToPos(signal.room.address);
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
                self.moving = Cell.addressToPos(signal.room.address);
                return true;
            },
            .babysitting_food_required => {
                self.job = .{
                    .role = .babysitting_food,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.addressToPos(signal.room.address);
                return true;
            },
            .babysitting_egg_required => {
                self.job = .{
                    .role = .babysitting_egg,
                    .room = signal.room,
                    .waypoint = signal.waypoint,
                    .destination = signal.destination,
                };
                self.moving = Cell.addressToPos(signal.room.address);
                return true;
            },
            .babysitting_attention_required => {
                self.job = .{
                    .role = .babysitting_attention,
                    .room = signal.room,
                    .waypoint = null,
                    .destination = signal.destination,
                };
                self.moving = Cell.addressToPos(signal.room.address);
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
    incubator_food_required,
    incubator_attention_required,
    incubator_egg_required,
    queen_egg_available,
    queen_attention_required,
    babysitting_food_required,
    babysitting_egg_required,
    babysitting_attention_required,
    collection_bee_required,

    /// Several signals are emitted, and meant to be picked up by other rooms. So when
    /// those initial signals are consumed, we don't want to mark the signal as done.
    /// The signal will be managed once the downstream signal has been consumed.
    pub fn decrementWhenRoomConsumes(self: *const Self) bool {
        return switch (self.*) {
            .storage_space_available,
            .storage_food_available,
            .incubator_food_required,
            .incubator_attention_required,
            .incubator_egg_required,
            => false,
            .rest_slot_available,
            .room_maintenance_required,
            .room_construction_required,
            .queen_egg_available,
            .queen_attention_required,
            .collection_bee_required,
            .babysitting_food_required,
            .babysitting_egg_required,
            .babysitting_attention_required,
            => true,
        };
    }

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
    signals: std.ArrayList(Signal),
    food_queue: std.ArrayList(usize),
    work_queue: std.ArrayList(usize),
    rest_queue: std.ArrayList(usize),
    /// the previous time that health rest etc was reduced
    prev_tick_down: u64 = 0,
    working_bees: usize = 0,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .rng = std.rand.DefaultPrng.init(0),
            .bees = std.ArrayList(Bee).init(allocator),
            .jobs = std.ArrayList(Job).init(allocator),
            .rooms = std.ArrayList(Room).init(allocator),
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
        self.signals.deinit();
    }

    pub fn update(self: *Self, ticks: u64, arena: std.mem.Allocator) void {
        const raw_delta_t = ticks - self.ticks;
        const delta_t = @min(raw_delta_t, DELTA_T_CAP);
        self.ticks = ticks;
        self.arena = arena;
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_0");
        // iterate through all bees. move them if required. check if job is complete
        for (self.bees.items, 0..) |*bee, b| {
            if (bee.dead()) continue;
            if (bee.job) |*job| {
                if (bee.moving) |target_pos| {
                    // bee is either moving to job room or job destination
                    const travel = target_pos.subtract(bee.position).normalize().scale(@floatFromInt(f32, delta_t) * BEE_TRAVEL_SPEED * bee.speed);
                    bee.position = bee.position.add(travel);
                    if (target_pos.distanceSqr(bee.position) < BEE_REACH_DISTANCE_SQR) {
                        bee.job = job.nextStage(bee, ticks);
                    }
                } else {
                    // bee is not moving. bee is doing job.
                    if (job.jobTicksPerformed(self.ticks) > job.role.ticksLength()) {
                        // job is complete. mark bee as free
                        self.roomAt(job.room.address).?.slots_available[job.room.slot_index] = true;
                        self.roomAt(job.room.address).?.slots_signals[job.room.slot_index] = false;
                        // if the job needs to update the room do that.
                        if (job.role.shouldCloseDestinationSignals()) {
                            self.roomAt(job.destination.?.address).?.slots_available[job.destination.?.slot_index] = true;
                            self.roomAt(job.destination.?.address).?.slots_signals[job.destination.?.slot_index] = false;
                        }
                        if (job.role.shouldCloseWaypointSignals()) {
                            self.roomAt(job.waypoint.?.address).?.slots_available[job.destination.?.slot_index] = false;
                            self.roomAt(job.waypoint.?.address).?.slots_signals[job.destination.?.slot_index] = false;
                        }
                        switch (job.role) {
                            .rest => {
                                bee.rest = 255;
                            },
                            .eating => {
                                bee.health = 255;
                            },
                            .babysitting_egg, .babysitting_food, .babysitting_attention => {
                                self.roomAt(job.destination.?.address).?.room.incubator += 1;
                            },
                            else => {},
                        }
                        bee.job = null;
                        self.work_queue.append(b) catch unreachable;
                        if (false) helpers.debugPrint("bee{d} completed job", .{b});
                    }
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_1");
        // iterate through all the rooms that emit signals.
        for (self.rooms.items) |*room| {
            switch (room.room) {
                .storage => {
                    for (room.slots_available, 0..) |avail, i| {
                        if (room.slots_signals[i]) continue;
                        if (avail) {
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
                else => {},
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_2");
        // iterate through all the signals, and see if they can be consumed by nearby rooms
        for (self.signals.items, 0..) |*signal, i| {
            if (signal.consumed) continue;
            const center = signal.room.address;
            for (NEIGHBOURS) |n| {
                const address = center.add(n);
                if (self.roomAt(address)) |room| {
                    if (room.tryConsumeSignal(signal)) |new_signal| {
                        if (room.room == .incubator) helpers.debugPrint("signal{d} was consumed by incubator", .{i});
                        signal.consumed = true;
                        if (signal.signal.decrementWhenRoomConsumes()) self.roomAt(signal.room.address).?.slots_signals[signal.room.slot_index] = false;
                        self.signals.append(new_signal) catch unreachable;
                        break;
                    }
                }
            }
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_3");
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
        while (self.ticks - self.prev_tick_down > BEE_TICK_RATE) {
            self.prev_tick_down += BEE_TICK_RATE;
            for (self.bees.items, 0..) |*bee, i| {
                if (bee.health > 0) {
                    bee.health -= 1;
                    if (bee.health == 128) self.food_queue.append(i) catch unreachable;
                }
                if (bee.rest > 0) {
                    bee.rest -= 1;
                    if (bee.rest == 128) self.rest_queue.append(i) catch unreachable;
                }
                if (bee.age < BEE_AGE_LIMIT) bee.age += 1;
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
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_6");
        {
            // check working bees counts
            var count: usize = 0;
            for (self.bees.items) |bee| {
                if (bee.job != null) count += 1;
            }
            if (count != self.working_bees) helpers.debugPrint("{d} working bees", .{count});
            self.working_bees = count;
        }
        if (PRINT_F_DEBUG) c.debugPrint("hive_update_7");
    }

    fn addBee(self: *Self, address: Address) void {
        var bee = Bee{};
        bee.position = Cell.addressToPos(address);
        bee.speed = (1 - BEE_SPEED_VARIATION) + (self.rng.random().float(f32) * 2 * BEE_SPEED_VARIATION);
        self.work_queue.insert(0, self.bees.items.len) catch unreachable;
        self.bees.append(bee) catch unreachable;
    }

    fn setupHive(self: *Self) void {
        for (0..NUM_START_BEES) |_| self.addBee(QUEEN_ADDRESS);
        self.rooms.append(.{ .room = .queen, .address = QUEEN_ADDRESS }) catch unreachable;
        self.rooms.append(.{ .room = .storage, .address = .{ .x = -1, .y = -1 } }) catch unreachable;
        self.rooms.append(.{ .room = .collection, .address = .{ .x = 1, .y = -1 } }) catch unreachable;
        self.rooms.append(.{ .room = .babysitting, .address = .{ .x = -1, .y = 1 } }) catch unreachable;
        self.rooms.append(.{ .room = .{ .incubator = 0 }, .address = .{ .x = 1, .y = 1 } }) catch unreachable;
        self.rooms.append(.{ .room = .rest, .address = .{ .x = 0, .y = -2 } }) catch unreachable;
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

    fn roomAt(self: *Self, address: Vec2i) ?*Room {
        for (self.rooms.items) |*room| {
            if (address.equal(room.address)) return room;
        }
        return null;
    }
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,

    cells: std.ArrayList(Cell),
    cells_address: std.AutoHashMap(Vec2i, usize),
    hive: Hive,
    highlighted: std.ArrayList(usize),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .cells = std.ArrayList(Cell).init(allocator),
            .cells_address = std.AutoHashMap(Vec2i, usize).init(allocator),
            .highlighted = std.ArrayList(usize).init(allocator),
            .hive = Hive.init(allocator, arena_handle.allocator()),
            .haathi = haathi,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.cells.deinit();
        self.cells_address.deinit();
        self.highlighted.deinit();
        self.hive.deinit();
    }

    fn setup(self: *Self) void {
        self.initCells();
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.hive.update(self.ticks, self.arena);
        self.highlighted.clearRetainingCapacity();
        for (self.cells.items, 0..) |cell, i| {
            if (cell.containsPoint(self.haathi.inputs.mouse.current_pos)) self.highlighted.append(i) catch unreachable;
        }
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            // self.hive.debugRooms();
            self.hive.debugLists();
        }
    }

    fn initCells(self: *Self) void {
        var x: isize = -HIVE_SIZE;
        while (x <= HIVE_SIZE + 1) : (x += 1) {
            var y: isize = -10;
            while (y <= HIVE_SIZE + 1) : (y += 1) {
                const address = Vec2i{ .x = x, .y = y };
                if (Cell.isValidCellAddress(address)) {
                    var cell = Cell.init(address);
                    cell.address = address;
                    self.cells_address.put(address, self.cells.items.len) catch unreachable;
                    self.cells.append(cell) catch unreachable;
                }
            }
        }
    }

    fn drawCell(self: *Self, cell: *Cell, color: Vec4) void {
        self.haathi.drawPoly(.{ .points = cell.points[0..], .color = color });
        self.haathi.drawPath(.{
            .points = cell.points[0..],
            .color = colors.solarized_base00,
            .closed = true,
            .width = 3,
        });
    }

    fn cellAt(self: *Self, address: Vec2i) *Cell {
        std.debug.assert(Cell.isValidCellAddress(address));
        const cell_address = self.cells_address.get(.{ .x = 0, .y = 0 }).?;
        return &self.cells.items[cell_address];
    }

    pub fn render(self: *Self) void {
        self.haathi.drawText(.{
            .text = "hiveminder",
            .position = .{ .x = 1280 / 2, .y = 720 / 4 },
            .color = colors.solarized_base2.alpha(0.7),
            .style = FONT_1,
        });
        for (self.cells.items) |*cell| {
            self.drawCell(cell, colors.solarized_base1);
        }
        for (self.highlighted.items) |cell_index| {
            self.drawCell(&self.cells.items[cell_index], colors.solarized_red);
        }
        for (self.hive.rooms.items) |room| {
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
                    .position = Cell.addressToPos(room.address).add(.{ .y = 20 }),
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
