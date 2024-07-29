// TODO... Note how this file was modified from scottredig's file.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    // TODO... change this so that it goes into ./zig-out/<example_name>
    const dir = std.Build.InstallDir.bin;

    /////////////////////////////////////////////////////////////
    // generate js exe
    const generate_js = b.addExecutable(.{
        .name = "generate_js",
        .root_source_file = b.path("src/generate_js.zig"),
        .target = b.host,
        // Reusing this will occur more often than compiling this, as
        // it usually can be cached.  So faster execution is worth slower
        // initial build.
        .optimize = .ReleaseSafe,
    });
    b.installArtifact(generate_js);

    /////////////////////////////////////////////////////////////
    // module

    const module = b.addModule("zjb", .{
        .root_source_file = b.path("src/zjb.zig"),
    });

    /////////////////////////////////////////////////////////////
    // Our fractal example.

    const fractal = b.addExecutable(.{
        .name = "fractal",
        .root_source_file = b.path("fractal/fractal.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize,
    });
    fractal.root_module.addImport("zjb", module);
    fractal.entry = .disabled;
    fractal.rdynamic = true;

    const extract_fractal = b.addRunArtifact(generate_js);
    // const extract_fractal = b.addRunArtifact(zjb.artifact("generate_js"));
    const extract_fractal_out = extract_fractal.addOutputFileArg("zjb_extract.js");
    extract_fractal.addArg("Zjb"); // Name of js class.
    extract_fractal.addArtifactArg(fractal);

    const fractal_step = b.step("fractal", "build the Julia set example");
    fractal_step.dependOn(&b.addInstallArtifact(fractal, .{
        .dest_dir = .{ .override = dir },
        }).step);
    fractal_step.dependOn(&b.addInstallFileWithDir(extract_fractal_out, dir, "zjb_extract.js").step);
    fractal_step.dependOn(&b.addInstallDirectory(.{
        // TODO... make the index.html etc. that gets copied into every project from one place.
        .source_dir = b.path("fractal/static"),
        .install_dir = dir,
        .install_subdir = "",
        }).step);
}
