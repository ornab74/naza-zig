const std = @import("std");

pub fn build(b: *std.Build) void {
    // The pure-Zig kernels need the host's SIMD instruction set to approach
    // the performance of native inference runtimes. Cross-compilers can opt
    // out with `-Dnative-cpu=false`.
    const native_cpu = b.option(bool, "native-cpu", "use the host CPU feature set") orelse true;
    var default_target: std.Target.Query = .{};
    if (native_cpu) default_target.cpu_model = .native;
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    // Model inference is dominated by scalar dequantization/matmul loops;
    // Debug mode is unusably slow for the interactive application. Keep tests
    // explicitly overridable, while making the normal executable fast by
    // default (`-Doptimize=Debug` remains available for debugging).
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "optimization mode") orelse .ReleaseFast;

    const root = b.createModule(.{
        .root_source_file = b.path("src/naza_all.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "naza-zig",
        .root_module = root,
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the NAZA pure-Zig monolith");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.stdio = .inherit;
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    run_step.dependOn(&run_cmd.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/naza_all.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run monolith tests");
    test_step.dependOn(&run_tests.step);
}
