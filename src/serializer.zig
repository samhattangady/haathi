const std = @import("std");
const c = @import("interface.zig");
const helpers = @import("helpers.zig");

pub const JsonWriter = std.io.Writer(*JsonStream, JsonStreamError, JsonStream.write);
pub const JsonStreamError = error{JsonWriteError};
pub const JsonSerializer = std.json.WriteStream(JsonWriter, .{ .checked_to_fixed_depth = 256 });
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

    // pub fn saveDataToFile(self: *Self, filepath: []const u8, allocator: std.mem.Allocator) !void {
    //     // TODO (08 Dec 2021 sam): See whether we want to add a hash or base64 encoding
    //     try helpers.writeFileContents(filepath, self.buffer.items, allocator);
    //     if (false) {
    //         helpers.debugPrint("saving to file {s}\n", .{filepath});
    //     }
    // }

    pub fn serializer(self: *Self) JsonSerializer {
        return std.json.writeStream(self.writer(), .{});
    }
};

const SerializableField = struct {
    struct_name: []const u8,
    fields: []const []const u8,
};

fn tryObjectField(struct_name: []const u8, js: *JsonSerializer) !void {
    if (struct_name.len > 0) {
        try js.objectField(struct_name);
    }
}

pub fn serialize(struct_name: []const u8, data: anytype, js: *JsonSerializer) !void {
    switch (@typeInfo(@TypeOf(data))) {
        .Struct => {
            try tryObjectField(struct_name, js);
            try js.beginObject();
            try data.serialize(js);
            try js.endObject();
        },
        .Pointer => {
            if (@TypeOf(data[0]) == u8) {
                try tryObjectField(struct_name, js);
                try js.write(data);
            } else {
                try tryObjectField(struct_name, js);
                try js.beginArray();
                for (data) |elem| {
                    try serialize("", elem, js);
                }
                try js.endArray();
            }
        },
        .Optional => {
            if (data) |d| {
                try serialize(struct_name, d, js);
            } else {
                try tryObjectField(struct_name, js);
                try js.emitNull();
            }
        },
        .Enum => {
            try tryObjectField(struct_name, js);
            try js.write(@tagName(data));
        },
        .Float, .Int => {
            try tryObjectField(struct_name, js);
            try js.write(data);
        },
        else => {
            helpers.debugPrint("Could not serialize {s}\n", .{@tagName(@typeInfo(@TypeOf(data)))});
        },
    }
}

fn tryGetObject(struct_name: []const u8, js: std.json.Value, options: DeserializationOptions) ?std.json.Value {
    if (struct_name.len == 0) return js;
    if (js.object.get(struct_name)) |val| {
        return val;
    }
    if (options.error_on_not_found) unreachable;
    return null;
}

pub const DeserializationOptions = struct {
    error_on_not_found: bool = false,
};

pub fn deserialize(struct_name: []const u8, data: anytype, js: std.json.Value, options: DeserializationOptions) void {
    const figured_type = @TypeOf(data.*);
    if (@typeInfo(figured_type) == .Optional) {
        if (tryGetObject(struct_name, js, options)) |value| {
            if (value == .null) {
                data.* = null;
                return;
            } else {
                const new_type = @typeInfo(figured_type).Optional.child;
                deserializeType(struct_name, data, js, options, new_type);
                return;
            }
        } else {
            if (options.error_on_not_found)
                unreachable; // could not find the field
        }
    }
    deserializeType(struct_name, data, js, options, figured_type);
}

fn deserializeType(struct_name: []const u8, data: anytype, js: std.json.Value, options: DeserializationOptions, comptime T: type) void {
    // helpers.debugPrint("deserializing {s}\n", .{struct_name});
    // check if it is a std.ArrayList
    const is_optional = @typeInfo(@TypeOf(data.*)) == .Optional;
    switch (@typeInfo(T)) {
        .Struct => {
            if (tryGetObject(struct_name, js, options)) |value| {
                if (is_optional) {
                    data.* = .{};
                    data.*.?.deserialize(value, options);
                } else {
                    data.deserialize(value, options);
                }
            } else {
                if (options.error_on_not_found)
                    unreachable; // could not find the field
            }
        },
        .Pointer => {
            if (tryGetObject(struct_name, js, options)) |value| {
                data.* = value.string; // assumed that all pointers are strings
            }
        },
        .Optional => {
            unreachable; // we should have taken care of optionals above
        },
        .Enum => {
            if (tryGetObject(struct_name, js, options)) |value| {
                data.* = std.meta.stringToEnum(@TypeOf(data.*), value.string).?;
            } else {
                if (options.error_on_not_found)
                    unreachable; // could not find the field
            }
        },
        .Float => |float_data| {
            if (tryGetObject(struct_name, js, options)) |value| {
                if (float_data.bits == 16) data.* = @as(f16, @floatCast(value.float));
                if (float_data.bits == 32) data.* = @as(f32, @floatCast(value.float));
                if (float_data.bits == 64) data.* = @as(f64, @floatCast(value.float));
            } else {
                if (options.error_on_not_found)
                    unreachable; // could not find the field
            }
        },
        .Int => |int_data| {
            if (tryGetObject(struct_name, js, options)) |value| {
                switch (int_data.signedness) {
                    .signed => {
                        if (int_data.bits == 8) data.* = @as(i8, @intCast(value.integer));
                        if (int_data.bits == 16) data.* = @as(i16, @intCast(value.integer));
                        if (int_data.bits == 32) data.* = @as(i32, @intCast(value.integer));
                        if (int_data.bits == 64) data.* = @as(i64, @intCast(value.integer));
                    },
                    .unsigned => {
                        if (int_data.bits == 8) data.* = @as(u8, @intCast(value.integer));
                        if (int_data.bits == 16) data.* = @as(u16, @intCast(value.integer));
                        if (int_data.bits == 32) data.* = @as(u32, @intCast(value.integer));
                        if (int_data.bits == 64) data.* = @as(u64, @intCast(value.integer));
                    },
                }
            } else {
                if (options.error_on_not_found)
                    unreachable; // could not find the field
            }
        },
        else => {
            helpers.debugPrint("Could not deserialize {s}\n", .{@tagName(@typeInfo(@TypeOf(data.*)))});
        },
    }
}
