const std = @import("std");
const stb = @import("zstbi");
const vec = @import("vec.zig");

const WINDOW_WIDTH = 1024;
const WINDOW_HEIGHT = 768;
const POSITION = Vec3f{ 0, 0, 0 };
const FOV: f32 = std.math.pi / 2.0;
const MAX_DEPTH = 4;

const Vec3f = @Vector(3, f32);
const Vec4f = @Vector(4, f32);
const Color = @Vector(4, u8);

const Geometry = union(enum) {
    Plane: Plane,
    Sphere: Sphere,

    fn normal(self: Geometry, point: Vec3f) Vec3f {
        switch (self) {
            inline else => |impl| return impl.normal(point),
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

    fn normal(self: Sphere, point: Vec3f) Vec3f {
        return vec.normalize(point - self.center);
    }

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

const Plane = struct {
    planeNormal: Vec3f,
    planeOffset: f32,

    fn normal(self: Plane, point: Vec3f) Vec3f {
        _ = point;
        return self.planeNormal;
    }

    fn intersect(self: Plane, rayOrigin: Vec3f, rayDirection: Vec3f, distance: *f32) bool {
        const denom: f32 = vec.dot(self.planeNormal, rayDirection);
        if (@abs(denom) < 1e-6) return false;
        distance.* = -(vec.dot(self.planeNormal, rayOrigin) + self.planeOffset) / denom;
        return distance.* >= 1e-4;
    }
};

const Material = struct {
    albedo: Vec4f,
    diffuseColor: Vec3f,
    specularExponent: f32,
    refactiveIndex: f32,
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
    background: []Vec3f,
    objects: std.ArrayList(Object) = std.ArrayList(Object).init(std.heap.page_allocator),
    lights: std.ArrayList(Light) = std.ArrayList(Light).init(std.heap.page_allocator),

    fn intersect(self: Scene, rayOrigin: Vec3f, rayDirection: Vec3f, hit: *Vec3f, normal: *Vec3f, obj: *Object) bool {
        var minDistance = std.math.floatMax(f32);
        for (self.objects.items) |object| {
            var objDistance: f32 = undefined;
            if (object.geometry.intersect(rayOrigin, rayDirection, &objDistance) and objDistance < minDistance) {
                minDistance = objDistance;
                hit.* = rayOrigin + vec.scale(rayDirection, objDistance);
                normal.* = object.geometry.normal(hit.*);
                obj.* = object;
            }
        }
        return minDistance < 1000;
    }
};

fn castRay(scene: Scene, background: Vec3f, rayOrigin: Vec3f, rayDirection: Vec3f, depth: usize) Vec3f {
    var hit: Vec3f = undefined;
    var normal: Vec3f = undefined;
    var object: Object = undefined;
    if (depth > MAX_DEPTH or !scene.intersect(rayOrigin, rayDirection, &hit, &normal, &object)) {
        return background;
    }

    const reflectDirection: Vec3f = vec.normalize(vec.reflect(rayDirection, normal));
    const reflectOrigin: Vec3f = if (vec.dot(reflectDirection, normal) < 0.0) hit - vec.scale(normal, 1e-3) else hit + vec.scale(normal, 1e-3);
    const reflectColor = castRay(scene, background, reflectOrigin, reflectDirection, depth + 1);
    const refractDirection: Vec3f = vec.normalize(vec.refract(rayDirection, normal, object.material.refactiveIndex));
    const refractOrigin: Vec3f = if (vec.dot(refractDirection, normal) < 0.0) hit - vec.scale(normal, 1e-3) else hit + vec.scale(normal, 1e-3);
    const refractColor = castRay(scene, background, refractOrigin, refractDirection, depth + 1);

    var diffuseLightIntensity: f32 = 0.0;
    var specularLightIntensity: f32 = 0.0;
    for (scene.lights.items) |light| {
        const lightDirection = vec.normalize(light.position - hit);
        const lightDistance = vec.length(light.position - hit);
        const shadowOrigin = if (vec.dot(lightDirection, normal) < 0.0)
            hit - vec.scale(normal, 1e-3)
        else
            hit + vec.scale(normal, 1e-3);

        var shadowHit: Vec3f = undefined;
        var shadowNormal: Vec3f = undefined;
        var shadowObject: Object = undefined;
        if (scene.intersect(shadowOrigin, lightDirection, &shadowHit, &shadowNormal, &shadowObject) and vec.length(shadowHit - shadowOrigin) < lightDistance) {
            continue;
        }

        diffuseLightIntensity += light.intensity * @max(0.0, vec.dot(lightDirection, normal));
        specularLightIntensity += light.intensity * std.math.pow(f32, @max(0.0, vec.dot(-vec.reflect(-lightDirection, normal), rayDirection)), object.material.specularExponent);
    }

    const diff = vec.scale(object.material.diffuseColor, diffuseLightIntensity * object.material.albedo[0]);
    const spec = vec.scale(Vec3f{ 1.0, 1.0, 1.0 }, specularLightIntensity * object.material.albedo[1]);
    const refl = vec.scale(reflectColor, object.material.albedo[2]);
    const refr = vec.scale(refractColor, object.material.albedo[3]);
    return spec + diff + refl + refr;
}

inline fn getDirection(i: usize, j: usize) Vec3f {
    const ij: f32 = @floatFromInt(i);
    const jf: f32 = @floatFromInt(j);
    const x: f32 = (2 * (0.5 + ij) / WINDOW_WIDTH - 1) * @tan(FOV / 2.0) * WINDOW_WIDTH / WINDOW_HEIGHT;
    const y: f32 = -(2 * (0.5 + jf) / WINDOW_HEIGHT - 1) * @tan(FOV / 2.0);
    return vec.normalize(Vec3f{ x, y, -1 });
}

fn render(scene: Scene) !void {
    var image = try stb.Image.createEmpty(WINDOW_WIDTH, WINDOW_HEIGHT, 4, .{});

    var frameBuffer: *[WINDOW_WIDTH * WINDOW_HEIGHT]Color = @alignCast(@ptrCast(&image.data[0]));

    for (0..WINDOW_HEIGHT) |j| {
        for (0..WINDOW_WIDTH) |i| {
            const offset = j * WINDOW_WIDTH + i;
            var color3f = castRay(scene, scene.background[offset], POSITION, getDirection(i, j), 0);
            const max: f32 = @max(color3f[0], color3f[1], color3f[2]);
            if (max > 1) {
                color3f = vec.scale(color3f, 1 / max);
            }
            frameBuffer[offset] = vec.toColor(color3f, 255);
        }
    }

    try image.writeToFile("./src/main.png", stb.ImageWriteFormat.png);
}

pub fn main() !void {
    stb.init(std.heap.page_allocator);

    const background = try stb.Image.loadFromFile("./src/background.jpg", 0);

    const ivory = Material{ .albedo = Vec4f{ 0.6, 0.3, 0.1, 0.0 }, .diffuseColor = Vec3f{ 0.4, 0.4, 0.3 }, .specularExponent = 50.0, .refactiveIndex = 1.0 };
    const glass = Material{ .albedo = Vec4f{ 0.0, 0.5, 0.1, 0.8 }, .diffuseColor = Vec3f{ 0.6, 0.7, 0.8 }, .specularExponent = 125.0, .refactiveIndex = 1.5 };
    const redRubber = Material{ .albedo = Vec4f{ 0.9, 0.1, 0.0, 0.0 }, .diffuseColor = Vec3f{ 0.3, 0.1, 0.1 }, .specularExponent = 10.0, .refactiveIndex = 1.0 };
    const mirror = Material{ .albedo = Vec4f{ 0.0, 10.0, 0.8, 0.0 }, .diffuseColor = Vec3f{ 1.0, 1.0, 1.0 }, .specularExponent = 1425.0, .refactiveIndex = 1.0 };
    const carpet = Material{ .albedo = Vec4f{ 0.1, 0.025, 0.0, 0.04 }, .diffuseColor = Vec3f{ 0.5, 0.3, 0.1 }, .specularExponent = 0.0, .refactiveIndex = 0.0 };

    const plane = Object{
        .geometry = Geometry{ .Plane = Plane{ .planeNormal = .{ 0, 1, 0 }, .planeOffset = 4 } },
        .material = carpet,
    };

    const sphere1 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ -3, 0, -16 }, .radius = 2 } },
        .material = ivory,
    };

    const sphere2 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ -1.0, -1.5, -12 }, .radius = 2 } },
        .material = glass,
    };

    const sphere3 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ 1.5, -0.5, -18 }, .radius = 3 } },
        .material = redRubber,
    };

    const sphere4 = Object{
        .geometry = Geometry{ .Sphere = Sphere{ .center = Vec3f{ 7, 5, -18 }, .radius = 4 } },
        .material = mirror,
    };

    const light1 = Light{ .position = Vec3f{ -20, 20, 20 }, .intensity = 1.5 };
    const light2 = Light{ .position = Vec3f{ 30, 50, -25 }, .intensity = 1.8 };
    const light3 = Light{ .position = Vec3f{ 30, 20, 30 }, .intensity = 1.7 };

    const imgDataF32 = try std.heap.page_allocator.alloc(Vec3f, WINDOW_WIDTH * WINDOW_HEIGHT);
    defer std.heap.page_allocator.free(imgDataF32);

    for (0..WINDOW_WIDTH * WINDOW_HEIGHT) |i| {
        const r: f32 = @floatFromInt(background.data[i * 3 + 0]);
        const g: f32 = @floatFromInt(background.data[i * 3 + 1]);
        const b: f32 = @floatFromInt(background.data[i * 3 + 2]);
        imgDataF32[i] = .{ r / 255.0, g / 255.0, b / 255.0 };
    }

    var scene = Scene{ .background = imgDataF32 };

    try scene.objects.append(plane);
    try scene.objects.append(sphere1);
    try scene.objects.append(sphere2);
    try scene.objects.append(sphere3);
    try scene.objects.append(sphere4);

    try scene.lights.append(light1);
    try scene.lights.append(light2);
    try scene.lights.append(light3);

    try render(scene);
}
