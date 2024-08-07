const std = @import("std");

pub fn build(b: *std.Build) void {
    // if (b.option(bool, "font_builder", "Tool to build fonts")) |_| font_builder(b);
    // if (b.option(bool, "synthelligence", "Build Synthelligence Game")) |_| synth_builder(b);
    if (b.option(bool, "hiveminder", "Build Hiveminder Game")) |_| jam_game_builder(b, .hiveminder);
    if (b.option(bool, "drifter", "Build Drifter Game")) |_| jam_game_builder(b, .drifter);
    if (b.option(bool, "juggler", "Build Juggler Game")) |_| jam_game_builder(b, .juggler);
    if (b.option(bool, "charger", "Build Charger Game")) |_| jam_game_builder(b, .charger);
    if (b.option(bool, "holiday", "Build holiday Game")) |_| jam_game_builder(b, .holiday);
    if (b.option(bool, "cellular", "Build Cellular Game")) |_| jam_game_builder(b, .cellular);
    if (b.option(bool, "sprite", "Build Sprite Test")) |_| jam_game_builder(b, .sprite);
    if (b.option(bool, "goal", "Build Goal Game")) |_| jam_game_builder(b, .goal);
    if (b.option(bool, "base", "Build Base Game")) |_| jam_game_builder(b, .base);
}

pub const Game = enum {
    synthelligence,
    hiveminder,
    drifter,
    juggler,
    charger,
    holiday,
    cellular,
    sprite,
    goal,
    base,
};

// fn font_builder(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//     const exe = b.addExecutable(.{
//         .name = "haathi",
//         .root_source_file = .{ .path = "src/font.zig" },
//         .target = target,
//         .optimize = optimize,
//         .link_libc = true,
//     });
//     exe.addSystemIncludePath(std.build.LazyPath.relative("dependencies/stb"));
//     exe.addCSourceFile(.{
//         .file = std.build.LazyPath.relative("dependencies/defines.c"),
//         .flags = &[_][]const u8{"-std=c99"},
//     });
//     b.installArtifact(exe);
//     const run_cmd = b.addRunArtifact(exe);
//     run_cmd.step.dependOn(b.getInstallStep());
//     if (b.args) |args| {
//         run_cmd.addArgs(args);
//     }
//     const run_step = b.step("run", "Run the app");
//     run_step.dependOn(&run_cmd.step);
// }

// fn synth_builder(b: *std.Build) void {
//     const target = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
//     const optimize = b.standardOptimizeOption(.{});
//     var options = b.addOptions();
//     options.addOption(Game, "game", .synthelligence);
//     const exe = b.addSharedLibrary(.{
//         .name = "synthelligence",
//         .root_source_file = .{ .path = "src/main.zig" },
//         .target = target,
//         .optimize = optimize,
//     });
//     exe.addOptions("build_options", options);
//     exe.addSystemIncludePath(std.build.LazyPath.relative("src"));
//     exe.rdynamic = true;
//     // b.default_step.dependOn(&exe.step);
//     b.installArtifact(exe);
// }

fn jam_game_builder(b: *std.Build, game: Game) void {
    const target_query = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});
    var options = b.addOptions();
    options.addOption(Game, "game", game);
    const exe = b.addExecutable(.{
        .name = "haathi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", options);
    exe.addSystemIncludePath(.{ .path = "src" });
    exe.entry = .disabled;
    exe.rdynamic = true;
    // b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
