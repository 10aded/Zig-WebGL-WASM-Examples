// An example of rendering a blinking window in WebGL
// without having to write native .js code by using the zjb
// library. (Using the library makes it possbile to call
// .js functions from within Zig when needed.)
//
// Created by 10aded throughout March 2025. 
//
// Build this example with the command:
//
//     zig build blinking_screen -Doptimize=Fast
//
// run in the top directory of the project.
//
// This creates a static webpage in ./zig-out/bin ; to run the
// webpage spawn a web server from within ./zig-out/bin (e.g.
// with python via
//
//     python -m http.server
//
// and then access the url localhost:8000 in a web browser.
//
// Building the project requires a Zig compiler of at least
// version 0.13.0. It can be easily and freely downloaded at:
//
//     https://ziglang.org/download/
//
// The entire source code of this project is available on GitHub at:
//
//     https://github.com/10aded/Zig-WebGL-WASM-Examples
//
// This code heavily relies on Scott Redig's Zig Javascript
// Bridge library (zjb), available at:
//
//     https://github.com/scottredig/zig-javascript-bridge
//
// Zjb has a MIT license, see the link / included dependency
// for more details.
//
// These example and others were developed (almost) entirely
// on the Twitch channel 10aded; copies of the stream are
// on YouTube at the @10aded channel.

const std = @import("std");
const zjb = @import("zjb");

const CANVAS_WIDTH  : i32 = 500;
const CANVAS_HEIGHT : i32 = 500;

const PI = std.math.pi;

// Globals
var glcontext      : zjb.Handle = undefined;

// WebGL constants obtained from the WebGL specification at:
// https://registry.khronos.org/webgl/specs/1.0.0/
const gl_COLOR_BUFFER_BIT : i32 = 0x4000;

// Timestamp
var initial_timestamp      : f64 = undefined;

fn log(v: anytype) void {
    zjb.global("console").call("log", .{v}, void);
}

fn logStr(str: []const u8) void {
    const handle = zjb.string(str);
    defer handle.release();
    zjb.global("console").call("log", .{handle}, void);
}

export fn main() void {
    init_clock();

    init_webgl_context();
    
    logStr("Debug: Begin main loop.");
    
    animationFrame(initial_timestamp);
}

fn init_clock() void {
    const timeline = zjb.global("document").get("timeline", zjb.Handle);
    defer timeline.release();
    
    initial_timestamp = timeline.get("currentTime", f64);
}

fn init_webgl_context() void {
    const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
    defer canvas.release();

    canvas.set("width",  CANVAS_WIDTH);
    canvas.set("height", CANVAS_HEIGHT);
    
    glcontext = canvas.call("getContext", .{zjb.constString("webgl")}, zjb.Handle);
}

fn animationFrame(timestamp: f64) callconv(.C) void {

    // NOTE: The timestamp is in milliseconds.
    const time_seconds = timestamp / 1000;
    const time_seconds_f32 : f32 = @floatCast(time_seconds);

    const oscillating_value = 0.5 * (1 + std.math.sin(2 * PI * time_seconds_f32));
    
    // Render the background color.
    const bcg : @Vector(4, f32) = .{oscillating_value, 0.5, 1, 1};
    glcontext.call("clearColor", .{bcg[0], bcg[1], bcg[2], bcg[3]}, void);
    glcontext.call("clear",      .{gl_COLOR_BUFFER_BIT}, void);

    zjb.ConstHandle.global.call("requestAnimationFrame", .{zjb.fnHandle("animationFrame", animationFrame)}, void);
}
