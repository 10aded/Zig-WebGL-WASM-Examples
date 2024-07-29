const std = @import("std");
const zjb = @import("zjb");

const vertex_shader_source   = @embedFile("vertex.glsl");
const fragment_shader_source = @embedFile("fragment.glsl");

const alloc = std.heap.wasm_allocator;

fn log(v: anytype) void {
    zjb.global("console").call("log", .{v}, void);
}
fn logStr(str: []const u8) void {
    const handle = zjb.string(str);
    defer handle.release();
    zjb.global("console").call("log", .{handle}, void);
}

pub const panic = zjb.panic;
export fn main() void {
    zjb.global("console").call("log", .{zjb.constString("Hello from Zig")}, void);

    {
        const formatted = std.fmt.allocPrint(alloc, "Runtime string: current timestamp {d}", .{zjb.global("Date").call("now", .{}, f32)}) catch |e| zjb.throwError(e);
        defer alloc.free(formatted);

        const str = zjb.string(formatted);
        defer str.release();

        zjb.global("console").call("log", .{str}, void);
    }

    logStr("\n============================= Array View Example =============================");
    {
        var arr = [_]u16{ 1, 2, 3 };
        const obj = zjb.u16ArrayView(&arr);
        defer obj.release();

        logStr("View of Zig u16 array from Javascript, with its length");
        log(obj);
        log(obj.get("length", f64)); // 3

        arr[0] = 4;
        logStr("Changes from Zig are visible in Javascript");
        log(obj);

        logStr("Unless wasm's memory grows, which causes the ArrayView to be invalidated.");
        _ = @wasmMemoryGrow(0, 1);
        arr[0] = 5;
        log(obj);
        log(obj.get("length", f64)); // 0
    }

    logStr("\n============================= Data View Examples =============================");
    logStr("dataView allows extraction of numbers from WASM's memory.");
    {
        const arr = [_]u16{ 1, 2, 3 };
        const obj = zjb.dataView(&arr);
        defer obj.release();

        logStr("dataView works for arrays.");
        log(obj);
        log(obj.call("getUint16", .{ @sizeOf(u16) * 0, true }, f32));
        log(obj.call("getUint16", .{ @sizeOf(u16) * 1, true }, f32));
        log(obj.call("getUint16", .{ @sizeOf(u16) * 2, true }, f32));
    }

    {
        const S = extern struct {
            a: u16,
            b: u16,
            c: u32,
        };
        const s = S{ .a = 1, .b = 2, .c = 3 };
        const obj = zjb.dataView(&s);
        defer obj.release();

        logStr("dataView also works for structs, make sure they're extern!");
        log(obj);
        log(obj.call("getUint16", .{ @offsetOf(S, "a"), true }, f32));
        log(obj.call("getUint16", .{ @offsetOf(S, "b"), true }, f32));
        log(obj.call("getUint32", .{ @offsetOf(S, "c"), true }, f32));
    }

    logStr("\n============================= Maps and index getting/setting =============================");
    {
        const obj = zjb.global("Map").new(.{});
        defer obj.release();

        const myI32: i32 = 0;
        obj.indexSet(myI32, 0);
        const myI64: i64 = 0;
        obj.indexSet(myI64, 1);

        obj.set("Hello", obj.indexGet(myI64, f64));

        const str = zjb.string("some_key");
        defer str.release();
        obj.indexSet(str, 2);

        log(obj);
    }

    logStr("\n============================= html canvas webgl example =============================");
    {
        const canvas = zjb.global("document").call("getElementById", .{zjb.constString("canvas")}, zjb.Handle);
        defer canvas.release();

        canvas.set("width", 500);
        canvas.set("height", 500);

        // const ID = zjb.global("Uint8ClampedArray").new(.{2000});
        // log(ID);
        
        const glcontext = canvas.call("getContext", .{zjb.constString("webgl")}, zjb.Handle);
        defer glcontext.release();

        // Mozilla's WebGl tutorial / documentation says to do:
        // 
        //     glcontext.clearColor(0,1,1,1);
        //     glcontext.clear(gl.COLOR_BUFFER_BIT);
        //
        // we call these in-built browser .js procs from Zig, ensuring our
        // project has the minimal amount of actual javascript code possible.

//        glcontext.call("clearColor", .{0,0.5,1,1}, void);
//        glcontext.call("clear", .{glcontext.get("COLOR_BUFFER_BIT", i32)}, void);


        // https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Tutorial/Adding_2D_content_to_a_WebGL_context


        // gl constants.
        const gl_VERTEX_SHADER    = glcontext.get("VERTEX_SHADER",    i32);
        const gl_FRAGMENT_SHADER  = glcontext.get("FRAGMENT_SHADER",  i32);
        const gl_COMPILE_STATUS   = glcontext.get("COMPILE_STATUS",   i32);
        const gl_LINK_STATUS      = glcontext.get("LINK_STATUS",      i32);
        
        const gl_ARRAY_BUFFER     = glcontext.get("ARRAY_BUFFER",     i32);
        const gl_STATIC_DRAW      = glcontext.get("STATIC_DRAW",      i32);
        const gl_DEPTH_TEST       = glcontext.get("DEPTH_TEST",       i32);
        const gl_LEQUAL           = glcontext.get("LEQUAL",           i32);
        const gl_COLOR_BUFFER_BIT = glcontext.get("COLOR_BUFFER_BIT", i32);
        const gl_DEPTH_BUFFER_BIT = glcontext.get("DEPTH_BUFFER_BIT", i32);
        const gl_TRIANGLE_STRIP   = glcontext.get("TRIANGLE_STRIP",   i32);

        const gl_FLOAT            = glcontext.get("FLOAT",            i32);
        
        // const shader = gl.createShader(gl.VERTEX_SHADER);

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


        // const shaderProgram = gl.createProgram();
        // gl.attachShader(shaderProgram, vertexShader);
        // gl.attachShader(shaderProgram, fragmentShader);
        // gl.linkProgram(shaderProgram);

        const shader_program = glcontext.call("createProgram", .{}, zjb.Handle);
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

        log(shader_program);
        
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

        const positions     = [_] f32{1, 1, -1, 1, 1, -1, -1, -1};
        const positions_obj = zjb.dataView(&positions);
        defer positions_obj.release();

        //gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);
        glcontext.call("bufferData", .{gl_ARRAY_BUFFER, positions_obj, gl_STATIC_DRAW}, void);

        log(position_buffer);




        // Now, finally, actualy (try) to render the geometry!
        
        // gl.clearColor(0.0, 0.0, 0.0, 1.0); // Clear to black, fully opaque
        // gl.clearDepth(1.0); // Clear everything
        // gl.enable(gl.DEPTH_TEST); // Enable depth testing
        // gl.depthFunc(gl.LEQUAL); // Near things obscure far things
        glcontext.call("clearColor", .{0.3,0.3, 0.3,1},     void);
        glcontext.call("clearDepth", .{1},             void);
        glcontext.call("enable",     .{gl_DEPTH_TEST}, void);
        glcontext.call("depthFunc",  .{gl_LEQUAL},     void);

        //gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        glcontext.call("clear", .{gl_COLOR_BUFFER_BIT | gl_DEPTH_BUFFER_BIT}, void);

        // setPositionAttribute(gl, buffers, programInfo);
        
        //        gl.bindBuffer(gl.ARRAY_BUFFER, buffers.position);
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
//        gl.enableVertexAttribArray(programInfo.attribLocations.vertexPosition);
        
        // gl.useProgram(programInfo.program);
        glcontext.call("useProgram", .{shader_program}, void);

        const offset = 0;
        const vertexCount = 4;

        // The Actual Drawing command!
        // gl.drawArrays(gl.TRIANGLE_STRIP, offset, vertexCount);
        glcontext.call("drawArrays", .{gl_TRIANGLE_STRIP, offset, vertexCount}, void);

        // --------------------------- END ----------
        
        // const hex_color_str : [] const u8 = "#333333";
        // context.set("fillStyle", zjb.constString(hex_color_str));

        // // Zig logo by Zig Software Foundation, github.com/ziglang/logo
        // const shapes = [_][]const f64{
        //     &[_]f64{ 46, 22, 28, 44, 19, 30 },
        //     &[_]f64{ 46, 22, 33, 33, 28, 44, 22, 44, 22, 95, 31, 95, 20, 100, 12, 117, 0, 117, 0, 22 },
        //     &[_]f64{ 31, 95, 12, 117, 4, 106 },

        //     &[_]f64{ 56, 22, 62, 36, 37, 44 },
        //     &[_]f64{ 56, 22, 111, 22, 111, 44, 37, 44, 56, 32 },
        //     &[_]f64{ 116, 95, 97, 117, 90, 104 },
        //     &[_]f64{ 116, 95, 100, 104, 97, 117, 42, 117, 42, 95 },
        //     &[_]f64{ 150, 0, 52, 117, 3, 140, 101, 22 },

        //     &[_]f64{ 141, 22, 140, 40, 122, 45 },
        //     &[_]f64{ 153, 22, 153, 117, 106, 117, 120, 105, 125, 95, 131, 95, 131, 45, 122, 45, 132, 36, 141, 22 },
        //     &[_]f64{ 125, 95, 130, 110, 106, 117 },
        // };

        // for (shapes) |shape| {
        //     context.call("moveTo", .{ shape[0], shape[1] }, void);
        //     for (1..shape.len / 2) |i| {
        //         context.call("lineTo", .{ shape[2 * i], shape[2 * i + 1] }, void);
        //     }
        //     context.call("fill", .{}, void);
        // }

        // // Draw rectangle.
        // context.call("fillRect", .{100, 100, 100, 100}, void);

        // // Make a green ImageData object.
        // const IMDW = 25;
        // const IMDH = 100;

        // var single_pixel = [_]u8 { 255, 0, 0, 255};
        // const obj = zjb.u8ClampedArrayView(&single_pixel);
        // //        pub fn u8ClampedArrayView(data: []const u8) Handle {
        // //        const obj = zjb.u16ArrayView(&arr);
        // defer obj.release();

        
        // const image_data = context.call("createImageData", .{obj, IMDW, IMDH}, zjb.Handle);
        // defer image_data.release();

        // const idata_width  = image_data.get("width",  i32);
        // const idata_height = image_data.get("height", i32);
        // const idate_ptr    = image_data.get("data",   zjb.Handle);
        // for (0..IMDH) |j| {
        //     for (0..IMDW) |i| {
        //         idate_ptr.indexSet(@as(i32, @intCast(4 * (IMDW * j + i) + 1)), 255);
        //         idate_ptr.indexSet(@as(i32, @intCast(4 * (IMDW * j + i) + 3)), 255);
        //     }
        // }


//         var single_pixel = [_]u8 { 255, 0, 0, 255};
//         const obj = zjb.u8ClampedArrayView(&single_pixel);
// //        pub fn u8ClampedArrayView(data: []const u8) Handle {
//         //        const obj = zjb.u16ArrayView(&arr);
//         defer obj.release();

        // image_data.set("width", 20);
        // image_data.set("height", 20);
        
        // Draw the green object!
//        context.call("putImageData", .{image_data, 10, 10}, void);
//        ctx.putImageData(myImageData, dx, dy);

        // const barrels = "barrels";
        // const formatted = std.fmt.allocPrint(alloc, "In cups of rocks it slops: flop, slop, slap: bounded in {s}. Also {d} {d}.\n", .{barrels, idata_width, idata_height}) catch |e| zjb.throwError(e);

        // const proteus = zjb.string(formatted);
        // zjb.global("console").call("log", .{proteus}, void);
        
        // Fails, "type 'zjb.Handle' does not support field access"
        // const pixel_array = image_data.call("data", .{}, zjb.Handle);
        // zjb.global("console").call("log", .{ zjb.constString("Pixel Array:"), pixel_array }, void);
        
    }

    logStr("\n============================= Handle vs ConstHandle =============================");
    {
        logStr("zjb.global and zjb.constString add their ConstHandle on first use, and remember for subsiquent uses.  They can't be released.");
        logStr("While zjb.string and Handle return values must be released after being used or they'll leak.");
        logStr("See that some string remain in handles, while others have been removed after use.");
        const handles = zjb.global("zjb").get("_handles", zjb.Handle);
        defer handles.release();
        log(handles);
    }

    logStr("\n============================= Exporting functions (press a key for a callback) =============================");
    zjb.global("document").call("addEventListener", .{ zjb.constString("keydown"), zjb.fnHandle("keydownCallback", keydownCallback) }, void);
}

fn keydownCallback(event: zjb.Handle) callconv(.C) void {
    defer event.release();

    zjb.global("console").call("log", .{ zjb.constString("From keydown callback, event:"), event }, void);
}

var value: i32 = 0;
fn incrementAndGet(increment: i32) callconv(.C) i32 {
    value += increment;
    return value;
}

comptime {
    zjb.exportFn("incrementAndGet", incrementAndGet);
}
