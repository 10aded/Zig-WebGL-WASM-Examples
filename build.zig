// TODO... Note how this file was modified from scottredig's file.

const std = @import("std");

fn make_wasm_build_exe_options( b : *std.Build, comptime example_name : [] const u8, optimize : std.builtin.OptimizeMode ) std.Build.ExecutableOptions {
    const exe_options : std.Build.ExecutableOptions = .{
        .name = example_name,
        .root_source_file = b.path(example_name ++ "/main.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .freestanding }),
        .optimize = optimize, 
    };
    return exe_options;
}

pub fn build(b: *std.Build) void {
    // Dependencies from build.zig.zon .
    const zjb = b.dependency("zjb", .{});    

    const optimize : std.builtin.OptimizeMode = b.standardOptimizeOption(.{});
    
    // Define example output directories.
    const output_dirs = [_] std.Build.InstallDir {
        .{ .custom = "blinking_screen"  },
        .{ .custom = "looping_fractal"  },
        .{ .custom = "rainbow_triangle" },
    };

    const static_website_dirs = [_] std.Build.LazyPath {
        b.path("blinking_screen/static"),
        b.path("looping_fractal/static"),
        b.path("rainbow_triangle/static"),
    };
    
    // Create build options for the .wasms
    const blinking_screen  = b.addExecutable(make_wasm_build_exe_options(b, "blinking_screen", optimize));
    const looping_fractal  = b.addExecutable(make_wasm_build_exe_options(b, "looping_fractal", optimize));
    const rainbow_triangle = b.addExecutable(make_wasm_build_exe_options(b, "rainbow_triangle", optimize));

    // Add zjb to the exes, set entry options etc.
    const exe_list = [_] * std.Build.Step.Compile {
        blinking_screen,
        looping_fractal,
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

    const blinking_screen_step  = b.step("blinking_screen",  "Build the blinking_screen example.");
    const looping_fractal_step  = b.step("looping_fractal",  "Build the looping_fractal example.");
    const rainbow_triangle_step = b.step("rainbow_triangle", "Build the rainbow_triangle example.");

    const build_steps : [3] *std.Build.Step= .{
        blinking_screen_step,
        looping_fractal_step,
        rainbow_triangle_step,
    };

    for (build_steps, exe_list, output_dirs, generated_js_paths, static_website_dirs) |step, exe, output_dir, js_path, static_website_dir| {

        step.dependOn(&b.addInstallArtifact(exe, .{.dest_dir = .{.override = output_dir}}).step);
        step.dependOn(&b.addInstallFileWithDir(js_path, output_dir, "zjb_extract.js").step);
        step.dependOn(&b.addInstallDirectory(.{
            .source_dir  = static_website_dir,
            .install_dir = output_dir,
            .install_subdir = "",
            }).step);
    }
}
