const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    if (b.option(bool, "font_builder", "Tool to build fonts")) |_| font_builder(b);
    if (b.option(bool, "synthelligence", "Build Synthelligence Game")) |_| synth_builder(b);
    if (b.option(bool, "hiveminder", "Build Hiveminder Game")) |_| jam_game_builder(b, .hiveminder);
    if (b.option(bool, "drifter", "Build Drifter Game")) |_| jam_game_builder(b, .drifter);
    if (b.option(bool, "juggler", "Build Juggler Game")) |_| jam_game_builder(b, .juggler);
    if (b.option(bool, "holiday", "Build Juggler Game")) |_| jam_game_builder(b, .holiday);
}

pub const Game = enum {
    synthelligence,
    hiveminder,
    drifter,
    juggler,
    holiday,
};

fn font_builder(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "haathi",
        .root_source_file = .{ .path = "src/font.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addSystemIncludePath("dependencies/stb");
    exe.addCSourceFile("dependencies/defines.c", &[_][]const u8{"-std=c99"});
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn synth_builder(b: *std.build.Builder) void {
    const target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    const optimize = b.standardOptimizeOption(.{});
    var options = b.addOptions();
    options.addOption(Game, "game", .synthelligence);
    const exe = b.addSharedLibrary(.{
        .name = "synthelligence",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addOptions("build_options", options);
    exe.addSystemIncludePath("src");
    exe.rdynamic = true;
    // b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}

fn jam_game_builder(b: *std.build.Builder, game: Game) void {
    const target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    const optimize = b.standardOptimizeOption(.{});
    var options = b.addOptions();
    options.addOption(Game, "game", game);
    const exe = b.addSharedLibrary(.{
        .name = "haathi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addOptions("build_options", options);
    exe.addSystemIncludePath("src");
    exe.rdynamic = true;
    // b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
