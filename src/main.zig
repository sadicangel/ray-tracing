const std = @import("std");
const stb = @import("zstbi");

const Vector3f = @Vector(3, f32);

pub inline fn length(self: Vector3f) f32 {
    return @sqrt(self[0] * self[0] + self[1] * self[1] + self[2] * self[2]);
}

pub inline fn normalize(self: Vector3f) Vector3f {
    const len: f32 = length(self);
    return Vector3f{ self[0] / len, self[1] / len, self[2] / len };
}

pub inline fn dot(self: Vector3f, other: Vector3f) f32 {
    return self[0] * other[0] + self[1] * other[1] + self[2] * other[2];
}

const Color = @Vector(4, u8);

pub const Sphere = struct {
    center: Vector3f,
    radius: f32,
};

pub fn sphereIntersect(self: Sphere, rayOrigin: Vector3f, rayDirection: Vector3f, distance: *f32) bool {
    const L: Vector3f = self.center - rayOrigin;
    const tca: f32 = dot(L, rayDirection);
    const d2: f32 = dot(L, L) - tca * tca;
    if (d2 > self.radius * self.radius) return false;
    const thc: f32 = @sqrt(self.radius * self.radius - d2);
    distance.* = tca - thc;
    const t1 = tca + thc;
    if (distance.* < 0.0) distance.* = t1;
    if (distance.* < 0.0) return false;
    return true;
}

pub inline fn clampToU8(d: f32) u8 {
    return @intFromFloat(255 * @max(0, @min(1, d)));
}

pub inline fn clampToColor(vector: Vector3f) Color {
    return Color{
        clampToU8(vector[0]),
        clampToU8(vector[1]),
        clampToU8(vector[2]),
        255,
    };
}

pub fn castRay(rayOrigin: Vector3f, rayDirection: Vector3f, sphere: Sphere) Color {
    var distance = std.math.floatMax(f32);
    if (!sphereIntersect(sphere, rayOrigin, rayDirection, &distance)) {
        return clampToColor(Vector3f{ 0.2, 0.7, 0.8 }); // background color
    }
    return clampToColor(Vector3f{ 0.4, 0.4, 0.3 });
}

pub fn render(sphere: Sphere) !void {
    const width = 1024;
    const height = 768;
    const fov: f32 = std.math.pi / 2.0;

    var image = try stb.Image.createEmpty(width, height, 4, .{});

    var frameBuffer: *[width * height]Color = @alignCast(@ptrCast(&image.data[0]));

    for (0..height) |j| {
        for (0..width) |i| {
            const ij: f32 = @floatFromInt(i);
            const jf: f32 = @floatFromInt(j);
            const x: f32 = (2 * (0.5 + ij) / width - 1) * @tan(fov / 2.0) * width / height;
            const y: f32 = -(2 * (0.5 + jf) / height - 1) * @tan(fov / 2.0);
            const direction = normalize(Vector3f{ x, y, -1 });

            frameBuffer[i + j * width] = castRay(Vector3f{ 0, 0, 0 }, direction, sphere);
        }
    }

    try image.writeToFile("./src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const sphere = Sphere{ .center = Vector3f{ -3, 0, -16 }, .radius = 2 };

    try render(sphere);
}
