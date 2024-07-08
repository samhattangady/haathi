const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const FONT_3 = @import("haathi.zig").FONT_3;
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
const CARD_POINTER_OFFSET = Vec2{ .x = -17, .y = -27 };
const STEP_DURATION = 300;
const BALL_DELAY = 80;
const DEBUG_1 = false;
const BUILDER_MODE = true;
const START_SCREEN = 13;

const LEVELS = [_][]const u8{
    "size|12|7 ball|3|2 target|9|3 player|3|2|player card|dribble|1|0|3 card|dribble|1|1|1 card|dribble|1|0|2",
    "size|12|7 ball|4|2 target|9|3 player|2|2|player card|move|1|0|2 card|dribble|1|0|2 card|dribble|1|1|2 card|dribble|1|-1|1",
    "size|12|7 ball|4|3 target|5|3 player|4|3|player card|kick|1|0|2 card|dribble|-1|0|1 card|move|0|-1|4 card|move|1|1|2 card|move|-1|0|2 card|move|1|1|2",
    "size|12|7 ball|1|2 target|7|4 player|1|2|player player|3|4|player card|kick|1|1|2 card|kick|1|1|2 card|kick|1|-1|2 card|move|1|0|2 card|move|1|0|2 card|move|1|0|2 card|move|1|0|2",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player player|5|3|opponent card|dribble|1|1|1 card|dribble|1|-1|1 card|dribble|1|0|3 card|dribble|1|0|1",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player player|5|3|opponent player|5|5|player card|kick|1|1|2 card|kick|1|-1|2 card|move|1|-1|1 card|move|1|1|1 card|dribble|1|0|2 card|move|1|0|2",
    "size|12|7 ball|3|1 target|9|3 player|3|1|player player|5|1|opponent player|5|2|opponent player|5|4|opponent player|5|5|opponent card|kick|1|1|4 card|dribble|1|-1|2 card|move|0|1|4 card|move|0|1|4 card|move|1|-1|4",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player player|9|4|opponent player|8|3|opponent player|5|3|opponent player|6|2|opponent card|dribble|1|1|3 card|dribble|1|-1|2 card|dribble|0|-1|2 card|dribble|0|1|1 card|dribble|1|0|1",
    "size|12|7 ball|3|2 target|9|5 player|3|2|player card|dribble|1|1|3 card|dribble|1|0|1 card|dribble|1|0|1 card|dribble|1|0|1 cell|rock|0|3 cell|rock|1|3 cell|rock|2|3 cell|rock|3|3 cell|rock|4|3 cell|rock|6|3 cell|rock|7|3 cell|rock|8|3 cell|rock|9|3 cell|rock|10|3 cell|rock|11|3",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player player|5|3|opponent card|dribble|1|0|2 card|kick|1|1|4 card|move|1|1|2 card|move|1|-1|2 cell|rock|2|5 cell|rock|3|5 cell|rock|4|5 cell|rock|5|5 cell|rock|6|5 cell|rock|7|5 cell|rock|8|5",
    "size|12|7 ball|6|2 target|6|5 player|6|2|player player|6|5|player card|kick|0|1|5 card|move|-1|0|2 card|move|1|0|2 card|dribble|-1|0|2 card|dribble|1|0|2 cell|rock|3|6 cell|rock|4|6 cell|rock|5|6",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player player|5|3|opponent card|dribble|1|-1|2 card|dribble|1|1|2 card|dribble|1|0|2",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player",
    "size|12|7 ball|3|3 target|9|3 player|3|3|player",
};
const SPACER = "\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t";

const LINE1 = [_][]const u8{
    "Every year my grandpa and his friends meet up.",
    "And they talk about the year that we won the championship",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "Drag the cards onto the field to relive their memories",
};
const LINE2 = [_][]const u8{
    "No no no. You're telling it all wrong.",
    "He didn't start with the ball.",
    "He chased it down at the half line.",
    "And did a couple of those fancy stepovers...",
};
const LINE3 = [_][]const u8{
    "He kicked it and just ran around.",
    "like he was playing with his food.",
    "Nervewracking, yet magical.",
};
const LINE4 = [_][]const u8{
    "Then they got into a string of passes",
    "Like the ball was one of their own teammates.",
};
const LINE5 = [_][]const u8{
    "Got past a defender like he didn't even exist.",
    "Left him standing there like a scarecrow.",
};
const LINE6 = [_][]const u8{
    "No no no. It didn't happen like that.",
    "They used their passing to get past the first defender",
};
const LINE7 = [_][]const u8{
    "Suddenly this ferocious wall of defenders came in their way",
    "So he responded with a ferocious feint and found a crack",
};
const LINE8 = [_][]const u8{
    "No no no. All nonsense.",
    "He systematically probed and found cracks in their walls.",
};
const LINE9 = [_][]const u8{
    "Then they got to the scary part of the field",
    "See in those days, fields weren't so well maintained...",
    "So that could pose a problem.",
};
const LINE10 = [_][]const u8{
    "But our boys were used to those conditions.",
    "On that play, they just got around it like it was nothing.",
    "Used it to beat another defender as well!",
};
const LINE11 = [_][]const u8{
    "And that cross...",
    "How perfect it was",
};
const LINE12 = [_][]const u8{
    "And he was staring at goal" ++ SPACER,
    "",
    "",
    "",
    "",
    SPACER ++ "No, he still had a man to beat",
    "",
    "",
    "",
    "",
    "Oh right. There was the last defender" ++ SPACER,
    "That happened." ++ SPACER,
};
const LINE13 = [_][]const u8{
    "And now he was staring at goal" ++ SPACER,
    "And he just hammered in the shot" ++ SPACER,
    "",
    "",
    SPACER ++ "No, not at all. He chipped it",
    "",
    "",
    "No. Smashed it" ++ SPACER,
    "",
    "",
    SPACER ++ "No, pure finesse",
};
const LINE14 = [_][]const u8{
    "Umm grandpa, I think I need to leave",
    "",
    "",
    "Oh sure. See you next time." ++ SPACER,
    "...but it was a power shot..." ++ SPACER,
    "",
    "",
    SPACER ++ "NO! It was pure touch.",
    "",
    "",
    "..." ++ SPACER,
    "",
    "",
    SPACER ++ "...",
};
const LINE15 = [_][]const u8{
    "Bye grandma, I shall leave." ++ SPACER,
    "Leave that fight as well..." ++ SPACER,
    "",
    "",
    SPACER ++ "Oh, leaving so soon?",
    SPACER ++ "Are you sure?",
    SPACER ++ "I could tell you what really happened you know?",
    "",
    "",
    "You were there?" ++ SPACER,
    "",
    "",
    SPACER ++ "Well...",
};
const LINE16 = [_][]const u8{
    "So both of these boys had gotten tickets for the match",
    "and tickets for the train.",
    "",
    "",
    "They ended up missing the train.",
    "So they ended up missing the match.",
};
const LINE17 = [_][]const u8{
    "They missed the match?!" ++ SPACER,
    "What about the stories then?" ++ SPACER,
    "",
    "",
    SPACER ++ "You know how it is...",
    SPACER ++ "The emotion was so strong,",
    SPACER ++ "the memory was forced to appear...",
    "",
    "",
    "Oh grandpa..." ++ SPACER,
    "I wonder what actually happened though..." ++ SPACER,
};
const LINE18 = [_][]const u8{
    "",
    "",
    "",
    "",
    "You know what? I think it doesn't matter...",
    "The stories that we share are more important",
    "than what actually happened.",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "Thanks for playing.",
};

const Dialogue = struct {
    lines: []const []const u8,
};

const DIALOGUES = [_]Dialogue{
    .{ .lines = LINE1[0..] },
    .{ .lines = LINE2[0..] },
    .{ .lines = LINE3[0..] },
    .{ .lines = LINE4[0..] },
    .{ .lines = LINE5[0..] },
    .{ .lines = LINE6[0..] },
    .{ .lines = LINE7[0..] },
    .{ .lines = LINE8[0..] },
    .{ .lines = LINE9[0..] },
    .{ .lines = LINE10[0..] },
    .{ .lines = LINE11[0..] },
    .{ .lines = LINE12[0..] },
    .{ .lines = LINE13[0..] },
    .{ .lines = LINE14[0..] },
    .{ .lines = LINE15[0..] },
    .{ .lines = LINE16[0..] },
    .{ .lines = LINE17[0..] },
    .{ .lines = LINE18[0..] },
};

const Screen = union(enum) {
    level: []const u8,
    dialogue: Dialogue,
};

const SCREENS = [_]Screen{
    .{ .dialogue = DIALOGUES[0] },
    .{ .level = LEVELS[0] },
    .{ .dialogue = DIALOGUES[1] },
    .{ .level = LEVELS[1] },
    .{ .dialogue = DIALOGUES[2] },
    .{ .level = LEVELS[2] },
    .{ .dialogue = DIALOGUES[3] },
    .{ .level = LEVELS[3] },
    .{ .dialogue = DIALOGUES[4] },
    .{ .level = LEVELS[4] },
    .{ .dialogue = DIALOGUES[5] },
    .{ .level = LEVELS[5] },
    .{ .dialogue = DIALOGUES[6] },
    .{ .level = LEVELS[6] },
    .{ .dialogue = DIALOGUES[7] },
    .{ .level = LEVELS[7] },
    .{ .dialogue = DIALOGUES[8] },
    .{ .level = LEVELS[8] },
    .{ .dialogue = DIALOGUES[9] },
    .{ .level = LEVELS[9] },
    .{ .dialogue = DIALOGUES[10] },
    .{ .level = LEVELS[10] },
    .{ .dialogue = DIALOGUES[11] },
    .{ .level = LEVELS[11] },
    .{ .dialogue = DIALOGUES[12] },
    .{ .dialogue = DIALOGUES[13] },
    .{ .dialogue = DIALOGUES[14] },
    .{ .dialogue = DIALOGUES[15] },
    .{ .dialogue = DIALOGUES[16] },
    .{ .dialogue = DIALOGUES[17] },
};

const Team = enum {
    player,
    opponent,
};
const Player = struct {
    const Self = @This();
    team: Team = .player,
    address: Vec2i = .{},
    movements: std.ArrayList(Movement),
    position: Vec2 = .{},
    last_sprite_update_tick: u64 = 0,
    sprite_index: usize = 0,
    swing_animation: ?u64 = null,
    sprite_sheet: [6]Sprite = undefined,
    sprite: Sprite = undefined,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .movements = std.ArrayList(Movement).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.movements.deinit();
    }

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movements.items.len > 0) {
            const move = self.movements.items[0];
            self.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) _ = self.movements.orderedRemove(0);
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
        if (self.swing_animation) |anim_start| {
            if (ticks > anim_start) self.sprite_sheet = sprites.player_swing();
            // start the animation here, and set anim_start to 0 for reference
            if (anim_start != 0) {
                self.swing_animation = 0;
                self.sprite_index = 0;
            }
        }
        if (ticks - self.last_sprite_update_tick > 100) {
            self.sprite_index += 1;
            self.last_sprite_update_tick = ticks;
        }
        if (self.sprite_index == 6) {
            self.sprite_index = 0;
            if (self.swing_animation) |anim_start| {
                if (ticks > anim_start) self.swing_animation = null;
            }
        }
        self.sprite = self.sprite_sheet[self.sprite_index];
    }

    pub fn swingAnimation(self: *Self, ticks: u64) void {
        self.swing_animation = ticks;
    }

    pub fn moveDelay(self: *Self) u64 {
        var delay: u64 = 0;
        for (self.movements.items) |move| delay += move.duration;
        return delay;
    }

    pub fn addMove(self: *Self, ticks: u64, change: Vec2i, new: bool) void {
        self.address = self.address.add(change);
        if (new) {
            if (self.movements.items.len > 0) {
                self.position = self.movements.items[self.movements.items.len - 1].to;
                self.movements.clearRetainingCapacity();
            }
        }
        const duration_mul: u64 = @intCast(change.maxMag());
        var delay: u64 = 0;
        var end_pos = self.position;
        for (self.movements.items) |move| {
            delay += move.duration;
            end_pos = move.to;
        }
        const dx: f32 = @floatFromInt(change.x);
        const dy: f32 = @floatFromInt(change.y);
        const dest = end_pos.add(.{ .x = (CELL_WIDTH + CELL_PADDING_X) * dx, .y = (CELL_HEIGHT + CELL_PADDING_Y) * -dy });
        const move = Movement{ .from = end_pos, .to = dest, .start = (BALL_DELAY * duration_mul) + ticks + delay, .duration = (STEP_DURATION - BALL_DELAY) * duration_mul };
        self.movements.append(move) catch unreachable;
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
    movements: std.ArrayList(Movement),
    sprite: Sprite = undefined,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .movements = std.ArrayList(Movement).init(allocator), .sprite = sprites.BALL[0] };
    }

    pub fn deinit(self: *Self) void {
        self.movements.deinit();
    }

    pub fn reset(self: *Self) void {
        self.movements.clearRetainingCapacity();
    }

    pub fn update(self: *Self, ticks: u64) void {
        if (self.movements.items.len > 0) {
            const move = self.movements.items[0];
            self.position = move.getPos(ticks);
            if (ticks > (move.start + move.duration)) _ = self.movements.orderedRemove(0);
        } else {}
        self.sprite_index = if (self.movements.items.len == 0) 0 else 1;
        self.sprite = sprites.BALL[self.sprite_index];
    }

    pub fn moveDelay(self: *Self) u64 {
        var delay: u64 = 0;
        for (self.movements.items) |move| delay += move.duration;
        return delay;
    }

    pub fn addMove(self: *Self, ticks: u64, change: Vec2i, new: bool) void {
        self.address = self.address.add(change);
        if (new) {
            if (self.movements.items.len > 0) {
                self.position = self.movements.items[self.movements.items.len - 1].to;
                self.movements.clearRetainingCapacity();
            }
        }
        const duration_mul: u64 = @intCast(change.maxMag());
        var delay: u64 = 0;
        var end_pos = self.position;
        for (self.movements.items) |move| {
            delay += move.duration;
            end_pos = move.to;
        }
        const dx: f32 = @floatFromInt(change.x);
        const dy: f32 = @floatFromInt(change.y);
        const dest = end_pos.add(.{ .x = (CELL_WIDTH + CELL_PADDING_X) * dx, .y = (CELL_HEIGHT + CELL_PADDING_Y) * -dy });
        const move = Movement{ .from = end_pos, .to = dest, .start = ticks + delay, .duration = (STEP_DURATION - BALL_DELAY) * duration_mul };
        self.movements.append(move) catch unreachable;
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

    pub fn toString(self: *Self) []const u8 {
        return switch (self.*) {
            .kick => "K",
            .dribble => "D",
            .move => "R",
        };
    }
};

const CardDirection = struct {
    direction: Vec2i = .{},
    magnitude: usize = 0,
};

const Card = struct {
    const Self = @This();
    effect: CardEffect = undefined,
    direction: CardDirection = .{},
    rect: Rect = undefined,
    movement: ?Movement = null,
    // the sprites will contain the offsets at position
    sprites: [8]Drawable = [_]Drawable{.{}} ** 8,
    arrow_sprite: Sprite = undefined,
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
        self.text = std.fmt.bufPrintZ(&self.buffer, "{d}", .{self.direction.magnitude}) catch unreachable;
        const dirs = [_]Vec2i{
            .{ .x = 1, .y = 1 },
            .{ .x = 0, .y = 1 },
            .{ .x = -1, .y = 1 },
            .{ .x = -1, .y = 0 },
            .{ .x = -1, .y = -1 },
            .{ .x = 0, .y = -1 },
            .{ .x = 1, .y = -1 },
            .{ .x = 1, .y = 0 },
        };
        for (dirs, 0..) |dir, i| {
            if (self.direction.direction.equal(dir)) {
                self.arrow_sprite = sprites.ARROWS[i];
                break;
            }
        }
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
            if (count == 3) self.direction.direction.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 4) self.direction.direction.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
            if (count == 5) self.direction.magnitude = std.fmt.parseInt(usize, tok, 10) catch unreachable;
        }
    }

    pub fn serialize(self: *const Self, arena: std.mem.Allocator) []u8 {
        const dir = self.direction.direction;
        return std.fmt.allocPrintZ(arena, "card|{s}|{d}|{d}|{d}", .{ @tagName(self.effect), dir.x, dir.y, self.direction.magnitude }) catch unreachable;
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
    valid_drop: ?Vec2i = null,
    target: Vec2i = .{},
    state: StateData = .{ .idle = .{} },
    bg_sprites: std.ArrayList(Drawable),
    pane: std.ArrayList(Drawable),
    sprite_index: usize = 0,
    level: []const u8 = undefined,
    last_sprite_update_tick: u64 = 0,
    target_offset: f32 = 1,
    animations_complete_at: u64 = 0,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .players = std.ArrayList(Player).init(allocator),
            .cards = std.ArrayList(Card).init(allocator),
            .cells = std.ArrayList(Cell).init(allocator),
            .ball = Ball.init(allocator),
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
        for (self.cards.items) |*card| card.initSprites();
        self.target = .{ .x = 1, .y = 3 };
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

    fn reset(self: *Self) void {
        self.deserialize(self.level);
    }

    fn deserialize(self: *Self, str: []const u8) void {
        self.level = str;
        self.failed = false;
        self.completed = false;
        for (self.players.items) |*player| player.deinit();
        self.players.clearRetainingCapacity();
        self.cells.clearRetainingCapacity();
        self.cards.clearRetainingCapacity();
        var tokens = std.mem.split(u8, str, " ");
        while (tokens.next()) |token| {
            if (std.mem.eql(u8, token[0..4], "ball")) {
                self.ball.reset();
                self.ball.deserialize(token);
            }
            if (std.mem.eql(u8, token[0..6], "player")) {
                var player = Player.init(self.allocator);
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
            if (std.mem.eql(u8, token[0..6], "target")) {
                var toks = std.mem.split(u8, token, "|");
                var count: usize = 0;
                while (toks.next()) |tok| {
                    count += 1;
                    if (count == 1) continue;
                    if (count == 2) self.target.x = std.fmt.parseInt(i32, tok, 10) catch unreachable;
                    if (count == 3) self.target.y = std.fmt.parseInt(i32, tok, 10) catch unreachable;
                }
            }
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
            const tok = std.fmt.allocPrint(self.arena, "size|{d}|{d}", .{ self.width, self.height }) catch unreachable;
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        {
            const tok = self.ball.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        {
            const tok = std.fmt.allocPrint(self.arena, "target|{d}|{d}", .{ self.target.x, self.target.y }) catch unreachable;
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.players.items) |player| {
            const tok = player.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.cards.items) |card| {
            const tok = card.serialize(self.arena);
            string.appendSlice(tok) catch unreachable;
            string.append(' ') catch unreachable;
        }
        for (self.cells.items) |cell| {
            const tok = cell.serialize(self.arena);
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
            if (player.team != .player) continue;
            if (player.address.equal(address)) return player;
        }
        return null;
    }

    fn opponentAt(self: *Self, address: Vec2i) ?*Player {
        for (self.players.items) |*player| {
            if (player.team != .opponent) continue;
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
        // Just assume that cells[0] is at 0,0
        const origin = self.cells.items[0].position;
        const dx: f32 = @floatFromInt(address.x);
        const dy: f32 = @floatFromInt(address.y);
        return origin.add(.{ .x = dx * CELL_WIDTH, .y = -dy * CELL_HEIGHT });
    }

    fn movePlayerBy(self: *Self, player: *Player, change: CardDirection) void {
        // check all the cells between current position and final, and if any of them are
        // opponent or rock, we fail.
        var pos = player.address;
        for (0..change.magnitude) |_| {
            pos = pos.add(change.direction);
            player.addMove(self.ticks, change.direction, false);
            if (self.opponentAt(pos)) |other| {
                self.failed = true;
                other.swingAnimation(self.ticks + self.ball.moveDelay());
                player.addMove(self.ticks, change.direction.scale(-1), false);
                break;
            }
            if (self.getCellAt(pos)) |cell| {
                if (cell.cell == .rock) {
                    self.failed = true;
                    player.addMove(self.ticks, change.direction.scale(-1), false);
                    break;
                }
            } else {
                // oob needs to fail
                self.failed = true;
                break;
            }
        }
        self.animations_complete_at = @max(self.animations_complete_at, self.ticks + player.moveDelay());
    }

    fn moveBallBy(self: *Self, change: CardDirection) void {
        var pos = self.ball.address;
        var dir = change.direction;
        for (0..change.magnitude) |_| {
            pos = pos.add(dir);
            self.ball.addMove(self.ticks, dir, false);
            if (self.opponentAt(pos)) |other| {
                if (other.team == .opponent) {
                    other.swingAnimation(self.ticks + self.ball.moveDelay());
                    self.ball.addMove(self.ticks, .{ .x = -10, .y = 20 }, false);
                    self.failed = true;
                    break;
                }
            }
            if (self.getCellAt(pos)) |cell| {
                if (cell.cell == .rock) {
                    dir.y *= -1;
                }
            } else {
                // oob needs to fail
                self.failed = true;
            }
        }
        self.animations_complete_at = @max(self.animations_complete_at, self.ticks + self.ball.moveDelay());
        // check all the cells between current position and final, and if any of them are
        // opponent or rock, we fail.
        // const dir = change.
    }

    fn maybePlayCard(self: *Self, card_index: usize, cell_index: usize) void {
        if (self.failed) {
            self.cards.items[card_index].moveTo(self.ticks, self.cards.items[card_index].original_pos, 100);
            return;
        }
        var used = false;
        const cell = self.cells.items[cell_index];
        if (self.playerAt(cell.address)) |player| {
            const card = self.cards.items[card_index];
            switch (card.effect) {
                .move => {
                    self.movePlayerBy(player, card.direction);
                    // player.moveBy(self.ticks, card.direction);
                    used = true;
                },
                .kick => {
                    if (self.ball.address.equal(cell.address)) {
                        self.moveBallBy(card.direction);
                        // self.ball.moveBy(self.ticks, card.direction);
                        used = true;
                    }
                },
                .dribble => {
                    if (self.ball.address.equal(cell.address)) {
                        self.moveBallBy(card.direction);
                        self.movePlayerBy(player, card.direction);
                        //     player.addMove(self.ticks, card.direction.direction, true);
                        //     self.ball.addMove(self.ticks, card.direction.direction, true);
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
        // we just check if level is complete here.
        if (self.ball.address.equal(self.target) and self.playerAt(self.target) != null) {
            self.completed = true;
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
                self.valid_drop = null;
                self.state.card_drag.cell_index = null;
                var card = &self.cards.items[data.card_index];
                card.rect.position = mouse.current_pos.subtract(data.card_offset);
                for (self.cells.items, 0..) |cell, i| {
                    const rect = Rect{ .position = cell.position, .size = CELL_SIZE };
                    if (rect.contains(card.rect.position)) {
                        self.state.card_drag.cell_index = i;
                        const ball_at = self.ball.address.equal(cell.address);
                        const player_at = self.playerAt(cell.address) != null;
                        if (self.failed) break;
                        switch (card.effect) {
                            .move => {
                                if (player_at) self.valid_drop = cell.address;
                            },
                            .kick, .dribble => {
                                if (player_at and ball_at) self.valid_drop = cell.address;
                            },
                        }
                        break;
                    }
                }
                if (mouse.l_button.is_released) {
                    if (self.state.card_drag.cell_index) |ci| {
                        self.maybePlayCard(self.state.card_drag.card_index, ci);
                    } else {
                        self.cards.items[data.card_index].moveTo(self.ticks, self.cards.items[data.card_index].original_pos, 100);
                    }
                    self.valid_drop = null;
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }
};

const GameMode = enum {
    menu,
    game,
};
pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    mode: GameMode = .menu,
    ticks: u64 = 0,
    field: Field,
    bg: std.ArrayList(Drawable),
    screen_index: usize = 0,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .field = Field.init(allocator, arena_handle.allocator()),
            .bg = std.ArrayList(Drawable).init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        if (BUILDER_MODE) {
            self.mode = .game;
            self.screen_index = START_SCREEN - 1;
            self.incrementScreenIndex();
        }
        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn setup(self: *Self) void {
        var y: f32 = 0;
        while (y < SCREEN_SIZE.y) : (y += 64) {
            var x: f32 = 0;
            while (x < SCREEN_SIZE.x) : (x += 64) {
                self.bg.append(.{ .sprite = sprites.BANNERS[4], .position = .{ .x = x, .y = y } }) catch unreachable;
            }
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        switch (self.mode) {
            .menu => self.updateMenu(),
            .game => self.updateGame(),
        }
    }

    pub fn updateMenu(self: *Self) void {
        _ = self;
    }

    pub fn updateGame(self: *Self) void {
        switch (SCREENS[self.screen_index]) {
            .level => {
                self.updateField();
            },
            .dialogue => {},
        }
    }

    pub fn endFrame(self: *Self) void {
        switch (self.mode) {
            .menu => {
                if (self.haathi.inputs.mouse.l_button.is_clicked) self.mode = .game;
            },
            .game => {
                switch (SCREENS[self.screen_index]) {
                    .level => {
                        if (self.field.completed and self.ticks > self.field.animations_complete_at + 300) {
                            self.incrementScreenIndex();
                        }
                    },
                    .dialogue => {
                        if (self.haathi.inputs.mouse.l_button.is_clicked) self.incrementScreenIndex();
                    },
                }
            },
        }
    }

    pub fn incrementScreenIndex(self: *Self) void {
        self.field.completed = false;
        self.screen_index += 1;
        if (self.screen_index >= SCREENS.len) {
            self.screen_index = 0;
            self.mode = .menu;
        }
        if (SCREENS[self.screen_index] == .level) {
            self.field.deserialize(SCREENS[self.screen_index].level);
        }
    }

    pub fn updateField(self: *Self) void {
        if (self.haathi.inputs.getKey(.r).is_clicked) {
            self.field.reset();
        }
        self.field.update(self.haathi.inputs, self.arena, self.ticks);
        // if (self.haathi.inputs.getKey(.d).is_clicked) {
        //     if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.addMove(self.ticks, .{ .x = 1 }, true);
        //     self.field.players.items[0].addMove(self.ticks, .{ .x = 1 }, true);
        //     self.field.resolveEffects();
        // }
        // if (self.haathi.inputs.getKey(.a).is_clicked) {
        //     if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.addMove(self.ticks, .{ .x = -1 }, true);
        //     self.field.players.items[0].addMove(self.ticks, .{ .x = -1 }, true);
        //     self.field.resolveEffects();
        // }
        // if (self.haathi.inputs.getKey(.w).is_clicked) {
        //     if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.addMove(self.ticks, .{ .y = 1 }, true);
        //     self.field.players.items[0].addMove(self.ticks, .{ .y = 1 }, true);
        //     self.field.resolveEffects();
        // }
        // if (self.haathi.inputs.getKey(.s).is_clicked) {
        //     if (self.field.players.items[0].address.equal(self.field.ball.address)) self.field.ball.addMove(self.ticks, .{ .y = -1 }, true);
        //     self.field.players.items[0].addMove(self.ticks, .{ .y = -1 }, true);
        //     self.field.resolveEffects();
        // }
        // if (self.haathi.inputs.getKey(.space).is_clicked) {
        //     self.field.serialize();
        // }
    }

    pub fn render(self: *Self) void {
        if (DEBUG_1) c.debugPrint("render 0");
        self.haathi.setCursor(.auto);
        const mouse_pos = self.haathi.inputs.mouse.current_pos;
        if (mouse_pos.x < SCREEN_SIZE.x and mouse_pos.y < SCREEN_SIZE.y) self.haathi.setCursor(.none);
        if (DEBUG_1) c.debugPrint("render 1");
        for (self.bg.items) |sprite| {
            self.haathi.drawSprite(.{
                .position = sprite.position,
                .sprite = sprite.sprite,
            });
        }
        if (DEBUG_1) c.debugPrint("render 2");
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = Vec4.fromHexRgba("#47ABA9A8"),
        });
        switch (self.mode) {
            .menu => self.renderMenu(),
            .game => self.renderGame(),
        }
        self.haathi.drawSprite(.{
            .position = self.haathi.inputs.mouse.current_pos.add(POINTER_OFFSET),
            .sprite = sprites.POINTER,
        });
        self.endFrame();
    }

    fn renderMenu(self: *Self) void {
        self.haathi.drawText(.{
            .text = "the legend of the",
            .position = .{ .x = SCREEN_SIZE.x * 0.5, .y = SCREEN_SIZE.y * 0.21 },
            .color = Vec4.fromHexRgb("#161C2E"),
        });
        self.haathi.drawText(.{
            .text = "Golden Goal",
            .position = .{ .x = SCREEN_SIZE.x * 0.5, .y = SCREEN_SIZE.y * 0.3 },
            .color = Vec4.fromHexRgb("#161C2E"),
            .style = FONT_3,
        });
        self.haathi.drawText(.{
            .text = "click to start",
            .position = .{ .x = SCREEN_SIZE.x * 0.5, .y = SCREEN_SIZE.y * 0.8 },
            .color = Vec4.fromHexRgb("#161C2E"),
        });
    }

    fn renderGame(self: *Self) void {
        switch (SCREENS[self.screen_index]) {
            .level => self.renderField(),
            .dialogue => |data| {
                for (data.lines, 0..) |line, i| {
                    const fi: f32 = @floatFromInt(i);
                    const pos = Vec2{ .x = SCREEN_SIZE.x / 2, .y = 120 + (fi * 28) };
                    self.haathi.drawText(.{
                        .text = line,
                        .position = pos,
                        .color = Vec4.fromHexRgb("#161C2E"),
                    });
                }
            },
        }
    }

    fn renderField(self: *Self) void {
        if (DEBUG_1) c.debugPrint("render 3");
        for (self.field.pane.items) |sprite| {
            self.haathi.drawSprite(.{
                .position = sprite.position,
                .sprite = sprite.sprite,
            });
        }
        self.haathi.drawText(.{
            .text = "R: Restart",
            .position = .{ .x = (PANE_X_PADDING * 0.8) + (TOKEN_PANE_WIDTH / 2), .y = SCREEN_SIZE.y * 0.83 },
            .color = Vec4.fromHexRgb("#161C2E"),
        });
        if (DEBUG_1) c.debugPrint("render 4");
        if (true) {
            for (self.field.bg_sprites.items) |sprite| {
                self.haathi.drawSprite(.{
                    .position = sprite.position,
                    .sprite = sprite.sprite,
                });
            }
        }
        if (DEBUG_1) c.debugPrint("render 5");
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
        if (self.field.valid_drop) |pos1| {
            if (self.field.state == .card_drag) {
                const data = self.field.state.card_drag;
                const card = self.field.cards.items[data.card_index];
                const pos2 = pos1.add(card.direction.direction.scale(@intCast(card.direction.magnitude)));
                var points = self.arena.alloc(Vec2, 2) catch unreachable;
                points[0] = self.field.getPosOf(pos1).add(CELL_SIZE.scale(0.5));
                points[1] = self.field.getPosOf(pos2).add(CELL_SIZE.scale(0.5));
                self.haathi.drawPath(.{
                    .points = points,
                    .color = Vec4.fromHexRgba("#EFE1ABCC"),
                    .width = 12,
                });
            }
        }
        if (DEBUG_1) c.debugPrint("render 6");
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
        if (DEBUG_1) c.debugPrint("render 7");
        if (DEBUG_1) c.debugPrint("render 8");
        if (true) {
            for (self.field.players.items) |player| {
                self.haathi.drawSprite(.{
                    .position = player.position.add(PLAYER_SPRITE_OFFSET),
                    .sprite = player.sprite,
                });
            }
        }
        if (DEBUG_1) c.debugPrint("render 9");
        if (true) {
            self.haathi.drawSprite(.{
                .position = self.field.ball.position,
                .sprite = self.field.ball.sprite,
            });
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
                self.haathi.drawSprite(.{
                    .position = card.rect.position.add(.{ .x = 84, .y = 12 }).add(card.sprites[3].position),
                    .sprite = card.arrow_sprite,
                });

                self.haathi.drawText(.{
                    .text = card.text,
                    .position = card.rect.position.add(card.rect.size.scale(0.5)).add(card.sprites[3].position).add(.{ .x = 44 }),
                    .color = Vec4.fromHexRgba("#EFE1ABFF"),
                });
            }
        }
        if (self.field.state == .card_drag) {
            const card_index = self.field.state.card_drag.card_index;
            const card = self.field.cards.items[card_index];
            self.haathi.drawSprite(.{
                .position = card.rect.position.add(CARD_POINTER_OFFSET),
                .sprite = sprites.POINTER_RED,
            });
        }
        if (DEBUG_1) c.debugPrint("render 10");
        if (self.field.failed) {
            self.haathi.drawText(.{
                .text = "Level Failed",
                .position = .{ .x = SCREEN_SIZE.x * 0.7, .y = SCREEN_SIZE.y * 0.9 },
                .color = Vec4.fromHexRgb("#161C2E"),
            });
        }
        if (DEBUG_1) c.debugPrint("render 11");
        if (DEBUG_1) c.debugPrint("render 12");
    }
};
