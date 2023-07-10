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
const HEX_SCALE = 30;
const HIVE_SIZE = 7;
const HIVE_ORIGIN = Vec2{ .x = 1280 / 2, .y = 720 / 2 };

const HEX_OFFSETS = [6]Vec2{
    .{ .x = @cos(2 * pi * (0.0 / 6.0)), .y = @sin(2 * pi * (0.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (1.0 / 6.0)), .y = @sin(2 * pi * (1.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (2.0 / 6.0)), .y = @sin(2 * pi * (2.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (3.0 / 6.0)), .y = @sin(2 * pi * (3.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (4.0 / 6.0)), .y = @sin(2 * pi * (4.0 / 6.0)) },
    .{ .x = @cos(2 * pi * (5.0 / 6.0)), .y = @sin(2 * pi * (5.0 / 6.0)) },
};

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

    pub fn init(origin: Vec2, index: Vec2i) Self {
        var self: Self = undefined;
        const center = origin.add(.{ .x = (HEX_SCALE + (HEX_SCALE * HEX_OFFSETS[5].x - HEX_OFFSETS[4].x)) * @floatFromInt(f32, index.x), .y = (HEX_SCALE * HEX_OFFSETS[5].y) * @floatFromInt(f32, index.y) });
        for (HEX_OFFSETS, 0..) |ho, i| {
            self.points[i] = center.add(ho.scale(HEX_SCALE));
        }
        return self;
    }

    pub fn isValidCellAddress(index: Vec2i) bool {
        const x_even = @mod(index.x, 2) == 0;
        const y_even = @mod(index.y, 2) == 0;
        return x_even == y_even;
    }

    pub fn containsPoint(self: *const Self, pos: Vec2) bool {
        const bounding_box = Rect{
            .position = .{ .x = self.points[3].x, .y = self.points[5].y },
            .size = .{ .x = self.points[0].x - self.points[3].x, .y = self.points[1].y - self.points[5].y },
        };
        return helpers.polygonContainsPoint(self.points[0..], pos, bounding_box);
    }
};

pub const Role = enum {
    babysitting,
    food_collection,
    building,
    maintaining,
};

pub const Job = struct {
    const Self = @This();
    role: Role,
    address: Vec2i,
    // slot within the address
    index: u8,
    // index of the bee doing the job
    occupied: ?u16 = null,
    // when the job was created
    ticks_created: u64 = 0,
    // when the job was started
    ticks_started: u64 = 0,

    pub fn update(self: *Self) void {
        _ = self;
    }
};

pub const Room = struct {
    room: enum {
        queen,
        babysitting,
        food_collection,
        building,
        maintaining,
        rest,
        storage,
        incubator,
    },
    address: Vec2i,
};

pub const Bee = struct {
    const Self = @This();
    /// slowly goes up, eventually bee will die.
    age: u8 = 0,
    /// health goes up and down based on food consumption
    health: u8 = 255,
    /// rest goes up and down based on time spent on job and rest
    rest: u8 = 255,
    position: Vec2 = .{},
};

pub const Hive = struct {
    const Self = @This();
    food: usize = 0,
    ticks: u64 = 0,
    bees: std.ArrayList(Bee),
    jobs: std.ArrayList(Job),
    rooms: std.ArrayList(Room),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .bees = std.ArrayList(Bee).init(allocator),
            .jobs = std.ArrayList(Job).init(allocator),
            .rooms = std.ArrayList(Room).init(allocator),
        };
        self.setupHive();
    }

    pub fn deinit(self: *Self) void {
        self.bees.deinit();
        self.jobs.deinit();
        self.rooms.deinit();
    }

    pub fn update(self: *Self, ticks: u64) void {
        // add a tick to each running job
        for (self.jobs.items) |*job| job.update(ticks);
        // check all the current jobs, and see if they are done.
    }
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,

    cells: std.ArrayList(Cell),
    cells_address: std.AutoHashMap(Vec2i, usize),
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
        self.highlighted.clearRetainingCapacity();
        for (self.cells.items, 0..) |cell, i| {
            if (cell.containsPoint(self.haathi.inputs.mouse.current_pos)) self.highlighted.append(i) catch unreachable;
        }
    }

    fn initCells(self: *Self) void {
        var x: isize = -HIVE_SIZE;
        while (x <= HIVE_SIZE + 1) : (x += 1) {
            var y: isize = -10;
            while (y <= HIVE_SIZE + 1) : (y += 1) {
                const address = Vec2i{ .x = x, .y = y };
                if (Cell.isValidCellAddress(address)) {
                    var cell = Cell.init(HIVE_ORIGIN, address);
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
    }
};
