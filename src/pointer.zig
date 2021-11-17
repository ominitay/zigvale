const std = @import("std");
const assert = std.debug.assert;

pub fn Pointer(comptime T: type) type {
    assert(@typeInfo(T) == .Pointer);
    return packed struct {
        pointer: T,
        padding: @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = 64 - @bitSizeOf(T),
        } }) = 0,
    };
}
