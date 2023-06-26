pub extern fn fillRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn roundRect(x: f32, y: f32, width: f32, height: f32, radius: f32) void;
pub extern fn clearCanvas(color: [*]const u8) void;
pub extern fn debugPrint(string: [*]const u8) void; // this needs to be null terminated.
pub extern fn milliTimestamp() i64;
pub extern fn fillStyle(color: [*]const u8) void;
pub extern fn strokeStyle(color: [*]const u8) void;
pub extern fn beginPath() void;
pub extern fn fill() void;
pub extern fn stroke() void;
pub extern fn moveTo(x: f32, y: f32) void;
pub extern fn lineTo(x: f32, y: f32) void;
pub extern fn lineWidth(width: f32) void;
pub extern fn ellipse(x: f32, y: f32, rx: f32, ry: f32, start: f32, end: f32, counter: bool) void;
