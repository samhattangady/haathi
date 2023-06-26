const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    target_points: std.ArrayList(f32),
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,
    ticks: u64 = 0,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var target_points = std.ArrayList(f32).init(allocator);
        for (0..1000) |i| {
            var val = (@floatFromInt(f32, i) / 1000) * std.math.pi * 2;
            target_points.append(@sin(val)) catch unreachable;
        }
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        return .{
            .haathi = haathi,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
            .target_points = target_points,
        };
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
    }

    pub fn render(self: *Self) void {
        const padding: f32 = 10;
        const box_size = Vec2{ .x = 300, .y = 200 };
        const box_pos = Vec2{ .x = 1280 - (padding + box_size.x), .y = padding };
        self.haathi.drawRect(.{ .position = box_pos, .size = box_size, .color = colors.solarized_base2, .radius = 10 });
        var points = std.ArrayList(Vec2).init(self.arena);
        for (self.target_points.items, 0..) |point, i| {
            const x = box_pos.x + padding + @floatFromInt(f32, i) / @floatFromInt(f32, self.target_points.items.len) * (box_size.x - padding * 2);
            const y = box_pos.y + padding + ((box_size.y - (2 * padding)) / 2) + (point * ((box_size.y - (2 * padding)) / 2));
            points.append(.{ .x = x, .y = y }) catch unreachable;
        }
        self.haathi.drawPath(.{ .points = points.items, .color = colors.solarized_base1 });
    }
};

const ComponentType = enum {
    source_third,
    source_half,
    source_one,
    source_two,
    source_three,
    min,
    max,
    scale_half,
    scale_double,
    display_main,
};

pub const Component = struct {
    const Self = @This();
    type: ComponentType,
    roots_memory: [8]u8,
    stems_memory: [8]u8,
    roots: []u8,
    stems: []u8,
};
