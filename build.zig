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
    //const rainbow_triangle_dir : std.Build.InstallDir = .{ .custom = "rainbow_triangle" };

    const output_dirs = [_] std.Build.InstallDir {
        .{ .custom = "rainbow_triangle" },
    };

    const static_website_dirs = [_] std.Build.LazyPath {
        b.path("rainbow_triangle/static"),
    };
    
    // Create build options for the .wasms
//    const blinking_screen  = b.addExecutable(make_wasm_build_exe_options(b, "blinking_screen"));
  //  const changing_fractal = b.addExecutable(make_wasm_build_exe_options(b, "changing_fractal"));
    const rainbow_triangle = b.addExecutable(make_wasm_build_exe_options(b, "rainbow_triangle"));


    // Add zjb to the exes, set entry options etc.
    const exe_list = [_] * std.Build.Step.Compile {
        //..
        //..
        rainbow_triangle,
    };
    
    for (exe_list) |exe| {
        exe.root_module.addImport("zjb", zjb.module("zjb"));
        exe.entry = .disabled;
        exe.rdynamic = true;
    }

    var generated_js_paths : [exe_list.len] std.Build.LazyPath = undefined;

    for (exe_list, 0..) |exe, i| {
        // Creates a `Step.Run` with an executable built with `addExecutable`.
        const generate_js_exe = b.addRunArtifact(zjb.artifact("generate_js"));

         // "Provides a file path as a command line argument to the command being run."
        generated_js_paths[i] = generate_js_exe.addOutputFileArg("zjb_extract.js");

        generate_js_exe.addArg("Zjb");       // Currently NO documentation in Run.zig as to what this does. (~0.14.0-dev-3030)
        generate_js_exe.addArtifactArg(exe); // Currently NO documentation in Run.zig as to what this does.
    }

    // ..
    // ..
    const rainbow_triangle_step = b.step("rainbow_triangle", "Build the hello Zig example");

    
    
    rainbow_triangle_step.dependOn(&b.addInstallArtifact(exe_list[0], .{
        .dest_dir = .{.override = output_dirs[0]},
        }).step);
    
    rainbow_triangle_step.dependOn(&b.addInstallFileWithDir(generated_js_paths[0], output_dirs[0], "zjb_extract.js").step);
    rainbow_triangle_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = static_website_dirs[0],
        .install_dir = output_dirs[0],
        .install_subdir = "",
    }).step);
}
