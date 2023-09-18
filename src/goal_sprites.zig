const helpers = @import("helpers.zig");
const Vec2 = helpers.Vec2;
const Sprite = @import("haathi.zig").Sprite;

pub const BLANK = Sprite{ .path = "sprites/pointer.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 0, .y = 0 } };
pub const POINTER = Sprite{ .path = "sprites/pointer.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } };
pub const POINTER_RED = Sprite{ .path = "sprites/pointer_red.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } };
pub const TERRAIN_SPRITES = [_]Sprite{
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 0, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 0, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 0, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 64, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 64, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 64, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 64, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 128, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 128, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 128, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 128, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 192, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 192, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 192, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 192, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    // sand
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 320, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 320, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 320, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 320, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 384, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 384, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 384, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 384, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 448, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 448, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 448, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 448, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 512, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 512, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 512, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 512, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
    // tufts
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 256, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 576, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
};

/// send in request where bool is whether the direction is an edge.
pub fn terrain_grass(up: bool, down: bool, left: bool, right: bool) Sprite {
    const iu = up;
    const id = down;
    const il = left;
    const ir = right;
    const nu = !up;
    const nd = !down;
    const nl = !left;
    const nr = !right;
    // so that we share with sand
    const base = 0;
    // up border
    if (iu and id and il and ir) return TERRAIN_SPRITES[base + 15];
    if (iu and id and il and nr) return TERRAIN_SPRITES[base + 3];
    if (iu and id and nl and ir) return TERRAIN_SPRITES[base + 11];
    if (iu and id and nl and nr) return TERRAIN_SPRITES[base + 7];
    if (iu and nd and il and ir) return TERRAIN_SPRITES[base + 12];
    if (iu and nd and il and nr) return TERRAIN_SPRITES[base + 0];
    if (iu and nd and nl and ir) return TERRAIN_SPRITES[base + 8];
    if (iu and nd and nl and nr) return TERRAIN_SPRITES[base + 4];
    // no up border
    if (nu and id and il and ir) return TERRAIN_SPRITES[base + 14];
    if (nu and id and il and nr) return TERRAIN_SPRITES[base + 2];
    if (nu and id and nl and ir) return TERRAIN_SPRITES[base + 10];
    if (nu and id and nl and nr) return TERRAIN_SPRITES[base + 6];
    if (nu and nd and il and ir) return TERRAIN_SPRITES[base + 13];
    if (nu and nd and il and nr) return TERRAIN_SPRITES[base + 1];
    if (nu and nd and nl and ir) return TERRAIN_SPRITES[base + 9];
    if (nu and nd and nl and nr) return TERRAIN_SPRITES[base + 5];
    unreachable;
}

/// send in request where bool is whether the direction is an edge.
pub fn terrain_sand(up: bool, down: bool, left: bool, right: bool) Sprite {
    const iu = up;
    const id = down;
    const il = left;
    const ir = right;
    const nu = !up;
    const nd = !down;
    const nl = !left;
    const nr = !right;
    // so that we share with sand
    const base = 16;
    // up border
    if (iu and id and il and ir) return TERRAIN_SPRITES[base + 15];
    if (iu and id and il and nr) return TERRAIN_SPRITES[base + 3];
    if (iu and id and nl and ir) return TERRAIN_SPRITES[base + 11];
    if (iu and id and nl and nr) return TERRAIN_SPRITES[base + 7];
    if (iu and nd and il and ir) return TERRAIN_SPRITES[base + 12];
    if (iu and nd and il and nr) return TERRAIN_SPRITES[base + 0];
    if (iu and nd and nl and ir) return TERRAIN_SPRITES[base + 8];
    if (iu and nd and nl and nr) return TERRAIN_SPRITES[base + 4];
    // no up border
    if (nu and id and il and ir) return TERRAIN_SPRITES[base + 14];
    if (nu and id and il and nr) return TERRAIN_SPRITES[base + 2];
    if (nu and id and nl and ir) return TERRAIN_SPRITES[base + 10];
    if (nu and id and nl and nr) return TERRAIN_SPRITES[base + 6];
    if (nu and nd and il and ir) return TERRAIN_SPRITES[base + 13];
    if (nu and nd and il and nr) return TERRAIN_SPRITES[base + 1];
    if (nu and nd and nl and ir) return TERRAIN_SPRITES[base + 9];
    if (nu and nd and nl and nr) return TERRAIN_SPRITES[base + 5];
    unreachable;
}

const BLUE_PLAYER = [_]Sprite{
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 0, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 192, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 384, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 576, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 768, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Blue.png", .anchor = .{ .x = 960, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
};

pub fn blue_player(moving: bool) [6]Sprite {
    if (!moving) return [6]Sprite{
        BLUE_PLAYER[0],
        BLUE_PLAYER[6],
        BLUE_PLAYER[12],
        BLUE_PLAYER[18],
        BLUE_PLAYER[24],
        BLUE_PLAYER[30],
    } else return [6]Sprite{
        BLUE_PLAYER[1],
        BLUE_PLAYER[7],
        BLUE_PLAYER[13],
        BLUE_PLAYER[19],
        BLUE_PLAYER[25],
        BLUE_PLAYER[31],
    };
}

const RED_PLAYER = [_]Sprite{
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 0, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 192, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 384, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 576, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 768, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 192 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 384 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 576 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 768 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Pawn_Red.png", .anchor = .{ .x = 960, .y = 960 }, .size = .{ .x = 192, .y = 192 } },
};

pub fn red_player(moving: bool) [6]Sprite {
    if (!moving) return [6]Sprite{
        RED_PLAYER[30],
        RED_PLAYER[24],
        RED_PLAYER[18],
        RED_PLAYER[12],
        RED_PLAYER[6],
        RED_PLAYER[0],
    } else return [6]Sprite{
        RED_PLAYER[1],
        RED_PLAYER[7],
        RED_PLAYER[13],
        RED_PLAYER[19],
        RED_PLAYER[25],
        RED_PLAYER[31],
    };
}

pub fn player_swing() [6]Sprite {
    const row = 2;
    return [6]Sprite{
        RED_PLAYER[row + 30],
        RED_PLAYER[row + 24],
        RED_PLAYER[row + 18],
        RED_PLAYER[row + 12],
        RED_PLAYER[row + 6],
        RED_PLAYER[row + 0],
    };
}

pub const TARGETS = [_]Sprite{
    .{ .path = "sprites/marker_1.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/marker_2.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/marker_3.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/marker_4.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
};
pub const TARGET_OFFSETS = [_]Vec2{
    .{ .x = -32, .y = -32 },
    .{ .x = 32, .y = -32 },
    .{ .x = -32, .y = 32 },
    .{ .x = 32, .y = 32 },
};

pub const FOAM = [_]Sprite{
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 0 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 1 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 2 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 3 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 4 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 5 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 6 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
    .{ .path = "sprites/Foam.png", .anchor = .{ .x = 7 * 192, .y = 0 }, .size = .{ .x = 192, .y = 192 } },
};
pub const BALL = [_]Sprite{
    .{ .path = "sprites/Ball.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Ball.png", .anchor = .{ .x = 64, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
};

pub const BANNERS = [_]Sprite{
    // folds on left and right - top
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 192, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 256, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 512, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    // folds on left and right - mid
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 192, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 256, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 512, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    // folds on left and right - mid
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 192, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 256, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners.png", .anchor = .{ .x = 512, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
};

pub const BANNERS_SHADOW = [_]Sprite{
    // folds on left and right - top
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 192, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 256, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 512, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    // folds on left and right - mid
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 192, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 256, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 512, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    // folds on left and right - mid
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 192, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 256, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Banners_Shadow.png", .anchor = .{ .x = 512, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
};
pub const BUTTONS = [_]Sprite{
    .{ .path = "sprites/Button_Red.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_Pressed.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides.png", .anchor = .{ .x = 64, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides.png", .anchor = .{ .x = 128, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides_Pressed.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides_Pressed.png", .anchor = .{ .x = 64, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Red_3Slides_Pressed.png", .anchor = .{ .x = 128, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Shadow.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Shadow.png", .anchor = .{ .x = 64, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Button_Shadow.png", .anchor = .{ .x = 128, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
};

pub const ROCKS = Sprite{ .path = "sprites/Rocks.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } };

pub const ELEVATION = [_]Sprite{
    .{ .path = "sprites/Tilemap_Elevation.png", .anchor = .{ .x = 192, .y = 256 }, .size = .{ .x = 64, .y = 128 } },
};

pub const ARROWS = [_]Sprite{
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 0 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 1 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 2 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 3 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 4 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 5 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 6 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
    .{ .path = "sprites/arrows.png", .anchor = .{ .x = 7 * 24, .y = 0 }, .size = .{ .x = 24, .y = 24 } },
};
