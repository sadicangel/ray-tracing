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

    for (0..height) |j| {
        for (0..width) |i| {
            const r: f32 = @floatFromInt(j);
            const g: f32 = @floatFromInt(i);

            const p: usize = (i + j * width) * 4;

            image.data[p + 0] = clampToU8(r / height);
            image.data[p + 1] = clampToU8(g / width);
            image.data[p + 2] = 0x00;
            image.data[p + 3] = 0xFF;
        }
    }

    try image.writeToFile("D:/Development/ray-tracing/src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    try render();
}
