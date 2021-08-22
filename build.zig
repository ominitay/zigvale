const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();

    const lib_tests = b.addTest("zigvale.zig");
    lib_tests.setBuildMode(mode);

    const tests = b.step("test", "Run tests");
    tests.dependOn(&lib_tests.step);
}
