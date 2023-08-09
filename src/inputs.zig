const std = @import("std");
const c = @import("interface.zig");

const helpers = @import("helpers.zig");
const Frame = helpers.Frame;
const Vec2 = helpers.Vec2;
const TYPING_BUFFER_SIZE = 16;

pub const Key = enum {
    const Self = @This();
    space,
    alt,
    control,
    shift,
    enter,
    tab,
    arrowdown,
    arrowup,
    arrowleft,
    arrowright,
    backspace,
    delete,
    escape,
    meta,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    num_1,
    num_2,
    num_3,
    num_4,
    num_5,
    num_6,
    num_7,
    num_8,
    num_9,
    num_0,
    open_bracket,
    close_bracket,
    semi_colon,
    quote,
    backslash,
    slash,
    period,
    comma,
    tilde,
    any_key,
    not_supported,

    pub fn fromInt(val: anytype) Self {
        comptime std.debug.assert(@typeInfo(@TypeOf(val)) == .Int);
        if (val < 0) return .not_supported;
        if (val >= @typeInfo(Self).Enum.fields.len) return .not_supported;
        return std.meta.intToEnum(Self, val) catch unreachable;
    }

    pub fn toInt(key: *const Self) usize {
        return @intFromEnum(key.*);
    }
};
const NUM_KEYS = @typeInfo(Key).Enum.fields.len;

pub const Inputs = struct {
    const Self = @This();
    keys: [NUM_KEYS]SingleInput = [_]SingleInput{.{}} ** NUM_KEYS,
    mouse: MouseState = MouseState{},
    typed: [TYPING_BUFFER_SIZE]u8 = [_]u8{0} ** TYPING_BUFFER_SIZE,
    num_typed: usize = 0,

    pub fn getKey(self: *Self, key: Key) *SingleInput {
        return &self.keys[key.toInt()];
    }

    pub fn getConstKey(self: *const Self, key: Key) *const SingleInput {
        return &self.keys[key.toInt()];
    }

    pub fn typeKey(self: *Self, k: u8) void {
        if (self.num_typed >= TYPING_BUFFER_SIZE) {
            helpers.debugPrint("Typing buffer already filled.\n", .{});
            return;
        }
        self.typed[self.num_typed] = k;
        self.num_typed += 1;
    }

    pub fn reset(self: *Self) void {
        for (&self.keys) |*key| key.reset();
        self.mouse.resetMouse();
        self.num_typed = 0;
    }

    pub fn handleKeyDown(self: *Self, code: u32, ticks: u64) void {
        self.getKey(Key.fromInt(code)).setDown(ticks);
        self.getKey(.any_key).setDown(ticks);
    }

    pub fn handleKeyUp(self: *Self, code: u32, ticks: u64) void {
        _ = ticks;
        self.getKey(Key.fromInt(code)).setRelease();
        self.getKey(.any_key).setRelease();
    }
    pub fn handleMouseMove(self: *Self, x: i32, y: i32) void {
        self.mouse.handleMouseMove(x, y);
    }
    pub fn handleMouseDown(self: *Self, code: i32, ticks: u64) void {
        self.mouse.handleMouseDown(code, ticks);
    }
    pub fn handleMouseUp(self: *Self, code: i32, ticks: u64) void {
        self.mouse.handleMouseUp(code, ticks);
    }
    pub fn handleMouseWheel(self: *Self, y: i32) void {
        self.mouse.handleMouseWheel(y);
    }
};

pub const SingleInput = struct {
    is_down: bool = false,
    is_clicked: bool = false, // For one frame when key is pressed
    is_released: bool = false, // For one frame when key is released
    down_from: u64 = 0,

    pub fn reset(self: *SingleInput) void {
        self.is_clicked = false;
        self.is_released = false;
    }

    pub fn setDown(self: *SingleInput, ticks: u64) void {
        self.is_down = true;
        self.is_clicked = true;
        self.down_from = ticks;
    }

    pub fn setRelease(self: *SingleInput) void {
        self.is_down = false;
        self.is_released = true;
    }
};

pub const MouseState = struct {
    const Self = @This();
    current_pos: Vec2 = .{},
    previous_pos: Vec2 = .{},
    l_down_pos: Vec2 = .{},
    r_down_pos: Vec2 = .{},
    m_down_pos: Vec2 = .{},
    l_button: SingleInput = .{},
    r_button: SingleInput = .{},
    m_button: SingleInput = .{},
    wheel_y: i32 = 0,

    pub fn resetMouse(self: *Self) void {
        self.previous_pos = self.current_pos;
        self.l_button.reset();
        self.r_button.reset();
        self.m_button.reset();
        self.wheel_y = 0;
    }

    pub fn lSinglePosClick(self: *Self) bool {
        if (self.l_button.is_released == false) return false;
        if (self.l_down_pos.distanceToSqr(self.current_pos) == 0) return true;
        return false;
    }

    pub fn lMoved(self: *Self) bool {
        return (self.l_down_pos.distanceToSqr(self.current_pos) > 0);
    }

    pub fn movement(self: *Self) Vec2 {
        return Vec2.subtract(self.previous_pos, self.current_pos);
    }

    pub fn handleMouseDown(self: *Self, code: i32, ticks: u64) void {
        const button = switch (code) {
            0 => &self.l_button,
            1 => &self.m_button,
            2 => &self.r_button,
            else => &self.l_button,
        };
        const pos = switch (code) {
            0 => &self.l_down_pos,
            1 => &self.m_down_pos,
            2 => &self.r_down_pos,
            else => &self.l_down_pos,
        };
        button.setDown(ticks);
        pos.* = self.current_pos;
    }

    pub fn handleMouseUp(self: *Self, code: i32, ticks: u64) void {
        const button = switch (code) {
            0 => &self.l_button,
            1 => &self.m_button,
            2 => &self.r_button,
            else => &self.l_button,
        };
        button.setRelease();
        _ = ticks;
    }

    pub fn handleMouseWheel(self: *Self, y: i32) void {
        self.wheel_y += std.math.sign(y);
    }

    pub fn handleMouseMove(self: *Self, x: i32, y: i32) void {
        self.current_pos = Vec2.fromInts(x, y);
    }
};

pub const Button = struct {
    const Self = @This();
    position: Vec2 = .{},
    size: Vec2 = .{},
    text: []const u8 = "",
    mouse_over: bool = false,
    hovered: bool = false,
    disabled: bool = false,
    highlighted: bool = false,
    hidden: bool = false,
    /// mouse is down and was clicked down within the bounds of the button
    triggered: bool = false,
    /// mouse was clicked in button on this frame.
    just_clicked: bool = false,
    /// mouse was clicked and released within bounds of button
    clicked: bool = false,
    r_clicked: bool = false,
    m_clicked: bool = false,
    value: i8 = 0,

    pub fn update(self: *Self, mouse: *const MouseState, frame: Frame) void {
        if (self.disabled) return;
        self.mouse_over = self.inBounds(mouse.current_pos, frame);
        self.hovered = !mouse.l_button.is_down and self.mouse_over;
        self.clicked = mouse.l_button.is_released and self.inBounds(mouse.l_down_pos, frame) and self.inBounds(mouse.current_pos, frame);
        self.triggered = mouse.l_button.is_down and self.inBounds(mouse.l_down_pos, frame);
        self.just_clicked = mouse.l_button.is_clicked and self.inBounds(mouse.current_pos, frame);
        self.m_clicked = mouse.m_button.is_released and self.inBounds(mouse.m_down_pos, frame) and self.inBounds(mouse.current_pos, frame);
        self.r_clicked = mouse.r_button.is_released and self.inBounds(mouse.r_down_pos, frame) and self.inBounds(mouse.current_pos, frame);
    }

    // This is probably not needed because update state will have l_button.is_released as false anyway
    pub fn reset(self: *Self) void {
        self.clicked = false;
        self.r_clicked = false;
        self.m_clicked = false;
    }

    pub fn disable(self: *Self) void {
        self.disabled = true;
        self.hovered = false;
        self.triggered = false;
        self.clicked = false;
        self.r_clicked = false;
        self.m_clicked = false;
    }

    pub fn enable(self: *Self) void {
        self.disabled = false;
    }

    fn inBounds(self: *const Self, pos: Vec2, frame: Frame) bool {
        const world_pos = frame.fromScreenPos(pos);
        return helpers.inBoxCentered(world_pos, self.position, self.size);
    }
};
