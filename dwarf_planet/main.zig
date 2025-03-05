// An example of rendering a texture in WebGL
// without having to write native .js code using the zjb
// library. (Using the library makes it possbile to call
// .js functions from within Zig when needed.)
//
// Created by 10aded throughout March 2025. 
//
// Build this example with the command:
//
//     zig build dwarf_planet -Doptimize=Fast
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
//
// The photo of Pluto below was taken by the New Horizons spacecraft
// on 14 July 2015 and is in the public domain and available from:
//
//     https://commons.wikimedia.org/wiki/File:Pluto-01_Stern_03_Pluto_Color_TXT.jpg
//

const std = @import("std");
const zjb = @import("zjb");

const qoi = @import("qoi.zig");

const vertex_shader_source   = @embedFile("vertex_shader.glsl");
const fragment_shader_source = @embedFile("fragment_shader.glsl");

const CANVAS_WIDTH  : i32 = 500;
const CANVAS_HEIGHT : i32 = 500;

// Type aliases.
const Color = @Vector(4, u8);

// Globals
var glcontext      : zjb.Handle = undefined;
var triangle_vbo   : zjb.Handle = undefined;
var color_vertex_shader_program : zjb.Handle = undefined;

// WebGL constants obtained from the WebGL specification at:
// https://registry.khronos.org/webgl/specs/1.0.0/
const gl_FLOAT            : i32 = 0x1406; 
const gl_ARRAY_BUFFER     : i32 = 0x8892;
const gl_STATIC_DRAW      : i32 = 0x88E4;
const gl_COLOR_BUFFER_BIT : i32 = 0x4000;
const gl_TRIANGLES        : i32 = 0x0004;

const gl_VERTEX_SHADER    : i32 = 0x8B31;
const gl_FRAGMENT_SHADER  : i32 = 0x8B30;

const gl_COMPILE_STATUS   : i32 = 0x8B81;
const gl_LINK_STATUS      : i32 = 0x8B82;

// Timestamp
var initial_timestamp      : f64 = undefined;

// Image

// The photo of Pluto below was taken by the New Horizons spacecraft,
// see the header of this file for more information.
const pluto_qoi = @embedFile("./pluto_new_horizons.qoi");
const pluto_header = qoi.comptime_header_parser(pluto_qoi);
const pluto_width  = pluto_header.image_width;
const pluto_height = pluto_header.image_height;
var pluto_pixel_bytes : [pluto_width * pluto_height] Color = undefined;

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

    decompress_image();

    init_webgl_context();

    compile_shaders();

    setup_array_buffers();
    
    logStr("Debug: Begin main loop.");
    
    animationFrame(initial_timestamp);
}

fn init_clock() void {
    const timeline = zjb.global("document").get("timeline", zjb.Handle);
    defer timeline.release();
    
    initial_timestamp = timeline.get("currentTime", f64);
}

fn decompress_image() void {
    qoi.qoi_to_pixels(pluto_qoi, pluto_width * pluto_height, &pluto_pixel_bytes);
    log(@as(i32, @intCast(pluto_width)));
    log(@as(i32, @intCast(pluto_height)));
}

fn init_webgl_context() void {
    const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
    defer canvas.release();

    canvas.set("width",  CANVAS_WIDTH);
    canvas.set("height", CANVAS_HEIGHT);
    
    glcontext = canvas.call("getContext", .{zjb.constString("webgl")}, zjb.Handle);
}

fn compile_shaders() void {
    // Try compiling the vertex and fragment shaders.
    const vertex_shader_source_handle   = zjb.constString(vertex_shader_source);
    const fragment_shader_source_handle = zjb.constString(fragment_shader_source);

    const vertex_shader   = glcontext.call("createShader", .{gl_VERTEX_SHADER},   zjb.Handle);
    const fragment_shader = glcontext.call("createShader", .{gl_FRAGMENT_SHADER}, zjb.Handle);

    glcontext.call("shaderSource", .{vertex_shader, vertex_shader_source_handle}, void);
    glcontext.call("shaderSource", .{fragment_shader, fragment_shader_source_handle}, void);
    
    glcontext.call("compileShader", .{vertex_shader},   void);
    glcontext.call("compileShader", .{fragment_shader}, void);

    // Check to see that the vertex and fragment shaders compiled.
    const vs_comp_ok = glcontext.call("getShaderParameter", .{vertex_shader,   gl_COMPILE_STATUS}, bool);
    const fs_comp_ok = glcontext.call("getShaderParameter", .{fragment_shader, gl_COMPILE_STATUS}, bool);

    if (! vs_comp_ok) {
        logStr("ERROR: vertex shader failed to compile!");
        const info_log : zjb.Handle = glcontext.call("getShaderInfoLog", .{vertex_shader}, zjb.Handle);
        log(info_log);
    }
    
    if (! fs_comp_ok) {
        const info_log : zjb.Handle = glcontext.call("getShaderInfoLog", .{fragment_shader}, zjb.Handle);
        log(info_log);
        logStr("ERROR: fragment shader failed to compile!");
    }
    
    // Try and link the vertex and fragment shaders.
    color_vertex_shader_program = glcontext.call("createProgram", .{}, zjb.Handle);
    glcontext.call("attachShader", .{color_vertex_shader_program, vertex_shader},   void);
    glcontext.call("attachShader", .{color_vertex_shader_program, fragment_shader}, void);

    // NOTE: Before we link the program, we need to manually choose the locations
    // for the vertex attributes, otherwise the linker chooses for us. See, e.g:
    // https://webglfundamentals.org/webgl/lessons/webgl-attributes.html

    glcontext.call("bindAttribLocation", .{color_vertex_shader_program, 0, zjb.constString("aPos")}, void);
    glcontext.call("bindAttribLocation", .{color_vertex_shader_program, 1, zjb.constString("aTexCoord")}, void);

    glcontext.call("linkProgram",  .{color_vertex_shader_program}, void);

    // Check that the shaders linked.
    const shader_linked_ok = glcontext.call("getProgramParameter", .{color_vertex_shader_program, gl_LINK_STATUS}, bool);

    if (shader_linked_ok) {
        logStr("Debug: Shader linked successfully!");
    } else {
        logStr("ERROR: Shader failed to link!");
    }
}

fn setup_array_buffers() void {
    // Define an equilateral RGB triangle.
        const triangle_gpu_data : [6 * 4] f32 = .{
            // xpos, ypos, xtex, ytex,
             1,  1,  1, 1,// RT
            -1,  1,  0, 1,// LT
             1, -1,  1, 0,// RB
            -1,  1,  0, 1,// LT
             1, -1,  1, 0,// RB
            -1, -1,  0, 0,// LB
    };
    
    const gpu_data_obj = zjb.dataView(&triangle_gpu_data);
    
    // Create a WebGLBuffer, seems similar to making a VBO via gl.genBuffers in pure OpenGL.
    triangle_vbo = glcontext.call("createBuffer", .{}, zjb.Handle);

    glcontext.call("bindBuffer", .{gl_ARRAY_BUFFER, triangle_vbo}, void);
    glcontext.call("bufferData", .{gl_ARRAY_BUFFER, gpu_data_obj, gl_STATIC_DRAW, 0, @sizeOf(@TypeOf(triangle_gpu_data))}, void);

    // Set the VBO attributes.
    // NOTE: The index (locations) were specified just before linking the vertex and fragment shaders. 
    glcontext.call("enableVertexAttribArray", .{0}, void);
    glcontext.call("vertexAttribPointer", .{
        0,                // index
        2,                // number of components
        gl_FLOAT,         // type
        false,            // normalize
        5 * @sizeOf(f32), // stride
        0 * @sizeOf(f32), // offset
        }, void);

    glcontext.call("enableVertexAttribArray", .{1}, void);
    glcontext.call("vertexAttribPointer", .{1, 3, gl_FLOAT, false, 5 * @sizeOf(f32), 2 * @sizeOf(f32)}, void);
}

fn animationFrame(timestamp: f64) callconv(.C) void {

    // NOTE: The timestamp is in milliseconds.
    const time_seconds = timestamp / 1000;
    
    // Render the background color.
    glcontext.call("clearColor", .{0.2, 0.2, 0.2, 1}, void);
    glcontext.call("clear",      .{gl_COLOR_BUFFER_BIT}, void);

    // Render the rainbow triangle.
    glcontext.call("useProgram", .{color_vertex_shader_program}, void);

    // Set the time uniform in the fragment shader.
    const time_seconds_f32 : f32 = @floatCast(time_seconds);
    const time_uniform_location = glcontext.call("getUniformLocation", .{color_vertex_shader_program, zjb.constString("time")}, zjb.Handle);
    glcontext.call("uniform1f", .{time_uniform_location, time_seconds_f32}, void);
    
    // The Actual Drawing command!
    glcontext.call("drawArrays", .{gl_TRIANGLES, 0, 3}, void);

    zjb.ConstHandle.global.call("requestAnimationFrame", .{zjb.fnHandle("animationFrame", animationFrame)}, void);
}
