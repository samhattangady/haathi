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

const NUM_BALL_PATH_POINTS = 64;
const GRAVITY = 2;
const JUGGLER_CENTER = SCREEN_SIZE.scale(0.5).add(.{ .x = -PANE_WIDTH / 2, .y = 100 });
const HAND_SIZE = Vec2{ .x = 25, .y = 10 };
const MAX_DT = @as(u64, 1000 / 30);
/// How many ticks pass between each point in the ball path
const PATH_TICK_RATE = 30;
const HAND_MOVE_DURATION_TICKS = 270;
const CATCH_RADIUS_SQR = 12 * 12;
const TRAIL_SIZE = 24;
const TRAIL_WIDTH = 10;
const NUM_SLOTS_IN_TRACK = 64;
const TRACK_BUTTONS_LEFT_WIDTH = 60;
const TRACK_PADDING = 10;
const TRACK_HEIGHT = 48;
const TRACK_WIDTH = SCREEN_SIZE.x - TRACK_BUTTONS_LEFT_WIDTH - (3 * TRACK_PADDING);
const SLOT_PADDING = 3;
const SLOT_WIDTH = (TRACK_WIDTH - (SLOT_PADDING * (NUM_SLOTS_IN_TRACK + 1))) / NUM_SLOTS_IN_TRACK;
const PANE_BUTTON_SIZE = Vec2{ .x = 100, .y = 30 };
const PANE_BUTTON_X = SCREEN_SIZE.x - (PANE_BUTTON_SIZE.x * 3) - (TRACK_PADDING * 3);
const PANE_BUTTON_Y = TRACK_PADDING;
const PANE_WIDTH = (PANE_BUTTON_SIZE.x * 3) + (TRACK_PADDING * 2);
const PANE_X = PANE_BUTTON_X;
const PANE_Y = PANE_BUTTON_SIZE.y + (TRACK_PADDING * 2);
const PANE_HEIGHT = TRACK_1_Y - TRACK_PADDING - PANE_Y;
const TRACK_1_Y = SCREEN_SIZE.y - TRACK_PADDING - TRACK_HEIGHT - TRACK_PADDING - TRACK_HEIGHT;
const DEFAULT_BLOCK_WIDTH_COUNT = 7;
const DEFAULT_BLOCK_WIDTH = (DEFAULT_BLOCK_WIDTH_COUNT * SLOT_WIDTH) + ((DEFAULT_BLOCK_WIDTH_COUNT - 1) * SLOT_PADDING);
const HAND_SLOT_OFFSET_AMOUNT = 50;
const HEIGHT_OFFSET = 50;
const BLOCK_BUTTON_SIZE = Vec2{ .x = 140, .y = 48 };

const BallPath = struct {
    const Self = @This();
    /// points are equidistant by time.
    points: [NUM_BALL_PATH_POINTS]Vec2,
    /// what fraction of the path has been travelled
    progress_ticks: u64 = 0,

    pub fn init(start_pos: Vec2, throw: ThrowParams, side: HandSide) Self {
        var self: Self = .{ .points = undefined };
        var i: usize = 0;
        var pos = start_pos;
        var dir = throw.vector(side);
        while (i < NUM_BALL_PATH_POINTS) : (i += 1) {
            self.points[i] = pos;
            pos = pos.add(dir);
            dir = dir.add(.{ .y = GRAVITY });
        }
        return self;
    }

    pub fn getPosition(self: *const Self) Vec2 {
        const progress = PATH_TICK_RATE / self.progress_ticks;
        if (progress > NUM_BALL_PATH_POINTS) {
            return self.points[NUM_BALL_PATH_POINTS - 1];
        }
        const ticks = @floatFromInt(f32, self.progress_ticks);
        const index = ticks / PATH_TICK_RATE;
        const prev_index = @intFromFloat(usize, @round(index - 0.5));
        if (prev_index > NUM_BALL_PATH_POINTS - 2) return self.points[NUM_BALL_PATH_POINTS - 1];
        const prev = self.points[prev_index];
        const next = self.points[prev_index + 1];
        const amount = index - @floatFromInt(f32, prev_index);
        std.debug.assert(amount <= 1);
        return prev.lerp(next, amount);
    }
};

const TrailLine = struct {
    points: [2]Vec2,
    width: f32,
};

const Trail = struct {
    const Self = @This();
    points: [TRAIL_SIZE]Vec2 = [_]Vec2{JUGGLER_CENTER} ** TRAIL_SIZE,
    start_index: u8 = 0,

    pub fn init(pos: Vec2) Self {
        return Self{ .points = [_]Vec2{pos} ** TRAIL_SIZE };
    }

    pub fn addPos(self: *Self, pos: Vec2) void {
        self.points[self.start_index] = pos;
        self.start_index = helpers.applyChangeLooped(self.start_index, 1, TRAIL_SIZE - 1);
    }

    pub fn trail(self: *const Self, arena: std.mem.Allocator) []TrailLine {
        const lines = arena.alloc(TrailLine, TRAIL_SIZE - 1) catch unreachable;
        var i: isize = 0;
        while (i < TRAIL_SIZE - 1) : (i += 1) {
            const p0 = @mod(@intCast(isize, self.start_index) - i, TRAIL_SIZE);
            const p1 = @mod(@intCast(isize, self.start_index) - i - 1, TRAIL_SIZE);
            const width = helpers.lerpf(TRAIL_WIDTH, 0, @floatFromInt(f32, i) / TRAIL_SIZE);
            const index = @intCast(usize, i);
            lines[index] = .{
                .points = [2]Vec2{ self.points[@intCast(usize, p0)], self.points[@intCast(usize, p1)] },
                .width = width,
            };
        }
        return lines;
    }
};

const Ball = struct {
    const Self = @This();
    position: Vec2,
    path: ?BallPath,
    trail: Trail = .{},

    pub fn update(self: *Self, dt: u64) void {
        if (self.path) |*path| {
            path.progress_ticks += dt;
            self.position = path.getPosition();
        }
        self.trail.addPos(self.position);
    }
};

const InstructionType = enum {
    const Self = @This();
    ready, // catch
    throw,
    move,
    // wait_,
    //
    pub fn text(self: *Self) []const u8 {
        return switch (self.*) {
            .ready => "catch",
            .throw => "throw",
            .move => "move",
        };
    }

    pub fn color(self: *const Self) Vec4 {
        return switch (self.*) {
            .ready => colors.endesga_orange0.lerp(colors.endesga_grey0, 0.4),
            .throw => colors.endesga_green0.lerp(colors.endesga_grey0, 0.4),
            .move => colors.endesga_pink0.lerp(colors.endesga_grey0, 0.2),
        };
    }
    pub fn textColor(self: *const Self) Vec4 {
        return switch (self.*) {
            .ready => colors.endesga_tan3,
            .throw => colors.endesga_green2,
            .move => colors.endesga_red2,
        };
    }
};

/// in means towards the body, out means away from the body.
const ThrowTarget = enum {
    in_5,
    in_4,
    in_3,
    in_2,
    in_1,
    up,
    out_1,
    out_2,
    pub fn powerf(self: *const ThrowTarget) f32 {
        return switch (self.*) {
            .in_5 => 5,
            .in_4 => 4,
            .in_3 => 3,
            .in_2 => 2,
            .in_1 => 1,
            .up => 0,
            .out_1 => -1,
            .out_2 => -2,
        };
    }
};
const NUM_THROW_TARGETS = @typeInfo(ThrowTarget).Enum.fields.len;

const ThrowHeight = enum {
    height_1,
    height_2,
    height_3,
    height_4,
    height_5,

    pub fn power(self: *const ThrowHeight) u8 {
        return switch (self.*) {
            .height_1 => 1,
            .height_2 => 2,
            .height_3 => 3,
            .height_4 => 4,
            .height_5 => 5,
        };
    }
};

const ThrowParams = struct {
    const Self = @This();
    target: ThrowTarget,
    height: ThrowHeight,

    pub fn vector(self: *const Self, side: HandSide) Vec2 {
        // projectile motion. we have y (vertical comp of velocity) from height
        // y = sqrt(2*H*g)
        // x = (R*g) / y
        const dir: f32 = if (side == .left) -1 else 1;
        const max_height = @floatFromInt(f32, self.height.power()) * HEIGHT_OFFSET;
        const range = self.target.powerf() * HAND_SLOT_OFFSET_AMOUNT;
        const y = @sqrt(2 * max_height * GRAVITY) * -1;
        const x = (range * GRAVITY) / (2 * @fabs(y));
        return .{ .x = dir * x, .y = y };
    }

    pub fn text(self: *const Self, arena: std.mem.Allocator) []const u8 {
        return std.fmt.allocPrintZ(arena, "{s} h{d}", .{
            @tagName(self.target),
            self.height.power(),
        }) catch unreachable;
    }
};

// TODO (24 Jul 2023 sam): add vertical positions as well?
const HandPos = enum {
    const Self = @This();
    left_out, // reverse cascade throw?
    left_neutral, // cascade catch
    left_in, // cascade throw
    middle, // columns middle
    right_in, // cascade throw
    right_neutral, // cascade catch
    right_out, // reverse cascade throw?

    pub fn position(self: *const Self) Vec2 {
        return switch (self.*) {
            .left_out => JUGGLER_CENTER.add(.{ .x = 3 * HAND_SLOT_OFFSET_AMOUNT }),
            .left_neutral => JUGGLER_CENTER.add(.{ .x = 2 * HAND_SLOT_OFFSET_AMOUNT }),
            .left_in => JUGGLER_CENTER.add(.{ .x = 1 * HAND_SLOT_OFFSET_AMOUNT }),
            .middle => JUGGLER_CENTER.add(.{}),
            .right_out => JUGGLER_CENTER.add(.{ .x = -3 * HAND_SLOT_OFFSET_AMOUNT }),
            .right_neutral => JUGGLER_CENTER.add(.{ .x = -2 * HAND_SLOT_OFFSET_AMOUNT }),
            .right_in => JUGGLER_CENTER.add(.{ .x = -1 * HAND_SLOT_OFFSET_AMOUNT }),
        };
    }
};

const MoveParams = struct {
    move: Movement,
    speed: f32 = 1,
};

const InstructionParams = union(InstructionType) {
    ready: void,
    throw: ThrowParams,
    move: MoveParams,
};

const Instruction = struct {
    const Self = @This();
    instruction: InstructionParams,
    length: u16 = 20,

    pub fn text(self: *const Self, arena: std.mem.Allocator) []const u8 {
        _ = arena;
        switch (self.instruction) {
            .move => |_| {
                return "move";
            },
            .throw => |_| {
                return "throw";
            },
            .ready => return "catch",
        }
    }

    pub fn text2(self: *const Self, arena: std.mem.Allocator) []const u8 {
        switch (self.instruction) {
            .move => |params| {
                return params.move.text();
            },
            .throw => |params| {
                return params.text(arena);
            },
            .ready => return "",
        }
    }
};

const Block = struct {
    const Self = @This();
    instruction: Instruction,
    start_index: u8 = 0,
    width: u8 = 0,

    pub fn color(self: *const Self) Vec4 {
        const inst_type: InstructionType = self.instruction.instruction;
        return inst_type.color();
    }
    pub fn textColor(self: *const Self) Vec4 {
        const inst_type: InstructionType = self.instruction.instruction;
        return inst_type.textColor();
    }
};

const Track = struct {
    const Self = @This();
    rect: Rect,
    slots: std.ArrayList(Rect),
    blocks: std.ArrayList(Block),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .rect = undefined,
            .slots = std.ArrayList(Rect).init(allocator),
            .blocks = std.ArrayList(Block).init(allocator),
        };
        return self;
    }

    pub fn initSlots(self: *Self) void {
        for (0..NUM_SLOTS_IN_TRACK) |i| {
            const fi = @floatFromInt(f32, i);
            self.slots.append(.{
                .position = .{
                    .x = self.rect.position.x + ((fi + 1) * SLOT_PADDING) + (fi * SLOT_WIDTH),
                    .y = self.rect.position.y + SLOT_PADDING,
                },
                .size = .{ .x = SLOT_WIDTH, .y = self.rect.size.y - (SLOT_PADDING * 2) },
            }) catch unreachable;
        }
    }

    pub fn addBlock(self: *Self, instruction: Instruction, slot_index: u8) void {
        // TODO (25 Jul 2023 sam): Check that there is no overlaps.
        const block = Block{
            .instruction = instruction,
            .start_index = slot_index,
            .width = DEFAULT_BLOCK_WIDTH_COUNT,
        };
        self.blocks.append(block) catch unreachable;
    }

    pub fn deleteBlock(self: *Self, index: usize) void {
        if (index > self.blocks.items.len - 1) {
            helpers.debugPrint("trying to delete index {d} when there are only {d} blocks", .{ index, self.blocks.items.len });
            return;
        }
        _ = self.blocks.orderedRemove(index);
    }

    fn slotOccupied(self: *const Self, index: usize) bool {
        for (self.blocks.items) |block| {
            if (index >= block.start_index and index < block.start_index + block.width) return true;
        }
        return false;
    }

    pub fn getSlot(self: *const Self, pos: Vec2) struct {
        not_allowed: bool,
        index: ?usize,
    } {
        var na = false;
        var index: ?usize = null;
        for (self.slots.items, 0..) |slot, i| {
            if (slot.contains(pos)) {
                index = i;
                break;
            }
        }
        if (index) |i| {
            if (self.slotOccupied(i)) {
                na = true;
                index = null;
            }
            return .{ .not_allowed = na, .index = index };
        } else {
            return .{ .not_allowed = false, .index = null };
        }
    }
};

const Program = struct {
    const Self = @This();
    tracks: [2]Track,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .tracks = [2]Track{ Track.init(allocator), Track.init(allocator) },
            .allocator = allocator,
        };
        self.setup();
        return self;
    }

    fn setup(self: *Self) void {
        self.tracks[0].rect = .{
            .position = .{ .x = (TRACK_PADDING * 2) + TRACK_BUTTONS_LEFT_WIDTH, .y = TRACK_1_Y },
            .size = .{ .x = TRACK_WIDTH, .y = TRACK_HEIGHT },
        };
        self.tracks[1].rect = .{
            .position = .{ .x = (TRACK_PADDING * 2) + TRACK_BUTTONS_LEFT_WIDTH, .y = SCREEN_SIZE.y - TRACK_PADDING - TRACK_HEIGHT },
            .size = .{ .x = TRACK_WIDTH, .y = TRACK_HEIGHT },
        };
        self.tracks[0].initSlots();
        self.tracks[1].initSlots();
    }

    pub fn addBlock(self: *Self, instruction: Instruction, track_index: u8, slot_index: u8) void {
        self.tracks[track_index].addBlock(instruction, slot_index);
    }
};

const HandSide = enum {
    left,
    right,
};

const HandState = union(enum) {
    ready: void,
    moving: struct {
        move_start_ticks: u64,
        start_position: Vec2,
        target_position: Vec2,
    },
    throwing: ThrowParams,
};

const Hand = struct {
    const Self = @This();
    side: HandSide,
    instructions: std.ArrayList(Instruction),
    inst_index: u8 = 0,
    state: HandState = .ready,
    position: Vec2,
    start_position: Vec2 = .{},
    holding: ?usize = null,
    ticks: u64 = 0,

    pub fn init(side: HandSide, allocator: std.mem.Allocator) Self {
        const pos = switch (side) {
            .right => HandPos.right_in.position(),
            .left => HandPos.left_in.position(),
        };
        var self = Self{
            .side = side,
            .instructions = std.ArrayList(Instruction).init(allocator),
            .position = pos,
        };
        self.setupCascadeInstructions();
        return self;
    }

    pub fn update(self: *Self, dt: u64, juggler: *Juggler) void {
        self.ticks += dt;
        switch (self.state) {
            .ready => {
                for (juggler.balls.items, 0..) |*ball, i| {
                    if (ball.path) |path| {
                        if (path.progress_ticks < PATH_TICK_RATE) continue;
                        if (self.position.distanceSqr(ball.position) < CATCH_RADIUS_SQR) {
                            ball.path = null;
                            self.holding = i;
                            self.incInstIndex();
                            return;
                        }
                    }
                }
            },
            .moving => |move| {
                const progress = @floatFromInt(f32, self.ticks - move.move_start_ticks) / HAND_MOVE_DURATION_TICKS;
                if (progress >= 1) {
                    self.position = move.target_position;
                    self.incInstIndex();
                    return;
                }
                self.position = move.start_position.lerp(move.target_position, progress);
                if (self.holding) |ball_index| juggler.balls.items[ball_index].position = self.position;
            },
            .throwing => |throw| {
                if (self.holding) |ball_index| {
                    juggler.balls.items[ball_index].path = BallPath.init(self.position, throw, self.side);
                    self.holding = null;
                    self.incInstIndex();
                    return;
                } else {
                    c.debugPrint("trying to throw ball that is not being held...");
                }
            },
        }
    }

    fn incInstIndex(self: *Self) void {
        self.inst_index = helpers.applyChangeLooped(self.inst_index, 1, @intCast(u8, self.instructions.items.len - 1));
        const instruction = self.instructions.items[self.inst_index];
        switch (instruction.instruction) {
            .move => |move| {
                self.state = .{ .moving = .{
                    .move_start_ticks = self.ticks,
                    .start_position = self.position,
                    .target_position = self.position.add(move.move.offset(self.side)),
                } };
            },
            .ready => {
                self.state = .ready;
            },
            .throw => |throw| {
                self.state = .{ .throwing = throw };
            },
        }
    }

    fn setupCascadeInstructions(self: *Self) void {
        self.instructions.append(.{ .instruction = .{
            .move = .{
                .move = .in_1,
            },
        } }) catch unreachable;
        self.instructions.append(.{ .instruction = .{
            .throw = .{
                .target = .in_3,
                .height = .height_5,
            },
        } }) catch unreachable;
        self.instructions.append(.{ .instruction = .{
            .move = .{
                .move = .out_1,
            },
        } }) catch unreachable;
        self.instructions.append(.{ .instruction = .ready }) catch unreachable;
    }
};

const Juggler = struct {
    const Self = @This();
    hands: [2]Hand,
    balls: std.ArrayList(Ball),
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,
    ticks: u64 = 0,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .hands = [_]Hand{ Hand.init(.left, allocator), Hand.init(.right, allocator) },
            .balls = std.ArrayList(Ball).init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    fn setup(self: *Self) void {
        const throw = ThrowParams{
            .height = .height_2,
            .target = .in_3,
        };
        // ball 0 is midair, thrown by left
        self.balls.append(.{ .position = .{}, .path = BallPath.init(
            HandPos.left_in.position(),
            throw,
            .left,
        ) }) catch unreachable;
        self.balls.items[0].path.?.progress_ticks = 300;
        // ball 1 is being held by right, about to be thrown
        self.balls.append(.{ .position = .{}, .path = null }) catch unreachable;
        // ball 2 is being held by left, just caught
        self.balls.append(.{ .position = .{}, .path = null }) catch unreachable;
        self.hands[1].state = .{ .throwing = throw };
        self.hands[1].inst_index = 1;
        self.hands[1].holding = 1;
        self.hands[0].state = .{ .moving = .{
            .move_start_ticks = 0,
            .start_position = HandPos.left_neutral.position(),
            .target_position = HandPos.left_in.position(),
        } };
        self.hands[0].inst_index = 0;
        self.hands[0].holding = 2;
    }

    fn update(self: *Self, dt: u64) void {
        self.ticks += dt;
        for (self.balls.items) |*ball| ball.update(dt);
        for (self.hands[0..]) |*hand| hand.update(dt, self);
    }
};

const Pane = enum {
    code,
    setup,
    howto,
};

const CodeButton = enum {
    move_in,
    move_out,
    throw_in,
    throw_out,
    throw_high,
    throw_low,
};

const Movement = enum {
    in_4,
    in_3,
    in_2,
    in_1,
    out_1,
    out_2,
    out_3,
    out_4,

    pub fn text(self: *const Movement) []const u8 {
        return switch (self.*) {
            .in_4 => "in_4",
            .in_2 => "in_2",
            .in_3 => "in_3",
            .in_1 => "in_1",
            .out_1 => "out_1",
            .out_2 => "out_2",
            .out_3 => "out_3",
            .out_4 => "out_4",
        };
    }

    pub fn num_slots(self: *const Movement) u8 {
        return switch (self.*) {
            .in_4, .out_4 => 4,
            .in_3, .out_3 => 3,
            .in_2, .out_2 => 2,
            .in_1, .out_1 => 1,
        };
    }

    pub fn in(self: *const Movement) bool {
        return switch (self.*) {
            .in_4,
            .in_3,
            .in_2,
            .in_1,
            => true,
            .out_1,
            .out_2,
            .out_3,
            .out_4,
            => false,
        };
    }

    pub fn offset(self: *const Movement, side: HandSide) Vec2 {
        const hand: f32 = if (side == .left) -1 else 1;
        const dir: f32 = if (self.in()) 1 else -1;
        const amount = @floatFromInt(f32, self.num_slots());
        return .{ .x = dir * hand * amount * HAND_SLOT_OFFSET_AMOUNT };
    }
};

const StateData = union(enum) {
    idle: struct {
        block_button_index: ?usize = null,
    },
    idle_drag: void,
    block_drag: struct {
        instruction: Instruction,
        hovered_track: ?u8 = null,
        hovered_slot: ?u8 = null,
    },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    pane_buttons: std.ArrayList(Button),
    code_buttons: std.ArrayList(Button),
    block_buttons: std.ArrayList(Button),
    code_text: std.ArrayList(TextLine),
    state: StateData = .{ .idle = .{} },
    juggler: Juggler,
    program: Program,
    paths: [NUM_THROW_TARGETS]BallPath = undefined,
    paused: bool = false,
    cursor: CursorStyle = .default,
    block: ?Block = null,
    active_pane: Pane = .code,
    hand_positions: [7]Vec2 = undefined,
    movement_amount: Movement = .in_1,
    throw_params: ThrowParams = .{ .height = .height_3, .target = .in_3 },

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .juggler = Juggler.init(allocator, arena_handle.allocator()),
            .program = Program.init(allocator),
            .pane_buttons = std.ArrayList(Button).init(allocator),
            .code_buttons = std.ArrayList(Button).init(allocator),
            .block_buttons = std.ArrayList(Button).init(allocator),
            .code_text = std.ArrayList(TextLine).init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.pane_buttons.deinit();
        self.code_buttons.deinit();
        self.block_buttons.deinit();
        self.code_text.deinit();
    }

    pub fn setup(self: *Self) void {
        for (0..NUM_THROW_TARGETS) |i| {
            const target = @enumFromInt(ThrowTarget, i);
            const throw = ThrowParams{
                .height = .height_5,
                .target = target,
            };
            self.paths[i] = BallPath.init(JUGGLER_CENTER, throw, .left);
        }
        for (0..@typeInfo(InstructionType).Enum.fields.len) |i| {
            const pane = @enumFromInt(Pane, i);
            const fi = @floatFromInt(f32, i);
            self.pane_buttons.append(.{
                .rect = .{
                    .position = .{
                        .x = PANE_BUTTON_X + (fi * (PANE_BUTTON_SIZE.x + TRACK_PADDING)),
                        .y = PANE_BUTTON_Y,
                    },
                    .size = PANE_BUTTON_SIZE,
                },
                .value = @intCast(u8, @intFromEnum(pane)),
                .text = @tagName(pane),
            }) catch unreachable;
        }
        self.hand_positions[0] = HandPos.left_out.position();
        self.hand_positions[1] = HandPos.left_neutral.position();
        self.hand_positions[2] = HandPos.left_in.position();
        self.hand_positions[3] = HandPos.middle.position();
        self.hand_positions[4] = HandPos.right_in.position();
        self.hand_positions[5] = HandPos.right_neutral.position();
        self.hand_positions[6] = HandPos.right_out.position();
        {
            const center_pane_x = PANE_X + (PANE_WIDTH / 2);
            var y: f32 = PANE_Y + (TRACK_PADDING * 3);
            self.code_text.append(.{ .text = "move hand", .position = .{ .x = center_pane_x, .y = y } }) catch unreachable;
            y += 20;
            const code_button_size = Vec2{ .x = 30, .y = 48 };
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - 100 - code_button_size.x, .y = y },
                    .size = code_button_size,
                },
                .text = "<",
                .value = @intCast(u8, @intFromEnum(CodeButton.move_in)),
            }) catch unreachable;
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x + 100, .y = y },
                    .size = code_button_size,
                },
                .text = ">",
                .value = @intCast(u8, @intFromEnum(CodeButton.move_out)),
            }) catch unreachable;
            self.block_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - (BLOCK_BUTTON_SIZE.x / 2), .y = y },
                    .size = BLOCK_BUTTON_SIZE,
                },
                .value = @intCast(u8, @intFromEnum(InstructionType.move)),
                .text = "move",
            }) catch unreachable;
            y += 80;
            self.code_text.append(.{ .text = "throw ball", .position = .{ .x = center_pane_x, .y = y } }) catch unreachable;
            y += 20;
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - 100 - code_button_size.x, .y = y },
                    .size = code_button_size.add(.{ .y = -12 }),
                },
                .text = "<",
                .value = @intCast(u8, @intFromEnum(CodeButton.throw_in)),
            }) catch unreachable;
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x + 100, .y = y },
                    .size = code_button_size.add(.{ .y = -12 }),
                },
                .text = ">",
                .value = @intCast(u8, @intFromEnum(CodeButton.throw_out)),
            }) catch unreachable;
            self.block_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - (BLOCK_BUTTON_SIZE.x / 2), .y = y },
                    .size = BLOCK_BUTTON_SIZE.add(.{ .y = 30 }),
                },
                .value = @intCast(u8, @intFromEnum(InstructionType.throw)),
                .text = "throw",
            }) catch unreachable;
            y += 42;
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - 100 - code_button_size.x, .y = y },
                    .size = code_button_size.add(.{ .y = -12 }),
                },
                .text = "v",
                .value = @intCast(u8, @intFromEnum(CodeButton.throw_low)),
            }) catch unreachable;
            self.code_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x + 100, .y = y },
                    .size = code_button_size.add(.{ .y = -12 }),
                },
                .text = "^",
                .value = @intCast(u8, @intFromEnum(CodeButton.throw_high)),
            }) catch unreachable;
            y += 80;
            self.code_text.append(.{ .text = "catch ball", .position = .{ .x = center_pane_x, .y = y } }) catch unreachable;
            y += 20;
            self.block_buttons.append(.{
                .rect = .{
                    .position = .{ .x = center_pane_x - (BLOCK_BUTTON_SIZE.x / 2), .y = y },
                    .size = BLOCK_BUTTON_SIZE,
                },
                .value = @intCast(u8, @intFromEnum(InstructionType.ready)),
                .text = "catch",
            }) catch unreachable;
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        const prev_ticks = self.ticks;
        self.ticks = ticks;
        if (self.haathi.inputs.getKey(.space).is_clicked) self.paused = !self.paused;
        if (!self.paused) {
            const dt = @min(self.ticks - prev_ticks, MAX_DT);
            self.juggler.update(dt);
        }
        for (self.pane_buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.code_buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        for (self.block_buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        self.updateMouse();
        self.updateButtonText();
    }

    fn updateButtonText(self: *Self) void {
        // block0 - move
        // self.block_buttons.items[0].text = std.fmt.allocPrintZ(self.arena, "move {s}", .{@tagName(self.movement_amount)}) catch unreachable;
        self.block_buttons.items[0].text2 = self.movement_amount.text();
        self.block_buttons.items[1].text2 = self.throw_params.text(self.arena);
    }

    fn triggerCodeButton(self: *Self, code: CodeButton) void {
        switch (code) {
            .move_in => self.movement_amount = helpers.enumChange(self.movement_amount, -1, false),
            .move_out => self.movement_amount = helpers.enumChange(self.movement_amount, 1, false),
            .throw_in => self.throw_params.target = helpers.enumChange(self.throw_params.target, -1, false),
            .throw_out => self.throw_params.target = helpers.enumChange(self.throw_params.target, 1, false),
            .throw_high => self.throw_params.height = helpers.enumChange(self.throw_params.height, 1, false),
            .throw_low => self.throw_params.height = helpers.enumChange(self.throw_params.height, -1, false),
        }
    }

    pub fn updateMouse(self: *Self) void {
        const mouse = self.haathi.inputs.mouse;
        self.cursor = .default;
        switch (self.state) {
            .idle => |data| {
                _ = data;
                var active_pane: ?u8 = null;
                var active_code: ?u8 = null;
                self.state.idle.block_button_index = null;
                for (self.pane_buttons.items) |*button| {
                    if (button.contains(mouse.current_pos)) {
                        active_pane = button.value;
                        self.cursor = .pointer;
                        break;
                    }
                }
                for (self.code_buttons.items) |*button| {
                    if (button.contains(mouse.current_pos)) {
                        active_code = button.value;
                        self.cursor = .pointer;
                        break;
                    }
                }
                for (self.block_buttons.items, 0..) |*button, i| {
                    if (button.contains(mouse.current_pos)) {
                        self.state.idle.block_button_index = i;
                        self.cursor = .grabbing;
                        break;
                    }
                }
                if (mouse.l_button.is_clicked) {
                    if (active_pane) |pane_i| {
                        const pane = @enumFromInt(Pane, pane_i);
                        self.active_pane = pane;
                        return;
                    }
                    if (active_code) |code_i| {
                        const code = @enumFromInt(CodeButton, code_i);
                        self.triggerCodeButton(code);
                        return;
                    }
                    if (self.state.idle.block_button_index) |bbi| {
                        const inst = @enumFromInt(InstructionType, self.block_buttons.items[bbi].value);
                        switch (inst) {
                            .move => {
                                const move_instruction =
                                    .{
                                    .instruction = .{
                                        .move = .{
                                            .move = self.movement_amount,
                                        },
                                    },
                                };
                                self.state = .{
                                    .block_drag = .{
                                        .instruction = move_instruction,
                                    },
                                };
                                self.block = .{ .instruction = move_instruction };
                            },
                            .throw => {
                                const throw_instruction =
                                    .{
                                    .instruction = .{
                                        .throw = self.throw_params,
                                    },
                                };
                                self.state = .{
                                    .block_drag = .{
                                        .instruction = throw_instruction,
                                    },
                                };
                                self.block = .{ .instruction = throw_instruction };
                            },
                            .ready => {
                                const catch_instruction = .{ .instruction = .ready };
                                self.state = .{
                                    .block_drag = .{
                                        .instruction = catch_instruction,
                                    },
                                };
                                self.block = .{ .instruction = catch_instruction };
                            },
                        }
                    }
                }
                if (mouse.r_button.is_clicked) {
                    // delete block from track if we are hovering.
                    delete_block: {
                        for (&self.program.tracks) |*track| {
                            for (track.blocks.items, 0..) |block, i| {
                                const widthf = @floatFromInt(f32, block.width);
                                const size = Vec2{ .x = (widthf * SLOT_WIDTH) + ((widthf - 1) * SLOT_PADDING), .y = TRACK_HEIGHT - SLOT_PADDING * 2 };
                                const pos = track.slots.items[block.start_index].position;
                                const rect = Rect{ .position = pos, .size = size };
                                if (rect.contains(mouse.current_pos)) {
                                    track.deleteBlock(i);
                                    break :delete_block;
                                }
                            }
                        }
                    }
                }
            },
            .idle_drag => {
                if (mouse.l_button.is_released) self.state = .{ .idle = .{} };
            },
            .block_drag => |data| {
                self.state.block_drag.hovered_slot = null;
                self.state.block_drag.hovered_track = null;
                for (self.program.tracks, 0..) |track, i| {
                    if (track.rect.contains(mouse.current_pos)) self.state.block_drag.hovered_track = @intCast(u8, i);
                }
                if (self.state.block_drag.hovered_track) |ti| {
                    const track = self.program.tracks[ti];
                    const slot = track.getSlot(mouse.current_pos);
                    if (slot.not_allowed) self.cursor = .no_drop;
                    if (slot.index) |si| {
                        self.state.block_drag.hovered_track = ti;
                        self.state.block_drag.hovered_slot = @intCast(u8, si);
                    }
                }
                if (mouse.l_button.is_released) {
                    if (self.state.block_drag.hovered_track) |ti| {
                        if (self.state.block_drag.hovered_slot) |si| {
                            self.program.addBlock(data.instruction, ti, si);
                        }
                    }
                    self.block = null;
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }

    // fn renderBlockText(self: *Self, rect: Rect, block: Block) void {
    // }

    pub fn render(self: *Self) void {
        self.haathi.setCursor(self.cursor);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        // all possible hand positions
        for (self.hand_positions) |pos| {
            self.haathi.drawRect(.{
                .position = pos,
                .size = HAND_SIZE,
                .color = colors.endesga_grey4.alpha(0.1),
                .centered = true,
                .radius = 3,
            });
        }
        for (self.juggler.hands) |hand| {
            self.haathi.drawRect(.{
                .position = hand.position,
                .size = HAND_SIZE,
                .color = colors.endesga_grey4,
                .centered = true,
                .radius = 3,
            });
        }
        if (false) {
            for (self.paths) |path| {
                var points = self.arena.alloc(Vec2, NUM_BALL_PATH_POINTS) catch unreachable;
                for (path.points, 0..) |pos, i| points[i] = pos;
                self.haathi.drawPath(.{
                    .points = points[0..],
                    .color = colors.solarized_orange,
                    .width = 1,
                });
            }
        }
        for (self.juggler.balls.items) |ball| {
            // for (ball.trail.trail(self.arena)) |line| {
            //     self.haathi.drawPath(.{
            //         .points = line.points[0..],
            //         .width = line.width,
            //         .color = colors.solarized_blue.alpha(0.3),
            //     });
            // }
            for (ball.trail.points) |pos| {
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = .{ .x = 6, .y = 6 },
                    .color = colors.endesga_blue1.alpha(0.1),
                    .centered = true,
                    .radius = 10,
                });
            }
            self.haathi.drawRect(.{
                .position = ball.position,
                .size = .{ .x = 20, .y = 20 },
                .color = colors.endesga_blue2,
                .centered = true,
                .radius = 10,
            });
        }
        for (self.program.tracks) |track| {
            self.haathi.drawRect(.{
                .position = track.rect.position,
                .size = track.rect.size,
                .color = colors.endesga_grey2,
            });
            for (track.slots.items) |slot| {
                self.haathi.drawRect(.{
                    .position = slot.position,
                    .size = slot.size,
                    .color = colors.endesga_grey1,
                });
            }
            for (track.blocks.items) |block| {
                const widthf = @floatFromInt(f32, block.width);
                const size = Vec2{ .x = (widthf * SLOT_WIDTH) + ((widthf - 1) * SLOT_PADDING), .y = TRACK_HEIGHT - SLOT_PADDING * 2 };
                const pos = track.slots.items[block.start_index].position;
                self.haathi.drawRect(.{
                    .position = pos,
                    .size = size,
                    .color = block.color(),
                });
                //     self.haathi.drawText(.{
                //         .position = pos.add(size.scale(0.5)).add(.{ .y = 6 }),
                //         .color = block.textColor(),
                //         .text = block.instruction.text(self.arena),
                //     });
                self.haathi.drawText(.{
                    .position = pos.add(size.scale(0.5)).add(.{ .y = -6 }),
                    .color = block.textColor(),
                    .text = block.instruction.text(self.arena),
                });
                self.haathi.drawText(.{
                    .position = pos.add(size.scale(0.5)).add(.{ .y = 18 }),
                    .color = block.textColor(),
                    .text = block.instruction.text2(self.arena),
                });
            }
        }
        for (self.pane_buttons.items) |button| {
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = colors.endesga_grey2,
                .radius = 2,
            });
            self.haathi.drawText(.{
                .position = button.rect.center().add(.{ .y = 6 }),
                .color = colors.endesga_grey0.alpha(0.8),
                .text = button.text,
            });
        }
        // draw pane
        {
            const button = self.pane_buttons.items[@intFromEnum(self.active_pane)];
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size.add(.{ .y = TRACK_PADDING + 5 }),
                .color = colors.endesga_grey4,
                .radius = 2,
            });
            self.haathi.drawText(.{
                .position = button.rect.center().add(.{ .y = 6 }),
                .color = colors.endesga_grey0.alpha(1.0),
                .text = button.text,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = PANE_X, .y = PANE_Y },
                .size = .{ .x = PANE_WIDTH, .y = PANE_HEIGHT },
                .color = colors.endesga_grey4,
                .radius = 2,
            });
        }
        if (self.active_pane == .code) {
            for (self.code_text.items) |text| {
                self.haathi.drawText(.{
                    .position = text.position.add(.{ .y = 6 }),
                    .color = colors.endesga_grey0,
                    .text = text.text,
                });
            }
            for (self.code_buttons.items) |button| {
                self.haathi.drawRect(.{
                    .position = button.rect.position,
                    .size = button.rect.size,
                    .color = colors.endesga_grey1,
                    .radius = 2,
                });
                self.haathi.drawText(.{
                    .position = button.rect.center().add(.{ .y = 6 }),
                    .color = colors.endesga_grey3,
                    .text = button.text,
                });
            }
            for (self.block_buttons.items) |button| {
                self.haathi.drawRect(.{
                    .position = button.rect.position,
                    .size = button.rect.size,
                    .color = @enumFromInt(InstructionType, button.value).color(),
                    .radius = 2,
                });
                self.haathi.drawText(.{
                    .position = button.rect.center().add(.{ .y = -6 }),
                    .color = @enumFromInt(InstructionType, button.value).textColor(),
                    .text = button.text,
                });
                self.haathi.drawText(.{
                    .position = button.rect.center().add(.{ .y = 18 }),
                    .color = @enumFromInt(InstructionType, button.value).textColor(),
                    .text = button.text2,
                });
            }
        }
        if (self.block) |block| {
            var pos = self.haathi.inputs.mouse.current_pos;
            var size = BLOCK_BUTTON_SIZE;
            var centered = true;
            var scale: f32 = 0.0;
            if (self.state == .block_drag) {
                if (self.state.block_drag.hovered_track) |ti| {
                    if (self.state.block_drag.hovered_slot) |si| {
                        pos = self.program.tracks[ti].slots.items[si].position;
                        size = Vec2{ .x = DEFAULT_BLOCK_WIDTH, .y = TRACK_HEIGHT - (2 * 3) };
                        centered = false;
                        scale = 0.5;
                    }
                }
            }
            self.haathi.drawRect(.{
                .position = pos,
                .size = size,
                .color = block.color(),
                .centered = centered,
            });
            self.haathi.drawText(.{
                .position = pos.add(size.scale(scale)).add(.{ .y = -6 }),
                .color = block.textColor(),
                .text = block.instruction.text(self.arena),
            });
            self.haathi.drawText(.{
                .position = pos.add(size.scale(scale)).add(.{ .y = 18 }),
                .color = block.textColor(),
                .text = block.instruction.text2(self.arena),
            });
        }
    }
};
