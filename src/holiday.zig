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
const PIN_VALUE_STYLE = "12px JetBrainsMono";

const NUM_ROWS = 10;
const NUM_COLS = 25;
const GRID_HEIGHT = SCREEN_SIZE.y * 0.7;
const GRID_WIDTH = SCREEN_SIZE.x;
const SIM_TICK = 100;
const NUM_EXTRA_SIM_STEPS = 5;
const PIN_SPACING = 60; // pins are placed in equilateral triangles.
const DEBUG_PRINT_1 = false;
const HEAD_PIN_POSITION = Vec2{ .x = SCREEN_SIZE.x * 0.25, .y = SCREEN_SIZE.y * 0.5 };
const SELECTION_POS = Vec2{ .x = 20, .y = 20 };
const SELECTION_SIZE = Vec2{ .x = SCREEN_SIZE.x * 0.75, .y = (SCREEN_SIZE.y) - (DEFAULT_FRAME_SIZE * 1.6) };
const NUM_CARDS = 6;
const NUM_CARD_ROWS = 2;
const CARDS_Y_OFFSET = SELECTION_SIZE.y * 0.125;
const CARD_SIZE = Vec2{ .x = 200, .y = 120 };
const START_BUTTON_SIZE = Vec2{ .x = CARD_SIZE.x, .y = 40 };
const CARD_PADDING = 30;
const NUM_CARDS_TO_SELECT = 2;
const BUTTON_START_Y = 60;
const BUTTON_SIZE = Vec2{ .x = 180, .y = 30 };
const BUTTON_START_X = SCREEN_SIZE.x * 0.45;
const BUTTON_PADDING = 20;
const DEFAULT_FRAME_SIZE = 90;

const Pin = struct {
    const Self = @This();
    position: Vec2 = undefined,
    size: f32 = 20,
    value: usize = 1,
    // x is the col, y is the row
    // in one row, x is either all even or odd
    // first pin is at 0, 0
    // second row is -1,1 and 1,1
    // third row is -2,2, 0,2 and 2,2
    // and so on.
    address: Vec2i,
    present: bool = true,
    fallen_dir: ?Vec2i = null,
    just_fallen: bool = true,

    pub fn init(address: Vec2i, pin_scale: f32) Self {
        var self = Self{ .address = address };
        self.setPosition(pin_scale);
        return self;
    }

    pub fn setPosition(self: *Self, pin_scale: f32) void {
        const x_padding: f32 = pin_scale * PIN_SPACING * 0.5;
        const y_padding: f32 = pin_scale * PIN_SPACING * @cos(std.math.pi / 6.0);
        const origin = HEAD_PIN_POSITION;
        self.position.x = origin.x + (x_padding * @as(f32, @floatFromInt(self.address.x)));
        self.position.y = origin.y - (y_padding * @as(f32, @floatFromInt(self.address.y)));
    }

    pub fn reset(self: *Self) void {
        self.present = true;
        self.fallen_dir = null;
        self.just_fallen = true;
    }

    pub fn fallen(self: *const Self) bool {
        return self.fallen_dir != null;
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
    shots: std.ArrayList(usize),
    // score for each shot
    scores: std.ArrayList(?usize),
    // total number of pins in frame.
    clears: std.ArrayList(bool),
    effects: std.ArrayList(ScoreEffect),
    multiplier: usize = 1,
    extra: usize = 0,
    total: ?usize = null,
    cumulative: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .shots = std.ArrayList(usize).init(allocator),
            .scores = std.ArrayList(?usize).init(allocator),
            .clears = std.ArrayList(bool).init(allocator),
            .effects = std.ArrayList(ScoreEffect).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.shots.deinit();
        self.scores.deinit();
        self.clears.deinit();
        self.effects.deinit();
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

    pub fn deinit(self: *Self) void {
        for (self.frames.items) |*frame| frame.deinit();
        self.frames.deinit();
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
                    var total: usize = 0;
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
                    frame.total = frame_total * frame.multiplier;
                    frame.total.? += frame.extra;
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
                // TODO (15 Aug 2023 sam): should not be 10
                frame.total = 10 + frame.shots.items[1] + frame.shots.items[2];
            } else if (frame.clears.items[1]) {
                frame.total = 10 + frame.shots.items[2];
            }
            frame.cumulative = self.frames.items[self.frames.items.len - 2].cumulative.? + frame.total.?;
        }
    }

    fn getScore(self: *const Self, frame_index: usize, shot_index: usize) ?usize {
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

const RewardType = enum {
    /// add an extra frame
    extra_frame,
    /// add an extra row of pins
    extra_pins,
    /// multiply the frame score by frame number
    frame_multiplier,
    /// select more effects,
    more_effects,
    /// more cards to choose
    more_cards,
};
const REWARD_TYPE_COUNT = @typeInfo(RewardType).Enum.fields.len;
const Reward = struct {
    reward: RewardType,
    value: f32,
};

fn randomQuestReward(frame_reward: bool, rng: std.rand.Random) Reward {
    _ = frame_reward;
    const reward: RewardType = @enumFromInt(rng.uintLessThan(u8, REWARD_TYPE_COUNT));
    return .{
        .reward = reward,
        .value = 1,
    };
}

const ScoreEffectType = enum {
    const Self = @This();
    /// multiply pins fallen by the nth roll
    num_scale,
    /// double pin value
    double_pin,
    /// on all rolls, knock down an equal number of pins.
    equal_score,
    /// adds its own value to all pins it knocks down
    pin_value_adder,
    /// leave pin standing at the end of frame
    pin_standing,
    /// all pins standing at the end of frame,
    all_standing,
    /// hit on all rolls (more than one roll
    hit_on_all_rolls,

    /// this kind of effect is applied directly to a pin
    pub fn pinSpecific(self: *const Self) bool {
        return switch (self.*) {
            .num_scale,
            .equal_score,
            .pin_value_adder,
            .all_standing,
            .hit_on_all_rolls,
            => false,
            .double_pin,
            .pin_standing,
            => true,
        };
    }

    pub fn compulsory(self: *const Self) bool {
        return switch (self.*) {
            .num_scale,
            .equal_score,
            .pin_value_adder,
            .all_standing,
            .hit_on_all_rolls,
            => false,
            .double_pin,
            .pin_standing,
            => true,
        };
    }

    pub fn isQuest(self: *const Self) bool {
        return switch (self.*) {
            .equal_score,
            .pin_standing,
            .all_standing,
            .hit_on_all_rolls,
            => true,
            .num_scale,
            .double_pin,
            .pin_value_adder,
            => false,
        };
    }
};
const NUM_SCORE_EFFECTS = @typeInfo(ScoreEffectType).Enum.fields.len;
const SCORE_EFFECTS = allScoreEffects();

fn allScoreEffects() [NUM_SCORE_EFFECTS]ScoreEffectType {
    var effects: [NUM_SCORE_EFFECTS]ScoreEffectType = undefined;
    for (0..NUM_SCORE_EFFECTS) |i| effects[i] = @enumFromInt(i);
    return effects;
}

const ScoreEffect = struct {
    effect: ScoreEffectType,
    index: ?usize = null,
    reward: ?Reward = null,
    completed: bool = false,
};

const Phalanx = struct {
    const Self = @This();
    pins: std.ArrayList(Pin),
    drops: std.ArrayList(PinDrop),
    queue: std.ArrayList(Dropper),
    scorecard: Scorecard,
    score_effects: std.ArrayList(ScoreEffect),
    active_frame: u8 = 0,
    frame_num_shot: u8 = 0,
    num_pin_rows: usize = 0,
    ticks: u64 = 0,
    sim_generation: usize = 0,
    total_num_frames: usize = 6,
    /// the last generation that the ball hit anything. Used to end the sim.
    last_ball_hit: usize = 0,
    prev_tick: u64 = 0,
    simming: bool = false,
    ball: Ball = undefined,
    ball_col: i8 = 0,
    num_shots_per_frame: u8 = 2,
    frame_just_complete: bool = false,
    total_score: usize = 0,
    can_throw: bool = false,
    pin_scale: f32 = 1,
    cards_to_select: usize = NUM_CARDS_TO_SELECT,
    card_choices: usize = 5,
    allocator: std.mem.Allocator,
    arena: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, arena: std.mem.Allocator) Self {
        var self = Self{
            .pins = std.ArrayList(Pin).init(allocator),
            .drops = std.ArrayList(PinDrop).init(allocator),
            .queue = std.ArrayList(Dropper).init(allocator),
            .score_effects = std.ArrayList(ScoreEffect).init(allocator),
            .scorecard = Scorecard.init(allocator),
            .allocator = allocator,
            .arena = arena,
        };
        self.setup();
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.pins.deinit();
        self.drops.deinit();
        self.queue.deinit();
        self.score_effects.deinit();
        self.scorecard.deinit();
    }

    fn setup(self: *Self) void {
        // setup 4 rows.
        // const addresses = [_]Vec2i{
        //     .{ .x = 0, .y = 0 },
        //     .{ .x = -1, .y = 1 },
        //     .{ .x = 1, .y = 1 },
        //     .{ .x = -2, .y = 2 },
        //     .{ .x = 0, .y = 2 },
        //     .{ .x = 2, .y = 2 },
        //     .{ .x = -3, .y = 3 },
        //     .{ .x = -1, .y = 3 },
        //     .{ .x = 1, .y = 3 },
        //     .{ .x = 3, .y = 3 },
        //     // .{ .x = -4, .y = 4 },
        //     // .{ .x = -2, .y = 4 },
        //     // .{ .x = 0, .y = 4 },
        //     // .{ .x = 2, .y = 4 },
        //     // .{ .x = 4, .y = 4 },
        // };
        // for (addresses) |adr| {
        //     const pin = Pin.init(adr, 4);
        //     self.pins.append(pin) catch unreachable;
        // }
        for (0..4) |_| self.addPinRow();
        for (0..self.total_num_frames) |_| {
            var frame = Frame.init(self.allocator);
            self.scorecard.frames.append(frame) catch unreachable;
        }
        self.resetBall();
    }

    pub fn loadSelectedEffects(self: *Self, selection: SelectEffects) void {
        self.clearFrameEffects();
        for (selection.cards.items) |card| {
            if (card.selected) {
                self.score_effects.append(card.effect) catch unreachable;
                self.scorecard.frames.items[self.active_frame].effects.append(card.effect) catch unreachable;
            }
        }
    }

    fn applyPinEffect(self: *Self, effect_index: usize, pin_index: usize) void {
        var effect = &self.score_effects.items[effect_index];
        effect.index = pin_index;
        switch (effect.effect) {
            .double_pin => {
                self.pins.items[pin_index].value *= 2;
            },
            .pin_standing => {
                self.score_effects.items[effect_index].index = pin_index;
            },
            .num_scale,
            .equal_score,
            .pin_value_adder,
            .all_standing,
            .hit_on_all_rolls,
            => {},
        }
    }

    fn checkCanThrow(self: *Self) void {
        self.can_throw = true;
        for (self.score_effects.items) |effect| {
            if (effect.effect.pinSpecific() and effect.effect.compulsory() and effect.index == null) {
                self.can_throw = false;
                return;
            }
        }
    }

    fn update(self: *Self, arena: std.mem.Allocator, ticks: u64) void {
        self.arena = arena;
        self.ticks = ticks;
        self.checkCanThrow();
        if (self.simming and self.ticks - self.prev_tick > SIM_TICK) {
            self.prev_tick = self.ticks;
            self.simulationStep();
        }
    }

    fn resetBall(self: *Self) void {
        self.ball = .{
            .row = -2,
            .col = self.ball_col,
            .direction = .{ .x = -1, .y = 1 },
            .position = .{},
        };
        self.setBallPosition();
    }

    fn changeBallCol(self: *Self, change: i8) void {
        if (self.simming) return;
        self.ball_col += change;
        self.ball_col = std.math.clamp(self.ball_col, (-1 * @as(i8, @intCast(self.num_pin_rows))) - 1, @as(i8, @intCast(self.num_pin_rows)));
        self.resetBall();
    }

    fn throwBall(self: *Self) void {
        if (!self.can_throw) return;
        if (self.active_frame >= self.total_num_frames) return;
        if (self.simming) return;
        self.sim_generation = 0;
        self.queue.clearRetainingCapacity();
        self.simming = true;
        self.prev_tick = self.ticks;
        self.last_ball_hit = 0;
    }

    fn setBallPosition(self: *Self) void {
        const pin_address = Vec2i{ .x = self.ball.col, .y = self.ball.row };
        const pin = Pin.init(pin_address, self.pin_scale);
        self.ball.position = pin.position.add(.{ .x = self.pin_scale * PIN_SPACING / 4, .y = self.pin_scale * 25 });
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
        if (self.ball.row > self.num_pin_rows + 5) {
            self.resetBall();
            self.simming = false;
            self.updateScorecard();
        }
    }

    fn maybeDropPin(self: *Self, address: Vec2i, prev: ?usize, direction: Vec2i) bool {
        if (self.standingPinAt(address)) |pin_index| {
            for (self.score_effects.items) |effect| {
                switch (effect.effect) {
                    .pin_value_adder => {
                        if (prev) |prev_index| {
                            self.pins.items[pin_index].value += self.pins.items[prev_index].value;
                        }
                    },
                    .double_pin,
                    .num_scale,
                    .equal_score,
                    .all_standing,
                    .hit_on_all_rolls,
                    .pin_standing,
                    => {},
                }
            }
            self.pins.items[pin_index].fallen_dir = direction;
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
        var score: usize = 0;
        for (self.pins.items) |pin| {
            if (pin.fallen() and pin.present) score += pin.value;
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 2");
        const cleared = self.allPinsFallen();
        score = self.applyFrameScoreEffects(score);
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
            if (pin.fallen()) {
                pin.present = false;
                pin.just_fallen = false;
            }
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
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 7");
        if (goto_next_frame) {
            self.checkQuests();
            self.scorecard.frames.items[self.active_frame].complete = true;
            self.active_frame += 1;
            self.frame_num_shot = 0;
            self.frame_just_complete = true;
        }
        if (reset_pins) {
            for (self.pins.items) |*pin| pin.reset();
        }
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 8");
        self.scorecard.calculateScores();
        if (DEBUG_PRINT_1) c.debugPrint("updateScorecard 9");
        for (self.scorecard.frames.items) |frame| {
            if (frame.cumulative) |fc| self.total_score = fc;
        }
    }

    fn checkQuests(self: *Self) void {
        for (self.score_effects.items) |*effect| {
            if (!effect.effect.isQuest()) continue;
            switch (effect.effect) {
                .equal_score => {
                    const num_shots_taken = self.frame_num_shot;
                    if (num_shots_taken == 1) continue;
                    var all_same = true;
                    const frame = self.scorecard.frames.items[self.active_frame];
                    const first_shot = frame.shots.items[0];
                    for (1..num_shots_taken) |shot_index| {
                        if (frame.shots.items[shot_index] != first_shot) {
                            all_same = false;
                            break;
                        }
                    }
                    if (all_same) {
                        self.applyReward(effect.reward.?);
                        effect.completed = true;
                    }
                },
                .pin_standing => {
                    if (effect.index) |pin_index| {
                        if (!self.pins.items[pin_index].fallen()) {
                            effect.completed = true;
                            self.applyReward(effect.reward.?);
                        }
                    }
                },
                .all_standing => {
                    var all_standing = true;
                    for (self.pins.items) |pin| {
                        if (pin.fallen()) {
                            all_standing = false;
                            break;
                        }
                    }
                    if (all_standing) {
                        self.applyReward(effect.reward.?);
                        effect.completed = true;
                    }
                },
                .hit_on_all_rolls => {
                    const num_shots_taken = self.frame_num_shot;
                    if (num_shots_taken == 1) continue;
                    var all_hit = true;
                    const frame = self.scorecard.frames.items[self.active_frame];
                    for (0..num_shots_taken) |shot_index| {
                        if (frame.shots.items[shot_index] == 0) {
                            all_hit = false;
                            break;
                        }
                    }
                    if (all_hit) {
                        self.applyReward(effect.reward.?);
                        effect.completed = true;
                    }
                },
                .num_scale,
                .double_pin,
                .pin_value_adder,
                => {},
            }
        }
    }

    fn applyReward(self: *Self, reward: Reward) void {
        // TODO (16 Aug 2023 sam): check the value in reward.
        switch (reward.reward) {
            .extra_pins => {
                self.addPinRow();
            },
            .extra_frame => {
                self.addFrame();
            },
            .frame_multiplier => {
                self.scorecard.frames.items[self.active_frame].multiplier = self.active_frame + 1;
            },
            .more_effects => {
                self.cards_to_select += 1;
            },
            .more_cards => {
                self.card_choices += 1;
            },
        }
    }

    fn clearFrameEffects(self: *Self) void {
        self.score_effects.clearRetainingCapacity();
    }

    fn addFrame(self: *Self) void {
        if (self.total_num_frames > 12) return;
        self.total_num_frames += 1;
        var frame = Frame.init(self.allocator);
        self.scorecard.frames.append(frame) catch unreachable;
    }

    fn addPinRow(self: *Self) void {
        var x: i32 = -1 * @as(i32, @intCast(self.num_pin_rows));
        while (x <= self.num_pin_rows) : (x += 2) {
            const address = Vec2i{ .x = x, .y = @intCast(self.num_pin_rows + 1) };
            const pin = Pin.init(address, self.pin_scale);
            self.pins.append(pin) catch unreachable;
        }
        self.num_pin_rows += 1;
        self.pin_scale = if (self.num_pin_rows > 6) std.math.pow(f32, 0.9, @as(f32, @floatFromInt(self.num_pin_rows - 6))) else 1;
        for (self.pins.items) |*pin| pin.setPosition(self.pin_scale);
    }

    fn applyFrameScoreEffects(self: *Self, start: usize) usize {
        var score = start;
        for (self.score_effects.items) |effect| {
            switch (effect.effect) {
                .num_scale => score *= (self.frame_num_shot + 1),
                .equal_score,
                .pin_value_adder,
                .all_standing,
                .hit_on_all_rolls,
                .double_pin,
                .pin_standing,
                => {},
            }
        }
        return score;
    }

    /// does not handle final frame. that's done elsewhere
    fn frameComplete(self: *Self) bool {
        if (self.allPinsFallen()) return true;
        if (self.frame_num_shot >= self.num_shots_per_frame) return true;
        return false;
    }

    fn allPinsFallen(self: *const Self) bool {
        for (self.pins.items) |pin| {
            if (!pin.fallen()) return false;
        }
        return true;
    }

    fn standingPinAt(self: *Self, address: Vec2i) ?usize {
        for (self.pins.items, 0..) |pin, i| {
            if (pin.fallen()) continue;
            if (pin.address.equal(address)) return i;
        }
        return null;
    }
};

const EffectCard = struct {
    const Self = @This();
    button: Button,
    effect: ScoreEffect,
    selected: bool = false,
};

const SelectEffects = struct {
    const Self = @This();
    cards: std.ArrayList(EffectCard),
    enabled: bool = true,
    start: Button,
    cards_correct: bool = false,
    effects_correct: bool = false,
    cards_to_select: usize = undefined,

    pub fn init(allocator: std.mem.Allocator) Self {
        var self = Self{
            .cards = std.ArrayList(EffectCard).init(allocator),
            .start = .{
                .rect = .{
                    .position = .{
                        .x = SELECTION_POS.x + SELECTION_SIZE.x - 20,
                        .y = SELECTION_POS.y + (SELECTION_SIZE.y / 2),
                    },
                    .size = START_BUTTON_SIZE,
                },
                .text = "Start Bowling",
                .value = 0,
            },
        };
        return self;
    }

    pub fn randomiseSelection(self: *Self, seed: u64, num_card_choices: usize, num_cards_to_select: usize) void {
        self.cards_to_select = num_cards_to_select;
        var rng = std.rand.DefaultPrng.init(seed);
        self.cards.clearRetainingCapacity();
        {
            const num_cards_per_row: f32 = 4;
            const cards_row_width = (num_cards_per_row * CARD_SIZE.x) + ((num_cards_per_row - 1) * CARD_PADDING);
            const cards_x_offset = (SELECTION_SIZE.x - cards_row_width) / 2;
            var row: f32 = 0;
            for (0..num_card_choices) |i| {
                if (i > 0 and i % @as(usize, @intFromFloat(num_cards_per_row)) == 0) row += 1;
                const fi: f32 = @as(f32, @floatFromInt(i)) - (row * num_cards_per_row);
                const position = Vec2{
                    .x = cards_x_offset + (fi * (CARD_SIZE.x + CARD_PADDING)),
                    .y = CARDS_Y_OFFSET + (row * (CARD_SIZE.y + CARD_PADDING)),
                };
                const effect = SCORE_EFFECTS[rng.random().uintLessThan(usize, SCORE_EFFECTS.len)];
                const reward = if (effect.isQuest()) randomQuestReward(true, rng.random()) else null;
                self.cards.append(.{
                    .button = .{
                        .rect = .{
                            .position = SELECTION_POS.add(position),
                            .size = CARD_SIZE,
                        },
                        .text = "",
                        .value = 0,
                    },
                    .effect = .{ .effect = effect, .reward = reward },
                }) catch unreachable;
            }
        }
    }

    fn updateMouseInputs(self: *Self, mouse: MouseState) void {
        for (self.cards.items) |*card| card.button.update(mouse);
        if (mouse.l_button.is_clicked) {
            for (self.cards.items) |*card| {
                if (card.button.contains(mouse.current_pos)) card.selected = !card.selected;
            }
        }
        var cards_selected: usize = 0;
        for (self.cards.items) |card| cards_selected += if (card.selected) 1 else 0;
        self.cards_correct = (cards_selected == self.cards_to_select) or (cards_selected == self.cards.items.len);
        self.start.enabled = self.cards_correct;
        self.start.update(mouse);
    }
};

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
    effect_drag: struct {
        effect_index: usize,
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
    effects: std.ArrayList(ScoreEffect),
    selection: SelectEffects,
    show_final_screen: bool = false,
    reset_button: Button,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var self = Self{
            .haathi = haathi,
            .phalanx = Phalanx.init(allocator, arena_handle.allocator()),
            .buttons = std.ArrayList(Button).init(allocator),
            .effects = std.ArrayList(ScoreEffect).init(allocator),
            .selection = SelectEffects.init(allocator),
            .allocator = allocator,
            .reset_button = .{
                .rect = .{
                    .position = .{
                        .x = SELECTION_POS.x + SELECTION_SIZE.x + 40,
                        .y = SELECTION_POS.y + SELECTION_SIZE.y - 30 - 20,
                    },
                    .size = .{ .x = 180, .y = 30 },
                },
                .value = 0,
                .text = "Restart Game",
            },
            .arena_handle = arena_handle,
            .arena = arena_handle.allocator(),
        };
        self.setup();
        return self;
    }

    fn resetGame(self: *Self) void {
        self.phalanx.deinit();
        self.phalanx = Phalanx.init(self.allocator, self.arena);
        self.selection.enabled = true;
        self.selection.randomiseSelection(self.ticks, self.phalanx.card_choices, self.phalanx.cards_to_select);
        self.show_final_screen = false;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    fn setup(self: *Self) void {
        self.selection.randomiseSelection(helpers.milliTimestamp(), self.phalanx.card_choices, self.phalanx.cards_to_select);
    }

    fn resetButtons(self: *Self) void {
        self.buttons.clearRetainingCapacity();
        var y: f32 = BUTTON_START_Y;
        for (self.phalanx.score_effects.items, 0..) |effect, i| {
            if (effect.effect.pinSpecific() and effect.index == null) {
                self.buttons.append(.{
                    .rect = .{
                        .position = .{ .x = BUTTON_START_X, .y = y },
                        .size = BUTTON_SIZE,
                    },
                    .value = @intCast(i),
                    .text = @tagName(effect.effect),
                }) catch unreachable;
                y += BUTTON_PADDING + BUTTON_SIZE.y;
            }
        }
    }

    pub fn update(self: *Self, ticks: u64) void {
        _ = self.arena_handle.reset(.retain_capacity);
        self.arena = self.arena_handle.allocator();
        self.ticks = ticks;
        self.phalanx.update(self.arena, self.ticks);
        if (self.haathi.inputs.getKey(.space).is_clicked) self.phalanx.throwBall();
        if (self.haathi.inputs.getKey(.s).is_clicked) self.phalanx.simulationStep();
        if (self.haathi.inputs.getKey(.a).is_clicked) self.phalanx.changeBallCol(-1);
        if (self.haathi.inputs.getKey(.d).is_clicked) self.phalanx.changeBallCol(1);
        if (self.haathi.inputs.getKey(.p).is_clicked) self.phalanx.addFrame();
        if (self.haathi.inputs.getKey(.o).is_clicked) self.phalanx.addPinRow();
        if (self.haathi.inputs.getKey(.i).is_clicked) {
            self.phalanx.card_choices += 1;
            self.selection.randomiseSelection(self.ticks, self.phalanx.card_choices, self.phalanx.cards_to_select);
        }
        if (self.phalanx.frame_just_complete) {
            if (self.phalanx.active_frame == self.phalanx.total_num_frames) {
                self.show_final_screen = true;
            } else {
                self.phalanx.frame_just_complete = false;
                self.selection.randomiseSelection(self.ticks, self.phalanx.card_choices, self.phalanx.cards_to_select);
                self.selection.enabled = true;
            }
        }
        self.updateMouseInputs();
    }

    fn loadSelectedEffects(self: *Self) void {
        self.selection.enabled = false;
        self.phalanx.loadSelectedEffects(self.selection);
        self.resetButtons();
    }

    fn updateMouseInputs(self: *Self) void {
        const mouse = self.haathi.inputs.mouse;
        for (self.buttons.items) |*button| button.update(self.haathi.inputs.mouse);
        self.reset_button.update(mouse);
        if (self.reset_button.clicked) {
            self.resetGame();
        }
        if (self.selection.enabled) {
            self.selection.updateMouseInputs(mouse);
            if (self.selection.start.clicked) self.loadSelectedEffects();
            return;
        }
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
                        const effect_index: usize = @intCast(self.buttons.items[hi].value);
                        self.state = .{ .effect_drag = .{ .effect_index = effect_index } };
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
                        self.phalanx.applyPinEffect(data.effect_index, pi);
                        self.phalanx.checkCanThrow();
                        self.resetButtons();
                    }
                    self.state = .{ .idle = .{} };
                }
            },
        }
    }

    fn renderCard(self: *Self, card: EffectCard) void {
        if (card.button.hovered) {
            self.haathi.drawRect(.{
                .position = card.button.rect.position.add(.{ .x = -4, .y = -4 }),
                .size = card.button.rect.size.add(.{ .x = 8, .y = 8 }),
                .color = colors.endesga_grey2,
                .radius = 9,
            });
        }
        if (card.selected) {
            self.haathi.drawRect(.{
                .position = card.button.rect.position.add(.{ .x = -4, .y = -4 }),
                .size = card.button.rect.size.add(.{ .x = 8, .y = 8 }),
                .color = colors.endesga_grey1,
                .radius = 9,
            });
        }
        self.haathi.drawRect(.{
            .position = card.button.rect.position,
            .size = card.button.rect.size,
            .color = colors.endesga_grey3,
            .radius = 5,
        });
        self.haathi.drawText(.{
            .text = @tagName(card.effect.effect),
            .position = card.button.rect.position.add(.{ .x = card.button.rect.size.x / 2, .y = 22 }),
            .color = colors.endesga_grey1,
        });
        if (card.effect.reward) |reward| {
            self.haathi.drawText(.{
                .text = @tagName(reward.reward),
                .position = card.button.rect.position.add(.{ .x = card.button.rect.size.x / 2, .y = 42 }),
                .color = colors.endesga_grey1,
                .style = SCORE1,
            });
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = colors.endesga_grey1,
        });
        const ball_size = self.phalanx.pin_scale * PIN_SPACING * 0.8;
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
            const pin_color = if (pin.fallen()) colors.endesga_grey2 else colors.endesga_grey4;
            self.haathi.drawRect(.{
                .position = pin.position,
                .size = .{ .x = pin.size, .y = pin.size },
                .color = pin_color,
                .centered = true,
                .radius = pin.size,
            });
            if (pin.just_fallen) {
                if (pin.fallen_dir) |dir| {
                    const xdir: f32 = @floatFromInt(dir.x);
                    var points = self.arena.alloc(Vec2, 3) catch unreachable;
                    points[0] = pin.position.add(.{ .x = -pin.size * 0.5, .y = xdir * -pin.size * 0.5 * @cos(std.math.pi / 6.0) });
                    points[1] = pin.position.add(.{ .x = pin.size * 0.5, .y = xdir * pin.size * 0.5 * @cos(std.math.pi / 6.0) });
                    points[2] = pin.position.add(.{ .x = xdir * PIN_SPACING * 0.5, .y = -PIN_SPACING * @cos(std.math.pi / 6.0) });
                    self.haathi.drawPoly(.{
                        .points = points,
                        .color = colors.endesga_grey3,
                    });
                }
            }
            if (false) {
                const pin_pos = std.fmt.allocPrintZ(self.arena, "{d},{d}", .{ pin.address.x, pin.address.y }) catch unreachable;
                self.haathi.drawText(.{
                    .text = pin_pos,
                    .position = pin.position.add(.{ .y = 6 }),
                    .color = colors.endesga_grey0,
                });
            }
            if (!pin.fallen() and pin.value != 1) {
                const val = std.fmt.allocPrintZ(self.arena, "{d}", .{pin.value}) catch unreachable;
                self.haathi.drawText(.{
                    .text = val,
                    .position = pin.position.add(.{ .y = 4 }),
                    .color = colors.endesga_grey0,
                    .style = PIN_VALUE_STYLE,
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
                    .position = self.phalanx.ball.position.add(.{ .y = 2 }),
                    .color = colors.endesga_grey0,
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
                    .text = @tagName(self.phalanx.score_effects.items[data.effect_index].effect),
                    .position = self.haathi.inputs.mouse.current_pos,
                    .color = colors.endesga_grey0,
                    .alignment = .left,
                });
            },
            else => {},
        }
        // for (self.phalanx.score_effects.items) |effect| {
        //     if (effect.effect != .shield) continue;
        //     if (effect.index == null) continue;
        //     const pin = self.phalanx.pins.items[effect.index.?];
        //     self.haathi.drawRect(.{
        //         .position = pin.position,
        //         .size = .{ .x = pin.size, .y = pin.size },
        //         .color = colors.endesga_grey6,
        //         .centered = true,
        //         .radius = pin.size,
        //     });
        //     self.haathi.drawText(.{
        //         .text = @tagName(effect.effect),
        //         .position = pin.position,
        //         .color = colors.endesga_grey0,
        //         .alignment = .left,
        //     });
        // }
        {
            const ACTIVE_CARD_ROW_X = 40 + SELECTION_SIZE.x;
            const ACTIVE_CARD_WIDTH = SCREEN_SIZE.x - ACTIVE_CARD_ROW_X - 20;
            const ACTIVE_CARD_HEIGHT = SELECTION_SIZE.y + SELECTION_POS.y - 20;
            const ACTIVE_CARD_CENTER_X = ACTIVE_CARD_ROW_X + (ACTIVE_CARD_WIDTH / 2);
            self.haathi.drawText(.{
                .text = "Active Cards",
                .position = .{ .x = ACTIVE_CARD_CENTER_X, .y = 20 + 24 },
                .color = colors.endesga_grey4,
            });
            self.haathi.drawRect(.{
                .position = .{ .x = ACTIVE_CARD_ROW_X, .y = 20 },
                .size = .{ .x = ACTIVE_CARD_WIDTH, .y = ACTIVE_CARD_HEIGHT },
                .color = colors.endesga_grey4.alpha(0.2),
                .radius = 4,
            });
            const card_padding = 10;
            const card_height = 32;
            for (self.phalanx.score_effects.items, 0..) |effect, i| {
                const fi: f32 = @floatFromInt(i);
                const y = 54 + (fi * (card_padding + card_height));
                self.haathi.drawRect(.{
                    .position = .{ .x = ACTIVE_CARD_ROW_X + 10, .y = y },
                    .size = .{ .x = ACTIVE_CARD_WIDTH - 20, .y = card_height },
                    .color = colors.endesga_grey2,
                    .radius = 4,
                });
                if (effect.index) |pin_index| {
                    const pos = self.phalanx.pins.items[pin_index].position;
                    var points = self.arena.alloc(Vec2, 4) catch unreachable;
                    points[0] = pos.add(.{ .y = 3 });
                    points[1] = .{ .x = ACTIVE_CARD_ROW_X + 10, .y = y + (card_height / 2) + 3 };
                    points[2] = .{ .x = ACTIVE_CARD_ROW_X + 10, .y = y + (card_height / 2) - 3 };
                    points[3] = pos.add(.{ .y = -3 });
                    self.haathi.drawPoly(.{
                        .points = points,
                        .color = colors.endesga_grey2,
                    });
                }
                self.haathi.drawText(.{
                    .text = @tagName(effect.effect),
                    .position = .{ .x = ACTIVE_CARD_CENTER_X, .y = y + 14 },
                    .color = colors.endesga_grey5,
                    .style = PIN_VALUE_STYLE,
                });
                if (effect.reward) |reward| {
                    self.haathi.drawText(.{
                        .text = @tagName(reward.reward),
                        .position = .{ .x = ACTIVE_CARD_CENTER_X - (ACTIVE_CARD_WIDTH / 5), .y = y + 14 + 14 },
                        .color = colors.endesga_grey5,
                        .style = PIN_VALUE_STYLE,
                    });
                    const status = if (effect.completed) "Completed" else "Incomplete";
                    self.haathi.drawText(.{
                        .text = status,
                        .position = .{ .x = ACTIVE_CARD_CENTER_X + (ACTIVE_CARD_WIDTH / 4), .y = y + 14 + 14 },
                        .color = colors.endesga_grey5,
                        .style = PIN_VALUE_STYLE,
                    });
                }
            }
        }
        {
            // draw scorecard.
            const frame_size = if (self.phalanx.total_num_frames <= 13) DEFAULT_FRAME_SIZE else SCREEN_SIZE.x / @as(f32, @floatFromInt(self.phalanx.total_num_frames)) / 1.1;
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
                        {
                            const mul = std.fmt.allocPrintZ(self.arena, "x{d}", .{frame.multiplier}) catch unreachable;
                            self.haathi.drawText(.{
                                .position = .{ .x = x + (frame_size * 0.5), .y = y + frame_padding + (frame_size * 0.4) + 6 },
                                .text = mul,
                                .color = colors.endesga_grey5.alpha(0.6),
                                .style = SCORE1,
                            });
                        }
                    }
                    if (frame.total) |total| {
                        const cscore = std.fmt.allocPrintZ(self.arena, "+{d}", .{total}) catch unreachable;
                        self.haathi.drawText(.{
                            .position = .{ .x = x + (frame_size * 0.5), .y = y + frame_padding + (frame_size * 0.56) + 6 },
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
        if (self.show_final_screen) {
            self.haathi.drawRect(.{
                .position = SELECTION_POS,
                .size = SELECTION_SIZE.add(.{ .y = -200 }),
                .color = colors.endesga_grey5,
                .radius = 5,
            });
            self.haathi.drawText(.{
                .text = "Your game of bowling is complete.",
                .position = SELECTION_POS.add(.{ .x = SELECTION_SIZE.x / 2, .y = CARDS_Y_OFFSET - 20 }),
                .color = colors.endesga_grey1,
            });
            const score = std.fmt.allocPrintZ(self.arena, "You scored {d} points", .{self.phalanx.total_score}) catch unreachable;
            self.haathi.drawText(.{
                .text = score,
                .position = SELECTION_POS.add(.{ .x = SELECTION_SIZE.x / 2, .y = CARDS_Y_OFFSET - 20 + 40 }),
                .color = colors.endesga_grey1,
            });
        }
        if (self.selection.enabled) {
            self.haathi.drawRect(.{
                .position = SELECTION_POS,
                .size = SELECTION_SIZE,
                .color = colors.endesga_grey5,
                .radius = 5,
            });
            const card_select_color = if (self.selection.cards_correct) colors.endesga_grey0 else colors.endesga_red1;
            const select_text = std.fmt.allocPrintZ(self.arena, "Select {d} cards", .{self.phalanx.cards_to_select}) catch unreachable;
            self.haathi.drawText(.{
                .text = select_text,
                .position = SELECTION_POS.add(.{ .x = SELECTION_SIZE.x / 2, .y = CARDS_Y_OFFSET - 20 }),
                .color = card_select_color,
            });
            for (self.selection.cards.items) |card| self.renderCard(card);
            {
                const start_button = self.selection.start;
                if (start_button.hovered) {
                    self.haathi.drawRect(.{
                        .position = start_button.rect.position.add(.{ .x = -4, .y = -4 }),
                        .size = start_button.rect.size.add(.{ .x = 8, .y = 8 }),
                        .color = colors.endesga_grey0,
                        .radius = 9,
                    });
                }
                self.haathi.drawRect(.{
                    .position = start_button.rect.position,
                    .size = start_button.rect.size,
                    .color = colors.endesga_grey4,
                    .radius = 5,
                });
                const text_color = if (start_button.enabled) colors.endesga_grey0 else colors.endesga_red1;
                self.haathi.drawText(.{
                    .text = start_button.text,
                    .position = start_button.rect.position.add(start_button.rect.size.scale(0.5)).add(.{ .y = 6 }),
                    .color = text_color,
                });
            }
        }
        {
            if (self.reset_button.hovered) {
                self.haathi.drawRect(.{
                    .position = self.reset_button.rect.position.add(.{ .x = -4, .y = -4 }),
                    .size = self.reset_button.rect.size.add(.{ .x = 8, .y = 8 }),
                    .color = colors.endesga_grey1,
                    .radius = 9,
                });
            }
            self.haathi.drawRect(.{
                .position = self.reset_button.rect.position,
                .size = self.reset_button.rect.size,
                .color = colors.endesga_grey2,
                .radius = 5,
            });
            const text_color = colors.endesga_grey1;
            self.haathi.drawText(.{
                .text = self.reset_button.text,
                .position = self.reset_button.rect.position.add(self.reset_button.rect.size.scale(0.5)).add(.{ .y = 6 }),
                .color = text_color,
            });
        }
    }
};
