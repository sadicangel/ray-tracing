const std = @import("std");
const stb = @import("zstbi");
const vec = @import("vec.zig");

const BACKGROUND_COLOR = Color{ 51, 178, 204, 255 };

const Vec2f = @Vector(2, f32);
const Vec3f = @Vector(3, f32);
const Color = @Vector(4, u8);

const Geometry = union(enum) {
    Sphere: Sphere,

    fn center(self: Geometry) Vec3f {
        switch (self) {
            inline else => |impl| return impl.center,
        }
    }

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

const Material = struct {
    albedo: Vec2f,
    diffuseColor: Vec3f,
    specularExponent: f32,
};

const Object = struct {
    geometry: Geometry,
    material: Material,
};

const Light = struct {
    position: Vec3f,
    intensity: f32,
};

const Scene = struct {
    objects: std.ArrayList(Object) = std.ArrayList(Object).init(std.heap.page_allocator),
    lights: std.ArrayList(Light) = std.ArrayList(Light).init(std.heap.page_allocator),

    fn intersect(self: Scene, rayOrigin: Vec3f, rayDirection: Vec3f, hit: *Vec3f, norm: *Vec3f, obj: *Object) bool {
        var minDistance = std.math.floatMax(f32);
        for (self.objects.items) |object| {
            var objDistance: f32 = undefined;
            if (object.geometry.intersect(rayOrigin, rayDirection, &objDistance) and objDistance < minDistance) {
                minDistance = objDistance;
                hit.* = rayOrigin + vec.scale(rayDirection, objDistance);
                norm.* = vec.normalize(hit.* - object.geometry.center());
                obj.* = object;
            }
        }
        return minDistance < 1000;
    }
};

fn castRay(rayOrigin: Vec3f, rayDirection: Vec3f, scene: Scene) Color {
    var hit: Vec3f = undefined;
    var norm: Vec3f = undefined;
    var object: Object = undefined;
    if (!scene.intersect(rayOrigin, rayDirection, &hit, &norm, &object)) {
        return BACKGROUND_COLOR;
    }

    var diffuseLightIntensity: f32 = 0.0;
    var specularLightIntensity: f32 = 0.0;
    for (scene.lights.items) |light| {
        const lightDir: Vec3f = vec.normalize(light.position - hit);
        diffuseLightIntensity += light.intensity * @max(0.0, vec.dot(lightDir, norm));
        specularLightIntensity += light.intensity * std.math.pow(f32, @max(0.0, vec.dot(-vec.reflect(-lightDir, norm), rayDirection)), object.material.specularExponent);
    }

    const color = vec.scale(object.material.diffuseColor, diffuseLightIntensity * object.material.albedo[0]) + vec.scale(Vec3f{ 1.0, 1.0, 1.0 }, specularLightIntensity * object.material.albedo[1]);
    return vec.toColor(color, 255);
}

fn render(scene: Scene) !void {
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

            frameBuffer[i + j * width] = castRay(Vec3f{ 0, 0, 0 }, direction, scene);
        }
    }

    try image.writeToFile("./src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const ivory = Material{ .albedo = Vec2f{ 0.6, 0.3 }, .diffuseColor = Vec3f{ 0.4, 0.4, 0.3 }, .specularExponent = 50.0 };
    const redRubber = Material{ .albedo = Vec2f{ 0.9, 0.1 }, .diffuseColor = Vec3f{ 0.3, 0.1, 0.1 }, .specularExponent = 10.0 };

    const sphere1 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ -3, 0, -16 }, .radius = 2 } },
        .material = ivory,
    };

    const sphere2 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ -1.0, -1.5, -12 }, .radius = 2 } },
        .material = redRubber,
    };

    const sphere3 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ 1.5, -0.5, -18 }, .radius = 3 } },
        .material = redRubber,
    };

    const sphere4 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ 7, 5, -18 }, .radius = 4 } },
        .material = ivory,
    };

    const light1 = Light{ .position = Vec3f{ -20, 20, 20 }, .intensity = 1.5 };
    const light2 = Light{ .position = Vec3f{ 30, 50, -25 }, .intensity = 1.8 };
    const light3 = Light{ .position = Vec3f{ 30, 20, 30 }, .intensity = 1.7 };

    var scene = Scene{};
    try scene.objects.append(sphere1);
    try scene.objects.append(sphere2);
    try scene.objects.append(sphere3);
    try scene.objects.append(sphere4);

    try scene.lights.append(light1);
    try scene.lights.append(light2);
    try scene.lights.append(light3);

    try render(scene);
}
