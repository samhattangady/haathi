//! haathi font is a tool that takes multiple fonts, and renders a compressed image
//! of them and a json atlas that can be then used again later. this allows
//! games to use fonts without needing to ship stb_truetype or other similar
//! libraries. Specifically useful for WASM and things.
//!
//! TODO (05 May 2023 sam): needs to support unicode...

const std = @import("std");
const c = @import("c.zig");
const font_path = "fonts/JetBrainsMono/ttf/JetBrainsMono-Regular.ttf";
const out_path = "C:/Users/user/Antgineering/data/font_data.json";

const FONT_TEX_WIDTH = 512;
const FONT_TEX_HEIGHT = 512;
const CODEPOINT = 65;
const START_CODEPOINT = 32;
const END_CODEPOINT = 32 + 96;
const FONT_SIZE = 24;
const alpha = " .:ioVM@";
const PADDING = 1;

// desired output struct
// pub const Glyph = struct {
//     tex: [2]Vec2,
//     offsets: Vec2,
//     xadvance: f32,
// };

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

pub const BitmapData = struct {
    width: i32,
    height: i32,
    xoff: i32,
    yoff: i32,
    xadvance: f32,
    data: [*c]u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer {
        _ = gpa.deinit();
    }
    // load the fonts data stuffs
    var font_info: c.stbtt_fontinfo = undefined;
    var font_data = read_file_contents(font_path, gpa.allocator()) catch unreachable;
    defer gpa.allocator().free(font_data);
    _ = c.stbtt_InitFont(&font_info, &font_data[0], 0);
    const scale = c.stbtt_ScaleForPixelHeight(&font_info, FONT_SIZE);
    // TODO (10 May 2023 sam): This should contain the font enum as well.
    var bitmaps = std.AutoHashMap(usize, BitmapData).init(gpa.allocator());
    defer bitmaps.deinit();
    // load all the codepoints into their own bitmaps.
    for (START_CODEPOINT..END_CODEPOINT) |codepoint| {
        var bmp: BitmapData = undefined;
        bmp.data = c.stbtt_GetCodepointBitmap(&font_info, scale, scale, @intCast(i32, codepoint), &bmp.width, &bmp.height, &bmp.xoff, &bmp.yoff);
        // bmp.data = c.stbtt_GetCodepointSDF(&font_info, scale, @intCast(i32, codepoint), 1, 1, 1, &bmp.width, &bmp.height, &bmp.xoff, &bmp.yoff);
        var advance: i32 = undefined;
        c.stbtt_GetCodepointHMetrics(&font_info, @intCast(i32, codepoint), &advance, 0);
        bmp.xadvance = @intToFloat(f32, advance) * scale;
        bitmaps.put(codepoint, bmp) catch unreachable;
    }
    // pack all the rects within a texture
    var rects = std.ArrayList(c.stbrp_rect).init(gpa.allocator());
    defer rects.deinit();
    var codepoints = bitmaps.keyIterator();
    while (codepoints.next()) |codepoint| {
        const bmp = bitmaps.get(codepoint.*).?;
        rects.append(.{
            .id = @intCast(i32, codepoint.*),
            // add padding to the rects
            .w = bmp.width + PADDING,
            .h = bmp.height + PADDING,
            .x = 0,
            .y = 0,
            .was_packed = 0,
        }) catch unreachable;
    }
    {
        // TODO (10 May 2023 sam): This needs to be run multiple times to find the best texture map size.
        var packer_context: c.stbrp_context = undefined;
        var nodes = std.ArrayList(c.stbrp_node).init(gpa.allocator());
        defer nodes.deinit();
        for (0..rects.items.len) |_| {
            nodes.append(undefined) catch unreachable;
        }
        _ = c.stbrp_init_target(&packer_context, FONT_TEX_WIDTH, FONT_TEX_HEIGHT, &nodes.items[0], @intCast(i32, nodes.items.len));
        var was_packed = c.stbrp_pack_rects(&packer_context, &rects.items[0], @intCast(i32, rects.items.len));
        if (was_packed == 0) {}//std.debug.print("Could not pack rects \n", .{});
    }
    var font_bitmap = gpa.allocator().alloc(u8, FONT_TEX_WIDTH * FONT_TEX_HEIGHT) catch unreachable;
    defer gpa.allocator().free(font_bitmap);
    @memset(font_bitmap, 0);
    for (rects.items) |rect| {
        // copy the bmp into the font
        // The fonts are loaded in upside down. So we need to flip each char.
        const start_x = @intCast(usize, rect.x);
        const start_y = @intCast(usize, rect.y);
        const width = rect.w;
        const height = rect.h;
        const char_bitmap = bitmaps.get(@intCast(usize, rect.id)).?.data;
        defer c.stbtt_FreeBitmap(char_bitmap, null);
        var y: usize = 0;
        while (y < height - PADDING) : (y += 1) {
            var x: usize = 0;
            while (x < width - PADDING) : (x += 1) {
                const f_b_index = (x + start_x) + ((y + start_y) * FONT_TEX_WIDTH);
                const c_b_index = x + (y * @intCast(usize, width - PADDING));
                font_bitmap[f_b_index] = char_bitmap[c_b_index];
                // std.debug.print("{c}", .{alpha[char_bitmap[c_b_index] >> 5]});
            }
            // std.debug.print("\n", .{});
        }
    }
    var compressed = std.ArrayList(u8).init(gpa.allocator());
    defer compressed.deinit();
    var compressor = try std.compress.deflate.compressor(gpa.allocator(), compressed.writer(), .{ .level = .default_compression });
    _ = try compressor.write(font_bitmap);
    try compressor.close();
    compressor.deinit();
    // convert the compressed to base64
    var encoder = std.base64.standard.Encoder;
    var encoded = gpa.allocator().alloc(u8, encoder.calcSize(compressed.items.len)) catch unreachable;
    defer gpa.allocator().free(encoded);
    const encoded_string = encoder.encode(encoded, compressed.items);
    // write to file
    var stream = JsonStream.new(gpa.allocator());
    defer stream.deinit();
    var jser = stream.serializer();
    jser.whitespace = std.json.StringifyOptions.Whitespace{ .indent = .{ .Space = 2 } };
    var js = &jser;
    try js.beginObject();
    {
        try js.objectField("glyphs");
        try js.beginObject();
        for (rects.items) |rect| {
            const bmp = bitmaps.get(@intCast(usize, rect.id)).?;
            var buffer: [8]u8 = undefined;
            const field_name = std.fmt.bufPrint(&buffer, "{d}", .{rect.id}) catch unreachable;
            try js.objectField(field_name);
            try js.beginObject();
            {
                try js.objectField("x0");
                try js.emitNumber(@intToFloat(f32, rect.x) / FONT_TEX_WIDTH);
                try js.objectField("y0");
                try js.emitNumber(@intToFloat(f32, rect.y) / FONT_TEX_HEIGHT);
                try js.objectField("w");
                try js.emitNumber(rect.w - PADDING);
                try js.objectField("h");
                try js.emitNumber(rect.h - PADDING);
                try js.objectField("xoff");
                try js.emitNumber(bmp.xoff);
                try js.objectField("yoff");
                try js.emitNumber(bmp.yoff);
                try js.objectField("xadvance");
                try js.emitNumber(bmp.xadvance);
            }
            try js.endObject();
        }
        try js.endObject();
        try js.objectField("texture_data");
        try js.beginObject();
        {
            try js.objectField("width");
            try js.emitNumber(FONT_TEX_WIDTH);
            try js.objectField("height");
            try js.emitNumber(FONT_TEX_HEIGHT);
            try js.objectField("data");
            try js.emitString(encoded_string);
        }
        try js.endObject();
    }

    try js.endObject();
    stream.save_data_to_file(out_path) catch unreachable;
    // write_file_contents(out_path, compressed.items) catch unreachable;
    // var fib = std.io.fixedBufferStream(compressed.items);
    // const reader = fib.reader();
    // var decompression = try std.compress.deflate.decompressor(gpa.allocator(), reader, null);
    // defer decompression.deinit();
    // var decompressed = try decompression.reader().readAllAlloc(gpa.allocator(), std.math.maxInt(usize));
    // defer gpa.allocator().free(decompressed);
    // }
}

const JSON_SERIALIZER_MAX_DEPTH = 32;
pub const JsonWriter = std.io.Writer(*JsonStream, JsonStreamError, JsonStream.write);
pub const JsonStreamError = error{JsonWriteError};
pub const JsonSerializer = std.json.WriteStream(JsonWriter, JSON_SERIALIZER_MAX_DEPTH);
pub const JsonStream = struct {
    const Self = @This();
    buffer: std.ArrayList(u8),

    pub fn new(allocator: std.mem.Allocator) Self {
        return Self{
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.buffer.deinit();
    }

    pub fn writer(self: *Self) JsonWriter {
        return .{ .context = self };
    }

    pub fn write(self: *Self, bytes: []const u8) JsonStreamError!usize {
        self.buffer.appendSlice(bytes) catch unreachable;
        return bytes.len;
    }

    pub fn save_data_to_file(self: *Self, filepath: []const u8) !void {
        // TODO (08 Dec 2021 sam): See whether we want to add a hash or base64 encoding
        try write_file_contents(filepath, self.buffer.items);
    }

    pub fn serializer(self: *Self) JsonSerializer {
        return std.json.writeStream(self.writer(), JSON_SERIALIZER_MAX_DEPTH);
    }
};
