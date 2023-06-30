const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;

const DISPLAY_SIZE = 300;
const SIN_HALF = sineWaveScaled(0.5);
const SIN_ONE = sineWaveScaled(1);
const SIN_TWO = sineWaveScaled(2);
const COS_HALF = cosWaveScaled(0.5);
const COS_ONE = cosWaveScaled(1);
const COS_TWO = cosWaveScaled(2);
const CONST_ONE = constantWave(1);
const CONST_ZERO = constantWave(0);
const CONST_MINUS_ONE = constantWave(-1);
const DISPLAY_PADDING = 10;
const DISPLAY_BOX_SIZE = Vec2{ .x = 300, .y = 200 };
const COMPONENT_HEIGHT = 28;
const COMPONENT_WIDTH = 84;
const NUM_COMPONENT_ROWS = 9;
const NUM_COMPONENT_COLS = 8;
const NUM_BUTTON_ROWS = 2;
const NUM_BUTTON_COLS = 3;
const COMPONENT_RADIUS = COMPONENT_HEIGHT / 4;
const HIGHLIGHT_WIDTH = 3;
const STAGE_SELECT_Y = (DISPLAY_PADDING * 2) + DISPLAY_BOX_SIZE.y;
const STAGE_SELECT_SIZE = 16;
const STAGE_RADIUS = 3;
const STAGES = [_]WaveDisplay{
    stage(0),
    stage(1),
    stage(2),
    stage(3),
    stage(4),
    stage(5),
    stage(6),
    stage(7),
    stage(8),
    stage(9),
};
const MESSAGE_LINE1 = "sine cosine desine";
const MESSAGE_LINE2_1 = "the fundamental building block";
const MESSAGE_LINE2_2 = "of the universe is the wave";
const MESSAGE_LINE3_1 = "just waves all the way down";
const MESSAGE_LINE3_2 = "";
const MESSAGE_LINE4_1 = "just waves";
const MESSAGE_LINE4_2 = "all the way down";

const FONT_1 = "18px JetBrainsMono";
const TEXT_1_SIZE = 18;
const TEXT_1_YOFF = COMPONENT_HEIGHT - 8;
const FONT_2 = "16px JetBrainsMono";
const TEXT_2_SIZE = 16;
const TEXT_2_YOFF = COMPONENT_HEIGHT - 7;

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

fn constantWave(scale: f32) [DISPLAY_SIZE]f32 {
    var points: [DISPLAY_SIZE]f32 = undefined;
    for (0..DISPLAY_SIZE) |i| {
        points[i] = scale;
    }
    return points;
}

fn stage(lvl: usize) WaveDisplay {
    @setEvalBranchQuota(1000000);
    var wave = WaveDisplay{};
    switch (lvl) {
        0 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = (@sin(val));
            }
        },
        1 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = @fabs(@sin(val));
            }
        },
        2 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = @fabs(@cos(val));
            }
        },
        3 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = 0.5 + (@sin(val * 2) * 0.25);
            }
        },
        4 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = -0.5 + (@fabs(@cos(val * 2)) * -0.25);
            }
        },
        5 => {
            for (0..DISPLAY_SIZE) |i| {
                var t = @floatFromInt(f32, i) / DISPLAY_SIZE;
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = @max(t, @sin(val));
            }
        },
        6 => {
            for (0..DISPLAY_SIZE) |i| {
                var t = @floatFromInt(f32, i) / DISPLAY_SIZE;
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                wave.points[i] = (@sin(val) * (1 - t));
            }
        },
        7 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                const sin = 2 * @sin(val * 2);
                wave.points[i] = @min(@max(-1, sin), 1);
            }
        },
        8 => {
            for (0..DISPLAY_SIZE) |i| {
                var t = @floatFromInt(f32, i) / DISPLAY_SIZE;
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                const cos2t = @cos(val * 2);
                wave.points[i] = @min(t, @max(cos2t, -t));
            }
        },
        9 => {
            for (0..DISPLAY_SIZE) |i| {
                var val = (@floatFromInt(f32, i) / DISPLAY_SIZE) * std.math.pi * 2;
                const cos2t = @cos(val * 2) * 0.5;
                wave.points[i] = @max(@max(0, cos2t), @min(1, @cos(val) * 2));
            }
        },
        else => unreachable,
    }
    return wave;
}

const WaveDisplay = struct {
    points: [DISPLAY_SIZE]f32 = [_]f32{0} ** DISPLAY_SIZE,
    display: [DISPLAY_SIZE]Vec2 = undefined,
};

const COMPONENT_NAMES = [NUM_COMPONENTS][]const u8{
    "sin t/2",
    "sin t",
    "sin 2t",
    "1",
    "0",
    "-1",
    "cos t/2",
    "cos t",
    "cos 2t",
    "min",
    "max",
    "x 0.5",
    "x 2",
    "x -1",
    "x t",
    "x 2t",
    "x (1-t)",
    "avg",
    "output",
    "debug",
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
    scale_negate,
    scale_t,
    scale_two_t,
    scale_one_minus_t,
    average,
    output_main,
    display1,

    pub fn getSource(self: *const Self) ?*const [DISPLAY_SIZE]f32 {
        return switch (self.*) {
            .sin_half => &SIN_HALF,
            .sin_one => &SIN_ONE,
            .sin_two => &SIN_TWO,
            .cos_half => &COS_HALF,
            .cos_one => &COS_ONE,
            .cos_two => &COS_TWO,
            .const_one => &CONST_ONE,
            .const_zero => &CONST_ZERO,
            .const_minus_one => &CONST_MINUS_ONE,
            // non source types
            .min,
            .max,
            .scale_half,
            .scale_double,
            .scale_negate,
            .scale_t,
            .scale_two_t,
            .scale_one_minus_t,
            .average,
            .output_main,
            .display1,
            => null,
        };
    }

    pub fn isCalc(self: *const Self) bool {
        return switch (self.*) {
            .min,
            .max,
            .scale_half,
            .scale_double,
            .scale_negate,
            .scale_t,
            .scale_two_t,
            .scale_one_minus_t,
            .average,
            => true,
            .sin_half,
            .sin_one,
            .sin_two,
            .const_one,
            .const_zero,
            .const_minus_one,
            .cos_half,
            .cos_one,
            .cos_two,
            .output_main,
            .display1,
            => false,
        };
    }

    pub fn canDelete(self: *const Self) bool {
        return switch (self.*) {
            .sin_half,
            .sin_one,
            .sin_two,
            .const_one,
            .const_zero,
            .const_minus_one,
            .cos_half,
            .cos_one,
            .cos_two,
            .output_main,
            .display1,
            => false,
            .min,
            .max,
            .scale_half,
            .scale_double,
            .scale_negate,
            .scale_t,
            .scale_two_t,
            .scale_one_minus_t,
            .average,
            => true,
        };
    }

    pub fn singleInput(self: *const Self) bool {
        return switch (self.*) {
            .scale_half,
            .scale_double,
            .scale_negate,
            .scale_t,
            .scale_two_t,
            .scale_one_minus_t,
            .output_main,
            .display1,
            => true,
            .min,
            .max,
            .average,
            .sin_half,
            .sin_one,
            .sin_two,
            .const_one,
            .const_zero,
            .const_minus_one,
            .cos_half,
            .cos_one,
            .cos_two,
            => false,
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

    pub fn propogateCalculation(self: *Self, components: []Self, index: usize) void {
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
            .scale_half => {
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * 0.5;
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .scale_double => {
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * 2;
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .scale_negate => {
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * -1;
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .scale_t => {
                const t = @floatFromInt(f32, index) / @floatFromInt(f32, DISPLAY_SIZE);
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * t;
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .scale_one_minus_t => {
                const t = @floatFromInt(f32, index) / @floatFromInt(f32, DISPLAY_SIZE);
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * (1 - t);
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .scale_two_t => {
                const t = @floatFromInt(f32, index) / @floatFromInt(f32, DISPLAY_SIZE);
                const val = if (self.inputs.len == 0) 0 else self.inputs[0] * (2 * t);
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            .average => {
                var avg_val: f32 = 0;
                if (self.inputs.len > 0) {
                    for (self.inputs) |input| avg_val += input;
                    avg_val = avg_val / @floatFromInt(f32, self.inputs.len);
                }
                for (self.stems) |stem| _ = components[stem].addInput(avg_val);
            },
            .display1 => {
                const val = if (self.inputs.len > 0) self.inputs[0] else 0;
                for (self.stems) |stem| _ = components[stem].addInput(val);
            },
            else => unreachable,
        }
    }
};

const ComponentButton = struct {
    const Self = @This();
    rect: Rect,
    component_type: ComponentType,
};

const Control = enum {
    clear,
    verify,
    previous_level,
    next_level,
};

const ControlButton = struct {
    const Self = @This();
    rect: Rect,
    text: []const u8,
    control: Control,
};

const BUTTONS = [3][3]ComponentType{
    .{ .scale_one_minus_t, .scale_t, .scale_two_t },
    .{ .scale_half, .scale_negate, .scale_double },
    .{ .min, .average, .max },
};

const ComponentSlot = struct {
    const Self = @This();
    rect: Rect,
    component_type: ?ComponentType = null,
    row: u8,
    col: u8,

    pub fn singleInput(self: *const Self) bool {
        if (self.component_type) |ct| return ct.singleInput();
        return false;
    }
};

const Connection = struct {
    root: u8,
    stem: u8,
};

const StateData = union(enum) {
    idle: struct { hovered_button: ?usize = null, hovered_slot: ?usize = null, hovered_control: ?usize = null },
    idle_drag: void,
    button_drag: struct { component_type: ComponentType, hovered_slot: ?usize = null },
    create_connection: struct { root: u8, stem: ?u8 = null },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    target_points: WaveDisplay = .{},
    output_points: WaveDisplay = .{},
    display_points: WaveDisplay = .{},

    state: StateData = .{ .idle = .{} },
    update_display: bool = true,
    ticks: u64 = 0,
    temp_connection: ?Connection = null,
    show_display_graph: bool = false,
    stage_index: usize = 0,
    stage_name_buffer: [16]u8 = undefined,
    stage_name: []const u8 = undefined,
    completed_stages: [STAGES.len]bool = [_]bool{false} ** STAGES.len,
    text_y: f32 = 0,

    components: std.ArrayList(Component),
    buttons: std.ArrayList(ComponentButton),
    controls: std.ArrayList(ControlButton),
    slots: std.ArrayList(ComponentSlot),
    connections: std.ArrayList(Connection),
    hovered_connections: std.ArrayList(usize),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var components = std.ArrayList(Component).init(allocator);
        var buttons = std.ArrayList(ComponentButton).init(allocator);
        {
            const button_padding_y: f32 = (720 - (NUM_COMPONENT_ROWS * COMPONENT_HEIGHT)) / (NUM_COMPONENT_ROWS + 1);
            const button_padding_x: f32 = ((DISPLAY_BOX_SIZE.x + (DISPLAY_PADDING * 2)) - (NUM_BUTTON_COLS * COMPONENT_WIDTH)) / (NUM_BUTTON_COLS + 1);
            for (BUTTONS, 0..) |button_row, row| {
                for (button_row, 0..) |button, col| {
                    if (button == .const_zero) continue;
                    const col_x = @floatFromInt(f32, col);
                    const x = (1280 - DISPLAY_BOX_SIZE.x - (2 * DISPLAY_PADDING)) + (button_padding_x * (col_x + 1)) + (col_x * COMPONENT_WIDTH);
                    const y = 720 - ((1.3 * button_padding_y) + (@floatFromInt(f32, row) * ((button_padding_y / 2) + COMPONENT_HEIGHT)));
                    // const y = button_padding_y + ((@floatFromInt(f32, row) + (NUM_COMPONENT_ROWS - BUTTONS.len)) * ((button_padding_y / 2) + COMPONENT_HEIGHT));
                    buttons.append(.{
                        .rect = .{ .position = .{ .x = x, .y = y }, .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT } },
                        .component_type = button,
                    }) catch unreachable;
                }
            }
        }
        var slots = std.ArrayList(ComponentSlot).init(allocator);
        {
            const component_padding_y: f32 = (720 - (NUM_COMPONENT_ROWS * COMPONENT_HEIGHT)) / (NUM_COMPONENT_ROWS + 1);
            const component_padding_x: f32 = ((1280 - DISPLAY_BOX_SIZE.x - (DISPLAY_PADDING * 2)) - (NUM_COMPONENT_COLS * COMPONENT_WIDTH)) / (NUM_COMPONENT_COLS + 1);
            for (0..NUM_COMPONENT_COLS) |col| {
                const j = @floatFromInt(f32, col);
                const x = ((j + 1) * component_padding_x) + (j * COMPONENT_WIDTH);
                for (0..NUM_COMPONENT_ROWS) |row| {
                    const i = @floatFromInt(f32, row);
                    const y = ((i + 1) * component_padding_y) + (i * COMPONENT_HEIGHT);
                    const t: ?ComponentType = if (col == 0) @enumFromInt(ComponentType, row) else null;
                    slots.append(.{
                        .rect = .{ .position = .{ .x = x, .y = y }, .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT } },
                        .component_type = t,
                        .row = @intCast(u8, row),
                        .col = @intCast(u8, col),
                    }) catch unreachable;
                }
            }
        }
        slots.items[slots.items.len - 1].component_type = .output_main;
        slots.items[slots.items.len - 2].component_type = .display1;
        var connections = std.ArrayList(Connection).init(allocator);
        var controls = std.ArrayList(ControlButton).init(allocator);
        var text_y: f32 = 0;
        {
            const level_row_y = STAGE_SELECT_Y + STAGE_SELECT_SIZE + DISPLAY_PADDING;
            const clear_row_y = level_row_y + 40;
            text_y = clear_row_y + 50;
            const x_start = 1280 - DISPLAY_BOX_SIZE.x - DISPLAY_PADDING;
            const x_end = 1280 - DISPLAY_PADDING;
            controls.append(.{
                .rect = .{
                    .position = .{ .x = x_start, .y = level_row_y },
                    .size = .{ .x = COMPONENT_WIDTH * 0.4, .y = COMPONENT_HEIGHT },
                },
                .text = "<",
                .control = .previous_level,
            }) catch unreachable;
            controls.append(.{
                .rect = .{
                    .position = .{ .x = x_end - (COMPONENT_WIDTH * 0.4), .y = level_row_y },
                    .size = .{ .x = COMPONENT_WIDTH * 0.4, .y = COMPONENT_HEIGHT },
                },
                .text = ">",
                .control = .next_level,
            }) catch unreachable;
            controls.append(.{
                .rect = .{
                    .position = .{ .x = x_start, .y = clear_row_y },
                    .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT },
                },
                .text = "clear",
                .control = .clear,
            }) catch unreachable;
            controls.append(.{
                .rect = .{
                    .position = .{ .x = x_end - (COMPONENT_WIDTH), .y = clear_row_y },
                    .size = .{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT },
                },
                .text = "verify",
                .control = .verify,
            }) catch unreachable;
        }
        return .{
            .haathi = haathi,
            .buttons = buttons,
            .slots = slots,
            .components = components,
            .connections = connections,
            .controls = controls,
            .hovered_connections = std.ArrayList(usize).init(allocator),
            .text_y = text_y,
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Self) void {
        self.components.deinit();
        self.buttons.deinit();
        self.slots.deinit();
        self.connections.deinit();
        self.hovered_connections.deinit();
        // TODO (28 Jun 2023 sam): deinit the allocators and things also?
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.updateMouseState();
        if (self.update_display) self.updateGraphs();
    }

    fn updateMouseState(self: *Self) void {
        switch (self.state) {
            .idle => {
                const mouse = self.haathi.inputs.mouse;
                self.state.idle.hovered_button = null;
                self.state.idle.hovered_slot = null;
                self.state.idle.hovered_control = null;
                self.hovered_connections.clearRetainingCapacity();
                for (self.buttons.items, 0..) |button, i| {
                    if (button.rect.contains(mouse.current_pos)) {
                        self.state.idle.hovered_button = i;
                        break;
                    }
                }
                for (self.slots.items, 0..) |slot, i| {
                    if (slot.rect.contains(mouse.current_pos)) {
                        self.state.idle.hovered_slot = i;
                        break;
                    }
                }
                for (self.controls.items, 0..) |control, i| {
                    if (control.rect.contains(mouse.current_pos)) {
                        self.state.idle.hovered_control = i;
                        break;
                    }
                }
                if (mouse.l_button.is_clicked) {
                    if (self.state.idle.hovered_button) |hb| {
                        self.state = .{ .button_drag = .{ .component_type = self.buttons.items[hb].component_type } };
                        return;
                    }
                    if (self.state.idle.hovered_slot) |hs| {
                        if (self.slots.items[hs].component_type != null) {
                            self.state = .{ .create_connection = .{ .root = @intCast(u8, hs) } };
                            return;
                        }
                    }
                    if (self.state.idle.hovered_control) |hc| {
                        self.triggerControl(self.controls.items[hc].control);
                    }
                    self.state = .idle_drag;
                    return;
                }
                if (mouse.r_button.is_clicked) {
                    if (self.state.idle.hovered_slot) |si| {
                        if (self.slots.items[si].component_type) |ct| {
                            self.deleteConnectionsInvolving(si);
                            if (ct.canDelete()) self.slots.items[si].component_type = null;
                            self.update_display = true;
                        }
                    }
                }
                if (self.state.idle.hovered_slot) |si| {
                    if (self.slots.items[si].component_type) |_| {
                        for (self.connections.items, 0..) |conn, i| {
                            if (conn.root == si or conn.stem == si) self.hovered_connections.append(i) catch unreachable;
                        }
                    }
                }
            },
            .idle_drag => {
                const mouse = self.haathi.inputs.mouse;
                if (!mouse.l_button.is_down) {
                    self.state = .{ .idle = .{} };
                    return;
                }
            },
            .button_drag => |data| {
                const mouse = self.haathi.inputs.mouse;
                self.state.button_drag.hovered_slot = null;
                for (self.slots.items, 0..) |slot, i| {
                    if (slot.component_type != null) continue;
                    if (slot.rect.contains(mouse.current_pos)) {
                        self.state.button_drag.hovered_slot = i;
                    }
                }
                if (!mouse.l_button.is_down) {
                    if (self.state.button_drag.hovered_slot) |si|
                        self.slots.items[si].component_type = data.component_type;
                    self.state = .{ .idle = .{} };
                    return;
                }
            },
            .create_connection => |data| {
                const mouse = self.haathi.inputs.mouse;
                self.state.create_connection.stem = null;
                self.temp_connection = null;
                for (self.slots.items, 0..) |slot, i| {
                    if (slot.component_type == null) continue;
                    if (slot.rect.contains(mouse.current_pos)) {
                        if (i > data.root) {
                            self.state.create_connection.stem = @intCast(u8, i);
                            self.temp_connection = .{ .root = data.root, .stem = @intCast(u8, i) };
                        }
                    }
                }
                if (!mouse.l_button.is_down) {
                    // if (self.state.create_connection.stem) |si|
                    //     self.slots.items[si].component_type = data.component_type;
                    if (self.temp_connection) |conn| self.addConnection(conn);
                    self.temp_connection = null;
                    self.state = .{ .idle = .{} };
                    return;
                }
            },
        }
    }

    fn triggerControl(self: *Self, control: Control) void {
        switch (control) {
            .clear => {
                self.clearSlots();
            },
            .verify => {
                var match = true;
                for (0..DISPLAY_SIZE) |i| {
                    if (self.output_points.points[i] != self.target_points.points[i]) {
                        match = false;
                        break;
                    }
                }
                if (match) self.completed_stages[self.stage_index] = true;
            },
            .previous_level => {
                if (self.stage_index > 0) {
                    self.update_display = true;
                    self.stage_index -= 1;
                }
            },
            .next_level => {
                if (self.stage_index < STAGES.len - 1) {
                    self.update_display = true;
                    self.stage_index += 1;
                }
            },
        }
    }

    fn clearSlots(self: *Self) void {
        self.connections.clearRetainingCapacity();
        for (self.slots.items) |*slot| {
            if (slot.component_type != null and slot.component_type.?.canDelete())
                slot.component_type = null;
        }
        self.update_display = true;
    }

    fn updateGraphs(self: *Self) void {
        // clear the existing display
        @memset(self.output_points.points[0..], 0);
        @memset(self.display_points.points[0..], 0);
        self.target_points = STAGES[self.stage_index];
        self.show_display_graph = false;
        self.stage_name = std.fmt.bufPrintZ(self.stage_name_buffer[0..], "wave {d}", .{self.stage_index + 1}) catch unreachable;
        if (self.stage_index == 9) self.stage_name = "¯\\_(^_^)_/¯";
        self.components.clearRetainingCapacity();
        // create the new components
        {
            // index_map has key as the slot index, value as component index
            var index_map = std.AutoHashMap(u8, u8).init(self.arena);
            defer index_map.deinit();
            for (self.slots.items, 0..) |slot, si| {
                if (slot.component_type) |ct| {
                    const comp_index = @intCast(u8, self.components.items.len);
                    self.components.append(Component.new(ct)) catch unreachable;
                    index_map.put(@intCast(u8, si), comp_index) catch unreachable;
                }
            }
            for (self.connections.items) |conn| {
                const ri = index_map.get(conn.root).?;
                const si = index_map.get(conn.stem).?;
                _ = self.components.items[ri].addStem(si);
                _ = self.components.items[si].addRoot(ri);
            }
        }
        for (0..DISPLAY_SIZE) |i| {
            for (self.components.items) |*component| component.clearInputs();
            for (self.components.items) |*component| {
                if (component.type.getSource()) |source| {
                    const val = source[i];
                    for (component.stems) |stem_idx| _ = self.components.items[stem_idx].addInput(val);
                }
                if (component.type.isCalc() or component.type == .display1) {
                    component.propogateCalculation(self.components.items, i);
                }
                if (component.type == .output_main and component.inputs.len > 0) {
                    self.output_points.points[i] = component.inputs[0];
                }
                if (component.type == .display1) {
                    if (component.inputs.len > 0) {
                        self.display_points.points[i] = component.inputs[0];
                        self.show_display_graph = true;
                    }
                }
            }
        }
        self.update_display = false;
    }

    fn addConnection(self: *Self, connection: Connection) void {
        // Every connection should have the stem_idx > root_idx
        if (connection.stem > connection.root) {
            // If stem only supports single input, remove all other connections with stem
            if (self.slots.items[connection.stem].singleInput()) self.deleteConnectionsWithStem(connection.stem);
            self.connections.append(connection) catch unreachable;
            self.update_display = true;
        }
    }

    fn deleteConnectionsWithStem(self: *Self, index: u8) void {
        var i: usize = self.connections.items.len;
        while (i > 0) : (i -= 1) {
            const j = i - 1;
            const conn = self.connections.items[j];
            if (conn.stem == index) _ = self.connections.orderedRemove(j);
        }
    }

    fn deleteConnectionsInvolving(self: *Self, index: usize) void {
        var i: usize = self.connections.items.len;
        while (i > 0) : (i -= 1) {
            const j = i - 1;
            const conn = self.connections.items[j];
            if (conn.root == index or conn.stem == index) _ = self.connections.orderedRemove(j);
        }
    }

    pub fn drawConnection(self: *Self, connection: Connection, active: bool) void {
        var color = if (active) colors.solarized_base02 else colors.solarized_base0;
        var path = std.ArrayList(Vec2).init(self.arena);
        const root = self.slots.items[connection.root].rect;
        const stem = self.slots.items[connection.stem].rect;
        path.append(root.position.add(root.size.scale(0.5))) catch unreachable;
        path.append(stem.position.add(stem.size.scale(0.5))) catch unreachable;
        self.haathi.drawPath(.{ .points = path.items[0..], .color = color });
    }

    fn drawMessage(self: *Self) void {
        self.haathi.drawText(.{
            .text = MESSAGE_LINE1,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF },
            .color = colors.solarized_base2.alpha(0.7),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE2_1,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (1 * (TEXT_2_YOFF)) + 4 },
            .color = colors.solarized_base2.alpha(0.65),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE2_2,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (2 * (TEXT_2_YOFF)) + 4 },
            .color = colors.solarized_base2.alpha(0.60),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE3_1,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (3 * (TEXT_2_YOFF)) + 8 },
            .color = colors.solarized_base2.alpha(0.55),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE3_2,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (4 * (TEXT_2_YOFF)) + 12 },
            .color = colors.solarized_base2.alpha(0.50),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE4_1,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (5 * (TEXT_2_YOFF)) + 12 },
            .color = colors.solarized_base2.alpha(0.45),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = MESSAGE_LINE4_2,
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (6 * (TEXT_2_YOFF)) + 12 },
            .color = colors.solarized_base2.alpha(0.4),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
        self.haathi.drawText(.{
            .text = "bye",
            .position = .{ .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2), .y = self.text_y + TEXT_2_YOFF + (8 * (TEXT_2_YOFF)) + 12 },
            .color = colors.solarized_base2.alpha(0.2),
            .style = FONT_2,
            .width = DISPLAY_BOX_SIZE.x,
        });
    }

    pub fn render(self: *Self) void {
        const padding: f32 = DISPLAY_PADDING;
        const box_size = DISPLAY_BOX_SIZE;
        const box_pos = Vec2{ .x = 1280 - (padding + box_size.x), .y = padding };
        self.haathi.drawRect(.{ .position = .{ .x = 1280 - ((padding * 2) + 300), .y = 0 }, .size = .{ .x = 300 + (padding * 2), .y = 720 }, .color = colors.solarized_base0 });
        self.haathi.drawRect(.{ .position = box_pos, .size = box_size, .color = colors.solarized_base1, .radius = 10 });
        self.drawMessage();
        const displays = [_]*WaveDisplay{ &self.target_points, &self.output_points, &self.display_points };
        const cols = [displays.len]Vec4{ colors.solarized_base2, colors.solarized_base03, colors.solarized_base01 };
        const widths = [displays.len]f32{ 8, 5, 3 };
        for (displays, cols, widths, 0..) |display, col, w, di| {
            if (di == 2 and !self.show_display_graph) continue;
            for (display.points, 0..) |point, i| {
                const x = box_pos.x + padding + @floatFromInt(f32, i) / (DISPLAY_SIZE - 1) * (box_size.x - padding * 2);
                const y = box_pos.y + padding + ((box_size.y - (2 * padding)) / 2) - (point * ((box_size.y - (2 * padding)) / 2));
                display.display[i] = .{ .x = x, .y = y };
            }
            self.haathi.drawPath(.{ .points = display.display[0..], .color = col, .width = w });
        }
        var hovered_slot: ?usize = if (self.state == .idle) self.state.idle.hovered_slot else null;
        if (hovered_slot == null and self.state == .create_connection) {
            hovered_slot = self.state.create_connection.root;
        }
        for (self.slots.items) |slot| {
            if (slot.component_type == null) {
                self.haathi.drawRect(.{
                    .position = slot.rect.position,
                    .size = slot.rect.size,
                    .color = colors.solarized_base2,
                    .radius = COMPONENT_RADIUS,
                });
            }
        }
        for (self.connections.items) |conn| self.drawConnection(conn, false);
        if (self.temp_connection) |conn| self.drawConnection(conn, true);
        for (self.hovered_connections.items) |ci| self.drawConnection(self.connections.items[ci], true);
        for (self.slots.items, 0..) |slot, i| {
            if (slot.component_type) |t| {
                if (hovered_slot != null and hovered_slot.? == i) {
                    self.haathi.drawRect(.{
                        .position = slot.rect.position.add(.{ .x = -HIGHLIGHT_WIDTH, .y = -HIGHLIGHT_WIDTH }),
                        .size = slot.rect.size.add(.{ .x = HIGHLIGHT_WIDTH * 2, .y = HIGHLIGHT_WIDTH * 2 }),
                        .color = colors.solarized_base01,
                        .radius = COMPONENT_RADIUS + HIGHLIGHT_WIDTH,
                    });
                }
                self.haathi.drawRect(.{
                    .position = slot.rect.position,
                    .size = slot.rect.size,
                    .color = colors.solarized_base0,
                    .radius = COMPONENT_RADIUS,
                });
                self.haathi.drawText(.{
                    .text = COMPONENT_NAMES[@intFromEnum(t)],
                    .position = slot.rect.position.add(.{ .x = slot.rect.size.x / 2, .y = TEXT_1_YOFF }),
                    .color = colors.solarized_base3,
                    .style = FONT_1,
                });
            }
        }
        var hovered_button: ?usize = if (self.state == .idle) self.state.idle.hovered_button else null;
        for (self.buttons.items, 0..) |button, i| {
            if (hovered_button != null and hovered_button.? == i) {
                self.haathi.drawRect(.{
                    .position = button.rect.position.add(.{ .x = -HIGHLIGHT_WIDTH, .y = -HIGHLIGHT_WIDTH }),
                    .size = button.rect.size.add(.{ .x = HIGHLIGHT_WIDTH * 2, .y = HIGHLIGHT_WIDTH * 2 }),
                    .color = colors.solarized_base3,
                    .radius = COMPONENT_RADIUS + HIGHLIGHT_WIDTH,
                });
            }
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = colors.solarized_base00,
                .radius = COMPONENT_RADIUS,
            });
            self.haathi.drawText(.{
                .text = COMPONENT_NAMES[@intFromEnum(button.component_type)],
                .position = button.rect.position.add(.{ .x = button.rect.size.x / 2, .y = TEXT_1_YOFF }),
                .color = colors.solarized_base2,
                .style = FONT_1,
            });
        }
        var hovered_control: ?usize = if (self.state == .idle) self.state.idle.hovered_control else null;
        for (self.controls.items, 0..) |control, i| {
            if (hovered_control != null and hovered_control.? == i) {
                self.haathi.drawRect(.{
                    .position = control.rect.position.add(.{ .x = -HIGHLIGHT_WIDTH, .y = -HIGHLIGHT_WIDTH }),
                    .size = control.rect.size.add(.{ .x = HIGHLIGHT_WIDTH * 2, .y = HIGHLIGHT_WIDTH * 2 }),
                    .color = colors.solarized_base01,
                    .radius = COMPONENT_RADIUS + HIGHLIGHT_WIDTH,
                });
            }
            self.haathi.drawRect(.{
                .position = control.rect.position,
                .size = control.rect.size,
                .color = colors.solarized_base2,
                .radius = COMPONENT_RADIUS,
            });
            self.haathi.drawText(.{
                .text = control.text,
                .position = control.rect.position.add(.{ .x = control.rect.size.x / 2, .y = TEXT_1_YOFF }),
                .color = colors.solarized_base00,
                .style = FONT_1,
            });
        }
        self.haathi.drawText(.{
            .text = self.stage_name,
            .position = .{
                .x = 1280 - DISPLAY_PADDING - (DISPLAY_BOX_SIZE.x / 2),
                .y = self.controls.items[0].rect.position.y + TEXT_1_YOFF,
            },
            .color = colors.solarized_base2,
            .style = FONT_1,
        });
        {
            // stage select
            const x_start = 1280 - DISPLAY_PADDING - DISPLAY_BOX_SIZE.x;
            const x_end = 1280 - DISPLAY_PADDING;
            const stage_padding: f32 = ((x_end - x_start) - (@floatFromInt(f32, STAGES.len) * STAGE_SELECT_SIZE)) / @floatFromInt(f32, STAGES.len - 1);
            for (0..STAGES.len) |i| {
                const pos = Vec2{
                    .x = x_start + ((stage_padding + STAGE_SELECT_SIZE) * @floatFromInt(f32, i)),
                    .y = STAGE_SELECT_Y,
                };
                if (i == self.stage_index) {
                    self.haathi.drawRect(.{
                        .position = pos.add(.{ .x = -HIGHLIGHT_WIDTH, .y = -HIGHLIGHT_WIDTH }),
                        .size = .{ .x = STAGE_SELECT_SIZE + HIGHLIGHT_WIDTH * 2, .y = STAGE_SELECT_SIZE + HIGHLIGHT_WIDTH * 2 },
                        .color = colors.solarized_base01,
                        .radius = STAGE_RADIUS + HIGHLIGHT_WIDTH,
                    });
                }
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = .{ .x = STAGE_SELECT_SIZE, .y = STAGE_SELECT_SIZE },
                    .color = colors.solarized_base2,
                    .radius = STAGE_RADIUS,
                });
                if (self.completed_stages[i]) {
                    self.haathi.drawRect(.{
                        .position = pos.add(.{ .x = HIGHLIGHT_WIDTH, .y = HIGHLIGHT_WIDTH }),
                        .size = .{ .x = STAGE_SELECT_SIZE - HIGHLIGHT_WIDTH * 2, .y = STAGE_SELECT_SIZE - HIGHLIGHT_WIDTH * 2 },
                        .color = colors.solarized_base01,
                        .radius = STAGE_RADIUS,
                    });
                }
            }
        }
        if (self.state == .button_drag) {
            const size = Vec2{ .x = COMPONENT_WIDTH, .y = COMPONENT_HEIGHT };
            var pos = self.haathi.inputs.mouse.current_pos.add(size.scale(-0.5));
            if (self.state.button_drag.hovered_slot) |si| pos = self.slots.items[si].rect.position;
            self.haathi.drawRect(.{
                .position = pos,
                .size = size,
                .color = colors.solarized_base01,
                .radius = COMPONENT_RADIUS,
            });
            self.haathi.drawText(.{
                .text = COMPONENT_NAMES[@intFromEnum(self.state.button_drag.component_type)],
                .position = pos.add(.{ .x = size.x / 2, .y = TEXT_1_YOFF }),
                .color = colors.solarized_base2,
                .style = FONT_1,
            });
        }
    }
};
