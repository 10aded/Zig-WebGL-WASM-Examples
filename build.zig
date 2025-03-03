// TODO... Note how this file was modified from scottredig's file.

const std = @import("std");

fn make_wasm_build_exe_options( b : *std.Build, comptime example_name : [] const u8) std.Build.ExecutableOptions {
    const exe_options : std.Build.ExecutableOptions = .{
        .name = example_name,
        .root_source_file = b.path(example_name ++ "/main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = b.standardOptimizeOption(.{}),
    };
    return exe_options;
}

pub fn build(b: *std.Build) void {
    // Dependencies from build.zig.zon .
    const zjb = b.dependency("zjb", .{});    

    // Define example output directories.
    // const blinking_screen_dir  : std.Build.InstallDir = .{ .custom = "blinking_screen"  };
    // const changing_fractal_dir          : std.Build.InstallDir = .{ .custom = "changing_fractal"          };
    const rainbow_triangle_dir : std.Build.InstallDir = .{ .custom = "rainbow_triangle" };

    // Create build options for the .wasms
//    const blinking_screen  = b.addExecutable(make_wasm_build_exe_options(b, "blinking_screen"));
  //  const changing_fractal = b.addExecutable(make_wasm_build_exe_options(b, "changing_fractal"));
    const rainbow_triangle = b.addExecutable(make_wasm_build_exe_options(b, "rainbow_triangle"));

    // TODO... make a loop.
    
    rainbow_triangle.root_module.addImport("zjb", zjb.module("zjb"));
    rainbow_triangle.entry = .disabled;
    rainbow_triangle.rdynamic = true;


    
    const extract_rainbow_triangle = b.addRunArtifact(zjb.artifact("generate_js"));
    const extract_rainbow_triangle_out = extract_rainbow_triangle.addOutputFileArg("zjb_extract.js");
    extract_rainbow_triangle.addArg("Zjb"); // Name of js class.
    extract_rainbow_triangle.addArtifactArg(rainbow_triangle);

    const rainbow_triangle_step = b.step("rainbow_triangle", "Build the hello Zig example");
    rainbow_triangle_step.dependOn(&b.addInstallArtifact(rainbow_triangle, .{
        .dest_dir = .{ .override = rainbow_triangle_dir },
    }).step);
    rainbow_triangle_step.dependOn(&b.addInstallFileWithDir(extract_rainbow_triangle_out, rainbow_triangle_dir, "zjb_extract.js").step);
    rainbow_triangle_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = b.path("rainbow_triangle/static"),
        .install_dir = rainbow_triangle_dir,
        .install_subdir = "",
    }).step);
}
