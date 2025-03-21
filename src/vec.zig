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

pub inline fn toColor(vector: @Vector(3, f32), alpha: u8) @Vector(4, u8) {
    const min: @Vector(3, f32) = @splat(0.0);
    const max: @Vector(3, f32) = @splat(1.0);
    const mul: @Vector(3, f32) = @splat(255);
    const clamped: @Vector(3, u8) = @intFromFloat(mul * @max(min, @min(max, vector)));
    return @Vector(4, u8){ clamped[0], clamped[1], clamped[2], alpha };
}
