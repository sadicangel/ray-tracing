pub inline fn length(self: @Vector(3, f32)) f32 {
    return @sqrt(self[0] * self[0] + self[1] * self[1] + self[2] * self[2]);
}

pub inline fn lengthSquared(self: @Vector(3, f32)) f32 {
    return self[0] * self[0] + self[1] * self[1] + self[2] * self[2];
}

pub inline fn normalize(self: @Vector(3, f32)) @Vector(3, f32) {
    const len: f32 = length(self);
    return @Vector(3, f32){ self[0] / len, self[1] / len, self[2] / len };
}

pub inline fn dot(self: @Vector(3, f32), other: @Vector(3, f32)) f32 {
    return self[0] * other[0] + self[1] * other[1] + self[2] * other[2];
}

pub inline fn scale(self: @Vector(3, f32), x: f32) @Vector(3, f32) {
    const s: @Vector(3, f32) = @splat(x);
    return self * s;
}

const ZERO: @Vector(3, f32) = @splat(0.0);
const UNIT: @Vector(3, f32) = @splat(1.0);
const RBG: @Vector(3, f32) = @splat(255);

pub inline fn toColor(vector: @Vector(3, f32), alpha: u8) @Vector(4, u8) {
    const clamped: @Vector(3, u8) = @intFromFloat(RBG * @max(ZERO, @min(UNIT, vector)));
    return @Vector(4, u8){ clamped[0], clamped[1], clamped[2], alpha };
}

pub inline fn reflect(incident: @Vector(3, f32), normal: @Vector(3, f32)) @Vector(3, f32) {
    return incident - scale(normal, 2.0 * dot(incident, normal));
}

pub inline fn refract(incident: @Vector(3, f32), normal: @Vector(3, f32), refractiveIndex: f32) @Vector(3, f32) {
    var cosi: f32 = -@max(-1.0, @min(1.0, dot(incident, normal)));
    var etai: f32 = 1.0;
    var etat: f32 = refractiveIndex;
    var norm = normal;
    if (cosi < 0.0) {
        cosi = -cosi;
        etai, etat = .{ etat, etai };
        norm = -norm;
    }

    const eta: f32 = etai / etat;
    const k: f32 = 1.0 - eta * eta * (1.0 - cosi * cosi);
    if (k < 0.0) {
        return ZERO;
    }
    return scale(incident, eta) + scale(norm, eta * cosi - @sqrt(k));
}
