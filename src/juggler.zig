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
const JUGGLER_CENTER = SCREEN_SIZE.scale(0.5).add(.{ .x = -PANE_WIDTH / 2, .y = 100 });
const HAND_SIZE = Vec2{ .x = 25, .y = 10 };
const MAX_DT = @as(u64, 1000 / 30);
/// How many ticks pass between each point in the ball path
const PATH_TICK_RATE = 30;
const HAND_MOVE_DURATION_TICKS = 270;
const CATCH_RADIUS_SQR = 12 * 12;
const TRAIL_SIZE = 24;
const TRAIL_WIDTH = 10;
const NUM_SLOTS_IN_TRACK = 128;
const TRACK_BUTTONS_LEFT_WIDTH = 60;
const TRACK_PADDING = 10;
const TRACK_HEIGHT = 48;
const TRACK_WIDTH = SCREEN_SIZE.x - TRACK_BUTTONS_LEFT_WIDTH - (3 * TRACK_PADDING);
const SLOT_PADDING = 3;
const SLOT_WIDTH = (TRACK_WIDTH - (SLOT_PADDING * (NUM_SLOTS_IN_TRACK + 1))) / NUM_SLOTS_IN_TRACK;
const BLOCK_BUTTON_SIZE = Vec2{ .x = 100, .y = 30 };
const BLOCK_BUTTON_X = SCREEN_SIZE.x - (BLOCK_BUTTON_SIZE.x * 3) - (TRACK_PADDING * 3);
const BLOCK_BUTTON_Y = TRACK_PADDING;
const PANE_WIDTH = (BLOCK_BUTTON_SIZE.x * 3) + (TRACK_PADDING * 2);
const PANE_X = BLOCK_BUTTON_X;
const PANE_Y = BLOCK_BUTTON_SIZE.y + (TRACK_PADDING * 2);
const PANE_HEIGHT = TRACK_1_Y - TRACK_PADDING - PANE_Y;
const TRACK_1_Y = SCREEN_SIZE.y - TRACK_PADDING - TRACK_HEIGHT - TRACK_PADDING - TRACK_HEIGHT;
const DEFAULT_BLOCK_WIDTH_COUNT = 10;
const DEFAULT_BLOCK_WIDTH = (DEFAULT_BLOCK_WIDTH_COUNT * SLOT_WIDTH) + ((DEFAULT_BLOCK_WIDTH_COUNT - 1) * SLOT_PADDING);

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

const InstructionParams = union(InstructionType) {
    ready: void,
    throw: ThrowParams,
    move: MoveParams,
};

const Instruction = struct {
    instruction: InstructionParams,
    length: u16 = 20,
};

const Block = struct {
    instruction: InstructionType,
    start_index: u8 = 0,
    width: u8 = 0,
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

    pub fn addBlock(self: *Self, instruction: InstructionType, slot_index: u8) void {
        // TODO (25 Jul 2023 sam): Check that there is no overlaps.
        const block = Block{
            .instruction = instruction,
            .start_index = slot_index,
            .width = DEFAULT_BLOCK_WIDTH_COUNT,
        };
        self.blocks.append(block) catch unreachable;
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

    pub fn addBlock(self: *Self, instruction: InstructionType, track_index: u8, slot_index: u8) void {
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
                    .target_position = move.end_pos.position(self.side),
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
                .end_pos = .in,
            },
        } }) catch unreachable;
        self.instructions.append(.{ .instruction = .{
            .throw = .{
                .direction = .in_1,
                .power = .pow_3,
            },
        } }) catch unreachable;
        self.instructions.append(.{ .instruction = .{
            .move = .{
                .end_pos = .neutral,
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
        block_button_index: ?usize = null,
    },
    idle_drag: void,
    block_drag: struct {
        instruction: InstructionType,
        hovered_track: ?u8 = null,
        hovered_slot: ?u8 = null,
    },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    block_buttons: std.ArrayList(Button),
    state: StateData = .{ .idle = .{} },
    juggler: Juggler,
    program: Program,
    path: BallPath = undefined,
    paused: bool = false,
    cursor: CursorStyle = .default,
    block: ?Block = null,
    active_pane: InstructionType = .throw,

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
            .block_buttons = std.ArrayList(Button).init(allocator),
            .allocator = allocator,
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.block_buttons.deinit();
    }

    pub fn setup(self: *Self) void {
        const throw = ThrowParams{
            .power = .pow_3,
            .direction = .in_1,
        };
        self.path = BallPath.init(self.juggler.hands[0].position, throw, .left);
        for (0..@typeInfo(InstructionType).Enum.fields.len) |i| {
            const inst = @enumFromInt(InstructionType, i);
            const fi = @floatFromInt(f32, i);
            self.block_buttons.append(.{
                .rect = .{
                    .position = .{
                        .x = BLOCK_BUTTON_X + (fi * (BLOCK_BUTTON_SIZE.x + TRACK_PADDING)),
                        .y = BLOCK_BUTTON_Y,
                    },
                    .size = BLOCK_BUTTON_SIZE,
                },
                .value = @intCast(u8, @intFromEnum(inst)),
                .text = @tagName(inst),
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
        for (self.block_buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        self.updateMouse();
    }

    pub fn updateMouse(self: *Self) void {
        const mouse = self.haathi.inputs.mouse;
        self.cursor = .default;
        switch (self.state) {
            .idle => |data| {
                _ = data;
                self.state.idle.block_button_index = null;
                for (self.block_buttons.items, 0..) |*button, i| {
                    if (button.contains(mouse.current_pos)) {
                        self.state.idle.block_button_index = i;
                        self.cursor = .pointer;
                        break;
                    }
                }
                if (mouse.l_button.is_clicked) {
                    if (self.state.idle.block_button_index) |bbi| {
                        const instruction = @enumFromInt(InstructionType, self.block_buttons.items[bbi].value);
                        self.active_pane = instruction;
                        return;
                    }
                }
            },
            .idle_drag => {
                if (mouse.l_button.is_released) self.state = .{ .idle = .{} };
            },
            .block_drag => |data| {
                self.cursor = .grabbing;
                self.state.block_drag.hovered_slot = null;
                self.state.block_drag.hovered_track = null;
                for (self.program.tracks, 0..) |track, i| {
                    if (track.rect.contains(mouse.current_pos)) self.state.block_drag.hovered_track = @intCast(u8, i);
                }
                if (self.state.block_drag.hovered_track) |ti| {
                    const track = self.program.tracks[ti];
                    for (track.slots.items, 0..) |slot, i| {
                        if (slot.contains(mouse.current_pos)) {
                            self.state.block_drag.hovered_slot = @intCast(u8, i);
                            break;
                        }
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

    pub fn render(self: *Self) void {
        self.haathi.setCursor(self.cursor);
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        for (self.juggler.hands) |hand| {
            self.haathi.drawRect(.{
                .position = hand.position,
                .size = HAND_SIZE,
                .color = colors.endesga_grey4,
                .centered = true,
                .radius = 3,
            });
        }
        // self.haathi.drawPath(.{
        //     .points = self.path.points[0..],
        //     .color = colors.solarized_orange,
        //     .width = 1,
        // });
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
                    .color = colors.endesga_grey3,
                });
                self.haathi.drawText(.{
                    .position = pos.add(size.scale(0.5)).add(.{ .y = 6 }),
                    .color = colors.endesga_grey0,
                    .text = @tagName(block.instruction),
                });
            }
        }
        for (self.block_buttons.items) |button| {
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
            const button = self.block_buttons.items[@intFromEnum(self.active_pane)];
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
                .color = colors.endesga_grey3,
                .centered = centered,
            });
            self.haathi.drawText(.{
                .position = pos.add(size.scale(scale)).add(.{ .y = 6 }),
                .color = colors.endesga_grey0,
                .text = @tagName(block.instruction),
            });
        }
    }
};
