const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
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
const BOARD_CELL_SIZE = 8;
const BOARD_CELL_PADDING = 3;
const STEP_PLAY_RATE_TICKS = 100;

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

    pub fn toColor(self: *const Self) Vec4 {
        return switch (self.*) {
            .blank => colors.endesga_grey1,
            .thing => colors.endesga_grey3,
        };
    }
};

const Cell = struct {
    const Self = @This();
    cell: CellType,
    button: Button,

    pub fn update(self: *Self, mouse: MouseState) void {
        self.button.update(mouse);
        if (self.button.clicked) self.cell = helpers.enumChange(self.cell, 1, true);
    }
};

const Rule = struct {
    const Self = @This();
    condition: std.ArrayList(Cell),
    result: std.ArrayList(Cell),
    width: usize = 3,
    height: usize = 3,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator, x_start: f32, y_start: f32) Self {
        var self = Self{
            .condition = std.ArrayList(Cell).init(allocator),
            .result = std.ArrayList(Cell).init(allocator),
            .arena = arena,
            .allocator = allocator,
        };
        self.setup(x_start, y_start);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.condition.deinit();
        self.result.deinit();
    }

    fn setup(self: *Self, x_start: f32, y_start: f32) void {
        for (0..(self.width * self.height)) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = x_start + (CELL_PADDING * (col + 1)) + (CELL_SIZE * col);
            const y = y_start + (CELL_PADDING * (row + 1)) + (CELL_SIZE * row);
            self.condition.append(.{
                .cell = .blank,
                .button = .{
                    .rect = .{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = CELL_SIZE, .y = CELL_SIZE },
                    },
                    .value = 0,
                    .text = "",
                },
            }) catch unreachable;
        }
        const condition_width = (@as(f32, @floatFromInt(self.width)) * (CELL_SIZE + CELL_PADDING)) + CELL_PADDING;
        const x_result = x_start + condition_width + RULE_PANE_PADDING;
        for (0..(self.width * self.height)) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = x_result + (CELL_PADDING * (col + 1)) + (CELL_SIZE * col);
            const y = y_start + (CELL_PADDING * (row + 1)) + (CELL_SIZE * row);
            self.result.append(.{
                .cell = .blank,
                .button = .{
                    .rect = .{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = CELL_SIZE, .y = CELL_SIZE },
                    },
                    .value = 0,
                    .text = "",
                },
            }) catch unreachable;
        }
    }

    fn update(self: *Self, arena: std.mem.Allocator, mouse: MouseState) void {
        self.arena = arena;
        for (self.condition.items) |*cell| cell.update(mouse);
        for (self.result.items) |*cell| cell.update(mouse);
    }
};

const StepPart = enum {
    start,
    areas_found,
    changes_applied,
};

const SimStep = struct {
    step_index: usize = 0,
    rule_index: usize = 0,
    step: StepPart = .start,
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

const Board = struct {
    const Self = @This();
    cells: std.ArrayList(Cell),
    width: usize = 7,
    height: usize = 40,
    editing_mode: bool = true,
    ticks: u64 = 0,
    rules: []Rule = undefined,
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
            .condition_indices = std.ArrayList(usize).init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.cells.deinit();
        self.condition_indices.deinit();
    }

    pub fn setup(self: *Self) void {
        const width = BOARD_CELL_PADDING + ((BOARD_CELL_SIZE + BOARD_CELL_PADDING) * @as(f32, @floatFromInt(self.width)));
        const height = BOARD_CELL_PADDING + ((BOARD_CELL_SIZE + BOARD_CELL_PADDING) * @as(f32, @floatFromInt(self.height)));
        const start_x = BOARD_CENTER.x - (width / 2);
        const start_y = BOARD_CENTER.y - (height / 2);
        for (0..self.width * self.height) |index| {
            const col: f32 = @floatFromInt(index % self.width);
            const row: f32 = @floatFromInt(@divFloor(index, self.width));
            const x = start_x + (BOARD_CELL_PADDING * (col + 1)) + (BOARD_CELL_SIZE * col);
            const y = start_y + (BOARD_CELL_PADDING * (row + 1)) + (BOARD_CELL_SIZE * row);
            self.cells.append(.{
                .cell = .blank,
                .button = .{
                    .rect = .{
                        .position = .{ .x = x, .y = y },
                        .size = .{ .x = BOARD_CELL_SIZE, .y = BOARD_CELL_SIZE },
                    },
                    .value = 0,
                    .text = "",
                },
            }) catch unreachable;
        }
        // setup the plus
        {
            std.debug.assert(self.width >= 5);
            self.cells.items[self.indexOf(self.height - 2, 2).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 2, 3).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 2, 4).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 1, 3).?].cell = .thing;
            self.cells.items[self.indexOf(self.height - 3, 3).?].cell = .thing;
        }
    }

    fn indexOf(self: *Self, row: usize, col: usize) ?usize {
        return (self.width * row) + col;
    }

    pub fn loadRules(self: *Self, rules: []Rule) void {
        self.rules = rules;
    }

    fn findRuleAreas(self: *Self, rule: Rule) void {
        self.condition_indices.clearRetainingCapacity();
        self.rule_width = rule.width;
        self.rule_height = rule.height;
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
        if (self.sim_mode == .paused) self.sim_mode = .substep;
        switch (self.sim_step.step) {
            .start => {
                self.findRuleAreas(self.rules[self.sim_step.rule_index]);
                self.sim_step.step = .areas_found;
            },
            .areas_found => {
                for (self.condition_indices.items) |ci| {
                    self.applyRule(self.rules[self.sim_step.rule_index], ci);
                }
                self.sim_step.step = .changes_applied;
            },
            .changes_applied => {
                self.sim_step.rule_index += 1;
                if (self.sim_step.rule_index >= self.rules.len) {
                    self.sim_step.rule_index = 0;
                    self.sim_step.step_index += 1;
                    if (self.sim_mode == .single_step) self.sim_mode = .paused;
                }
                self.sim_step.step = .start;
                self.condition_indices.clearRetainingCapacity();
            },
        }
    }

    pub fn update(self: *Self, ticks: u64, mouse: MouseState) void {
        self.ticks = ticks;
        if (self.editing_mode) {
            for (self.cells.items) |*cell| {
                cell.update(mouse);
            }
        }
        if (self.sim_mode.playing()) {
            if (self.ticks - self.last_step_ticks > STEP_PLAY_RATE_TICKS) self.step();
            if (self.sim_step.step_index - self.last_step_areas_found > 2) self.sim_mode = .paused;
        }
    }

    pub fn setSimMode(self: *Self, mode: SimMode) void {
        self.sim_mode = mode;
        // we don't call step or update last_step_ticks here
        // in the next frame, update will take care of it
    }

    pub fn clearBoard(self: *Self) void {
        for (self.cells.items) |*cell| cell.cell = .blank;
    }
};

const ButtonAction = enum {
    clear_board,
    sub_step,
    single_step,
    start_sim,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    rules: std.ArrayList(Rule),
    buttons: std.ArrayList(Button),
    board: Board,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .allocator = allocator,
            .rules = std.ArrayList(Rule).init(allocator),
            .buttons = std.ArrayList(Button).init(allocator),
            .board = Board.init(allocator, arena_handle.allocator()),
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.rules.items) |*rule| rule.deinit();
        self.rules.deinit();
        self.buttons.deinit();
    }

    fn setup(self: *Self) void {
        self.rules.append(Rule.init(self.allocator, self.arena, RULE_PANE_PADDING, RULE_PANE_PADDING)) catch unreachable;
        self.rules.append(Rule.init(self.allocator, self.arena, RULE_PANE_PADDING, (2 * RULE_PANE_PADDING) + (3 * (CELL_SIZE + CELL_PADDING)) + CELL_PADDING)) catch unreachable;
        // buttons
        {
            const BUTTON_PADDING = 20;
            const BUTTON_WIDTH = 150;
            const BUTTON_HEIGHT = 30;
            var x = SCREEN_SIZE.x - BUTTON_PADDING;
            for (0..@typeInfo(ButtonAction).Enum.fields.len) |i| {
                const action: ButtonAction = @enumFromInt(i);
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
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.board.update(self.ticks, self.haathi.inputs.mouse);
        for (self.rules.items) |*rule| {
            rule.update(self.arena, self.haathi.inputs.mouse);
        }
        if (self.haathi.inputs.getKey(.a).is_clicked) {
            self.board.loadRules(self.rules.items);
            self.board.step();
        }
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            self.board.loadRules(self.rules.items);
            self.board.setSimMode(.single_step);
        }
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.buttons.items, 0..) |button, i| {
            if (button.clicked) {
                const action: ButtonAction = @enumFromInt(i);
                self.performAction(action);
            }
        }
    }

    fn performAction(self: *Self, action: ButtonAction) void {
        self.board.loadRules(self.rules.items);
        switch (action) {
            .clear_board => self.board.clearBoard(),
            .sub_step => self.board.step(),
            .single_step => self.board.sim_mode = .single_step,
            .start_sim => self.board.sim_mode = .simming,
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
        for (self.rules.items) |rule| {
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
            }
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
            const pos = self.rules.items[self.board.sim_step.rule_index].result.items[0].button.rect.position;
            self.haathi.drawText(.{
                .text = @tagName(self.board.sim_step.step),
                .position = pos.add(.{ .x = 100, .y = 30 }),
                .color = colors.endesga_grey0,
            });
        }
        for (self.board.cells.items) |cell| {
            self.haathi.drawRect(.{
                .position = cell.button.rect.position,
                .size = cell.button.rect.size,
                .color = cell.cell.toColor(),
                .radius = 1,
            });
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
