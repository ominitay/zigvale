const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const stage1 = b.option(bool, "stage1", "Force using the stage1 compiler");

    const lib_tests = b.addTest("zigvale.zig");
    lib_tests.setTarget(target);
    lib_tests.setBuildMode(mode);
    lib_tests.use_stage1 = stage1;

    const lib_test_doc = lib_tests;
    lib_test_doc.emit_docs = .emit;

    const tests = b.step("test", "Run tests");
    tests.dependOn(&lib_tests.step);

    const docs = b.step("docs", "Generate documentation");
    docs.dependOn(&lib_test_doc.step);
}
