const std = @import("std");
const stb = @import("zstbi");

pub inline fn clampToU8(value: f32) u8 {
    return @intFromFloat(255 * @max(0, @min(1, value)));
}

pub fn render() !void {
    const width = 1024;
    const height = 768;

    var image = try stb.Image.createEmpty(width, height, 4, .{});
    //image.deinit();

    var i: usize = 0;
    while (i < image.data.len) : (i += 4) {
        const w: f32 = @floatFromInt((i / 4) % width);
        const h: f32 = @floatFromInt((i / 4) / height);

        image.data[i + 0] = clampToU8(h / height);
        image.data[i + 1] = clampToU8(w / width);
        image.data[i + 2] = 0x00;
        image.data[i + 3] = 0xFF;
    }

    try image.writeToFile("D:/Development/ray-tracing/src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    try render();
}
