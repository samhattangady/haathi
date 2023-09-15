const Sprite = @import("haathi.zig").Sprite;
pub const POINTER = Sprite{ .path = "sprites/pointer.png", .anchor = .{ .x = 0, .y = 0 }, .size = .{ .x = 64, .y = 64 } };
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
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 256, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 256, .y = 64 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 256, .y = 128 }, .size = .{ .x = 64, .y = 64 } },
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 256, .y = 192 }, .size = .{ .x = 64, .y = 64 } },
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
    .{ .path = "sprites/Tilemap_Flat.png", .anchor = .{ .x = 320, .y = 0 }, .size = .{ .x = 64, .y = 64 } },
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
