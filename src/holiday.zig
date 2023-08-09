const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;

const FONT_1 = "18px JetBrainsMono";

const NUM_ROWS = 10;
const NUM_COLS = 25;
const GRID_HEIGHT = SCREEN_SIZE.y * 0.7;
const GRID_WIDTH = SCREEN_SIZE.x;
const CELL_SIZE = 40;
const DEBUG_PRINT_1 = false;

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
};

const Pin = struct {
    const Self = @This();
    position: Vec2 = undefined,
    size: f32 = 20,
    // x is the col, y is the row
    // in one row, x is either all even or odd
    // first pin is at 0, 0
    // second row is -1,1 and 1,1
    // third row is -2,2, 0,2 and 2,2
    // and so on.
    address: Vec2i,
    fallen: bool = false,

    pub fn init(address: Vec2i, num_rows: usize) Self {
        var self = Self{ .address = address };
        self.setPosition(num_rows);
        return self;
    }

    pub fn setPosition(self: *Self, num_rows: usize) void {
        _ = num_rows; // TODO (08 Aug 2023): Use for scaling.
        const spacing = 60; // pins are placed in equilateral triangles.
        const x_padding = spacing * 0.5;
        const y_padding = spacing * @cos(std.math.pi / 6.0);
        const origin = SCREEN_SIZE.scale(0.5);
        self.position.x = origin.x + (x_padding * @as(f32, @floatFromInt(self.address.x)));
        self.position.y = origin.y - (y_padding * @as(f32, @floatFromInt(self.address.y)));
    }
};

const Dropper = struct {
    target: Vec2i,
    index: ?usize,
    direction: Vec2i,
};

const PinDrop = struct {
    index: usize,
    // if prev is null, then pin was dropped by ball
    prev: ?usize,
    gen: usize,
};

const Ball = struct {
    position: Vec2,
    address: Vec2i,
    direction: Vec2i,
};

const Phalanx = struct {
    const Self = @This();
    pins: std.ArrayList(Pin),
    drops: std.ArrayList(PinDrop),
    queue: std.ArrayList(Dropper),
    ticks: u64 = 0,
    sim_generation: usize = 0,
    ball: Ball = undefined,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .pins = std.ArrayList(Pin).init(allocator),
            .drops = std.ArrayList(PinDrop).init(allocator),
            .queue = std.ArrayList(Dropper).init(allocator),
            .allocator = allocator,
        };
        self.setup();
        return self;
    }

    fn setup(self: *Self) void {
        // setup 4 rows.
        const addresses = [_]Vec2i{
            .{ .x = 0, .y = 0 },
            .{ .x = -1, .y = 1 },
            .{ .x = 1, .y = 1 },
            .{ .x = -2, .y = 2 },
            .{ .x = 0, .y = 2 },
            .{ .x = 2, .y = 2 },
            .{ .x = -3, .y = 3 },
            .{ .x = -1, .y = 3 },
            .{ .x = 1, .y = 3 },
            .{ .x = 3, .y = 3 },
            .{ .x = -4, .y = 4 },
            .{ .x = -2, .y = 4 },
            .{ .x = 0, .y = 4 },
            .{ .x = 2, .y = 4 },
            .{ .x = 4, .y = 4 },
        };
        for (addresses) |adr| {
            const pin = Pin.init(adr, 4);
            self.pins.append(pin) catch unreachable;
        }
    }

    fn throwBall(self: *Self) void {
        self.ball = .{
            .address = .{},
            .direction = .{ .x = -1, .y = 1 },
            .position = SCREEN_SIZE.scale(0.5).add(.{ .y = 100 }),
        };
        self.setBallPosition();
        self.sim_generation = 0;
        self.queue.clearRetainingCapacity();
    }

    fn setBallPosition(self: *Self) void {
        const pin = Pin.init(self.ball.address, 4);
        self.ball.position = pin.position.add(.{ .x = @as(f32, @floatFromInt(self.ball.direction.x)) * -25, .y = 25 });
    }

    fn simulationStep(self: *Self) void {
        const len = self.queue.items.len;
        for (0..len) |_| {
            const drop = self.queue.orderedRemove(0);
            if (self.standingPinAt(drop.target)) |pin_index| {
                self.pins.items[pin_index].fallen = true;
                const fall = PinDrop{ .index = pin_index, .prev = drop.index, .gen = self.sim_generation };
                self.drops.append(fall) catch unreachable;
                self.queue.append(.{
                    .target = drop.target.add(drop.direction),
                    .index = pin_index,
                    .direction = drop.direction,
                }) catch unreachable;
            }
        }
        if (self.standingPinAt(self.ball.address)) |pin_index| {
            self.pins.items[pin_index].fallen = true;
            const fall = PinDrop{ .index = pin_index, .prev = null, .gen = self.sim_generation };
            self.drops.append(fall) catch unreachable;
            self.queue.append(.{
                .target = self.ball.address.add(self.ball.direction),
                .index = pin_index,
                .direction = self.ball.direction,
            }) catch unreachable;
            self.ball.direction.x *= -1;
        }
        self.sim_generation += 1;
        self.ball.address = self.ball.address.add(self.ball.direction);
        self.setBallPosition();
    }

    fn standingPinAt(self: *Self, address: Vec2i) ?usize {
        for (self.pins.items, 0..) |pin, i| {
            if (pin.fallen) continue;
            if (pin.address.equal(address)) return i;
        }
        return null;
    }
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    phalanx: Phalanx,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .phalanx = Phalanx.init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn setup(self: *Self) void {
        self.phalanx.throwBall();
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        if (self.haathi.inputs.getKey(.space).is_clicked) self.phalanx.simulationStep();
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        for (self.phalanx.pins.items) |pin| {
            self.haathi.drawRect(.{
                .position = pin.position,
                .size = .{ .x = pin.size, .y = pin.size },
                .color = colors.endesga_grey2,
                .centered = true,
                .radius = pin.size,
            });
            if (pin.fallen) {
                self.haathi.drawRect(.{
                    .position = pin.position,
                    .size = .{ .x = pin.size, .y = pin.size },
                    .color = colors.endesga_grey4,
                    .centered = true,
                    .radius = pin.size,
                });
            }
        }
        self.haathi.drawRect(.{
            .position = self.phalanx.ball.position,
            .size = .{ .x = 50, .y = 50 },
            .color = colors.endesga_blue2,
            .centered = true,
            .radius = 50,
        });
    }
};
