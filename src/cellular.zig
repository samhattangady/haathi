const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const serializer = @import("serializer.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;
const TextLine = helpers.TextLine;

const RULE_PANE_PADDING = 20;
const CELL_PADDING = 4;
const CELL_SIZE = 15;
const BOARD_CENTER = Vec2{ .x = SCREEN_SIZE.x * (2.0 / 3.0), .y = SCREEN_SIZE.y * 0.5 };
const BOARD_CELL_SIZE = 10;
const BOARD_CELL_PADDING = 4;
const STEP_PLAY_RATE_TICKS = 100;
const BUTTON_PADDING = 20;
const BUTTON_WIDTH = 150;
const BUTTON_HEIGHT = 30;

const EDITOR_STYLE = "10px JetBrainsMono";

const LEVELS = [_][]const u8{
    @embedFile("cell_levels/autosolver.json"),
    @embedFile("cell_levels/lev1.json"),
    @embedFile("cell_levels/lev2.json"),
    @embedFile("cell_levels/needs_fixed_conditions.json"),
};

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
};

const CellType = enum {
    const Self = @This();
    blank,
    thing,
    permanent,

    pub fn toColor(self: *const Self) Vec4 {
        return switch (self.*) {
            .blank => colors.endesga_grey1,
            .thing => colors.endesga_grey3,
            .permanent => colors.endesga_grey5,
        };
    }

    pub fn serialize(self: *const Self, js: *serializer.JsonSerializer) !void {
        try serializer.serialize("", @tagName(self.*), js);
    }
};

const Cell = struct {
    const Self = @This();
    cell: CellType,
    button: Button,
    /// stores the tick at which the cell was last toggled. This is to allow
    /// click and drag to change multiple cells together
    toggled_at: u64 = 0,

    pub fn update(self: *Self, mouse: MouseState, ticks: u64, allow_permanent: bool) void {
        self.button.update(mouse);
        if ((mouse.l_button.is_down and self.button.contains(mouse.current_pos) and self.toggled_at < mouse.l_button.down_from) or self.button.clicked) {
            self.cell = helpers.enumChange(self.cell, 1, true);
            self.toggled_at = ticks;
            if (self.cell == .permanent and !allow_permanent) {
                self.cell = helpers.enumChange(self.cell, 1, true);
            }
        }
    }

    pub fn serialize(self: *const Self, js: *serializer.JsonSerializer) !void {
        try serializer.serialize("cell", self.cell, js);
    }

    pub fn deserialize(self: *Self, js: std.json.Value, options: serializer.DeserializationOptions) void {
        serializer.deserialize("cell", &self.cell, js, options);
    }
};

const RuleButtonAction = enum {
    hi,
    hd,
    wi,
    wd,
    fc, // fixed_condition
    fr, // fixed_result
};

const RulePlayerButtonAction = enum {
    reset,
};

const Rule = struct {
    const Self = @This();
    condition: std.ArrayList(Cell),
    result: std.ArrayList(Cell),
    buttons: std.ArrayList(Button),
    player_buttons: std.ArrayList(Button),
    fixed_condition: bool = false,
    fixed_result: bool = false,
    width: usize = 3,
    height: usize = 3,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        const self = Self{
            .condition = std.ArrayList(Cell).init(allocator),
            .result = std.ArrayList(Cell).init(allocator),
            .buttons = std.ArrayList(Button).init(allocator),
            .player_buttons = std.ArrayList(Button).init(allocator),
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.condition.deinit();
        self.result.deinit();
        self.buttons.deinit();
        self.player_buttons.deinit();
    }

    pub fn serialize(self: *const Self, js: *serializer.JsonSerializer) !void {
        try serializer.serialize("width", self.width, js);
        try serializer.serialize("height", self.height, js);
        if (self.fixed_condition) try serializer.serialize("fixed_condition", self.condition.items, js);
        if (self.fixed_result) try serializer.serialize("fixed_result", self.result.items, js);
    }

    pub fn deserialize(self: *Self, js: std.json.Value, options: serializer.DeserializationOptions) void {
        serializer.deserialize("width", &self.width, js, options);
        serializer.deserialize("height", &self.height, js, options);
        if (js.object.get("fixed_condition") != null) {
            self.condition.clearRetainingCapacity();
            for (js.object.get("fixed_condition").?.array.items) |val| {
                var cell: Cell = undefined;
                serializer.deserialize("", &cell, val, options);
                self.condition.append(cell) catch unreachable;
            }
            self.fixed_condition = true;
        }
        if (js.object.get("fixed_result") != null) {
            self.result.clearRetainingCapacity();
            for (js.object.get("fixed_result").?.array.items) |val| {
                var cell: Cell = undefined;
                serializer.deserialize("", &cell, val, options);
                self.result.append(cell) catch unreachable;
            }
            self.fixed_result = true;
        }
    }

    fn adjustCellNumber(self: *Self) void {
        condition_cells: {
            const current = self.condition.items.len;
            const desired = self.width * self.height;
            if (current == desired) {
                break :condition_cells;
            } else if (current > desired) {
                const extra = current - desired;
                for (0..extra) |_| {
                    _ = self.condition.pop();
                }
            } else {
                const extra = desired - current;
                for (0..extra) |_| {
                    self.condition.append(.{ .cell = .blank, .button = undefined }) catch unreachable;
                }
            }
        }
        result_cells: {
            const current = self.result.items.len;
            const desired = self.width * self.height;
            if (current == desired) {
                break :result_cells;
            } else if (current > desired) {
                const extra = current - desired;
                for (0..extra) |_| {
                    _ = self.result.pop();
                }
            } else {
                const extra = desired - current;
                for (0..extra) |_| {
                    self.result.append(.{ .cell = .blank, .button = undefined }) catch unreachable;
                }
            }
        }
    }

    pub fn setupPositions(self: *Self, x_start: f32, y_start: f32) void {
        self.adjustCellNumber();
        for (0..(self.width * self.height)) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = x_start + (CELL_PADDING * (col + 1)) + (CELL_SIZE * col);
            const y = y_start + (CELL_PADDING * (row + 1)) + (CELL_SIZE * row);
            self.condition.items[index].button = .{
                .rect = .{
                    .position = .{ .x = x, .y = y },
                    .size = .{ .x = CELL_SIZE, .y = CELL_SIZE },
                },
                .value = 0,
                .text = "",
            };
        }
        const condition_width = (@as(f32, @floatFromInt(self.width)) * (CELL_SIZE + CELL_PADDING)) + CELL_PADDING;
        const x_result = x_start + condition_width + RULE_PANE_PADDING;
        for (0..(self.width * self.height)) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = x_result + (CELL_PADDING * (col + 1)) + (CELL_SIZE * col);
            const y = y_start + (CELL_PADDING * (row + 1)) + (CELL_SIZE * row);
            self.result.items[index].button = .{
                .rect = .{
                    .position = .{ .x = x, .y = y },
                    .size = .{ .x = CELL_SIZE, .y = CELL_SIZE },
                },
                .value = 0,
                .text = "",
            };
        }
        {
            self.buttons.clearRetainingCapacity();
            const RULE_BUTTON_SIZE = 14;
            const RULE_BUTTON_PADDING = 2;
            for (0..@typeInfo(RuleButtonAction).Enum.fields.len) |i| {
                const action: RuleButtonAction = @enumFromInt(i);
                const x = x_start + (@as(f32, @floatFromInt(i)) * (RULE_BUTTON_SIZE + RULE_BUTTON_PADDING));
                const y = y_start - (RULE_BUTTON_SIZE + RULE_BUTTON_PADDING);
                self.buttons.append(.{
                    .rect = .{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = RULE_BUTTON_SIZE, .y = RULE_BUTTON_SIZE },
                    },
                    .value = @intCast(i),
                    .text = @tagName(action),
                }) catch unreachable;
            }
        }
        {
            self.player_buttons.clearRetainingCapacity();
            for (0..@typeInfo(RulePlayerButtonAction).Enum.fields.len) |i| {
                const action: RulePlayerButtonAction = @enumFromInt(i);
                const res0 = self.result.items[0].button.rect;
                const pos = res0.position.add(.{
                    .x = @as(f32, @floatFromInt(self.width)) * (CELL_PADDING + CELL_SIZE),
                    .y = ((@as(f32, @floatFromInt(self.height)) * (CELL_PADDING + CELL_SIZE)) / 2) + (BUTTON_HEIGHT / 2),
                });
                self.player_buttons.append(.{
                    .rect = .{
                        .position = pos,
                        .size = .{ .x = BUTTON_WIDTH, .y = BUTTON_HEIGHT },
                    },
                    .value = @intCast(i),
                    .text = @tagName(action),
                }) catch unreachable;
            }
        }
    }

    fn copyPermanent(self: *Self) void {
        // copies permanent from condition to rule
        for (self.condition.items, self.result.items) |cond, *res| {
            if (cond.cell == .permanent) {
                res.cell = .permanent;
            } else if (res.cell == .permanent) {
                res.cell = .blank;
            }
        }
    }

    fn update(self: *Self, mouse: MouseState, editor: bool, ticks: u64, permanent_exists: bool) void {
        // TODO (28 Aug 2023 sam): condition should be based on if level has perm
        if (!self.fixed_condition) for (self.condition.items) |*cell| cell.update(mouse, ticks, permanent_exists);
        if (!self.fixed_result) for (self.result.items) |*cell| cell.update(mouse, ticks, false);
        self.copyPermanent();
        if (editor) for (self.buttons.items) |*button| button.update(mouse);
    }

    fn applyAction(self: *Self, value: u8) void {
        const action: RuleButtonAction = @enumFromInt(value);
        if (action == .hd and self.height == 1) return;
        if (action == .wd and self.width == 1) return;
        switch (action) {
            .hi => self.height += 1,
            .hd => self.height -= 1,
            .wi => self.width += 1,
            .wd => self.width -= 1,
            .fc => self.fixed_condition = !self.fixed_condition,
            .fr => self.fixed_result = !self.fixed_result,
        }
    }
};

const ZoneButtonAction = enum {
    hi,
    hd,
    wi,
    wd,
    r,
    l,
    u,
    d,
};

/// Zone is an area of the board that can be edited by the player.
const Zone = struct {
    const Self = @This();
    cells: std.ArrayList(Cell),
    buttons: std.ArrayList(Button),
    target_index: usize = 0,
    width: usize = 2,
    height: usize = 2,

    pub fn init(allocator: std.mem.Allocator) Self {
        const self = Self{
            .cells = std.ArrayList(Cell).init(allocator),
            .buttons = std.ArrayList(Button).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.cells.deinit();
        self.buttons.deinit();
    }

    fn adjustCellNumber(self: *Self) void {
        const current = self.cells.items.len;
        const desired = self.width * self.height;
        if (current == desired) {
            return;
        } else if (current > desired) {
            const extra = current - desired;
            for (0..extra) |_| _ = self.cells.pop();
        } else {
            const extra = desired - current;
            for (0..extra) |_| self.cells.append(.{ .cell = .blank, .button = undefined }) catch unreachable;
        }
    }

    pub fn setupPositions(self: *Self, origin: Vec2) void {
        self.adjustCellNumber();
        {
            var y: f32 = origin.y + CELL_PADDING;
            for (0..self.height) |row| {
                var x: f32 = origin.x + CELL_PADDING;
                for (0..self.width) |col| {
                    const index = (row * self.width) + col;
                    self.cells.items[index].button = .{
                        .rect = .{
                            .position = .{ .x = x, .y = y },
                            .size = .{ .x = CELL_SIZE, .y = CELL_SIZE },
                        },
                        .value = 0,
                        .text = "",
                    };
                    x += CELL_PADDING + CELL_SIZE;
                }
                y += CELL_PADDING + CELL_SIZE;
            }
        }
        {
            self.buttons.clearRetainingCapacity();
            const RULE_BUTTON_SIZE = 14;
            const RULE_BUTTON_PADDING = 2;
            for (0..@typeInfo(ZoneButtonAction).Enum.fields.len) |i| {
                const action: ZoneButtonAction = @enumFromInt(i);
                const x = origin.x + (@as(f32, @floatFromInt(i)) * (RULE_BUTTON_SIZE + RULE_BUTTON_PADDING));
                const y = origin.y - (RULE_BUTTON_SIZE + RULE_BUTTON_PADDING);
                self.buttons.append(.{
                    .rect = .{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = RULE_BUTTON_SIZE, .y = RULE_BUTTON_SIZE },
                    },
                    .value = @intCast(i),
                    .text = @tagName(action),
                }) catch unreachable;
            }
        }
    }

    fn applyAction(self: *Self, value: u8, board: *const Board) void {
        const action: ZoneButtonAction = @enumFromInt(value);
        if (action == .hd and self.height == 1) return;
        if (action == .wd and self.width == 1) return;
        if (action == .u and self.target_index < board.width) return;
        if (action == .d and self.target_index + board.width > board.cells.items.len) return;
        if (action == .l and self.target_index == 0) return;
        if (action == .r and self.target_index == board.cells.items.len) return;
        switch (action) {
            .hi => self.height += 1,
            .hd => self.height -= 1,
            .wi => self.width += 1,
            .wd => self.width -= 1,
            .r => self.target_index += 1,
            .l => self.target_index -= 1,
            .u => self.target_index -= board.width,
            .d => self.target_index += board.width,
        }
    }

    fn update(self: *Self, mouse: MouseState, editor: bool, ticks: u64) void {
        for (self.cells.items) |*cell| cell.update(mouse, ticks, false);
        if (editor) for (self.buttons.items) |*button| button.update(mouse);
    }

    pub fn serialize(self: *const Self, js: *serializer.JsonSerializer) !void {
        try serializer.serialize("width", self.width, js);
        try serializer.serialize("height", self.height, js);
        try serializer.serialize("target_index", self.target_index, js);
        try serializer.serialize("cells", self.cells.items, js);
    }

    pub fn deserialize(self: *Self, js: std.json.Value, options: serializer.DeserializationOptions) void {
        serializer.deserialize("width", &self.width, js, options);
        serializer.deserialize("height", &self.height, js, options);
        serializer.deserialize("target_index", &self.target_index, js, options);
        self.cells.clearRetainingCapacity();
        for (js.object.get("cells").?.array.items) |val| {
            var cell: Cell = undefined;
            serializer.deserialize("", &cell, val, options);
            self.cells.append(cell) catch unreachable;
        }
    }
};

const StepPart = enum {
    start,
    areas_found,
    changes_applied,
};

const SimStep = struct {
    const Self = @This();
    step_index: usize = 0,
    rule_index: usize = 0,
    step: StepPart = .start,

    pub fn reset(self: *Self) void {
        self.step_index = 0;
        self.rule_index = 0;
        self.step = .start;
    }

    pub fn atStart(self: *const Self) bool {
        return (self.step_index == 0 and self.rule_index == 0 and self.step == .start);
    }
};

const SimMode = enum {
    const Self = @This();
    simming,
    single_step,
    substep,
    paused,

    pub fn playing(self: *const Self) bool {
        return switch (self.*) {
            .simming,
            .single_step,
            => true,
            .substep,
            .paused,
            => false,
        };
    }
    pub fn simming(self: *const Self) bool {
        return switch (self.*) {
            .simming,
            .single_step,
            .substep,
            => true,
            .paused => false,
        };
    }
};

const BoardButtonAction = enum {
    add_rule,
    sub_rule,
    add_zone,
    sub_zone,
    add_target,
    sub_target,
    add_row,
    sub_row,
    add_col,
    sub_col,
};

const Board = struct {
    const Self = @This();
    cells: std.ArrayList(Cell),
    // stores the start state of all the cells for the level.
    start_state: std.ArrayList(CellType),
    zones: std.ArrayList(Zone),
    targets: std.ArrayList(Zone),
    buttons: std.ArrayList(Button),
    width: usize = 7,
    height: usize = 20,
    completed: bool = false,
    permanent_exists: bool = false,
    ticks: u64 = 0,
    rules: std.ArrayList(Rule),
    sim_mode: SimMode = .paused,
    sim_step: SimStep = .{},
    condition_indices: std.ArrayList(usize),
    rule_width: usize = 0,
    rule_height: usize = 0,
    last_step_ticks: u64 = 0,
    last_step_areas_found: usize = 0,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .cells = std.ArrayList(Cell).init(allocator),
            .start_state = std.ArrayList(CellType).init(allocator),
            .zones = std.ArrayList(Zone).init(allocator),
            .targets = std.ArrayList(Zone).init(allocator),
            .rules = std.ArrayList(Rule).init(allocator),
            .buttons = std.ArrayList(Button).init(allocator),
            .condition_indices = std.ArrayList(usize).init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.cells.deinit();
        self.start_state.deinit();
        for (self.zones.items) |*zone| zone.deinit();
        self.zones.deinit();
        for (self.targets.items) |*zone| zone.deinit();
        self.targets.deinit();
        for (self.rules.items) |*rule| rule.deinit();
        self.rules.deinit();
        self.condition_indices.deinit();
        self.buttons.deinit();
    }

    pub fn serialize(self: *const Self, js: *serializer.JsonSerializer) !void {
        try serializer.serialize("width", self.width, js);
        try serializer.serialize("height", self.height, js);
        try serializer.serialize("zones", self.zones.items, js);
        try serializer.serialize("targets", self.targets.items, js);
        try serializer.serialize("rules", self.rules.items, js);
        try serializer.serialize("cells", self.cells.items, js);
    }

    pub fn deserialize(self: *Self, js: std.json.Value, options: serializer.DeserializationOptions) void {
        // cleanup the things
        self.cells.clearRetainingCapacity();
        for (self.rules.items) |*rule| rule.deinit();
        self.rules.clearRetainingCapacity();
        for (self.zones.items) |*zone| zone.deinit();
        self.zones.clearRetainingCapacity();
        for (self.targets.items) |*zone| zone.deinit();
        self.targets.clearRetainingCapacity();
        // load the things
        serializer.deserialize("width", &self.width, js, options);
        serializer.deserialize("height", &self.height, js, options);
        for (js.object.get("cells").?.array.items) |val| {
            var cell: Cell = undefined;
            serializer.deserialize("", &cell, val, options);
            self.cells.append(cell) catch unreachable;
        }
        for (js.object.get("rules").?.array.items) |val| {
            var rule = Rule.init(self.allocator);
            serializer.deserialize("", &rule, val, options);
            self.rules.append(rule) catch unreachable;
        }
        for (js.object.get("zones").?.array.items) |val| {
            var zone = Zone.init(self.allocator);
            serializer.deserialize("", &zone, val, options);
            self.zones.append(zone) catch unreachable;
        }
        for (js.object.get("targets").?.array.items) |val| {
            var target = Zone.init(self.allocator);
            serializer.deserialize("", &target, val, options);
            self.targets.append(target) catch unreachable;
        }
        // setup the position things
        self.setupBoardCellPositions();
        self.setupRulePositions();
        self.setupZonePositions();
        self.setupTargetPositions();
        self.checkPermanent();
    }

    pub fn saveLevel(self: *Self) !void {
        var stream = serializer.JsonStream.new(self.allocator);
        defer stream.deinit();
        var jser = stream.serializer();
        var js = &jser;
        try js.beginObject();
        try serializer.serialize("level", self.*, js);
        try js.endObject();
        stream.buffer.append(0) catch unreachable;
        helpers.debugPrintAlloc(self.arena, "{s}", .{stream.buffer.items});
    }

    pub fn loadLevel(self: *Self, level: []const u8) void {
        c.debugPrint("loadLevel 1");
        var tree = std.json.parseFromSlice(std.json.Value, self.allocator, level, .{}) catch unreachable;
        c.debugPrint("loadLevel 2");
        defer tree.deinit();
        var js = tree.value;
        c.debugPrint("loadLevel 3");
        self.deserialize(js.object.get("level").?, .{});
        c.debugPrint("loadLevel 4");
    }

    fn checkPermanent(self: *Self) void {
        self.permanent_exists = false;
        for (self.cells.items) |cell| {
            if (cell.cell == .permanent) {
                self.permanent_exists = true;
                return;
            }
        }
    }

    fn setupBoardCellPositions(self: *Self) void {
        const width = BOARD_CELL_PADDING + ((BOARD_CELL_SIZE + BOARD_CELL_PADDING) * @as(f32, @floatFromInt(self.width)));
        const height = BOARD_CELL_PADDING + ((BOARD_CELL_SIZE + BOARD_CELL_PADDING) * @as(f32, @floatFromInt(self.height)));
        const start_x = BOARD_CENTER.x - (width / 2);
        const start_y = BOARD_CENTER.y - (height / 2);
        for (0..self.width * self.height) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = start_x + (BOARD_CELL_PADDING * (col + 1)) + (BOARD_CELL_SIZE * col);
            const y = start_y + (BOARD_CELL_PADDING * (row + 1)) + (BOARD_CELL_SIZE * row);
            self.cells.items[index].button = .{
                .rect = .{
                    .position = .{ .x = x, .y = y },
                    .size = .{ .x = BOARD_CELL_SIZE, .y = BOARD_CELL_SIZE },
                },
                .value = 0,
                .text = "",
            };
        }
    }

    fn setupRulePositions(self: *Self) void {
        var y: f32 = RULE_PANE_PADDING;
        for (self.rules.items) |*rule| {
            rule.setupPositions(RULE_PANE_PADDING, y);
            y += RULE_PANE_PADDING;
            y += @as(f32, @floatFromInt(rule.height)) * (CELL_SIZE + CELL_PADDING);
            y += CELL_PADDING;
        }
    }

    fn setupTargetPositions(self: *Self) void {
        var y: f32 = RULE_PANE_PADDING + BUTTON_HEIGHT + RULE_PANE_PADDING;
        const x: f32 = (SCREEN_SIZE.x) - RULE_PANE_PADDING - BUTTON_WIDTH;
        for (self.targets.items) |*target| {
            target.setupPositions(.{ .x = x, .y = y });
            y += RULE_PANE_PADDING;
            y += @as(f32, @floatFromInt(target.height)) * (CELL_SIZE + CELL_PADDING);
            y += CELL_PADDING;
        }
    }

    fn setupZonePositions(self: *Self) void {
        var y: f32 = RULE_PANE_PADDING;
        const x: f32 = (SCREEN_SIZE.x / 3) + RULE_PANE_PADDING;
        for (self.zones.items) |*zone| {
            zone.setupPositions(.{ .x = x, .y = y });
            y += RULE_PANE_PADDING;
            y += @as(f32, @floatFromInt(zone.height)) * (CELL_SIZE + CELL_PADDING);
            y += CELL_PADDING;
        }
    }

    pub fn setup(self: *Self) void {
        c.debugPrint("board setup 0");
        for (0..self.width * self.height) |_| self.cells.append(.{ .cell = .blank, .button = undefined }) catch unreachable;
        c.debugPrint("board setup 1");
        self.setupBoardCellPositions();
        c.debugPrint("board setup 2");
        // setup the plus
        {
            std.debug.assert(self.width >= 5);
            self.cells.items[self.indexOf(self.height - 2, 2).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 2, 3).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 2, 4).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 1, 3).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 3, 3).?].cell = .thing;
        }
        c.debugPrint("board setup 3");
        {
            var zone = Zone.init(self.allocator);
            zone.width = 3;
            zone.height = 3;
            zone.target_index = 10;
            self.zones.append(zone) catch unreachable;
            self.setupZonePositions();
        }
        c.debugPrint("board setup 4");
        {
            var target = Zone.init(self.allocator);
            target.width = 3;
            target.height = 3;
            target.target_index = 0;
            self.targets.append(target) catch unreachable;
            self.setupTargetPositions();
        }
        c.debugPrint("board setup 5");
        self.rules.append(Rule.init(self.allocator)) catch unreachable;
        self.rules.append(Rule.init(self.allocator)) catch unreachable;
        c.debugPrint("board setup 6");
        self.setupRulePositions();
        c.debugPrint("board setup 7");
        const BOARD_RULE_HEIGHT = 16;
        const BOARD_RULE_WIDTH = 60;
        const BOARD_RULE_PADDING = 6;
        c.debugPrint("board setup 8");
        for (0..@typeInfo(BoardButtonAction).Enum.fields.len) |i| {
            const action: BoardButtonAction = @enumFromInt(i);
            const y: f32 = BOARD_RULE_PADDING + (@as(f32, @floatFromInt(i)) * (BOARD_RULE_HEIGHT + BOARD_RULE_PADDING));
            const x: f32 = (SCREEN_SIZE.x / 3) - BOARD_RULE_PADDING - BOARD_RULE_WIDTH;
            self.buttons.append(.{
                .rect = .{
                    .position = .{ .x = x, .y = y },
                    .size = .{ .x = BOARD_RULE_WIDTH, .y = BOARD_RULE_HEIGHT },
                },
                .value = @intCast(i),
                .text = @tagName(action),
            }) catch unreachable;
        }
        c.debugPrint("board setup 9");
    }

    fn indexOf(self: *Self, row: usize, col: usize) ?usize {
        return (self.width * row) + col;
    }

    fn findRuleAreas(self: *Self, rule: Rule) void {
        self.condition_indices.clearRetainingCapacity();
        self.rule_width = rule.width;
        self.rule_height = rule.height;
        if (rule.height > self.height) return;
        if (rule.width > self.width) return;
        find_area: {
            for (0..self.height - rule.height + 1) |row| {
                for (0..self.width - rule.width + 1) |col| {
                    matches_condition: {
                        for (0..rule.height) |y| {
                            for (0..rule.width) |x| {
                                const board_cell = self.cells.items[self.indexOf(row + y, col + x).?];
                                const rule_cell = rule.condition.items[(y * rule.width) + x];
                                // helpers.debugPrint("board[{d},{d}] = {s}. rule[{d},{d}] = {s}.", .{ row, col, @tagName(board_cell.cell), y, x, @tagName(rule_cell.cell) });
                                if (board_cell.cell != rule_cell.cell) break :matches_condition;
                            }
                        }
                        self.condition_indices.append(self.indexOf(row, col).?) catch unreachable;
                        break :find_area;
                    }
                }
            }
        }
        if (self.condition_indices.items.len > 0) self.last_step_areas_found = self.sim_step.step_index;
    }

    /// apply rule at board section starting at index
    /// assumes that index is correct. doesn't do bounds check here.
    fn applyRule(self: *Self, rule: Rule, index: usize) void {
        for (0..rule.height) |y| {
            for (0..rule.width) |x| {
                const board_index = index + (self.width * y) + x;
                const rule_index = (rule.width * y) + x;
                self.cells.items[board_index].cell = rule.result.items[rule_index].cell;
            }
        }
    }

    fn step(self: *Self) void {
        if (self.completed) return;
        if (self.sim_mode == .paused) self.sim_mode = .substep;
        switch (self.sim_step.step) {
            .start => {
                self.findRuleAreas(self.rules.items[self.sim_step.rule_index]);
                self.sim_step.step = .areas_found;
            },
            .areas_found => {
                for (self.condition_indices.items) |ci| {
                    self.applyRule(self.rules.items[self.sim_step.rule_index], ci);
                }
                self.sim_step.step = .changes_applied;
            },
            .changes_applied => {
                self.sim_step.rule_index += 1;
                if (self.sim_step.rule_index >= self.rules.items.len) {
                    self.sim_step.rule_index = 0;
                    self.sim_step.step_index += 1;
                    if (self.sim_mode == .single_step) self.sim_mode = .paused;
                }
                self.sim_step.step = .start;
                self.condition_indices.clearRetainingCapacity();
            },
        }
        self.checkCompletion();
    }

    fn checkCompletion(self: *Self) void {
        self.completed = true;
        for (self.targets.items) |target| {
            for (0..target.height) |row| {
                for (0..target.width) |col| {
                    const index = (row * target.width) + col;
                    const board_index = target.target_index + (row * self.width) + col;
                    if (target.cells.items[index].cell != self.cells.items[board_index].cell) {
                        self.completed = false;
                        return;
                    }
                }
            }
        }
        self.sim_mode = .paused;
    }

    fn loadStartState(self: *Self) void {
        self.start_state.clearRetainingCapacity();
        for (self.cells.items) |cell| self.start_state.append(cell.cell) catch unreachable;
    }

    pub fn update(self: *Self, ticks: u64, arena: std.mem.Allocator, mouse: MouseState, editor: bool) void {
        self.ticks = ticks;
        self.arena = arena;
        for (self.rules.items) |*rule| rule.update(mouse, editor, ticks, self.permanent_exists);
        for (self.zones.items) |*zone| zone.update(mouse, editor, ticks);
        if (self.sim_step.atStart()) {
            for (self.zones.items) |*zone| {
                self.updateFromZone(zone);
            }
            self.loadStartState();
        }
        if (editor) {
            for (self.cells.items) |*cell| {
                cell.update(mouse, ticks, true);
                self.checkPermanent();
            }
            for (self.buttons.items) |*button| button.update(mouse);
            for (self.buttons.items) |button| {
                if (button.clicked) self.applyAction(@enumFromInt(button.value));
            }
            var rule_update = false;
            for (self.rules.items) |*rule| {
                for (rule.buttons.items) |button| {
                    if (button.clicked) {
                        rule_update = true;
                        rule.applyAction(button.value);
                    }
                }
            }
            if (rule_update) self.setupRulePositions();
            var zone_update = false;
            for (self.zones.items) |*zone| {
                for (zone.buttons.items) |button| {
                    if (button.clicked) {
                        zone_update = true;
                        zone.applyAction(button.value, self);
                    }
                }
            }
            if (zone_update) self.setupZonePositions();
            var target_update = false;
            for (self.targets.items) |*target| {
                target.update(mouse, editor, ticks);
                for (target.buttons.items) |button| {
                    if (button.clicked) {
                        target_update = true;
                        target.applyAction(button.value, self);
                    }
                }
            }
            if (target_update) self.setupTargetPositions();
        }
        if (self.sim_mode.playing()) {
            if (self.ticks - self.last_step_ticks > STEP_PLAY_RATE_TICKS) self.step();
            if (self.sim_step.step_index - self.last_step_areas_found > 2) self.sim_mode = .paused;
        }
    }

    fn applyAction(self: *Self, action: BoardButtonAction) void {
        switch (action) {
            .add_rule => {
                const rule = Rule.init(self.allocator);
                self.rules.append(rule) catch unreachable;
                self.setupRulePositions();
            },
            .sub_rule => {
                if (self.rules.items.len == 0) return;
                const rule = self.rules.pop();
                rule.deinit();
                self.setupRulePositions();
            },
            .add_zone => {
                const zone = Zone.init(self.allocator);
                self.zones.append(zone) catch unreachable;
                self.setupZonePositions();
            },
            .sub_zone => {
                if (self.zones.items.len == 0) return;
                const zone = self.zones.pop();
                zone.deinit();
                self.setupZonePositions();
            },
            .add_target => {
                const target = Zone.init(self.allocator);
                self.targets.append(target) catch unreachable;
                self.setupTargetPositions();
            },
            .sub_target => {
                if (self.targets.items.len == 0) return;
                const target = self.targets.pop();
                target.deinit();
                self.setupTargetPositions();
            },
            .add_row => {
                self.height += 1;
                self.adjustCellNumber();
                self.setupBoardCellPositions();
            },
            .sub_row => {
                if (self.height == 1) return;
                self.height -= 1;
                self.adjustCellNumber();
                self.setupBoardCellPositions();
            },
            .add_col => {
                self.width += 1;
                self.adjustCellNumber();
                self.setupBoardCellPositions();
            },
            .sub_col => {
                if (self.width == 1) return;
                self.width -= 1;
                self.adjustCellNumber();
                self.setupBoardCellPositions();
            },
        }
    }

    fn adjustCellNumber(self: *Self) void {
        const current = self.cells.items.len;
        const desired = self.width * self.height;
        if (current == desired) {
            return;
        } else if (current > desired) {
            const extra = current - desired;
            for (0..extra) |_| _ = self.cells.pop();
        } else {
            const extra = desired - current;
            for (0..extra) |_| self.cells.append(.{ .cell = .blank, .button = undefined }) catch unreachable;
        }
        self.loadStartState();
    }

    fn updateFromZone(self: *Self, zone: *const Zone) void {
        for (zone.cells.items, 0..) |cell, i| {
            const board_cell_index = zone.target_index + (self.width * @divFloor(i, zone.width)) + (i % zone.width);
            self.cells.items[board_cell_index].cell = cell.cell;
        }
    }

    pub fn setSimMode(self: *Self, mode: SimMode) void {
        self.sim_mode = mode;
        // we don't call step or update last_step_ticks here
        // in the next frame, update will take care of it
    }

    pub fn toggleSim(self: *Self) void {
        // we set to single step so that the current step gets completed.
        if (self.sim_mode == .simming) self.sim_mode = .single_step else self.sim_mode = .simming;
    }

    pub fn clearBoard(self: *Self) void {
        self.sim_step.reset();
        self.last_step_areas_found = 0;
        for (self.cells.items) |*cell| cell.cell = .blank;
        self.completed = false;
        self.condition_indices.clearRetainingCapacity();
    }

    pub fn resetBoard(self: *Self) void {
        self.clearBoard();
        for (self.start_state.items, self.cells.items) |start, *cell| cell.cell = start;
    }
};

const ButtonAction = enum {
    reset_board,
    sub_step,
    single_step,
    start_sim,
    clear_board,
    show_target,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    buttons: std.ArrayList(Button),
    show_target: bool = false,
    board: Board,
    editor_mode: bool = true,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .allocator = allocator,
            .buttons = std.ArrayList(Button).init(allocator),
            .board = Board.init(allocator, arena_handle.allocator()),
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.buttons.deinit();
    }

    fn setup(self: *Self) void {
        {
            // buttons
            var x = SCREEN_SIZE.x - BUTTON_PADDING;
            for (0..@typeInfo(ButtonAction).Enum.fields.len) |i| {
                const action: ButtonAction = @enumFromInt(i);
                if (action == .show_target) continue;
                self.buttons.append(.{
                    .rect = .{
                        .position = .{ .x = x - BUTTON_WIDTH, .y = SCREEN_SIZE.y - BUTTON_HEIGHT - BUTTON_PADDING },
                        .size = .{ .x = BUTTON_WIDTH, .y = BUTTON_HEIGHT },
                    },
                    .value = @intCast(i),
                    .text = @tagName(action),
                }) catch unreachable;
                x -= (BUTTON_PADDING + BUTTON_WIDTH);
            }
            {
                // target button
                const action = ButtonAction.show_target;
                self.buttons.append(.{
                    .rect = .{
                        .position = .{ .x = SCREEN_SIZE.x - BUTTON_WIDTH - BUTTON_PADDING, .y = BUTTON_PADDING },
                        .size = .{ .x = BUTTON_WIDTH, .y = BUTTON_HEIGHT },
                    },
                    .value = @intFromEnum(action),
                    .text = @tagName(action),
                }) catch unreachable;
            }
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.board.update(self.ticks, self.arena, self.haathi.inputs.mouse, self.editor_mode);
        if (self.haathi.inputs.getKey(.a).is_clicked) {
            self.board.step();
        }
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            self.board.setSimMode(.single_step);
        }
        if (self.haathi.inputs.getKey(.s).is_clicked) {
            self.board.saveLevel() catch unreachable;
        }
        if (self.haathi.inputs.getKey(.l).is_clicked) {
            self.board.loadLevel(LEVELS[0]);
        }
        if (true and self.haathi.inputs.getKey(.tab).is_clicked) {
            self.editor_mode = !self.editor_mode;
        }
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.buttons.items, 0..) |button, i| {
            const action: ButtonAction = @enumFromInt(i);
            if (action == .show_target) self.show_target = button.triggered or button.hovered;
            if (button.clicked) self.performAction(action);
        }
    }

    fn performAction(self: *Self, action: ButtonAction) void {
        switch (action) {
            .clear_board => self.board.clearBoard(),
            .reset_board => self.board.resetBoard(),
            .sub_step => self.board.step(),
            .single_step => self.board.sim_mode = .single_step,
            .start_sim => self.board.toggleSim(),
            .show_target => {},
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        self.haathi.drawRect(.{
            .position = .{ .x = SCREEN_SIZE.x * (1.0 / 3.0) },
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey2,
        });
        for (self.board.rules.items) |rule| {
            // draw "containers"
            {
                const pos = rule.condition.items[0].button.rect.position;
                const last = rule.condition.items[rule.condition.items.len - 1];
                const corner = last.button.rect.position.add(last.button.rect.size);
                const size = corner.subtract(pos);
                self.haathi.drawRect(.{
                    .position = pos.add(.{ .x = -CELL_PADDING, .y = -CELL_PADDING }),
                    .size = size.add(.{ .x = CELL_PADDING * 2, .y = CELL_PADDING * 2 }),
                    .color = colors.endesga_grey2,
                    .radius = CELL_PADDING,
                });
                if (rule.fixed_condition) {
                    const lock_pos = pos.add(.{ .x = -CELL_SIZE, .y = (size.y / 2) - (CELL_SIZE / 2) });
                    self.haathi.drawRect(.{
                        .position = lock_pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = colors.endesga_grey2,
                        .radius = 12,
                        .centered = true,
                    });
                    self.haathi.drawRect(.{
                        .position = lock_pos,
                        .size = .{ .x = 5, .y = 5 },
                        .color = colors.endesga_grey1,
                        .radius = 12,
                        .centered = true,
                    });
                    self.haathi.drawRect(.{
                        .position = lock_pos.add(.{ .y = 6 }),
                        .size = .{ .x = 12, .y = 12 },
                        .color = colors.endesga_grey2,
                        .radius = 2,
                        .centered = true,
                    });
                }
            }
            {
                const pos = rule.result.items[0].button.rect.position;
                const last = rule.result.items[rule.result.items.len - 1];
                const corner = last.button.rect.position.add(last.button.rect.size);
                const size = corner.subtract(pos);
                self.haathi.drawRect(.{
                    .position = pos.add(.{ .x = -CELL_PADDING, .y = -CELL_PADDING }),
                    .size = size.add(.{ .x = CELL_PADDING * 2, .y = CELL_PADDING * 2 }),
                    .color = colors.endesga_grey2,
                    .radius = CELL_PADDING,
                });
                if (rule.fixed_result) {
                    const lock_pos = pos.add(.{ .x = size.x + CELL_SIZE, .y = (size.y / 2) - (CELL_SIZE / 2) });
                    self.haathi.drawRect(.{
                        .position = lock_pos,
                        .size = .{ .x = 8, .y = 8 },
                        .color = colors.endesga_grey2,
                        .radius = 12,
                        .centered = true,
                    });
                    self.haathi.drawRect(.{
                        .position = lock_pos,
                        .size = .{ .x = 5, .y = 5 },
                        .color = colors.endesga_grey1,
                        .radius = 12,
                        .centered = true,
                    });
                    self.haathi.drawRect(.{
                        .position = lock_pos.add(.{ .y = 6 }),
                        .size = .{ .x = 12, .y = 12 },
                        .color = colors.endesga_grey2,
                        .radius = 2,
                        .centered = true,
                    });
                }
            }
            // draw lock
            for (rule.condition.items) |cell| {
                if (cell.button.hovered) {
                    self.haathi.drawRect(.{
                        .position = cell.button.rect.position.add(.{ .x = CELL_PADDING * -0.5, .y = CELL_PADDING * -0.5 }),
                        .size = cell.button.rect.size.add(.{ .x = CELL_PADDING, .y = CELL_PADDING }),
                        .color = colors.endesga_grey0,
                        .radius = 2 + (CELL_PADDING / 2),
                    });
                }
                self.haathi.drawRect(.{
                    .position = cell.button.rect.position,
                    .size = cell.button.rect.size,
                    .color = cell.cell.toColor(),
                    .radius = 2,
                });
            }
            for (rule.result.items) |cell| {
                if (cell.button.hovered) {
                    self.haathi.drawRect(.{
                        .position = cell.button.rect.position.add(.{ .x = CELL_PADDING * -0.5, .y = CELL_PADDING * -0.5 }),
                        .size = cell.button.rect.size.add(.{ .x = CELL_PADDING, .y = CELL_PADDING }),
                        .color = colors.endesga_grey0,
                        .radius = 2 + (CELL_PADDING / 2),
                    });
                }
                self.haathi.drawRect(.{
                    .position = cell.button.rect.position,
                    .size = cell.button.rect.size,
                    .color = cell.cell.toColor(),
                    .radius = 2,
                });
            }
            for (rule.player_buttons.items) |button| {
                if (button.hovered) {
                    self.haathi.drawRect(.{
                        .position = button.rect.position.add(.{ .x = -4, .y = -4 }),
                        .size = button.rect.size.add(.{ .x = 8, .y = 8 }),
                        .color = colors.endesga_grey0,
                        .radius = 9,
                    });
                }
                self.haathi.drawRect(.{
                    .position = button.rect.position,
                    .size = button.rect.size,
                    .color = colors.endesga_grey4,
                    .radius = 5,
                });
                const text_color = colors.endesga_grey1;
                self.haathi.drawText(.{
                    .text = button.text,
                    .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 6 }),
                    .color = text_color,
                });
            }
            if (self.editor_mode) {
                for (rule.buttons.items) |button| {
                    if (button.hovered) {
                        self.haathi.drawRect(.{
                            .position = button.rect.position.add(.{ .x = -2, .y = -2 }),
                            .size = button.rect.size.add(.{ .x = 4, .y = 4 }),
                            .color = colors.endesga_grey0,
                            .radius = 4,
                        });
                    }
                    self.haathi.drawRect(.{
                        .position = button.rect.position,
                        .size = button.rect.size,
                        .color = colors.endesga_grey4,
                        .radius = 2,
                    });
                    const text_color = colors.endesga_grey0;
                    self.haathi.drawText(.{
                        .text = button.text,
                        .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 3 }),
                        .color = text_color,
                        .style = EDITOR_STYLE,
                    });
                }
            }
        }
        if (self.editor_mode) {
            for (self.board.buttons.items) |button| {
                if (button.hovered) {
                    self.haathi.drawRect(.{
                        .position = button.rect.position.add(.{ .x = -2, .y = -2 }),
                        .size = button.rect.size.add(.{ .x = 4, .y = 4 }),
                        .color = colors.endesga_grey0,
                        .radius = 4,
                    });
                }
                self.haathi.drawRect(.{
                    .position = button.rect.position,
                    .size = button.rect.size,
                    .color = colors.endesga_grey4,
                    .radius = 2,
                });
                const text_color = colors.endesga_grey0;
                self.haathi.drawText(.{
                    .text = button.text,
                    .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 3 }),
                    .color = text_color,
                    .style = EDITOR_STYLE,
                });
            }
        }
        for (self.board.condition_indices.items) |index| {
            const cell = self.board.cells.items[index];
            const width = @as(f32, @floatFromInt(self.board.rule_width * (BOARD_CELL_SIZE + (BOARD_CELL_PADDING - 1))));
            const height = @as(f32, @floatFromInt(self.board.rule_height * (BOARD_CELL_SIZE + (BOARD_CELL_PADDING - 1))));
            self.haathi.drawRect(.{
                .position = cell.button.rect.position.add(.{ .x = -BOARD_CELL_PADDING, .y = -BOARD_CELL_PADDING }),
                .size = .{ .x = width + (BOARD_CELL_PADDING * 2), .y = height + (BOARD_CELL_PADDING * 2) },
                .color = colors.endesga_grey0,
                .radius = 2,
            });
        }
        if (self.board.sim_mode.simming()) {
            // rule application
            const pos = self.board.rules.items[self.board.sim_step.rule_index].result.items[0].button.rect.position;
            self.haathi.drawText(.{
                .text = @tagName(self.board.sim_step.step),
                .position = pos.add(.{ .x = 100, .y = 30 }),
                .color = colors.endesga_grey0,
            });
        }
        for (self.board.zones.items) |zone| {
            const bg_color = colors.endesga_grey5.lerp(colors.endesga_grey2, 0.7);
            var points = self.arena.alloc(Vec2, 2) catch unreachable;
            {
                const pos = zone.cells.items[0].button.rect.position.add(.{ .x = -CELL_PADDING, .y = -CELL_PADDING });
                const size = Vec2{
                    .x = CELL_PADDING + (@as(f32, @floatFromInt(zone.width)) * (CELL_PADDING + CELL_SIZE)),
                    .y = CELL_PADDING + (@as(f32, @floatFromInt(zone.height)) * (CELL_PADDING + CELL_SIZE)),
                };
                // bg of zone
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = size,
                    .color = bg_color,
                    .radius = 3,
                });
                points[0] = pos.add(size.scale(0.5));
            }
            {
                // bg of area in board
                const pos = self.board.cells.items[zone.target_index].button.rect.position.add(.{ .x = -BOARD_CELL_PADDING, .y = -BOARD_CELL_PADDING });
                const size = Vec2{
                    .x = BOARD_CELL_PADDING + (@as(f32, @floatFromInt(zone.width)) * (BOARD_CELL_PADDING + BOARD_CELL_SIZE)),
                    .y = BOARD_CELL_PADDING + (@as(f32, @floatFromInt(zone.height)) * (BOARD_CELL_PADDING + BOARD_CELL_SIZE)),
                };
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = size,
                    .color = bg_color,
                    .radius = 3,
                });
                points[1] = pos.add(size.scale(0.5));
            }
            self.haathi.drawPath(.{
                .points = points,
                .color = bg_color,
                .width = 4,
            });
            for (zone.cells.items) |cell| {
                self.haathi.drawRect(.{
                    .position = cell.button.rect.position,
                    .size = cell.button.rect.size,
                    .color = cell.cell.toColor(),
                    .radius = 1,
                });
            }
            if (self.editor_mode) {
                for (zone.buttons.items) |button| {
                    if (button.hovered) {
                        self.haathi.drawRect(.{
                            .position = button.rect.position.add(.{ .x = -2, .y = -2 }),
                            .size = button.rect.size.add(.{ .x = 4, .y = 4 }),
                            .color = colors.endesga_grey0,
                            .radius = 4,
                        });
                    }
                    self.haathi.drawRect(.{
                        .position = button.rect.position,
                        .size = button.rect.size,
                        .color = colors.endesga_grey4,
                        .radius = 2,
                    });
                    const text_color = colors.endesga_grey0;
                    self.haathi.drawText(.{
                        .text = button.text,
                        .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 3 }),
                        .color = text_color,
                        .style = EDITOR_STYLE,
                    });
                }
            }
        }
        for (self.board.targets.items) |zone| { // draw target things
            const bg_color = colors.endesga_grey5.lerp(colors.endesga_grey2, 0.7);
            var points = self.arena.alloc(Vec2, 2) catch unreachable;
            {
                const pos = zone.cells.items[0].button.rect.position.add(.{ .x = -CELL_PADDING, .y = -CELL_PADDING });
                const size = Vec2{
                    .x = CELL_PADDING + (@as(f32, @floatFromInt(zone.width)) * (CELL_PADDING + CELL_SIZE)),
                    .y = CELL_PADDING + (@as(f32, @floatFromInt(zone.height)) * (CELL_PADDING + CELL_SIZE)),
                };
                // bg of zone
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = size,
                    .color = bg_color,
                    .radius = 3,
                });
                points[0] = pos.add(size.scale(0.5));
            }
            {
                // bg of area in board
                const pos = self.board.cells.items[zone.target_index].button.rect.position.add(.{ .x = -BOARD_CELL_PADDING, .y = -BOARD_CELL_PADDING });
                const size = Vec2{
                    .x = BOARD_CELL_PADDING + (@as(f32, @floatFromInt(zone.width)) * (BOARD_CELL_PADDING + BOARD_CELL_SIZE)),
                    .y = BOARD_CELL_PADDING + (@as(f32, @floatFromInt(zone.height)) * (BOARD_CELL_PADDING + BOARD_CELL_SIZE)),
                };
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = size,
                    .color = bg_color,
                    .radius = 3,
                });
                points[1] = pos.add(size.scale(0.5));
            }
            self.haathi.drawPath(.{
                .points = points,
                .color = bg_color,
                .width = 4,
            });
            for (zone.cells.items) |cell| {
                self.haathi.drawRect(.{
                    .position = cell.button.rect.position,
                    .size = cell.button.rect.size,
                    .color = cell.cell.toColor(),
                    .radius = 1,
                });
            }
            if (self.editor_mode) {
                for (zone.buttons.items) |button| {
                    if (button.hovered) {
                        self.haathi.drawRect(.{
                            .position = button.rect.position.add(.{ .x = -2, .y = -2 }),
                            .size = button.rect.size.add(.{ .x = 4, .y = 4 }),
                            .color = colors.endesga_grey0,
                            .radius = 4,
                        });
                    }
                    self.haathi.drawRect(.{
                        .position = button.rect.position,
                        .size = button.rect.size,
                        .color = colors.endesga_grey4,
                        .radius = 2,
                    });
                    const text_color = colors.endesga_grey0;
                    self.haathi.drawText(.{
                        .text = button.text,
                        .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 3 }),
                        .color = text_color,
                        .style = EDITOR_STYLE,
                    });
                }
            }
        }
        for (self.board.cells.items) |cell| {
            self.haathi.drawRect(.{
                .position = cell.button.rect.position,
                .size = cell.button.rect.size,
                .color = cell.cell.toColor(),
                .radius = 1,
            });
        }
        if (self.board.completed) {
            self.haathi.drawText(.{
                .text = "Level Completed",
                .position = .{ .x = (SCREEN_SIZE.x * 2 / 3), .y = 50 },
                .color = colors.endesga_grey0,
            });
        }
        if (self.show_target or self.board.completed) {
            for (self.board.targets.items) |target| {
                const pos = self.board.cells.items[target.target_index].button.rect.position;
                const width = (@as(f32, @floatFromInt(target.width)) * (BOARD_CELL_SIZE + BOARD_CELL_PADDING)) - BOARD_CELL_PADDING;
                const height = (@as(f32, @floatFromInt(target.height)) * (BOARD_CELL_SIZE + BOARD_CELL_PADDING)) - BOARD_CELL_PADDING;
                self.haathi.drawRect(.{
                    .position = pos.add(.{ .x = -BOARD_CELL_PADDING * 1, .y = -BOARD_CELL_PADDING * 1 }),
                    .size = .{ .x = width + (2 * BOARD_CELL_PADDING), .y = height + (2 * BOARD_CELL_PADDING) },
                    .color = colors.endesga_grey0,
                    .radius = 1,
                });
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = .{ .x = width, .y = height },
                    .color = colors.endesga_grey2,
                    .radius = 1,
                });
                for (0..target.height) |row| {
                    for (0..target.width) |col| {
                        const frow: f32 = @floatFromInt(row);
                        const fcol: f32 = @floatFromInt(col);
                        const index = (row * target.width) + col;
                        const color = target.cells.items[index].cell.toColor();
                        const cell_pos = pos.add(.{
                            .x = fcol * (BOARD_CELL_PADDING + BOARD_CELL_SIZE),
                            .y = frow * (BOARD_CELL_PADDING + BOARD_CELL_SIZE),
                        });
                        const is_error = target.cells.items[index].cell != self.board.cells.items[target.target_index + (self.board.width * row) + col].cell;
                        if (is_error) {
                            self.haathi.drawRect(.{
                                .position = cell_pos.add(.{ .x = -BOARD_CELL_PADDING, .y = -BOARD_CELL_PADDING }),
                                .size = .{ .x = BOARD_CELL_SIZE + (2 * BOARD_CELL_PADDING), .y = BOARD_CELL_SIZE + (2 * BOARD_CELL_PADDING) },
                                .color = colors.endesga_red0,
                                .radius = 1,
                            });
                        }
                        self.haathi.drawRect(.{
                            .position = cell_pos,
                            .size = .{ .x = BOARD_CELL_SIZE, .y = BOARD_CELL_SIZE },
                            .color = color,
                            .radius = 1,
                        });
                    }
                }
            }
        }
        for (self.buttons.items) |button| {
            if (button.hovered) {
                self.haathi.drawRect(.{
                    .position = button.rect.position.add(.{ .x = -4, .y = -4 }),
                    .size = button.rect.size.add(.{ .x = 8, .y = 8 }),
                    .color = colors.endesga_grey0,
                    .radius = 9,
                });
            }
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = colors.endesga_grey4,
                .radius = 5,
            });
            const text_color = colors.endesga_grey1;
            self.haathi.drawText(.{
                .text = button.text,
                .position = button.rect.position.add(button.rect.size.scale(0.5)).add(.{ .y = 6 }),
                .color = text_color,
            });
        }
    }
};
