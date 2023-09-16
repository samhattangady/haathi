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
const TOKEN_PANE_WIDTH = 352;
// Padding above and below the pane
const TOKEN_PADDING = 30;
const PANE_X_PADDING = 40;
const CARD_WIDTH = 140;
const CARD_HEIGHT = 80;
const sprites = @import("goal_sprites.zig");
const PLAYER_SPRITE_OFFSET = Vec2{ .x = -64, .y = -68 };
const POINTER_OFFSET = Vec2{ .x = -22, .y = -17 };
const STEP_DURATION = 300;
const BALL_DELAY = 80;

const LEVELS = [_][]const u8{
    "size|12|7 ball|3|3 target|9|3 player|2|3|player player|4|5|player player|7|3|opponent card|kick|3|3 card|move|1|1 card|kick|2|2 card|dribble|2|-1 card|dribble|3|0 cell|rock|4|6",
};

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
    swing_animation: bool = false,
    sprite_sheet: [6]Sprite = undefined,
    sprite: Sprite = undefined,

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movement) |move| {
            self.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) self.movement = null;
            switch (self.team) {
                .player => self.sprite_sheet = sprites.blue_player(true),
                .opponent => self.sprite_sheet = sprites.red_player(true),
            }
        } else {
            switch (self.team) {
                .player => self.sprite_sheet = sprites.blue_player(false),
                .opponent => self.sprite_sheet = sprites.red_player(false),
            }
        }
        if (self.swing_animation) self.sprite_sheet = sprites.player_swing();
        if (ticks - self.last_sprite_update_tick > 100) {
            self.sprite_index += 1;
            self.last_sprite_update_tick = ticks;
        }
        if (self.sprite_index == 6) {
            self.sprite_index = 0;
            self.swing_animation = false;
        }
        self.sprite = self.sprite_sheet[self.sprite_index];
    }

    pub fn swingAnimation(self: *Self) void {
        // TODO (16 Sep 2023 sam): add delay before starting animation
        self.swing_animation = true;
        self.sprite_index = 0;
    }

    pub fn moveBy(self: *Self, ticks: u64, change: Vec2i) void {
        self.address = self.address.add(change);
        const duration_mul: u64 = @intCast(change.maxMag());
        if (self.movement) |move| self.position = move.to;
        const dx: f32 = @floatFromInt(change.x);
        const dy: f32 = @floatFromInt(change.y);
        const dest = self.position.add(.{ .x = (CELL_WIDTH + CELL_PADDING_X) * dx, .y = (CELL_HEIGHT + CELL_PADDING_Y) * -dy });
        self.movement = .{ .from = self.position, .to = dest, .start = ticks + (BALL_DELAY * duration_mul), .duration = (STEP_DURATION - BALL_DELAY) * duration_mul };
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.address.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 3) self.address.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 4) self.team = std.meta.stringToEnum(Team, tok).?;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []u8 {
        return std.fmt.allocPrintZ(arena, "player|{d}|{d}|{s}", .{ self.address.x, self.address.y, @tagName(self.team) }) catch unreachable;
    }
};

const Ball = struct {
    const Self = @This();
    position: Vec2 = .{},
    address: Vec2i = .{},
    last_sprite_update_tick: u64 = 0,
    sprite_index: usize = 0,
    movement: ?Movement = null,
    sprite: Sprite = undefined,

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movement) |move| {
            self.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) self.movement = null;
            //self.sprite_sheet = sprites.blue_player(true);
        } else {
            //self.sprite_sheet = sprites.blue_player(false);
        }
        self.sprite_index = if (self.movement == null) 0 else 1;
        self.sprite = sprites.BALL[self.sprite_index];
    }

    pub fn moveBy(self: *Self, ticks: u64, change: Vec2i) void {
        self.address = self.address.add(change);
        const duration_mul: u64 = @intCast(change.maxMag());
        if (self.movement) |move| self.position = move.to;
        const dx: f32 = @floatFromInt(change.x);
        const dy: f32 = @floatFromInt(change.y);
        const dest = self.position.add(.{ .x = (CELL_WIDTH + CELL_PADDING_X) * dx, .y = (CELL_HEIGHT + CELL_PADDING_Y) * -dy });
        self.movement = .{ .from = self.position, .to = dest, .start = ticks, .duration = (STEP_DURATION - BALL_DELAY) * duration_mul };
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.address.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 3) self.address.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []u8 {
        return std.fmt.allocPrintZ(arena, "ball|{d}|{d}", .{ self.address.x, self.address.y }) catch unreachable;
    }
};

const CellType = enum {
    empty,
    sand,
    rock,
};

const Cell = struct {
    const Self = @This();
    cell: CellType = .empty,
    address: Vec2i = .{},
    position: Vec2 = .{},
    sprites_mem: [4]Drawable = undefined,
    sprites: []Drawable = undefined,

    // based on the size, since we know the address, we can load the sprite.
    pub fn initSprite(self: *Self, width: usize, height: usize) void {
        const up = self.address.y == height - 1;
        const down = self.address.y == 0;
        const left = self.address.x == 0;
        const right = self.address.x == width - 1;
        self.sprites_mem[0] = .{ .sprite = sprites.terrain_grass(up, down, left, right) };
        self.sprites = self.sprites_mem[0..1];
        if (self.cell == .rock) {
            self.sprites_mem[1] = .{ .sprite = sprites.ELEVATION[0], .position = .{ .y = -64 } };
            self.sprites_mem[2] = .{ .sprite = sprites.terrain_grass(true, true, true, true), .position = .{ .y = -64 } };
            self.sprites_mem[3] = .{ .sprite = sprites.TERRAIN_SPRITES[32] };
            self.sprites = self.sprites_mem[0..4];
        }
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        c.debugPrint(str.ptr);
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.cell = std.meta.stringToEnum(CellType, tok).?;
            if (count == 3) self.address.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 4) self.address.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []u8 {
        if (self.cell == .empty) return "";
        return std.fmt.allocPrintZ(arena, "cell|{s}|{d}|{d}", .{ @tagName(self.cell), self.address.x, self.address.y }) catch unreachable;
    }
};

const CardEffect = enum {
    const Self = @This();
    move,
    kick,
    dribble,

    pub fn playerMove(self: *const Self) bool {
        return switch (self.*) {
            .move, .dribble => true,
            .kick => false,
        };
    }

    pub fn ballMove(self: *const Self) bool {
        return switch (self.*) {
            .kick, .dribble => true,
            .move => false,
        };
    }
};
const Card = struct {
    const Self = @This();
    effect: CardEffect = undefined,
    direction: Vec2i = .{},
    rect: Rect = undefined,
    movement: ?Movement = null,
    // the sprites will contain the offsets at position
    sprites: [8]Drawable = [_]Drawable{.{}} ** 8,
    used: bool = false,
    original_pos: Vec2 = .{},
    buffer: [16]u8 = undefined,
    text: []u8 = undefined,

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn initSprites(self: *Self) void {
        self.original_pos = self.rect.position;
        self.fillCardText();
        // shadow first
        self.sprites[0] = .{ .sprite = sprites.BUTTONS[8], .position = .{} };
        self.sprites[1] = .{ .sprite = sprites.BUTTONS[9], .position = .{ .x = 64 } };
        self.sprites[2] = .{ .sprite = sprites.BUTTONS[10], .position = .{ .x = 128 } };
        self.sprites[3] = .{ .sprite = sprites.BUTTONS[2], .position = .{} };
        self.sprites[4] = .{ .sprite = sprites.BUTTONS[3], .position = .{ .x = 64 } };
        self.sprites[5] = .{ .sprite = sprites.BUTTONS[4], .position = .{ .x = 128 } };
        if (self.effect.playerMove()) {
            self.sprites[6] = .{
                .sprite = sprites.blue_player(true)[0],
                // .position = PLAYER_SPRITE_OFFSET.scale(0.5).add(.{ .x = 24, .y = 0 }),
                .scale = .{ .x = 0.7, .y = 0.7 },
            };
        }
        if (self.effect.ballMove()) {
            self.sprites[7] = .{
                .sprite = sprites.BALL[0],
                // .position = PLAYER_SPRITE_OFFSET.scale(0.5).add(.{ .x = 24, .y = 0 }),
                .scale = .{ .x = 0.7, .y = 0.7 },
            };
        }
    }

    fn fillCardText(self: *Self) void {
        var index: usize = 0;
        const dir = self.direction;
        const xmax = std.math.absInt(dir.x) catch unreachable;
        const ymax = std.math.absInt(dir.y) catch unreachable;
        for (0..@as(usize, @intCast(xmax))) |_| {
            const char: u8 = if (dir.x > 0) 'r' else 'l';
            self.buffer[index] = char;
            index += 1;
        }
        for (0..@as(usize, @intCast(ymax))) |_| {
            const char: u8 = if (dir.y > 0) 'u' else 'd';
            self.buffer[index] = char;
            index += 1;
        }
        self.text = self.buffer[0..index];
    }

    pub fn moveTo(self: *Self, ticks: u64, pos: Vec2, duration: u64) void {
        self.movement = .{ .from = self.rect.position, .to = pos, .start = ticks, .duration = duration };
    }

    pub fn update(self: *Self, ticks: u64, mouse: MouseState) void {
        // TODO (16 Sep 2023 sam): Convert to pressed only when playable?
        if (self.movement) |move| {
            self.rect.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) self.movement = null;
        }
        const y_offset: f32 = if (self.rect.contains(mouse.current_pos)) -4 else 0;
        if (mouse.l_button.is_down and self.rect.contains(mouse.current_pos)) {
            self.sprites[3].sprite = sprites.BUTTONS[5];
            self.sprites[4].sprite = sprites.BUTTONS[6];
            self.sprites[5].sprite = sprites.BUTTONS[7];
        } else {
            self.sprites[3].sprite = sprites.BUTTONS[2];
            self.sprites[4].sprite = sprites.BUTTONS[3];
            self.sprites[5].sprite = sprites.BUTTONS[4];
        }
        for (self.sprites[3..6]) |*sprite| sprite.position.y = y_offset;
        self.sprites[6].position = PLAYER_SPRITE_OFFSET.scale(0.7).add(.{ .x = 24, .y = y_offset - 8 });
        self.sprites[7].position = .{ .x = 24, .y = y_offset - 8 };
    }

    pub fn deserialize(self: *Self, str: []const u8) void {
        c.debugPrint(str.ptr);
        var tokens = std.mem.split(u8, str, "|");
        var count: usize = 0;
        while (tokens.next()) |tok| {
            count += 1;
            if (count == 1) continue;
            if (count == 2) self.effect = std.meta.stringToEnum(CardEffect, tok).?;
            if (count == 3) self.direction.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 4) self.direction.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []u8 {
        const dir = self.direction;
        return std.fmt.allocPrintZ(arena, "card|{s}|{d}|{d}", .{ @tagName(self.effect), dir.x, dir.y }) catch unreachable;
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

const Drawable = struct {
    sprite: Sprite = sprites.BLANK,
    position: Vec2 = .{},
    scale: Vec2 = .{ .x = 1, .y = 1 },
};

const Field = struct {
    const Self = @This();
    ticks: u64 = 0,
    steps: usize = 0,
    width: usize = 0,
    height: usize = 0,
    players: std.ArrayList(Player),
    cells: std.ArrayList(Cell),
    cards: std.ArrayList(Card),
    ball: Ball,
    failed: bool = false,
    completed: bool = false,
    target: Vec2i = .{},
    state: StateData = .{ .idle = .{} },
    bg_sprites: std.ArrayList(Drawable),
    pane: std.ArrayList(Drawable),
    sprite_index: usize = 0,
    last_sprite_update_tick: u64 = 0,
    target_offset: f32 = 1,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .players = std.ArrayList(Player).init(allocator),
            .cards = std.ArrayList(Card).init(allocator),
            .cells = std.ArrayList(Cell).init(allocator),
            .ball = .{ .sprite = sprites.BALL[0] },
            .bg_sprites = std.ArrayList(Drawable).init(allocator),
            .pane = std.ArrayList(Drawable).init(allocator),
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
        self.bg_sprites.deinit();
        self.pane.deinit();
    }

    fn setup(self: *Self) void {
        self.width = 12;
        self.height = 7;
        self.setupCells(self.width, self.height);
        {
            const player_address = Vec2i{ .x = 2, .y = 3 };
            self.players.append(.{ .position = self.getPosOf(player_address), .address = player_address }) catch unreachable;
        }
        {
            const player_address = Vec2i{ .x = 4, .y = 4 };
            self.players.append(.{ .position = self.getPosOf(player_address), .address = player_address }) catch unreachable;
        }
        const opp_address = Vec2i{ .x = 7, .y = 3 };
        self.players.append(.{ .position = self.getPosOf(opp_address), .address = opp_address, .team = .opponent }) catch unreachable;
        for (self.cards.items) |*card| card.initSprites();
        self.target = .{ .x = 9, .y = 3 };
        const ball_address = Vec2i{ .x = 3, .y = 3 };
        self.ball.address = ball_address;
        self.ball.position = self.getPosOf(ball_address);
        self.setupPane();
    }

    fn setupPane(self: *Self) void {
        const banners = sprites.BANNERS;
        const shadows = sprites.BANNERS_SHADOW;
        var y: f32 = TOKEN_PADDING;
        self.pane.append(.{ .sprite = banners[0], .position = .{ .x = 0 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[1], .position = .{ .x = 1 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[1], .position = .{ .x = 2 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[1], .position = .{ .x = 3 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[2], .position = .{ .x = 4 * 64, .y = y } }) catch unreachable;
        for (0..8) |_| {
            y += 64;
            self.pane.append(.{ .sprite = banners[3], .position = .{ .x = 0 * 64, .y = y } }) catch unreachable;
            self.pane.append(.{ .sprite = banners[4], .position = .{ .x = 1 * 64, .y = y } }) catch unreachable;
            self.pane.append(.{ .sprite = banners[4], .position = .{ .x = 2 * 64, .y = y } }) catch unreachable;
            self.pane.append(.{ .sprite = banners[4], .position = .{ .x = 3 * 64, .y = y } }) catch unreachable;
            self.pane.append(.{ .sprite = banners[5], .position = .{ .x = 4 * 64, .y = y } }) catch unreachable;
        }
        y += 64;
        // shadows
        self.pane.append(.{ .sprite = shadows[6], .position = .{ .x = 0 * 64, .y = y + 18 } }) catch unreachable;
        self.pane.append(.{ .sprite = shadows[7], .position = .{ .x = 1 * 64, .y = y + 18 } }) catch unreachable;
        self.pane.append(.{ .sprite = shadows[7], .position = .{ .x = 2 * 64, .y = y + 18 } }) catch unreachable;
        self.pane.append(.{ .sprite = shadows[7], .position = .{ .x = 3 * 64, .y = y + 18 } }) catch unreachable;
        self.pane.append(.{ .sprite = shadows[8], .position = .{ .x = 4 * 64, .y = y + 18 } }) catch unreachable;
        // bottom row
        self.pane.append(.{ .sprite = banners[6], .position = .{ .x = 0 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[7], .position = .{ .x = 1 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[7], .position = .{ .x = 2 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[7], .position = .{ .x = 3 * 64, .y = y } }) catch unreachable;
        self.pane.append(.{ .sprite = banners[8], .position = .{ .x = 4 * 64, .y = y } }) catch unreachable;
        // add some x padding;
        for (self.pane.items) |*pane| pane.position.x += PANE_X_PADDING;
    }

    fn deserialize(self: *Self, str: []const u8) void {
        self.failed = false;
        self.completed = false;
        self.players.clearRetainingCapacity();
        self.cells.clearRetainingCapacity();
        self.cards.clearRetainingCapacity();
        var tokens = std.mem.split(u8, str, " ");
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, token[0..4], "ball")) {
                self.ball.deserialize(token);
            }
            if (std.mem.eql(u8, token[0..6], "player")) {
                var player: Player = .{};
                player.deserialize(token);
                player.position = self.getPosOf(player.address);
                self.players.append(player) catch unreachable;
            }
            if (std.mem.eql(u8, token[0..4], "card")) {
                var card: Card = .{};
                card.deserialize(token);
                self.cards.append(card) catch unreachable;
            }
            if (std.mem.eql(u8, token[0..4], "size")) {
                var toks = std.mem.split(u8, token, "|");
                var count: usize = 0;
                while (toks.next()) |tok| {
                    count += 1;
                    if (count == 1) continue;
                    if (count == 2) self.width = std.fmt.parseInt(usize, tok, 10) catch unreachable;
                    if (count == 3) self.height = std.fmt.parseInt(usize, tok, 10) catch unreachable;
                }
                self.setupCells(self.width, self.height);
            }
            // TODO (16 Sep 2023 sam): deserialize target
            if (std.mem.eql(u8, token[0..4], "cell")) {
                var address: Vec2i = .{};
                var toks = std.mem.split(u8, token, "|");
                var count: usize = 0;
                while (toks.next()) |tok| {
                    count += 1;
                    if (count == 3) address.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
                    if (count == 4) address.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
                }
                var cell = self.getCellAt(address).?;
                cell.deserialize(token);
                cell.initSprite(self.width, self.height);
            }
        }
        self.ball.position = self.getPosOf(self.ball.address);
        self.setupCards();
    }

    fn setupCards(self: *Self) void {
        for (self.cards.items, 0..) |*card, i| {
            const fi: f32 = @floatFromInt(i);
            card.rect = .{
                .size = .{ .x = 192, .y = 64 },
                .position = .{
                    .x = PANE_X_PADDING + 64,
                    .y = TOKEN_PADDING + 64 + (64 * fi),
                },
            };
            card.initSprites();
        }
    }

    fn serialize(self: *Self) void {
        var string = std.ArrayList(u8).init(self.arena);
        {
            var tok = std.fmt.allocPrint(self.arena, "size|{d}|{d}", .{ self.width, self.height }) catch unreachable;
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        {
            var tok = self.ball.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        {
            var tok = std.fmt.allocPrint(self.arena, "target|{d}|{d}", .{ self.target.x, self.target.y }) catch unreachable;
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.players.items) |player| {
            var tok = player.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.cards.items) |card| {
            var tok = card.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.cells.items) |cell| {
            var tok = cell.serialize(self.arena);
            if (tok.len == 0) continue;
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        string.append(0) catch unreachable;
        helpers.debugPrint("{s}", .{string.items});
    }

    fn setupCells(self: *Self, width: usize, height: usize) void {
        for (self.cells.items) |*cell| cell.deinit();
        self.cells.clearRetainingCapacity();
        const fw: f32 = @floatFromInt(width);
        const fh: f32 = @floatFromInt(height);
        const field_width = (fw * (CELL_WIDTH + CELL_PADDING_X)) - CELL_PADDING_X;
        const field_height = (fh * (CELL_HEIGHT + CELL_PADDING_Y)) - CELL_PADDING_Y;
        const field_origin = SCREEN_SIZE.scale(0.5).add(.{ .x = -field_width * 0.5, .y = field_height * 0.5 }).add(.{ .x = TOKEN_PANE_WIDTH * 0.5 });
        for (0..height) |y| {
            for (0..width) |x| {
                const fx: f32 = @floatFromInt(x);
                const fy: f32 = @floatFromInt(y);
                const position = field_origin.add(.{ .x = fx * (CELL_WIDTH + CELL_PADDING_X), .y = -fy * (CELL_HEIGHT + CELL_PADDING_Y) - CELL_HEIGHT }); // we want to get the left top corner of the box so we have to subtract cell height again.
                self.cells.append(.{ .position = position, .address = .{ .x = @intCast(x), .y = @intCast(y) } }) catch unreachable;
                self.cells.items[self.cells.items.len - 1].initSprite(width, height);
            }
        }
        self.bg_sprites.clearRetainingCapacity();
        for (self.cells.items) |cell| {
            self.bg_sprites.append(.{ .sprite = sprites.FOAM[0], .position = cell.position.add(.{ .x = -CELL_WIDTH, .y = -CELL_HEIGHT }) }) catch unreachable;
        }
    }

    fn update(self: *Self, inputs: Inputs, arena: std.mem.Allocator, ticks: u64) void {
        self.ticks = ticks;
        self.arena = arena;
        for (self.players.items) |*player| player.update(self.ticks);
        self.ball.update(self.ticks);
        for (self.cards.items) |*card| card.update(self.ticks, inputs.mouse);
        self.handleMouse(inputs.mouse);
        if (ticks - self.last_sprite_update_tick > 100) {
            self.sprite_index += 1;
            self.last_sprite_update_tick = ticks;
        }
        if (self.sprite_index == 8) self.sprite_index = 0;
        for (self.bg_sprites.items) |*bgs| bgs.sprite = sprites.FOAM[self.sprite_index];
        self.target_offset = 0.85 + 0.05 * (@cos(@as(f32, @floatFromInt(self.ticks)) / 100));
    }

    fn playerAt(self: *Self, address: Vec2i) ?*Player {
        for (self.players.items) |*player| {
            if (player.address.equal(address)) return player;
        }
        return null;
    }

    fn getCellAt(self: *Self, address: Vec2i) ?*Cell {
        for (self.cells.items) |*cell| {
            if (cell.address.equal(address)) return cell;
        }
        return null;
    }

    pub fn getPosOf(self: *Self, address: Vec2i) Vec2 {
        // TODO (16 Sep 2023 sam): Should we calculate this?
        for (self.cells.items) |*cell| {
            if (cell.address.equal(address)) return cell.position;
        }
        unreachable;
    }

    fn maybePlayCard(self: *Self, card_index: usize, cell_index: usize) void {
        var used = false;
        const cell = self.cells.items[cell_index];
        if (self.playerAt(cell.address)) |player| {
            const card = self.cards.items[card_index];
            switch (card.effect) {
                .move => {
                    player.moveBy(self.ticks, card.direction);
                    used = true;
                },
                .kick => {
                    if (self.ball.address.equal(cell.address)) {
                        self.ball.moveBy(self.ticks, card.direction);
                        used = true;
                    }
                },
                .dribble => {
                    if (self.ball.address.equal(cell.address)) {
                        player.moveBy(self.ticks, card.direction);
                        self.ball.moveBy(self.ticks, card.direction);
                        used = true;
                    }
                },
            }
        }
        if (used) {
            self.cards.items[card_index].used = true;
            self.cards.items[card_index].moveTo(self.ticks, .{ .x = -300, .y = -300 }, 100);
            self.resolveEffects();
        } else {
            self.cards.items[card_index].moveTo(self.ticks, self.cards.items[card_index].original_pos, 100);
        }
    }

    fn resolveEffects(self: *Self) void {
        c.debugPrint("resolving effects");
        // if player goes within 1 block of opponent, they die, and level is fail.
        for (self.players.items) |*player| {
            if (player.team == .player) {
                for (self.players.items) |*other| {
                    if (other.team == .opponent) {
                        const distance = player.address.distancei(other.address);
                        if (distance <= 1) {
                            // player.knocked_out = true;
                            self.failed = true;
                            other.swingAnimation();
                            c.debugPrint("failed");
                        }
                    }
                }
            }
        }
    }

    fn handleMouse(self: *Self, mouse: MouseState) void {
        switch (self.state) {
            .idle => {
                self.state.idle.card_index = null;
                for (self.cards.items, 0..) |card, i| {
                    if (card.used) continue;
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
                        self.cards.items[data.card_index].moveTo(self.ticks, self.cards.items[data.card_index].original_pos, 100);
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
            if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.moveBy(self.ticks, .{ .x = 1 });
            self.field.players.items[0].moveBy(self.ticks, .{ .x = 1 });
        }
        if (self.haathi.inputs.getKey(.a).is_clicked) {
            if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.moveBy(self.ticks, .{ .x = -1 });
            self.field.players.items[0].moveBy(self.ticks, .{ .x = -1 });
        }
        if (self.haathi.inputs.getKey(.w).is_clicked) {
            if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.moveBy(self.ticks, .{ .y = 1 });
            self.field.players.items[0].moveBy(self.ticks, .{ .y = 1 });
        }
        if (self.haathi.inputs.getKey(.s).is_clicked) {
            if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.moveBy(self.ticks, .{ .y = -1 });
            self.field.players.items[0].moveBy(self.ticks, .{ .y = -1 });
        }
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            self.field.serialize();
        }
        if (self.haathi.inputs.getKey(.v).is_clicked) {
            self.field.deserialize(LEVELS[0]);
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.setCursor(.auto);
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        if (mouse_pos.x < SCREEN_SIZE.x and mouse_pos.y < SCREEN_SIZE.y) self.haathi.setCursor(.none);
        if (mouse_pos.x == 0 or mouse_pos.y == 0) self.haathi.setCursor(.auto);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = Vec4.fromHexRgb("#47ABA9"),
        });
        for (self.field.pane.items) |sprite| {
            self.haathi.drawSprite(.{
                .position = sprite.position,
                .sprite = sprite.sprite,
            });
        }
        if (true) {
            for (self.field.bg_sprites.items) |sprite| {
                self.haathi.drawSprite(.{
                    .position = sprite.position,
                    .sprite = sprite.sprite,
                });
            }
        }
        if (true) {
            for (self.field.cells.items) |cell| {
                const sprite = cell.sprites[0];
                self.haathi.drawSprite(.{
                    .position = cell.position.add(sprite.position),
                    .sprite = sprite.sprite,
                });
            }
            for (self.field.cells.items) |cell| {
                for (cell.sprites[1..]) |sprite| {
                    self.haathi.drawSprite(.{
                        .position = cell.position.add(sprite.position),
                        .sprite = sprite.sprite,
                    });
                }
            }
        }
        // target
        if (true) {
            const pos = self.field.getPosOf(self.field.target);
            for (sprites.TARGETS, sprites.TARGET_OFFSETS) |sprite, offset| {
                self.haathi.drawSprite(.{
                    .position = pos.add(offset.scale(self.field.target_offset)),
                    .sprite = sprite,
                });
            }
        }
        if (true) {
            for (self.field.cards.items) |card| {
                if (card.used) continue;
                for (card.sprites) |sprite| {
                    self.haathi.drawSprite(.{
                        .position = card.rect.position.add(sprite.position),
                        .sprite = sprite.sprite,
                        .scale = sprite.scale,
                    });
                }
                self.haathi.drawText(.{
                    .text = card.text,
                    .position = card.rect.position.add(card.rect.size.scale(0.5)).add(card.sprites[3].position),
                    .color = Vec4{ .x = 1, .y = 1, .z = 1, .w = 1 },
                });
            }
        }
        if (true) {
            for (self.field.players.items) |player| {
                self.haathi.drawSprite(.{
                    .position = player.position.add(PLAYER_SPRITE_OFFSET),
                    .sprite = player.sprite,
                });
            }
        }
        if (true) {
            self.haathi.drawSprite(.{
                .position = self.field.ball.position,
                .sprite = self.field.ball.sprite,
            });
        }
        if (self.field.failed) {
            self.haathi.drawText(.{
                .text = "Level Failed",
                .position = .{ .x = SCREEN_SIZE.x / 2, .y = 100 },
                .color = colors.solarized_red,
            });
        }
        if (true) {
            if (mouse_pos.x != 0 and mouse_pos.y != 0) {
                self.haathi.drawSprite(.{
                    .position = self.haathi.inputs.mouse.current_pos.add(POINTER_OFFSET),
                    .sprite = sprites.POINTER,
                });
            }
        }
    }
};