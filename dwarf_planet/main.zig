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
var texture_shader_program : zjb.Handle = undefined;
var pluto_texture  : zjb.Handle = undefined;

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

const gl_TEXTURE0           : i32 = 0x84C0;
const gl_TEXTURE_2D         : i32 = 0x0DE1;
const gl_TEXTURE_WRAP_S     : i32 = 0x2802;
const gl_TEXTURE_WRAP_T     : i32 = 0x2803;
const gl_CLAMP_TO_EDGE      : i32 = 0x812F;
const gl_TEXTURE_MAG_FILTER : i32 = 0x2800;
const gl_TEXTURE_MIN_FILTER : i32 = 0x2801;
const gl_NEAREST            : i32 = 0x2600;

const gl_RGBA               : i32 = 0x1908;
const gl_UNSIGNED_BYTE      : i32 = 0x1401; // NOTE below!

// NOTE: in WebGL specification,  UNSIGNED_BYTE is commented out in
// /* PixelType */, the constant still seems to work though.

// Timestamp
var initial_timestamp      : f64 = undefined;

// Image

// The photo of Pluto below was taken by the New Horizons spacecraft,
// see the header of this file for more information.
const pluto_qoi = @embedFile("./pluto_new_horizons.qoi");
const pluto_header = qoi.comptime_header_parser(pluto_qoi);
const pluto_width  = pluto_header.image_width;
const pluto_height = pluto_header.image_height;

// TODO: In order to call gl.texImage2D to make a texture,
// the bytes need to be in a Uint8Array (when gl.UNSIGNED_BYTE) is
// called. (See: https://developer.mozilla.org/en-US/docs/Web/API/WebGLRenderingContext/texImage2D)
// So, without knowing if the WASM will store @Vector(4, u8) in the
// packed way as in x86_64, here were first decompress the .qoi
// into an array of @Vector(4, u8), then convert it to a [] u8.
// It would be EASY to modify the qoi decompressor to directly
// convert it to [] u8 but this is what we're doing for now!

var pluto_pixels : [pluto_width * pluto_height] Color = undefined;
var pluto_pixel_bytes : [4 * pluto_width * pluto_height] u8 = undefined;

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
    qoi.qoi_to_pixels(pluto_qoi, pluto_width * pluto_height, &pluto_pixels);

    for (pluto_pixels, 0..) |pixel, i| {
        pluto_pixel_bytes[4 * i + 0] = pixel[0];
        pluto_pixel_bytes[4 * i + 1] = pixel[1];
        pluto_pixel_bytes[4 * i + 2] = pixel[2];
        pluto_pixel_bytes[4 * i + 3] = pixel[3];
    }
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
    } else {
        logStr("Debug: vertex shader successfully compiled!");        
    }
    
    if (! fs_comp_ok) {
        const info_log : zjb.Handle = glcontext.call("getShaderInfoLog", .{fragment_shader}, zjb.Handle);
        log(info_log);
        logStr("ERROR: fragment shader failed to compile!");
    }
    
    // Try and link the vertex and fragment shaders.
    texture_shader_program = glcontext.call("createProgram", .{}, zjb.Handle);
    glcontext.call("attachShader", .{texture_shader_program, vertex_shader},   void);
    glcontext.call("attachShader", .{texture_shader_program, fragment_shader}, void);

    // NOTE: Before we link the program, we need to manually choose the locations
    // for the vertex attributes, otherwise the linker chooses for us. See, e.g:
    // https://webglfundamentals.org/webgl/lessons/webgl-attributes.html

    glcontext.call("bindAttribLocation", .{texture_shader_program, 0, zjb.constString("aPos")}, void);
    glcontext.call("bindAttribLocation", .{texture_shader_program, 1, zjb.constString("aTexCoord")}, void);

    glcontext.call("linkProgram",  .{texture_shader_program}, void);

    // Check that the shaders linked.
    const shader_linked_ok = glcontext.call("getProgramParameter", .{texture_shader_program, gl_LINK_STATUS}, bool);

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
             1,  1,  1, 0,// RT
            -1,  1,  0, 0,// LT
             1, -1,  1, 1,// RB
            -1,  1,  0, 0,// LT
             1, -1,  1, 1,// RB
            -1, -1,  0, 1,// LB
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
        4 * @sizeOf(f32), // stride
        0 * @sizeOf(f32), // offset
        }, void);

    glcontext.call("enableVertexAttribArray", .{1}, void);
    glcontext.call("vertexAttribPointer", .{1, 2, gl_FLOAT, false, 4 * @sizeOf(f32), 2 * @sizeOf(f32)}, void);

    // Setup pluto texture.
    pluto_texture = glcontext.call("createTexture", .{}, zjb.Handle);
    glcontext.call("bindTexture", .{gl_TEXTURE_2D, pluto_texture}, void);

    // NOTE: The WebGL specification does NOT define CLAMP_TO_BORDER... weird.
    glcontext.call("texParameteri", .{gl_TEXTURE_2D, gl_TEXTURE_WRAP_S, gl_CLAMP_TO_EDGE}, void);
    glcontext.call("texParameteri", .{gl_TEXTURE_2D, gl_TEXTURE_WRAP_T, gl_CLAMP_TO_EDGE}, void);
    glcontext.call("texParameteri", .{gl_TEXTURE_2D, gl_TEXTURE_MIN_FILTER, gl_NEAREST}, void);
    glcontext.call("texParameteri", .{gl_TEXTURE_2D, gl_TEXTURE_MAG_FILTER, gl_NEAREST}, void);
        
    // Note: The width and height have type "GLsizei"... i.e. a i32.
    const bm_width  : i32 = @intCast(pluto_width);
    const bm_height : i32 = @intCast(pluto_height);

    // !!! VERY IMPORTANT !!!
    // gl.texImage2D accepts a pixel source ONLY with type "Uint8Array". As such,
    // applying a zjb.dataView() to the pixels will result in NO texture being drawn.
    // Instead, use zjb.u8ArrayView().
    //
    // We spent something like 2 hours debugging this. Worst debugging experience of 2025 so far.
    
    const pixel_data_obj = zjb.u8ArrayView(&pluto_pixel_bytes);
    
    glcontext.call("texImage2D", .{gl_TEXTURE_2D, 0, gl_RGBA, bm_width, bm_height, 0, gl_RGBA, gl_UNSIGNED_BYTE, pixel_data_obj}, void);
}

fn animationFrame(timestamp: f64) callconv(.C) void {

    // NOTE: The timestamp is in milliseconds.
    const time_seconds = timestamp / 1000;
    
    // Render the background color.
    glcontext.call("clearColor", .{0.2, 0.2, 0.2, 1}, void);
    glcontext.call("clear",      .{gl_COLOR_BUFFER_BIT}, void);

    // Render the image of pluto!
    glcontext.call("useProgram", .{texture_shader_program}, void);

    // Set the time uniform in the fragment shader.
    const time_seconds_f32 : f32 = @floatCast(time_seconds);
    _ = time_seconds_f32;
    
    //    const time_uniform_location = glcontext.call("getUniformLocation", .{texture_shader_program, zjb.constString("time")}, zjb.Handle);


    
    //glcontext.call("uniform1f", .{time_uniform_location, time_seconds_f32}, void);


    // Make the blue_marble texture active.
    glcontext.call("activeTexture", .{gl_TEXTURE0}, void);
    //    gl.activeTexture(gl.TEXTURE0);

    glcontext.call("bindTexture", .{gl_TEXTURE_2D, pluto_texture}, void);
//    gl.bindTexture(gl.TEXTURE_2D, blue_marble_texture);

    const uSampler_location = glcontext.call("getUniformLocation", .{texture_shader_program, zjb.constString("uSampler")}, zjb.Handle);
//    const texture0_location = gl.getUniformLocation(texture_shader_program, "uSampler");

    glcontext.call("uniform1i", .{uSampler_location, 0}, void);
    //    gl.uniform1i(texture0_location, 0);
    
    // The Actual Drawing command!
    glcontext.call("drawArrays", .{gl_TRIANGLES, 0, 6}, void);

    zjb.ConstHandle.global.call("requestAnimationFrame", .{zjb.fnHandle("animationFrame", animationFrame)}, void);
}
