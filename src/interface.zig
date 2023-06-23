pub extern fn fillRect(x: f32, y: f32, width: f32, height: f32, color: [*]const u8) void;
pub extern fn clearCanvas(color: [*]const u8) void;
pub extern fn debugPrint(string: [*]const u8) void; // this needs to be null terminated.
