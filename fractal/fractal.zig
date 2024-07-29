const std = @import("std");
const zjb = @import("zjb");

const vertex_shader_source   = @embedFile("vertex.glsl");
const fragment_shader_source = @embedFile("fragment.glsl");

const alloc = std.heap.wasm_allocator;


// Constants
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

var glcontext      : zjb.Handle = undefined;
var shader_program : zjb.Handle = undefined;

export fn main() void {
    
    const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
    defer canvas.release();

    canvas.set("width",  500);
    canvas.set("height", 500);
    
    glcontext = canvas.call("getContext", .{zjb.constString("webgl")}, zjb.Handle);
    // glcontext.release();

    const timeline = zjb.global("document").get("timeline", zjb.Handle);
    defer timeline.release();

    const timestamp = timeline.get("currentTime", f64);
    last_timestamp_seconds = timestamp / 1000;

    init_shaders();
    
    logStr("\n======================== Start the main render loop.  ========================");
    animationFrame(timestamp);
}

fn init_shaders() void {
    // Constant-function args.
    const gl_VERTEX_SHADER    = glcontext.get("VERTEX_SHADER",    i32);
    const gl_FRAGMENT_SHADER  = glcontext.get("FRAGMENT_SHADER",  i32);
    const gl_COMPILE_STATUS   = glcontext.get("COMPILE_STATUS",   i32);
    const gl_LINK_STATUS      = glcontext.get("LINK_STATUS",      i32);

    // Setup vertex shader.
    const vertex_shader_source_handle = zjb.string(vertex_shader_source);
    const vertex_shader = glcontext.call("createShader", .{gl_VERTEX_SHADER}, zjb.Handle);
    glcontext.call("shaderSource", .{vertex_shader, vertex_shader_source_handle}, void);
    glcontext.call("compileShader", .{vertex_shader}, void);
    
    
    // Setup fragment Shader
    const fragment_shader_source_handle = zjb.string(fragment_shader_source);
    const fragment_shader = glcontext.call("createShader", .{gl_FRAGMENT_SHADER}, zjb.Handle);
    glcontext.call("shaderSource", .{fragment_shader, fragment_shader_source_handle}, void);
    glcontext.call("compileShader", .{fragment_shader}, void);

    // Check to see that the vertex shader and fragment shader compiled.
    const vs_comp_ok = glcontext.call("getShaderParameter", .{vertex_shader,   gl_COMPILE_STATUS}, bool);
    const fs_comp_ok = glcontext.call("getShaderParameter", .{fragment_shader, gl_COMPILE_STATUS}, bool);

    if (! vs_comp_ok) { logStr("ERROR: vertex shader failed to compile!"); }        
    if (! fs_comp_ok) { logStr("ERROR: fragment shader failed to compile!"); }

    shader_program = glcontext.call("createProgram", .{}, zjb.Handle);
    glcontext.call("attachShader", .{shader_program, vertex_shader}, void);
    glcontext.call("attachShader", .{shader_program, fragment_shader}, void);
    glcontext.call("linkProgram",  .{shader_program}, void);

    // Check that the shader_program actually linked.

    const shader_linked_ok = glcontext.call("getProgramParameter", .{shader_program, gl_LINK_STATUS}, bool);

    if (shader_linked_ok) {
        logStr("Shader linked successfully!");
    } else {
        logStr("ERROR: Shader failed to link!");
    }
}

fn animationFrame(timestamp: f64) callconv(.C) void {

    // NOTE: The timestamp is in milliseconds.
    const time_seconds = timestamp / 1000;

    // TODO... move these to global variables (groan).
    const gl_ARRAY_BUFFER     = glcontext.get("ARRAY_BUFFER",     i32);
    const gl_STATIC_DRAW      = glcontext.get("STATIC_DRAW",      i32);
    const gl_DEPTH_TEST       = glcontext.get("DEPTH_TEST",       i32);
    const gl_LEQUAL           = glcontext.get("LEQUAL",           i32);
    const gl_COLOR_BUFFER_BIT = glcontext.get("COLOR_BUFFER_BIT", i32);
    const gl_DEPTH_BUFFER_BIT = glcontext.get("DEPTH_BUFFER_BIT", i32);
    const gl_TRIANGLE_STRIP   = glcontext.get("TRIANGLE_STRIP",   i32);

    const gl_FLOAT            = glcontext.get("FLOAT",            i32);
    
    // If exec. gets here without errors, things are fine (probably).

    // Get the postion of the attribute "aVertexPosition"
    //vertexPosition: gl.getAttribLocation(shaderProgram, "aVertexPosition"),
    
    const avpos_string = zjb.string("aVertexPosition");
    const vertex_position = glcontext.call("getAttribLocation", .{shader_program, avpos_string}, zjb.Handle);
    log(vertex_position); // @debug

    const position_buffer = glcontext.call("createBuffer", .{}, zjb.Handle);

    // gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
    glcontext.call("bindBuffer", .{gl_ARRAY_BUFFER, position_buffer}, void);

    // Now create an array of positions for the square.
    //        const positions = [1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, -1.0];

//    const positions     = [_] f32{1, 1, -1, 1, 1, -1, -1, -1};
    const positions     = [_] f32{0.9, 0.9, -0.9, 0.9, 0.9, -0.9, -0.9, -0.9};
    const positions_obj = zjb.dataView(&positions);
    defer positions_obj.release();

    glcontext.call("bufferData", .{gl_ARRAY_BUFFER, positions_obj, gl_STATIC_DRAW}, void);

    log(position_buffer);

    const oscillating_value = 0.5 * (1 + std.math.sin(2 * PI * time_seconds));

    glcontext.call("clearColor", .{oscillating_value,0.5,1,1}, void);
    glcontext.call("clear", .{glcontext.get("COLOR_BUFFER_BIT", i32)}, void);
    glcontext.call("clearDepth", .{1},             void);
    glcontext.call("enable",     .{gl_DEPTH_TEST}, void);
    glcontext.call("depthFunc",  .{gl_LEQUAL},     void);

    glcontext.call("clear", .{gl_COLOR_BUFFER_BIT | gl_DEPTH_BUFFER_BIT}, void);
    glcontext.call("bindBuffer", .{gl_ARRAY_BUFFER, position_buffer}, void);
    glcontext.call("vertexAttribPointer", .{
        vertex_position,
        2,
        gl_FLOAT,
        false,
        0,
        0,
        }, void);
    
    // gl.vertexAttribPointer(
    //     programInfo.attribLocations.vertexPosition,
    //     numComponents,
    //     type,
    //     normalize,
    //     stride,
    //     offset,
    // );

    glcontext.call("enableVertexAttribArray", .{vertex_position}, void);
    glcontext.call("useProgram", .{shader_program}, void);

    const offset = 0;
    const vertexCount = 4;

    // The Actual Drawing command!
    // gl.drawArrays(gl.TRIANGLE_STRIP, offset, vertexCount);
    glcontext.call("drawArrays", .{gl_TRIANGLE_STRIP, offset, vertexCount}, void);

    zjb.ConstHandle.global.call("requestAnimationFrame", .{zjb.fnHandle("animationFrame", animationFrame)}, void);
}
