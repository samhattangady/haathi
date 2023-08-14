const std = @import("std");
const c = @import("interface.zig");
const Haathi = @import("haathi.zig").Haathi;
const colors = @import("colors.zig");
const MouseState = @import("inputs.zig").MouseState;
const SCREEN_SIZE = @import("haathi.zig").SCREEN_SIZE;
const CursorStyle = @import("haathi.zig").CursorStyle;

const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Vec2i = helpers.Vec2i;
const Vec4 = helpers.Vec4;
const Rect = helpers.Rect;
const Button = helpers.Button;

const FONT_1 = "18px JetBrainsMono";
const SCORE1 = "14px JetBrainsMono";

const NUM_ROWS = 10;
const NUM_COLS = 25;
const GRID_HEIGHT = SCREEN_SIZE.y * 0.7;
const GRID_WIDTH = SCREEN_SIZE.x;
const SIM_TICK = 100;
const NUM_EXTRA_SIM_STEPS = 5;
const PIN_SPACING = 60; // pins are placed in equilateral triangles.
const NUM_EFFECTS = @typeInfo(EffectType).Enum.fields.len;
const DEBUG_PRINT_1 = true;

const Pin = struct {
    const Self = @This();
    position: Vec2 = undefined,
    size: f32 = 20,
    // x is the col, y is the row
    // in one row, x is either all even or odd
    // first pin is at 0, 0
    // second row is -1,1 and 1,1
    // third row is -2,2, 0,2 and 2,2
    // and so on.
    address: Vec2i,
    present: bool = true,
    fallen: bool = false,

    pub fn init(address: Vec2i, num_rows: usize) Self {
        var self = Self{ .address = address };
        self.setPosition(num_rows);
        return self;
    }

    pub fn setPosition(self: *Self, num_rows: usize) void {
        _ = num_rows; // TODO (08 Aug 2023): Use for scaling.
        const x_padding = PIN_SPACING * 0.5;
        const y_padding = PIN_SPACING * @cos(std.math.pi / 6.0);
        const origin = SCREEN_SIZE.scale(0.5);
        self.position.x = origin.x + (x_padding * @as(f32, @floatFromInt(self.address.x)));
        self.position.y = origin.y - (y_padding * @as(f32, @floatFromInt(self.address.y)));
    }

    pub fn reset(self: *Self) void {
        self.present = true;
        self.fallen = false;
    }
};

const Dropper = struct {
    target: Vec2i,
    index: ?usize,
    direction: Vec2i,
};

const PinDrop = struct {
    index: usize,
    // if prev is null, then pin was dropped by ball
    prev: ?usize,
    gen: usize,
};

const Ball = struct {
    position: Vec2,
    row: i8 = 0,
    col: i8 = 0,
    direction: Vec2i,
};

const Frame = struct {
    const Self = @This();
    complete: bool = false,
    // number of pins knocked down.
    shots: std.ArrayList(u16),
    // score for each shot
    scores: std.ArrayList(?u16),
    // total number of pins in frame.
    clears: std.ArrayList(bool),
    total: ?usize = null,
    cumulative: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .shots = std.ArrayList(u16).init(allocator),
            .scores = std.ArrayList(?u16).init(allocator),
            .clears = std.ArrayList(bool).init(allocator),
        };
        return self;
    }
};

const Scorecard = struct {
    const Self = @This();
    frames: std.ArrayList(Frame),

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .frames = std.ArrayList(Frame).init(allocator),
        };
        return self;
    }

    pub fn calculateScores(self: *Self) void {
        var cumulative: usize = 0;
        for (self.frames.items, 0..) |*frame, frame_index| {
            // TODO (14 Aug 2023 sam): check effects here and all.
            // frame in progress. stop updating scorecard
            if (!frame.complete) break;
            // frame has already been calculated, can move on to next.
            if (frame.cumulative) |fc| {
                cumulative = fc;
                continue;
            }
            if (frame.total == null) {
                for (frame.shots.items, 0..) |score, shot_index| {
                    var total: u16 = 0;
                    total += score;
                    // number of next shots that will be added to this score
                    var additional: usize = 0;
                    if (frame.clears.items[shot_index]) {
                        if (shot_index == 0) {
                            additional = 2;
                        } else {
                            additional = 1;
                        }
                    }
                    var current_frame = frame_index;
                    var current_shot = shot_index + 1;
                    while (additional > 0) {
                        if (self.getScore(current_frame, current_shot)) |shot_score| {
                            total += shot_score;
                            additional -= 1;
                            current_shot += 1;
                        } else {
                            current_frame += 1;
                            current_shot = 0;
                        }
                        if (current_frame >= self.frames.items.len) break;
                    }
                    if (additional == 0) frame.scores.items[shot_index] = total;
                }
            }
            {
                var frame_scorable = true;
                var frame_total: usize = 0;
                for (frame.scores.items) |score| {
                    if (score) |sc| {
                        frame_total += sc;
                    } else {
                        frame_scorable = false;
                    }
                }
                if (frame_scorable) {
                    frame.total = frame_total;
                }
            }
            if (frame.total) |total| {
                cumulative += total;
                frame.cumulative = cumulative;
            }
        }
        self.calculateFinalFrameScore();
    }

    fn calculateFinalFrameScore(self: *Self) void {
        if (self.frames.items[self.frames.items.len - 1].complete) {
            var frame = &self.frames.items[self.frames.items.len - 1];
            // recalculate final frame score.
            if (frame.clears.items[0]) {
                frame.total = 10 + frame.shots.items[1] + frame.shots.items[2];
            } else if (frame.clears.items[1]) {
                frame.total = 10 + frame.shots.items[2];
            }
            frame.cumulative = self.frames.items[self.frames.items.len - 2].cumulative.? + frame.total.?;
        }
    }

    fn getScore(self: *const Self, frame_index: usize, shot_index: usize) ?u16 {
        if (frame_index < self.frames.items.len) {
            const frame = self.frames.items[frame_index];
            if (shot_index < frame.shots.items.len) {
                return frame.shots.items[shot_index];
            } else {
                return null;
            }
        } else {
            return null;
        }
    }
};

const EffectType = enum {
    shield,
};
const Effect = struct {
    effect: EffectType,
    pin_index: usize,
};

const Phalanx = struct {
    const Self = @This();
    pins: std.ArrayList(Pin),
    drops: std.ArrayList(PinDrop),
    queue: std.ArrayList(Dropper),
    effects: std.ArrayList(Effect),
    scorecard: Scorecard,
    active_frame: u8 = 0,
    frame_num_shot: u8 = 0,
    ticks: u64 = 0,
    sim_generation: usize = 0,
    total_num_frames: usize = 10,
    /// the last generation that the ball hit anything. Used to end the sim.
    last_ball_hit: usize = 0,
    prev_tick: u64 = 0,
    simming: bool = false,
    ball: Ball = undefined,
    ball_col: i8 = 0,
    num_shots_per_frame: u8 = 2,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .pins = std.ArrayList(Pin).init(allocator),
            .drops = std.ArrayList(PinDrop).init(allocator),
            .queue = std.ArrayList(Dropper).init(allocator),
            .effects = std.ArrayList(Effect).init(allocator),
            .scorecard = Scorecard.init(allocator),
            .allocator = allocator,
        };
        self.setup();
        return self;
    }

    fn setup(self: *Self) void {
        // setup 4 rows.
        const addresses = [_]Vec2i{
            .{ .x = 0, .y = 0 },
            .{ .x = -1, .y = 1 },
            .{ .x = 1, .y = 1 },
            .{ .x = -2, .y = 2 },
            .{ .x = 0, .y = 2 },
            .{ .x = 2, .y = 2 },
            .{ .x = -3, .y = 3 },
            .{ .x = -1, .y = 3 },
            .{ .x = 1, .y = 3 },
            .{ .x = 3, .y = 3 },
            // .{ .x = -4, .y = 4 },
            // .{ .x = -2, .y = 4 },
            // .{ .x = 0, .y = 4 },
            // .{ .x = 2, .y = 4 },
            // .{ .x = 4, .y = 4 },
        };
        for (addresses) |adr| {
            const pin = Pin.init(adr, 4);
            self.pins.append(pin) catch unreachable;
        }
        for (0..self.total_num_frames) |_| {
            var frame = Frame.init(self.allocator);
            self.scorecard.frames.append(frame) catch unreachable;
        }
        self.resetBall();
    }

    fn update(self: *Self, ticks: u64) void {
        self.ticks = ticks;
        if (self.simming and self.ticks - self.prev_tick > SIM_TICK) {
            self.prev_tick = self.ticks;
            self.simulationStep();
        }
    }

    fn resetBall(self: *Self) void {
        self.ball = .{
            .row = -3,
            .col = self.ball_col,
            .direction = .{ .x = -1, .y = 1 },
            .position = .{},
        };
        self.setBallPosition();
    }

    fn changeBallCol(self: *Self, change: i8) void {
        self.ball_col += change;
        self.resetBall();
    }

    fn throwBall(self: *Self) void {
        if (self.simming) return;
        self.sim_generation = 0;
        self.queue.clearRetainingCapacity();
        self.simming = true;
        self.prev_tick = self.ticks;
        self.last_ball_hit = 0;
    }

    fn setBallPosition(self: *Self) void {
        const pin_address = Vec2i{ .x = self.ball.col, .y = self.ball.row };
        const pin = Pin.init(pin_address, 4);
        self.ball.position = pin.position.add(.{ .x = PIN_SPACING / 4, .y = 25 });
    }

    fn simulationStep(self: *Self) void {
        const len = self.queue.items.len;
        for (0..len) |_| {
            const drop = self.queue.orderedRemove(0);
            _ = self.maybeDropPin(drop.target, drop.index, drop.direction);
        }
        const ball_left = Vec2i{ .x = self.ball.col, .y = self.ball.row };
        const ball_right = Vec2i{ .x = self.ball.col + 1, .y = self.ball.row };
        const left_drop = self.maybeDropPin(ball_left, null, .{ .x = -1, .y = 1 });
        const right_drop = self.maybeDropPin(ball_right, null, .{ .x = 1, .y = 1 });
        if (left_drop or right_drop) self.last_ball_hit = self.sim_generation;
        self.sim_generation += 1;
        self.ball.row += 1;
        self.setBallPosition();
        if (self.ball.row > 3 and self.sim_generation - self.last_ball_hit > NUM_EXTRA_SIM_STEPS) {
            self.resetBall();
            self.simming = false;
            self.updateScorecard();
        }
    }

    fn maybeDropPin(self: *Self, address: Vec2i, prev: ?usize, direction: Vec2i) bool {
        if (self.standingPinAt(address)) |pin_index| {
            for (self.effects.items) |effect| {
                if (effect.pin_index != pin_index) continue;
                switch (effect.effect) {
                    .shield => return false,
                }
            }
            self.pins.items[pin_index].fallen = true;
            const fall = PinDrop{ .index = pin_index, .prev = prev, .gen = self.sim_generation };
            self.drops.append(fall) catch unreachable;
            self.queue.append(.{
                .target = address.add(direction),
                .index = pin_index,
                .direction = direction,
            }) catch unreachable;
            return true;
        }
        return false;
    }

    fn updateScorecard(self: *Self) void {
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 1");
        var score: u16 = 0;
        for (self.pins.items) |pin| {
            if (pin.fallen and pin.present) score += 1;
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2");
        const cleared = self.allPinsFallen();
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2.1");
        self.scorecard.frames.items[self.active_frame].shots.append(score) catch unreachable;
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2.2");
        self.scorecard.frames.items[self.active_frame].scores.append(null) catch unreachable;
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2.3");
        self.scorecard.frames.items[self.active_frame].clears.append(cleared) catch unreachable;
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2.4");
        self.frame_num_shot += 1;
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 3");
        for (self.pins.items) |*pin| {
            if (pin.fallen) pin.present = false;
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 4");
        var goto_next_frame = false;
        var reset_pins = false;
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 5");
        if (self.active_frame == self.total_num_frames - 1) {
            if (self.allPinsFallen()) reset_pins = true;
            if (self.frame_num_shot == 3) {
                goto_next_frame = true;
            }
            if (!self.allPinsFallen() and self.frame_num_shot == 2) {
                // if second shot has not cleared all pins, we should end frame,
                // unless first shot was a strike
                goto_next_frame = true;
                if (self.scorecard.frames.items[self.active_frame].clears.items[0]) goto_next_frame = false;
            }
        } else {
            if (self.allPinsFallen() or self.frame_num_shot >= self.num_shots_per_frame) {
                goto_next_frame = true;
                reset_pins = true;
            }
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 6");
        if (reset_pins) {
            for (self.pins.items) |*pin| pin.reset();
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 7");
        if (goto_next_frame) {
            self.scorecard.frames.items[self.active_frame].complete = true;
            self.active_frame += 1;
            self.frame_num_shot = 0;
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 8");
        self.scorecard.calculateScores();
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 9");
    }

    /// does not handle final frame. that's done elsewhere
    fn frameComplete(self: *Self) bool {
        if (self.allPinsFallen()) return true;
        if (self.frame_num_shot >= self.num_shots_per_frame) return true;
        return false;
    }

    fn allPinsFallen(self: *const Self) bool {
        for (self.pins.items) |pin| {
            if (!pin.fallen) return false;
        }
        return true;
    }

    fn standingPinAt(self: *Self, address: Vec2i) ?usize {
        for (self.pins.items, 0..) |pin, i| {
            if (pin.fallen) continue;
            if (pin.address.equal(address)) return i;
        }
        return null;
    }
};

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
    effect_drag: struct {
        effect: EffectType,
        pin_index: ?usize = null,
    },
};

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    phalanx: Phalanx,
    buttons: std.ArrayList(Button),

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .phalanx = Phalanx.init(allocator),
            .buttons = std.ArrayList(Button).init(allocator),
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

    fn setup(self: *Self) void {
        for (0..NUM_EFFECTS) |i| {
            const fi = @as(f32, @floatFromInt(i));
            const effect = @as(EffectType, @enumFromInt(i));
            self.buttons.append(.{
                .rect = .{
                    .position = .{ .x = 60, .y = 60 + (fi * 30) },
                    .size = .{ .x = 100, .y = 24 },
                },
                .value = @as(u8, @intCast(i)),
                .text = @tagName(effect),
            }) catch unreachable;
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        // clear the arena and reset.
        self.arena_handle.deinit();
        self.arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.phalanx.update(self.ticks);
        if (self.haathi.inputs.getKey(.space).is_clicked) self.phalanx.throwBall();
        if (self.haathi.inputs.getKey(.s).is_clicked) self.phalanx.simulationStep();
        if (self.haathi.inputs.getKey(.a).is_clicked) self.phalanx.changeBallCol(-1);
        if (self.haathi.inputs.getKey(.d).is_clicked) self.phalanx.changeBallCol(1);
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        self.updateMouseInputs();
    }

    fn updateMouseInputs(self: *Self) void {
        const mouse = self.haathi.inputs.mouse;
        switch (self.state) {
            .idle => |_| {
                var hovered_index: ?usize = null;
                for (self.buttons.items, 0..) |button, i| {
                    if (button.contains(mouse.current_pos)) {
                        hovered_index = i;
                        break;
                    }
                }
                self.state.idle.index = hovered_index;
                if (mouse.l_button.is_clicked) {
                    if (hovered_index) |hi| {
                        const effect = @as(EffectType, @enumFromInt(self.buttons.items[hi].value));
                        self.state = .{ .effect_drag = .{ .effect = effect } };
                        return;
                    } else {
                        self.state = .idle_drag;
                    }
                }
            },
            .idle_drag => {
                if (mouse.l_button.is_released) self.state = .{ .idle = .{} };
            },
            .effect_drag => |data| {
                var pin_index: ?usize = null;
                for (self.phalanx.pins.items, 0..) |pin, i| {
                    if (mouse.current_pos.distanceSqr(pin.position) < pin.size * pin.size) {
                        pin_index = i;
                        break;
                    }
                }
                self.state.effect_drag.pin_index = pin_index;
                if (mouse.l_button.is_released) {
                    if (pin_index) |pi| {
                        self.phalanx.effects.append(.{ .effect = data.effect, .pin_index = pi }) catch unreachable;
                    }
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        const ball_size = PIN_SPACING * 0.8;
        {
            const path_size: f32 = ball_size * 0.8;
            // ball path
            const path_x = self.phalanx.ball.position.x - (path_size / 2);
            const path_length = SCREEN_SIZE.y * 0.7;
            self.haathi.drawRect(.{
                .position = .{ .x = path_x, .y = 0 },
                .size = .{ .x = path_size, .y = path_length },
                .color = colors.endesga_blue2.alpha(0.2),
            });
        }
        for (self.phalanx.pins.items) |pin| {
            self.haathi.drawRect(.{
                .position = pin.position,
                .size = .{ .x = pin.size, .y = pin.size },
                .color = colors.endesga_grey2,
                .centered = true,
                .radius = pin.size,
            });
            if (pin.fallen) {
                self.haathi.drawRect(.{
                    .position = pin.position,
                    .size = .{ .x = pin.size, .y = pin.size },
                    .color = colors.endesga_grey4,
                    .centered = true,
                    .radius = pin.size,
                });
            }
            if (false) {
                const pin_pos = std.fmt.allocPrintZ(self.arena, "{d},{d}", .{ pin.address.x, pin.address.y }) catch unreachable;
                self.haathi.drawText(.{
                    .text = pin_pos,
                    .position = pin.position.add(.{ .y = 6 }),
                    .color = colors.endesga_grey0,
                });
            }
        }
        {
            self.haathi.drawRect(.{
                .position = self.phalanx.ball.position,
                .size = .{ .x = ball_size, .y = ball_size },
                .color = colors.endesga_blue2,
                .centered = true,
                .radius = 50,
            });
            if (false) {
                const ball_pos = std.fmt.allocPrintZ(self.arena, "{d},{d}", .{ self.phalanx.ball.col, self.phalanx.ball.row }) catch unreachable;
                self.haathi.drawText(.{
                    .text = ball_pos,
                    .position = self.phalanx.ball.position.add(.{ .y = 6 }),
                    .color = colors.endesga_grey0,
                });
            }
        }
        const SCORECARD_PADDING = 50;
        for (self.phalanx.scorecard.frames.items, 0..) |frame, i| {
            const fi: f32 = @floatFromInt(i);
            const y = (fi + 1) * SCORECARD_PADDING;
            for (frame.shots.items, 0..) |score, j| {
                const fj: f32 = @floatFromInt(j);
                const x = (SCREEN_SIZE.x * 0.8) + (fj * SCORECARD_PADDING);
                const score_text = std.fmt.allocPrintZ(self.arena, "{d}", .{score}) catch unreachable;
                self.haathi.drawText(.{
                    .text = score_text,
                    .position = .{ .x = x, .y = y },
                    .color = colors.endesga_grey4,
                });
            }
        }
        for (self.buttons.items) |button| {
            const button_color = if (button.hovered) colors.endesga_grey6 else colors.endesga_grey5;
            const text_color = if (button.hovered) colors.endesga_grey0 else colors.endesga_grey1;
            self.haathi.drawRect(.{
                .position = button.rect.position,
                .size = button.rect.size,
                .color = button_color,
                .radius = 5,
            });
            self.haathi.drawText(.{
                .position = button.rect.position.add(.{ .x = button.rect.size.x / 2, .y = (button.rect.size.y / 2) + 5 }),
                .text = button.text,
                .color = text_color,
                .style = FONT_1,
            });
        }
        switch (self.state) {
            .effect_drag => |data| {
                if (data.pin_index) |pi| {
                    const pin = self.phalanx.pins.items[pi];
                    self.haathi.drawRect(.{
                        .position = pin.position,
                        .size = .{ .x = pin.size, .y = pin.size },
                        .color = colors.endesga_grey6,
                        .centered = true,
                        .radius = pin.size,
                    });
                }
                self.haathi.drawText(.{
                    .text = @tagName(data.effect),
                    .position = self.haathi.inputs.mouse.current_pos,
                    .color = colors.endesga_grey0,
                    .alignment = .left,
                });
            },
            else => {},
        }
        for (self.phalanx.effects.items) |effect| {
            const pin = self.phalanx.pins.items[effect.pin_index];
            self.haathi.drawRect(.{
                .position = pin.position,
                .size = .{ .x = pin.size, .y = pin.size },
                .color = colors.endesga_grey6,
                .centered = true,
                .radius = pin.size,
            });
            self.haathi.drawText(.{
                .text = @tagName(effect.effect),
                .position = pin.position,
                .color = colors.endesga_grey0,
                .alignment = .left,
            });
        }
        {
            // draw scorecard.
            const frame_size = 90; // TODO (14 Aug 2023 sam): make this depend on number of frames
            const frame_padding = frame_size * 0.1;
            const num_frames: f32 = @floatFromInt(self.phalanx.total_num_frames);
            const scoreboard_width = (frame_size * num_frames) + (frame_padding * (num_frames - 1));
            const scoreboard_x = (SCREEN_SIZE.x - scoreboard_width) / 2;
            for (self.phalanx.scorecard.frames.items, 0..) |frame, i| {
                const fi: f32 = @floatFromInt(i);
                const x = scoreboard_x + (fi * (frame_size + frame_padding));
                const y = SCREEN_SIZE.y - frame_size - (frame_padding * 2);
                self.haathi.drawRect(.{
                    .position = .{ .x = x, .y = y },
                    .size = .{ .x = frame_size, .y = frame_size },
                    .color = colors.endesga_grey4.alpha(0.2),
                });
                const shot_padding = frame_padding * (1.0 / 3.0);
                const shot_size = (frame_size - (shot_padding * 4.0)) / 3.0;
                var frame_num: usize = 0;
                for (0..3) |j| { // TODO (14 Aug 2023 sam): make this neater?
                    if (j == 0 and i != self.phalanx.total_num_frames - 1) continue;
                    const fj: f32 = @floatFromInt(j);
                    const sx = x + ((fj + 1) * shot_padding) + (fj * shot_size);
                    self.haathi.drawRect(.{
                        .position = .{ .x = sx, .y = y + shot_padding },
                        .size = .{ .x = shot_size, .y = shot_size },
                        .color = colors.endesga_grey4.alpha(0.2),
                    });
                    if (frame.shots.items.len > frame_num) {
                        const score = std.fmt.allocPrintZ(self.arena, "{d}", .{frame.shots.items[frame_num]}) catch unreachable;
                        self.haathi.drawText(.{
                            .position = .{ .x = sx + (shot_size * 0.5), .y = y + shot_padding + (shot_size * 0.5) + 4 },
                            .text = score,
                            .color = colors.endesga_grey5,
                            .style = SCORE1,
                        });
                        if (frame.clears.items[frame_num]) {
                            const symbol = if (frame_num == 0) "X" else "/";
                            self.haathi.drawText(.{
                                .position = .{ .x = sx + (shot_size * 0.5) + (shot_size * 0.25), .y = y + shot_padding + (shot_size * 0.5) + 4 + (shot_size * 0.5) },
                                .text = symbol,
                                .color = colors.endesga_grey5,
                                .style = SCORE1,
                            });
                        }
                        frame_num += 1;
                    }
                    if (frame.cumulative) |cumulative| {
                        const cscore = std.fmt.allocPrintZ(self.arena, "{d}", .{cumulative}) catch unreachable;
                        self.haathi.drawText(.{
                            .position = .{ .x = x + (frame_size * 0.5), .y = y + frame_padding + (frame_size * 0.75) + 6 },
                            .text = cscore,
                            .color = colors.endesga_grey6,
                        });
                    }
                    if (frame.total) |total| {
                        const cscore = std.fmt.allocPrintZ(self.arena, "+{d}", .{total}) catch unreachable;
                        self.haathi.drawText(.{
                            .position = .{ .x = x + (frame_size * 0.5), .y = y + frame_padding + (frame_size * 0.4) + 6 },
                            .text = cscore,
                            .color = colors.endesga_grey5.alpha(0.6),
                            .style = SCORE1,
                        });
                    }
                }

                if (i == self.phalanx.active_frame) {
                    self.haathi.drawRect(.{
                        .position = .{ .x = x, .y = y + frame_size + (frame_padding / 2.0) },
                        .size = .{ .x = frame_size, .y = frame_padding },
                        .color = colors.endesga_grey4.alpha(0.2),
                    });
                }
            }
        }
    }
};
