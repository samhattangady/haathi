const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Rect = helpers.Rect;

const DISPLAY_SIZE = 300;
const SIN_HALF = sineWaveScaled(0.5);
const SIN_ONE = sineWaveScaled(1);
const SIN_TWO = sineWaveScaled(2);
const COS_HALF = cosWaveScaled(0.5);
const COS_ONE = cosWaveScaled(1);
const COS_TWO = cosWaveScaled(2);
const DISPLAY_PADDING = 10;
const DISPLAY_BOX_SIZE = Vec2{ .x = 300, .y = 200 };
const COMPONENT_HEIGHT = 28;
const COMPONENT_WIDTH = 84;
const NUM_COMPONENT_ROWS = 9;
const NUM_COMPONENT_COLS = 8;
const NUM_BUTTON_ROWS = 2;
const NUM_BUTTON_COLS = 3;
const COMPONENT_RADIUS = COMPONENT_HEIGHT / 4;

const FONT_1 = "18px JetBrainsMono";
const TEXT_1_SIZE = 18;
// const TEXT_1_YOFF = COMPONENT_HEIGHT - ((COMPONENT_HEIGHT - TEXT_1_SIZE) / 2);
const TEXT_1_YOFF = COMPONENT_HEIGHT - 8;

fn sineWaveScaled(scale: f32) [DISPLAY_SIZE]f32 {
    var points: [DISPLAY_SIZE]f32 = undefined;
    for (0..DISPLAY_SIZE) |i| {
        var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2 * scale;
        points[i] = @sin(val);
    }
    return points;
}

fn cosWaveScaled(scale: f32) [DISPLAY_SIZE]f32 {
    var points: [DISPLAY_SIZE]f32 = undefined;
    for (0..DISPLAY_SIZE) |i| {
        var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2 * scale;
        points[i] = @cos(val);
    }
    return points;
}

const WaveDisplay = struct {
    points: [DISPLAY_SIZE]f32 = [_]f32{0} ** DISPLAY_SIZE,
    display: [DISPLAY_SIZE]Vec2 = undefined,
};

const COMPONENT_NAMES = [NUM_COMPONENTS][]const u8{
    "sin t/2",
    "sin t",
    "sin 2t",
    "-1",
    "0",
    "1",
    "cos t/2",
    "cos t",
    "cos 2t",
    "min",
    "max",
    "x 0.5",
    "x 2",
    "avg",
    "display",
};

const ComponentType = enum {
    const Self = @This();
    sin_half,
    sin_one,
    sin_two,
    const_one,
    const_zero,
    const_minus_one,
    cos_half,
    cos_one,
    cos_two,
    min,
    max,
    scale_half,
    scale_double,
    average,
    display_main,

    pub fn getSource(self: *const Self) ?*const [DISPLAY_SIZE]f32 {
        return switch (self.*) {
            .sin_half => &SIN_HALF,
            .sin_one => &SIN_ONE,
            .sin_two => &SIN_TWO,
            .cos_half,
            .cos_one,
            .cos_two,
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
const NUM_COMPONENTS = @typeInfo(ComponentType).Enum.fields.len;

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

const ComponentButton = struct {
    const Self = @This();
    rect: Rect,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    target_points: WaveDisplay,
    components: std.ArrayList(Component),
    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,
    update_display: bool = true,
    buttons: std.ArrayList(ComponentButton),
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
            components.append(Component.new(.sin_one)) catch unreachable;
            components.append(Component.new(.sin_two)) catch unreachable;
            components.append(Component.new(.min)) catch unreachable;
            components.append(Component.new(.display_main)) catch unreachable;
            _ = components.items[0].addStem(2);
            _ = components.items[1].addStem(2);
            _ = components.items[2].addRoot(0);
            _ = components.items[2].addRoot(1);
            _ = components.items[2].addStem(3);
            _ = components.items[3].addRoot(2);
        }
        var buttons = std.ArrayList(ComponentButton).init(allocator);
        {
            const button_padding_y: f32 = (720 - (NUM_COMPONENT_ROWS * COMPONENT_HEIGHT)) / (NUM_COMPONENT_ROWS + 1);
            const button_padding_x: f32 = ((DISPLAY_BOX_SIZE.x + (DISPLAY_PADDING * 2)) - (NUM_BUTTON_COLS * COMPONENT_WIDTH)) / (NUM_BUTTON_COLS + 1);
            for (0..3) |col| {
                const col_x = @floatFromInt(f32, col);
                const x = (1280 - DISPLAY_BOX_SIZE.x - (2 * DISPLAY_PADDING)) + (button_padding_x * (col_x + 1)) + (col_x * COMPONENT_WIDTH);
                const y = 720 - button_padding_y;
                buttons.append(.{ .rect = .{ .position = .{ .x = x, .y = y }, .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT } } }) catch unreachable;
            }
        }
        return .{
            .haathi = haathi,
            .buttons = buttons,
            .components = components,
            .target_points = target_points,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.components.deinit();
        self.buttons.deinit();
        // TODO (28 Jun 2023 sam): deinit the allocators and things also?
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        if (self.update_display) self.updateGraphs();
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
        self.update_display = false;
    }

    pub fn render(self: *Self) void {
        const padding: f32 = DISPLAY_PADDING;
        const box_size = DISPLAY_BOX_SIZE;
        const box_pos = Vec2{ .x = 1280 - (padding + box_size.x), .y = padding };
        self.haathi.drawRect(.{ .position = .{ .x = 1280 - ((padding * 2) + 300), .y = 0 }, .size = .{ .x = 300 + (padding * 2), .y = 720 }, .color = colors.solarized_base0 });
        self.haathi.drawRect(.{ .position = box_pos, .size = box_size, .color = colors.solarized_base1, .radius = 10 });
        for (self.target_points.points, 0..) |point, i| {
            const x = box_pos.x + padding + @floatFromInt(f32, i) / (DISPLAY_SIZE - 1) * (box_size.x - padding * 2);
            const y = box_pos.y + padding + ((box_size.y - (2 * padding)) / 2) - (point * ((box_size.y - (2 * padding)) / 2));
            self.target_points.display[i] = .{ .x = x, .y = y };
        }
        self.haathi.drawPath(.{ .points = self.target_points.display[0..], .color = colors.solarized_base2 });
        self.haathi.drawRect(.{ .position = self.haathi.inputs.mouse.current_pos, .size = .{ .x = 5, .y = 5 }, .color = colors.solarized_base00 });
        // Drawing the components
        {
            const component_padding_y: f32 = (720 - (NUM_COMPONENT_ROWS * COMPONENT_HEIGHT)) / (NUM_COMPONENT_ROWS + 1);
            const component_padding_x: f32 = ((1280 - DISPLAY_BOX_SIZE.x - (DISPLAY_PADDING * 2)) - (NUM_COMPONENT_COLS * COMPONENT_WIDTH)) / (NUM_COMPONENT_COLS + 1);
            for (0..NUM_COMPONENT_COLS) |row| {
                const j = @floatFromInt(f32, row);
                const x = ((j + 1) * component_padding_x) + (j * COMPONENT_WIDTH);
                for (0..NUM_COMPONENT_ROWS) |col| {
                    const i = @floatFromInt(f32, col);
                    const y = ((i + 1) * component_padding_y) + (i * COMPONENT_HEIGHT);
                    const color = if (row == 0) colors.solarized_base1 else colors.solarized_base2;
                    self.haathi.drawRect(.{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT },
                        .color = color,
                        .radius = COMPONENT_RADIUS,
                    });
                    // TODO (28 Jun 2023 sam): Not ideal that we are using the component enum ordering for this.
                    if (row == 0) {
                        self.haathi.drawText(.{
                            .text = COMPONENT_NAMES[col],
                            .position = .{ .x = x + (COMPONENT_WIDTH / 2), .y = y + TEXT_1_YOFF },
                            .color = colors.solarized_base3,
                            .style = FONT_1,
                        });
                    }
                }
            }
        }
        for (self.buttons.items) |button| {
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = colors.solarized_base00,
                .radius = COMPONENT_RADIUS,
            });
        }
    }
};
