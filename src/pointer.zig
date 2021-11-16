const std = @import("std");
const assert = std.debug.assert;

pub fn Pointer(comptime T: type) type {
    assert(@typeInfo(T) == .Pointer);
    return packed struct {
        address: u64,

        const Self = @This();

        pub fn pointer(self: Self) T {
            return @intToPtr(T, @intCast(usize, self.address));
        }

        pub fn setPointer(self: *Self, ptr: T) void {
            self.address = @intCast(u64, @ptrToInt(ptr));
        }
    };
}

pub fn OptionalPointer(comptime T: type) type {
    assert(@typeInfo(T) == .Pointer);
    return packed struct {
        address: u64,

        const Self = @This();

        pub fn pointer(self: Self) ?T {
            return @intToPtr(?T, @intCast(usize, self.address));
        }

        pub fn setPointer(self: *Self, ptr: ?T) void {
            self.address = @intCast(u64, @ptrToInt(ptr));
        }
    };
}
