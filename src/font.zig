//! haathi font is a tool that takes multiple fonts, and renders a qoi image
//! of them and a json atlas that can be then used again later. this allows
//! games to use fonts without needing to ship stb_truetype or other similar
//! libraries. Specifically useful for WASM and things.
//!
//! TODO (05 May 2023 sam): needs to support unicode...

const std = @import("std");
const c = @import("c.zig");
const font_path = "fonts/JetBrainsMono/ttf/JetBrainsMono-Light.ttf";
const out_path = "haathi.qoi";
const qoi = @import("qoi.zig");

const FONT_TEX_WIDTH = 100;
const FONT_TEX_HEIGHT = 100;
const CODEPOINT = 's';
const FONT_SIZE = 24;
const alpha = " .:ioVM@";

pub fn read_file_contents(path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const file_size = try file.getEndPos();
    const data = try file.readToEndAlloc(allocator, file_size);
    return data;
}

pub fn write_file_contents(path: []const u8, contents: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    _ = try file.writeAll(contents);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer {
        _ = gpa.deinit();
    }
    var font_info: c.stbtt_fontinfo = undefined;
    var font_data = read_file_contents(font_path, gpa.allocator()) catch unreachable;
    defer gpa.allocator().free(font_data);
    const init = c.stbtt_InitFont(&font_info, &font_data[0], 0);
    std.debug.print("init = {d}\n", .{init});
    const scale = c.stbtt_ScaleForPixelHeight(&font_info, FONT_SIZE);
    var width: i32 = undefined;
    var height: i32 = undefined;
    const char_bitmap = c.stbtt_GetCodepointBitmap(&font_info, scale, scale, CODEPOINT, &width, &height, 0, 0);
    var font_bitmap = gpa.allocator().alloc(qoi.Color, FONT_TEX_WIDTH * FONT_TEX_HEIGHT) catch unreachable;
    defer gpa.allocator().free(font_bitmap);
    const set_color = qoi.Color{ .r = 0, .g = 0, .b = 0 };
    @memset(font_bitmap, set_color);
    {
        // copy the bmp into the font
        var start_x: usize = 20;
        var start_y: usize = 20;
        var y: usize = 0;
        while (y < height) : (y += 1) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                const f_b_index = (x + start_x) + ((y + start_y) * FONT_TEX_WIDTH);
                const c_b_index = x + (y * @intCast(usize, width));
                std.debug.print("{c}", .{alpha[char_bitmap[c_b_index] >> 5]});
                font_bitmap[f_b_index] = .{
                    .r = char_bitmap[c_b_index],
                    .g = 0,
                    .b = 0,
                };
            }
            std.debug.print("\n", .{});
        }
    }
    var font_qoi_image = qoi.Image{
        .width = FONT_TEX_WIDTH,
        .height = FONT_TEX_HEIGHT,
        .pixels = font_bitmap,
        .colorspace = .sRGB,
    };
    var font_qoi = qoi.encodeBuffer(gpa.allocator(), font_qoi_image.asConst()) catch unreachable;
    defer gpa.allocator().free(font_qoi);
    write_file_contents(out_path, font_qoi) catch unreachable;
}
