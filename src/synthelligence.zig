const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;

const DISPLAY_SIZE = 300;
const SOURCE_ONE = sineWaveScaled(1);
const SOURCE_TWO = sineWaveScaled(2);

fn sineWaveScaled(scale: f32) [DISPLAY_SIZE]f32 {
    var points: [DISPLAY_SIZE]f32 = undefined;
    for (0..DISPLAY_SIZE) |i| {
        var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2 * scale;
        points[i] = @sin(val);
    }
    return points;
}

const WaveDisplay = struct {
    points: [DISPLAY_SIZE]f32 = [_]f32{0} ** DISPLAY_SIZE,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    target_points: WaveDisplay,
    components: std.ArrayList(Component),
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,
    ticks: u64 = 0,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var target_points = WaveDisplay{};
        for (0..DISPLAY_SIZE) |i| {
            var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 4;
            target_points.points[i] = @sin(val);
        }
        var components = std.ArrayList(Component).init(allocator);
        {
            components.append(Component.new(.source_one)) catch unreachable;
            components.append(Component.new(.source_two)) catch unreachable;
            components.append(Component.new(.min)) catch unreachable;
            components.append(Component.new(.display_main)) catch unreachable;
            _ = components.items[0].addStem(2);
            _ = components.items[1].addStem(2);
            _ = components.items[2].addRoot(0);
            _ = components.items[2].addRoot(1);
            _ = components.items[2].addStem(3);
            _ = components.items[3].addRoot(2);
        }
        return .{
            .haathi = haathi,
            .components = components,
            .target_points = target_points,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.updateGraphs();
    }

    fn updateGraphs(self: *Self) void {
        // TODO (27 Jun 2023 sam): We are doing a single pass here. Maybe that cannot be done
        // in the future? Or we would need some kind of reordering to be done when updating
        // connections.
        for (0..DISPLAY_SIZE) |i| {
            for (self.components.items) |*component| component.clearInputs();
            for (self.components.items) |*component| {
                if (component.type.getSource()) |source| {
                    const val = source[i];
                    for (component.stems) |stem_idx| _ = self.components.items[stem_idx].addInput(val);
                }
                if (component.type.isCalc()) {
                    component.propogateCalculation(self.components.items);
                }
                if (component.type == .display_main) {
                    self.target_points.points[i] = component.inputs[0];
                }
            }
        }
    }

    pub fn render(self: *Self) void {
        const padding: f32 = 10;
        const box_size = Vec2{ .x = 300, .y = 200 };
        const box_pos = Vec2{ .x = 1280 - (padding + box_size.x), .y = padding };
        self.haathi.drawRect(.{ .position = box_pos, .size = box_size, .color = colors.solarized_base2, .radius = 10 });
        var points = std.ArrayList(Vec2).init(self.arena);
        for (self.target_points.points, 0..) |point, i| {
            const x = box_pos.x + padding + @floatFromInt(f32, i) / (DISPLAY_SIZE - 1) * (box_size.x - padding * 2);
            const y = box_pos.y + padding + ((box_size.y - (2 * padding)) / 2) - (point * ((box_size.y - (2 * padding)) / 2));
            points.append(.{ .x = x, .y = y }) catch unreachable;
        }
        self.haathi.drawPath(.{ .points = points.items, .color = colors.solarized_base1 });
    }
};

const ComponentType = enum {
    const Self = @This();
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

    pub fn getSource(self: *const Self) ?*const [DISPLAY_SIZE]f32 {
        return switch (self.*) {
            .source_one => &SOURCE_ONE,
            .source_two => &SOURCE_TWO,
            .source_third,
            .source_half,
            .source_three,
            => null, // TODO
            else => null,
        };
    }

    pub fn isCalc(self: *const Self) bool {
        return switch (self.*) {
            .min,
            .max,
            => true,
            else => false,
        };
    }
};

pub const Component = struct {
    const Self = @This();
    type: ComponentType,
    roots_memory: [8]u8 = undefined,
    stems_memory: [8]u8 = undefined,
    roots: []u8 = undefined,
    stems: []u8 = undefined,
    inputs_memory: [8]f32 = [_]f32{ -5, -5, -5, -5, -5, -5, -5, -5 },
    inputs: []f32 = undefined,
    // output: f32 = 0,

    pub fn new(type_: ComponentType) Self {
        var self = Self{ .type = type_ };
        self.roots = self.roots_memory[0..0];
        self.stems = self.stems_memory[0..0];
        self.inputs = self.inputs_memory[0..];
        return self;
    }

    pub fn addRoot(self: *Self, root: u8) bool {
        const root_idx = self.roots.len;
        if (root_idx >= 8) return false;
        self.roots_memory[root_idx] = root;
        self.roots = self.roots_memory[0 .. root_idx + 1];
        return true;
    }

    pub fn addStem(self: *Self, stem: u8) bool {
        const stem_idx = self.stems.len;
        if (stem_idx >= 8) return false;
        self.stems_memory[stem_idx] = stem;
        self.stems = self.stems_memory[0 .. stem_idx + 1];
        return true;
    }

    pub fn clearInputs(self: *Self) void {
        self.inputs = self.inputs_memory[0..0];
    }

    pub fn addInput(self: *Self, input: f32) bool {
        const input_idx = self.inputs.len;
        if (input_idx >= 8) return false;
        self.inputs_memory[input_idx] = input;
        self.inputs = self.inputs_memory[0 .. input_idx + 1];
        return true;
    }

    pub fn propogateCalculation(self: *Self, components: []Self) void {
        switch (self.type) {
            .min => {
                var min_value: f32 = 2;
                for (self.inputs) |input| {
                    if (input < min_value) min_value = input;
                }
                for (self.stems) |stem| _ = components[stem].addInput(min_value);
            },
            .max => {
                var max_value: f32 = -2;
                for (self.inputs) |input| {
                    if (input > max_value) max_value = input;
                }
                for (self.stems) |stem| _ = components[stem].addInput(max_value);
            },
            else => {},
        }
    }
};
