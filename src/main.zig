const std = @import("std");
const stb = @import("zstbi");
const vec = @import("vec.zig");

const BACKGROUND_COLOR = Color{ 51, 178, 204, 255 };

const Color = @Vector(4, u8);
const Vec3f = @Vector(3, f32);

const Material = struct {
    diffuseColor: Vec3f,
};

const Object = struct {
    geometry: Geometry,
    material: Material,

    fn intersect(self: Object, rayOrigin: Vec3f, rayDirection: Vec3f, distance: *f32) bool {
        return self.geometry.intersect(rayOrigin, rayDirection, distance);
    }
};

const Geometry = union(enum) {
    Sphere: Sphere,

    fn intersect(self: Geometry, rayOrigin: Vec3f, rayDirection: Vec3f, distance: *f32) bool {
        switch (self) {
            inline else => |impl| return impl.intersect(rayOrigin, rayDirection, distance),
        }
    }
};

const Sphere = struct {
    center: Vec3f,
    radius: f32,

    fn intersect(self: Sphere, rayOrigin: Vec3f, rayDirection: Vec3f, distance: *f32) bool {
        const L: Vec3f = self.center - rayOrigin;
        const tca: f32 = vec.dot(L, rayDirection);
        const d2: f32 = vec.dot(L, L) - tca * tca;
        if (d2 > self.radius * self.radius) return false;
        const thc: f32 = @sqrt(self.radius * self.radius - d2);
        distance.* = tca - thc;
        const t1 = tca + thc;
        if (distance.* < 0.0) distance.* = t1;
        if (distance.* < 0.0) return false;
        return true;
    }
};

fn castRay(rayOrigin: Vec3f, rayDirection: Vec3f, object: Object) Color {
    var distance = std.math.floatMax(f32);
    if (!object.intersect(rayOrigin, rayDirection, &distance)) {
        return BACKGROUND_COLOR;
    }
    return vec.toColor(object.material.diffuseColor, 255);
}

fn render(object: Object) !void {
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
            const direction = vec.normalize(Vec3f{ x, y, -1 });

            frameBuffer[i + j * width] = castRay(Vec3f{ 0, 0, 0 }, direction, object);
        }
    }

    try image.writeToFile("./src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ -3, 0, -16 }, .radius = 2 } };
    const material = Material{ .diffuseColor = Vec3f{ 0.4, 0.4, 0.3 } };

    const object = Object{ .geometry = geometry, .material = material };

    try render(object);
}
