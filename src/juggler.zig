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

const NUM_BALL_PATH_POINTS = 64;
const GRAVITY = 2;
const JUGGLER_CENTER = SCREEN_SIZE.scale(0.5);
const HAND_SIZE = Vec2{ .x = 25, .y = 10 };
const MAX_DT = @as(u64, 1000 / 30);
/// How many ticks pass between each point in the ball path
const PATH_TICK_RATE = 30;
const HAND_MOVE_DURATION_TICKS = 300;
const CATCH_RADIUS_SQR = 12 * 12;

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

const Ball = struct {
    const Self = @This();
    position: Vec2,
    path: ?BallPath,

    pub fn update(self: *Self, dt: u64) void {
        if (self.path) |*path| {
            path.progress_ticks += dt;
            self.position = path.getPosition();
        }
    }
};

const InstructionType = enum {
    catch_, // TODO (24 Jul 2023 sam): maybe catching should be automatic.
    throw_,
    move_,
    // wait_,
};

/// in means towards the body, out means away from the body.
const ThrowDirection = enum {
    /// straight up
    up,
    in_0,
    in_1,
    in_2,
    /// straight across
    in_3,
    out_0,
    out_1,
    out_2,
    out_3,
};

const ThrowPower = enum {
    pow_1,
    pow_2,
    pow_3,
    pow_4,
    pow_5,
};

const ThrowParams = struct {
    const Self = @This();
    direction: ThrowDirection,
    power: ThrowPower,

    pub fn vector(self: *const Self, side: HandSide) Vec2 {
        const dir: f32 = if (side == .left) -1 else 1;
        _ = self;
        return .{ .x = dir * 7, .y = -20 };
    }
};

// TODO (24 Jul 2023 sam): add vertical positions as well?
const HandPos = enum {
    const Self = @This();
    out, // reverse cascade throw?
    neutral, // cascade catch
    in, // cascade throw
    middle, // columns middle
    across, // mills mess etc

    pub fn position(self: *const Self, side: HandSide) Vec2 {
        const dir: f32 = if (side == .right) -1 else 1;
        return switch (self.*) {
            .out => JUGGLER_CENTER.add(.{ .x = dir * 150 }),
            .neutral => JUGGLER_CENTER.add(.{ .x = dir * 100 }),
            .in => JUGGLER_CENTER.add(.{ .x = dir * 50 }),
            .middle => JUGGLER_CENTER.add(.{}),
            .across => JUGGLER_CENTER.add(.{ .x = dir * -50 }),
        };
    }
};

const MoveParams = struct {
    end_pos: HandPos,
    speed: f32 = 1,
};

const Instruction = union(InstructionType) {
    catch_: void,
    throw_: ThrowParams,
    move_: MoveParams,
};

const HandSide = enum {
    left,
    right,
};

const HandState = union(enum) {
    waiting: void,
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
    state: HandState = .waiting,
    position: Vec2,
    start_position: Vec2 = .{},
    holding: ?usize = null,
    ticks: u64 = 0,

    pub fn init(side: HandSide, allocator: std.mem.Allocator) Self {
        const pos = switch (side) {
            .right => HandPos.in.position(side),
            .left => HandPos.in.position(side),
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
            .waiting => {
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
        switch (instruction) {
            .move_ => |move| {
                self.state = .{ .moving = .{
                    .move_start_ticks = self.ticks,
                    .start_position = self.position,
                    .target_position = move.end_pos.position(self.side),
                } };
            },
            .catch_ => {
                self.state = .waiting;
            },
            .throw_ => |throw| {
                self.state = .{ .throwing = throw };
            },
        }
    }

    fn setupCascadeInstructions(self: *Self) void {
        self.instructions.append(.{
            .move_ = .{
                .end_pos = .in,
            },
        }) catch unreachable;
        self.instructions.append(.{
            .throw_ = .{
                .direction = .in_1,
                .power = .pow_3,
            },
        }) catch unreachable;
        self.instructions.append(.{
            .move_ = .{
                .end_pos = .neutral,
            },
        }) catch unreachable;
        self.instructions.append(.catch_) catch unreachable;
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
            .power = .pow_3,
            .direction = .in_1,
        };
        // ball 0 is midair, thrown by left
        self.balls.append(.{ .position = .{}, .path = BallPath.init(
            HandPos.in.position(.left),
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
            .start_position = HandPos.neutral.position(.left),
            .target_position = HandPos.in.position(.left),
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

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    juggler: Juggler,
    path: BallPath = undefined,
    paused: bool = false,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .juggler = Juggler.init(allocator, arena_handle.allocator()),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn setup(self: *Self) void {
        const throw = ThrowParams{
            .power = .pow_3,
            .direction = .in_1,
        };
        self.path = BallPath.init(self.juggler.hands[0].position, throw, .left);
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
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.solarized_base3,
        });
        for (self.juggler.hands) |hand| {
            self.haathi.drawRect(.{
                .position = hand.position,
                .size = HAND_SIZE,
                .color = colors.solarized_base1,
                .centered = true,
            });
            self.haathi.drawText(.{
                .text = @tagName(hand.state),
                .position = hand.position.add(.{ .y = 8 }),
                .color = colors.solarized_base03,
            });
        }
        // self.haathi.drawPath(.{
        //     .points = self.path.points[0..],
        //     .color = colors.solarized_orange,
        //     .width = 1,
        // });
        for (self.juggler.balls.items) |ball| {
            self.haathi.drawRect(.{
                .position = ball.position,
                .size = .{ .x = 20, .y = 20 },
                .color = colors.solarized_blue,
                .centered = true,
                .radius = 10,
            });
        }
    }
};
