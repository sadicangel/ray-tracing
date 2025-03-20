const std = @import("std");
const stb = @import("zstbi");

const Color = @Vector(4, u8);

pub inline fn clampToU8(dividend: anytype, divisor: anytype) u8 {
    const d: f32 = @floatFromInt(dividend);
    return @intFromFloat(255 * @max(0, @min(1, d / divisor)));
}

pub fn render() !void {
    const width = 1024;
    const height = 768;

    var image = try stb.Image.createEmpty(width, height, 4, .{});

    var colors: *[width * height]Color = @alignCast(@ptrCast(&image.data[0]));

    colors[0] = Color{ 0xFF, 0x00, 0x00, 0xFF };

    for (0..height) |j| {
        for (0..width) |i| {
            colors[i + j * width] = Color{ clampToU8(j, height), clampToU8(i, width), 0x00, 0xFF };
        }
    }

    try image.writeToFile("./src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    try render();
}
