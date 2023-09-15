const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;
const Sprite = @import("haathi.zig").Sprite;
const Inputs = @import("inputs.zig").Inputs;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Movement = helpers.Movement;
const Button = helpers.Button;
const TextLine = helpers.TextLine;
const CELL_WIDTH = 64;
const CELL_HEIGHT = 64;
const CELL_SIZE = Vec2{ .x = CELL_WIDTH, .y = CELL_HEIGHT };
const CELL_PADDING_X = 0;
const CELL_PADDING_Y = 0;
const TOKEN_PANE_HEIGHT = 220;
const TOKEN_PADDING = 20;
const CARD_WIDTH = 100;
const CARD_HEIGHT = (TOKEN_PANE_HEIGHT - (TOKEN_PADDING * 2));
const sprites = @import("goal_sprites.zig");
const PLAYER_SPRITE_OFFSET = Vec2{ .x = -58, .y = -76 };
const POINTER_OFFSET = Vec2{ .x = -22, .y = -17 };

const Team = enum {
    player,
    opponent,
};
const Player = struct {
    const Self = @This();
    team: Team = .player,
    address: Vec2i = .{},
    movement: ?Movement = null,
    position: Vec2 = .{},
    last_sprite_update_tick: u64 = 0,
    sprite_index: usize = 0,
    sprite_sheet: [6]Sprite = undefined,
    sprite: Sprite = undefined,

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movement) |move| {
            self.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) self.movement = null;
            self.sprite_sheet = sprites.blue_player(true);
        } else {
            self.sprite_sheet = sprites.blue_player(false);
        }
        if (ticks - self.last_sprite_update_tick > 100) {
            self.sprite_index += 1;
            self.last_sprite_update_tick = ticks;
        }
        if (self.sprite_index == 6) self.sprite_index = 1;
        self.sprite = self.sprite_sheet[self.sprite_index];
    }

    pub fn moveBy(self: *Self, ticks: u64, change: Vec2i) void {
        self.address = self.address.add(change);
        if (self.movement) |move| self.position = move.to;
        const dx: f32 = @floatFromInt(change.x);
        const dy: f32 = @floatFromInt(change.y);
        const dest = self.position.add(.{ .x = (CELL_WIDTH + CELL_PADDING_X) * dx, .y = (CELL_HEIGHT + CELL_PADDING_Y) * -dy });
        self.movement = .{ .from = self.position, .to = dest, .start = ticks, .duration = 300 };
    }
};

const Cell = struct {
    const Self = @This();
    address: Vec2i = .{},
    position: Vec2 = .{},
    sprite: Sprite = undefined,

    // based on the size, since we know the address, we can load the sprite.
    pub fn initSprite(self: *Self, width: usize, height: usize) void {
        const up = self.address.y == height - 1;
        const down = self.address.y == 0;
        const left = self.address.x == 0;
        const right = self.address.x == width - 1;
        self.sprite = sprites.terrain_grass(up, down, left, right);
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }
};

const CardEffect = union(enum) {
    move: Vec2i,
    kick: Vec2i,
};
const Card = struct {
    const Self = @This();
    effect: CardEffect,
    rect: Rect,
    movement: ?Movement = null,

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn moveTo(self: *Self, ticks: u64, pos: Vec2, duration: u64) void {
        self.movement = .{ .from = self.rect.position, .to = pos, .start = ticks, .duration = duration };
    }

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movement) |move| {
            self.rect.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) self.movement = null;
        }
    }
};

const StateData = union(enum) {
    idle: struct {
        card_index: ?usize = null,
    },
    idle_drag: void,
    card_drag: struct {
        card_index: usize,
        card_offset: Vec2,
        cell_index: ?usize = null,
    },
};

const Field = struct {
    const Self = @This();
    ticks: u64 = 0,
    steps: usize = 0,
    players: std.ArrayList(Player),
    cells: std.ArrayList(Cell),
    cards: std.ArrayList(Card),
    state: StateData = .{ .idle = .{} },
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .players = std.ArrayList(Player).init(allocator),
            .cards = std.ArrayList(Card).init(allocator),
            .cells = std.ArrayList(Cell).init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        for (self.players.items) |*player| player.deinit();
        self.players.deinit();
        for (self.cells.items) |*cell| cell.deinit();
        self.cells.deinit();
        for (self.cards.items) |*card| card.deinit();
        self.cards.deinit();
    }

    fn setup(self: *Self) void {
        self.setupCells(10, 6);
        self.players.append(.{ .position = self.cells.items[0].position }) catch unreachable;
        self.cards.append(.{
            .effect = .{ .move = .{ .x = 1 } },
            .rect = .{
                .size = .{ .x = CARD_WIDTH, .y = CARD_HEIGHT },
                .position = .{
                    .x = (SCREEN_SIZE.x / 2) - (CARD_WIDTH / 2),
                    .y = SCREEN_SIZE.y - TOKEN_PANE_HEIGHT,
                },
            },
        }) catch unreachable;
    }

    fn setupCells(self: *Self, width: usize, height: usize) void {
        for (self.cells.items) |*cell| cell.deinit();
        self.cells.clearRetainingCapacity();
        const fw: f32 = @floatFromInt(width);
        const fh: f32 = @floatFromInt(height);
        const field_width = (fw * (CELL_WIDTH + CELL_PADDING_X)) - CELL_PADDING_X;
        const field_height = (fh * (CELL_HEIGHT + CELL_PADDING_Y)) - CELL_PADDING_Y;
        const field_origin = SCREEN_SIZE.scale(0.5).add(.{ .x = -field_width * 0.5, .y = field_height * 0.5 }).add(.{ .y = (TOKEN_PANE_HEIGHT + (2 * TOKEN_PADDING)) * -0.5 });
        for (0..height) |y| {
            for (0..width) |x| {
                const fx: f32 = @floatFromInt(x);
                const fy: f32 = @floatFromInt(y);
                const position = field_origin.add(.{ .x = fx * (CELL_WIDTH + CELL_PADDING_X), .y = -fy * (CELL_HEIGHT + CELL_PADDING_Y) - CELL_HEIGHT }); // we want to get the left top corner of the box so we have to subtract cell height again.
                self.cells.append(.{ .position = position, .address = .{ .x = @intCast(x), .y = @intCast(y) } }) catch unreachable;
                self.cells.items[self.cells.items.len - 1].initSprite(width, height);
            }
        }
    }

    fn update(self: *Self, inputs: Inputs, arena: std.mem.Allocator, ticks: u64) void {
        self.ticks = ticks;
        self.arena = arena;
        for (self.players.items) |*player| player.update(self.ticks);
        for (self.cards.items) |*card| card.update(self.ticks);
        self.handleMouse(inputs.mouse);
    }

    fn playerAt(self: *Self, address: Vec2i) ?*Player {
        for (self.players.items) |*player| {
            if (player.address.equal(address)) return player;
        }
        return null;
    }

    fn maybePlayCard(self: *Self, card_index: usize, cell_index: usize) void {
        if (self.playerAt(self.cells.items[cell_index].address)) |player| {
            switch (self.cards.items[card_index].effect) {
                .move => |data| {
                    player.moveBy(self.ticks, data);
                },
                .kick => {},
            }
        }
    }

    fn handleMouse(self: *Self, mouse: MouseState) void {
        switch (self.state) {
            .idle => {
                self.state.idle.card_index = null;
                for (self.cards.items, 0..) |card, i| {
                    if (card.rect.contains(mouse.current_pos)) self.state.idle.card_index = i;
                }
                if (mouse.l_button.is_clicked) {
                    if (self.state.idle.card_index) |ci| {
                        self.state = .{
                            .card_drag = .{
                                .card_index = ci,
                                .card_offset = mouse.current_pos.subtract(self.cards.items[ci].rect.position),
                            },
                        };
                    } else {
                        self.state = .idle_drag;
                    }
                }
            },
            .idle_drag => {
                if (mouse.l_button.is_released) self.state = .{ .idle = .{} };
            },
            .card_drag => |data| {
                self.state.card_drag.cell_index = null;
                var card = &self.cards.items[data.card_index];
                card.rect.position = mouse.current_pos.subtract(data.card_offset);
                for (self.cells.items, 0..) |cell, i| {
                    const rect = Rect{ .position = cell.position, .size = CELL_SIZE };
                    if (rect.contains(card.rect.position)) {
                        self.state.card_drag.cell_index = i;
                    }
                }
                if (mouse.l_button.is_released) {
                    if (self.state.card_drag.cell_index) |ci| {
                        self.maybePlayCard(self.state.card_drag.card_index, ci);
                    } else {
                        self.cards.items[data.card_index].moveTo(self.ticks, .{}, 300);
                    }
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    field: Field,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        return .{
            .haathi = haathi,
            .field = Field.init(allocator, arena_handle.allocator()),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.field.update(self.haathi.inputs, self.arena, self.ticks);
        if (self.haathi.inputs.getKey(.d).is_clicked) {
            self.field.players.items[0].moveBy(self.ticks, .{ .x = 1 });
        }
        if (self.haathi.inputs.getKey(.a).is_clicked) {
            self.field.players.items[0].moveBy(self.ticks, .{ .x = -3 });
        }
        if (self.haathi.inputs.getKey(.w).is_clicked) {
            self.field.players.items[0].moveBy(self.ticks, .{ .y = 1 });
        }
        if (self.haathi.inputs.getKey(.s).is_clicked) {
            self.field.players.items[0].moveBy(self.ticks, .{ .y = -1 });
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.setCursor(.auto);
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        if (mouse_pos.x < SCREEN_SIZE.x and mouse_pos.y < SCREEN_SIZE.y) self.haathi.setCursor(.none);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = Vec4.fromHexRgb("#47ABA9"),
        });
        self.haathi.drawRect(.{
            .position = .{ .x = TOKEN_PADDING, .y = SCREEN_SIZE.y - TOKEN_PANE_HEIGHT - TOKEN_PADDING },
            .size = .{ .x = SCREEN_SIZE.x - (2 * TOKEN_PADDING), .y = TOKEN_PANE_HEIGHT },
            .color = colors.solarized_base1,
        });
        for (self.field.cells.items) |cell| {
            self.haathi.drawSprite(.{
                .position = cell.position,
                .sprite = cell.sprite,
                .scale = .{ .x = CELL_WIDTH / cell.sprite.size.x, .y = CELL_HEIGHT / cell.sprite.size.y },
            });
        }
        for (self.field.cards.items) |card| {
            self.haathi.drawRect(.{
                .position = card.rect.position,
                .size = card.rect.size,
                .color = colors.solarized_base2,
            });
        }
        for (self.field.players.items) |player| {
            self.haathi.drawSprite(.{
                .position = player.position.add(PLAYER_SPRITE_OFFSET),
                .sprite = player.sprite,
            });
        }
        self.haathi.drawSprite(.{
            .position = self.haathi.inputs.mouse.current_pos.add(POINTER_OFFSET),
            .sprite = sprites.POINTER,
        });
    }
};
