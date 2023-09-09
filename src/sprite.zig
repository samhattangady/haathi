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
const Sprite = @import("haathi.zig").Sprite;

const StateData = union(enum) {
    idle: struct {
        index: ?usize = null,
    },
    idle_drag: void,
};

const SPRITES = loadSprites();

fn loadSprites() [7]Sprite {
    var sprites: [7]Sprite = undefined;
    for (0..7) |i| {
        const fi: f32 = @floatFromInt(i);
        sprites[i] = .{
            .path = "run.png",
            .size = .{ .x = 48, .y = 48 },
            .anchor = .{ .x = 48 * fi, .y = 0 },
        };
    }
    return sprites;
}

pub const Game = struct {
    const Self = @This();
    haathi: *Haathi,
    ticks: u64 = 0,
    state: StateData = .{ .idle = .{} },
    sprite_index: usize = 0,
    last_sprite_update: u64 = 0,
    song_playing: bool = false,
    song_volume: f32 = 1,

    allocator: std.mem.Allocator,
    arena_handle: std.heap.ArenaAllocator,
    arena: std.mem.Allocator,

    pub fn init(haathi: *Haathi) Self {
        const allocator = haathi.allocator;
        var arena_handle = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        haathi.loadSound("ocean.mp3", true);
        haathi.loadSound("pop.mp3", false);
        return .{
            .haathi = haathi,
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
        if (self.ticks - self.last_sprite_update > 100) {
            self.last_sprite_update = self.ticks;
            self.sprite_index += 1;
            if (self.sprite_index == 7) self.sprite_index = 0;
        }
        if (self.haathi.inputs.getKey(.s).is_clicked) {
            self.haathi.playSound("pop.mp3", true);
        }
        if (self.haathi.inputs.getKey(.space).is_clicked) {
            self.song_playing = !self.song_playing;
            if (self.song_playing) {
                self.haathi.pauseSound("ocean.mp3");
            } else {
                self.haathi.playSound("ocean.mp3", false);
            }
        }
        if (self.haathi.inputs.mouse.wheel_y != 0) {
            if (self.haathi.inputs.mouse.wheel_y < 0) {
                self.song_volume = @min(self.song_volume * 1.1, 1);
            } else {
                self.song_volume = @max(self.song_volume / 1.1, 0);
            }
            self.haathi.setSoundVolume("ocean.mp3", self.song_volume);
        }
    }

    pub fn render(self: *Self) void {
        self.haathi.drawRect(.{
            .position = .{},
            .size = SCREEN_SIZE,
            .color = Vec4.fromHexRgb("#111111"),
        });
        self.haathi.drawSprite(.{
            .sprite = SPRITES[self.sprite_index],
            .position = SCREEN_SIZE.scale(0.5),
            .scale = 2,
        });
    }
};
