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

const Direction = enum {
    up,
    down,
    right,
};

const Cell = struct {
    address: Vec2i,
    position: Vec2,
    size: f32,
};

const PathCell = struct {
    index: usize,
    direction: Direction,
};

const Player = struct {
    position: Vec2 = .{},
    path_index: usize = 0,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    grid: std.ArrayList(Cell),
    path: std.ArrayList(PathCell),
    player: Player = .{},

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .grid = std.ArrayList(Cell).init(allocator),
            .path = std.ArrayList(PathCell).init(allocator),
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
        const x_padding = (GRID_WIDTH - (CELL_SIZE * NUM_COLS)) / (NUM_COLS + 1);
        const y_padding = (GRID_HEIGHT - (CELL_SIZE * NUM_ROWS)) / (NUM_ROWS + 1);
        for (0..NUM_ROWS) |y| {
            for (0..NUM_COLS) |x| {
                const xf = @floatFromInt(f32, x);
                const yf = @floatFromInt(f32, y);
                const cell = Cell{
                    .address = .{ .x = @intCast(i32, x), .y = @intCast(i32, y) },
                    .position = .{
                        .x = (CELL_SIZE * xf) + (x_padding * (xf + 1)),
                        .y = (CELL_SIZE * yf) + (y_padding * (yf + 1)),
                    },
                    .size = CELL_SIZE,
                };
                self.grid.append(cell) catch unreachable;
            }
        }
    }

    fn createPath(self: *Self) void {
        self.path.clearRetainingCapacity();
        // there are 3 cuts that we will be having to take.
        // we first want to generate those.
        if (DEBUG_PRINT_1) c.debugPrint("createPath 0");
        var rng = std.rand.DefaultPrng.init(self.ticks);
        var cuts = [5]usize{ 0, 0, 0, 0, NUM_COLS - 1 };
        cuts[1] = 2 + rng.random().uintLessThan(usize, NUM_COLS - 8);
        cuts[2] = cuts[1] + 2 + rng.random().uintLessThan(usize, NUM_COLS - 6 - cuts[1]);
        cuts[3] = cuts[2] + 2 + rng.random().uintLessThan(usize, NUM_COLS - 4 - cuts[2]);
        if (DEBUG_PRINT_1) helpers.debugPrint("createPath 1 cols = {d},{d},{d},{d},{d}", .{ cuts[0], cuts[1], cuts[2], cuts[3], cuts[4] });
        var down = true;
        for (cuts, 0..) |col, i| {
            if (DEBUG_PRINT_1) helpers.debugPrint("createPath 2 col{d}", .{col});
            // add path cells along col
            for (0..NUM_ROWS-1) |r| {
                const row = if (down) r else NUM_ROWS - r - 1;
                const index = (row * NUM_COLS) + col;
                const dir: Direction = if (down) .down else .up;
                self.path.append(.{
                    .index = index,
                    .direction = dir,
                }) catch unreachable;
            }
            if (col == NUM_COLS - 1) {
                self.path.append(.{
                    .index = self.grid.items.len-1,
                    .direction = .down,
                }) catch unreachable;
                break;
            }
            // add path cells between cols
            const row: usize = if (down) NUM_ROWS - 1 else 0;
            if (DEBUG_PRINT_1) helpers.debugPrint("createPath 3 col{d}", .{col});
            for (col..cuts[i + 1]) |col_i| {
                const index = (row * NUM_COLS) + col_i;
                self.path.append(.{
                    .index = index,
                    .direction = .right,
                }) catch unreachable;
            }
            down = !down;
        }
    }

    fn movePlayer(self: *Self) void {
        self.player.path_index += 1;
        if (self.player.path_index < self.path.items.len) self.player.position = self.grid.items[self.path.items[self.player.path_index].index].position;
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        if (self.haathi.inputs.getKey(.space).is_clicked) self.createPath();
        if (self.haathi.inputs.getKey(.s).is_clicked) self.movePlayer();
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        self.haathi.drawRect(.{
            .position = self.haathi.inputs.mouse.current_pos,
            .size = .{ .x = 5, .y = 5 },
            .color = colors.endesga_grey2,
            .centered = true,
            .radius = 5,
        });
        for (self.grid.items) |cell| {
            self.haathi.drawRect(.{
                .position = cell.position,
                .size = .{ .x = cell.size, .y = cell.size },
                .color = colors.endesga_grey2.alpha(0.2),
                .radius = 3,
            });
        }
        for (self.path.items) |path| {
            const cell = self.grid.items[path.index];
            self.haathi.drawRect(.{
                .position = cell.position,
                .size = .{ .x = cell.size, .y = cell.size },
                .color = colors.endesga_grey3,
                .radius = 3,
            });
            switch (path.direction) {
                .up => {
                    self.haathi.drawRect(.{
                        .position = cell.position.add(.{ .y = -cell.size / 2 }),
                        .size = .{ .x = cell.size, .y = cell.size },
                        .color = colors.endesga_grey3,
                    });
                },
                .down => {
                    self.haathi.drawRect(.{
                        .position = cell.position.add(.{ .y = cell.size / 2 }),
                        .size = .{ .x = cell.size, .y = cell.size },
                        .color = colors.endesga_grey3,
                    });
                },
                .right => {
                    self.haathi.drawRect(.{
                        .position = cell.position.add(.{ .x = cell.size / 2 }),
                        .size = .{ .x = cell.size, .y = cell.size },
                        .color = colors.endesga_grey3,
                    });
                },
            }
        }
            self.haathi.drawRect(.{
                .position = self.player.position.add(.{.x=CELL_SIZE/2, .y=CELL_SIZE/2}),
                .size = .{ .x = 20, .y = 20 },
                .color = colors.endesga_grey4,
                .radius = 3,
                .centered=true,
            });
    }
};
