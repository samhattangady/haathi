const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const FONT_1 = @import("haathi.zig").FONT_1;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;

const NUM_ROWS = 9;
const NUM_COLS = 16;
const NUM_CELLS = NUM_ROWS * NUM_COLS;

const CellAddress = struct {
    row: usize,
    col: usize,
};
const Cell = struct {
    position: Vec2 = undefined,
    address: CellAddress = undefined,
    index: usize = undefined,
};

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    cells: [NUM_CELLS]Cell = [_]Cell{.{}} ** NUM_CELLS,

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
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn setup(self: *Self) void {
        const x_gaps: f32 = SCREEN_SIZE.x / (NUM_COLS + 1);
        const y_gaps: f32 = SCREEN_SIZE.y / (NUM_ROWS + 1);
        for (0..NUM_ROWS) |y| {
            const yf = @floatFromInt(f32, y);
            for (0..NUM_COLS) |x| {
                const index = (y * NUM_COLS) + x;
                const xf = @floatFromInt(f32, x);
                self.cells[index] = .{
                    .position = .{ .x = x_gaps * (xf + 1), .y = y_gaps * (yf + 1) },
                    .address = .{ .row = y, .col = x },
                    .index = index,
                };
            }
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
    }

    fn getCellAddresss(self: *Self, index: usize) CellAddress {
        _ = self;
        _ = index;
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        for (self.cells) |cell| {
            self.haathi.drawRect(.{
                .position = cell.position,
                .size = .{ .x = 6, .y = 6 },
                .color = colors.endesga_grey2,
                .centered = true,
            });
        }
    }
};
