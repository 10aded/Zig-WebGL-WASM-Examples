const std = @import("std");
const zjb = @import("zjb");

const alloc = std.heap.wasm_allocator;

const PI = std.math.pi;

// Globals

var last_timestamp_seconds : f64 = undefined;

fn log(v: anytype) void {
    zjb.global("console").call("log", .{v}, void);
}
fn logStr(str: []const u8) void {
    const handle = zjb.string(str);
    defer handle.release();
    zjb.global("console").call("log", .{handle}, void);
}

pub const panic = zjb.panic;

var glcontext : zjb.Handle = undefined;

export fn main() void {
    logStr("\n======================== Start calling WebGL functions to draw a blinking square   ========================");

    const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
    defer canvas.release();

    canvas.set("width",  500);
    canvas.set("height", 500);
    
    glcontext = canvas.call("getContext", .{zjb.constString("webgl")}, zjb.Handle);
//    defer glcontext.release();

    const timeline = zjb.global("document").get("timeline", zjb.Handle);
    defer timeline.release();

    const timestamp = timeline.get("currentTime", f64);
    last_timestamp_seconds = timestamp / 1000;
    animationFrame(timestamp);

}
fn animationFrame(timestamp: f64) callconv(.C) void {

    // NOTE: The timestamp is in milliseconds.
    const time_seconds = timestamp / 1000;
    
    // Mozilla's WebGl documentation at:
    //
    //     https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Tutorial/Getting_started_with_WebGL
    //
    // says to call the following to set the canvas to a single color.
    // 
    //     glcontext.clearColor(0,1,1,1);
    //     glcontext.clear(gl.COLOR_BUFFER_BIT);
    //
    // we call these in-built browser .js procs from Zig, ensuring our
    // project has the minimal amount of actual javascript code possible.

    // Change the color depending on timestamp.
    const oscillating_value = 0.5 * (1 + std.math.sin(2 * PI * time_seconds));

    glcontext.call("clearColor", .{oscillating_value,0.5,1,1}, void);
    glcontext.call("clear", .{glcontext.get("COLOR_BUFFER_BIT", i32)}, void);    

    zjb.ConstHandle.global.call("requestAnimationFrame", .{zjb.fnHandle("animationFrame", animationFrame)}, void);
}
