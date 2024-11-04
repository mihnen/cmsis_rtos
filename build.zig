const std = @import("std");
pub const newlib = @import("gatz").newlib;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "cmsis_rtos_clib",
        .target = target,
        .optimize = optimize,
    });

    newlib.addIncludeHeadersAndSystemPathsTo(b, target, lib) catch |err| switch (err) {
        newlib.Error.CompilerNotFound => {
            std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
            unreachable;
        },
        newlib.Error.IncompatibleCpu => {
            std.log.err("Cpu: {s} isn't supported by gatz!\n", .{target.result.cpu.model.name});
            unreachable;
        },
    };

    const mod = b.addModule("cmsis_rtos", .{
        .root_source_file = b.path("src/cmsis_rtos.zig"),
        .target = target,
        .optimize = optimize,
    });

    mod.linkLibrary(lib);

    const root = "src/CMSIS_5";
    const cmsis_root = root ++ "/CMSIS";
    const cmsis_dev_root = root ++ "/Device/ARM";
    const cmsis_core_root = cmsis_root ++ "/Core";
    const cmsis_rtos_root = cmsis_root ++ "/RTOS2";

    const target_name = target.result.cpu.model.name;

    var cmsis_header_name: []const u8 = undefined;
    var cmsis_header_path: []const u8 = undefined;
    var cmsis_assembly_path: []const u8 = undefined;

    if (std.mem.eql(u8, target_name, std.Target.arm.cpu.cortex_m7.name)) {
        cmsis_header_name = "ARMCM7.h";
        cmsis_header_path = cmsis_dev_root ++ "/ARMCM7/Include";
        cmsis_assembly_path = cmsis_rtos_root ++ "/RTX/Source/GCC/irq_armv7m.S";
    } else if (std.mem.eql(u8, target_name, std.Target.arm.cpu.cortex_m4.name)) {
        cmsis_header_name = "ARMCM4.h";
        cmsis_header_path = cmsis_dev_root ++ "/ARMCM4/Include";
        cmsis_assembly_path = cmsis_rtos_root ++ "/RTX/Source/GCC/irq_armv7m.S";
    } else if (std.mem.eql(u8, target_name, std.Target.arm.cpu.cortex_m3.name)) {
        cmsis_header_name = "ARMCM3.h";
        cmsis_header_path = cmsis_dev_root ++ "/ARMCM3/Include";
        cmsis_assembly_path = cmsis_rtos_root ++ "/RTX/Source/GCC/irq_armv7m.S";
    } else if (std.mem.eql(u8, target_name, std.Target.arm.cpu.cortex_m0plus.name)) {
        cmsis_header_name = "ARMCM0plus.h";
        cmsis_header_path = cmsis_dev_root ++ "/ARMCM0plus/Include";
        cmsis_assembly_path = cmsis_rtos_root ++ "/RTX/Source/GCC/irq_armv6m.S";
    } else if (std.mem.eql(u8, target_name, std.Target.arm.cpu.cortex_m0.name)) {
        cmsis_header_name = "ARMCM0.h";
        cmsis_header_path = cmsis_dev_root ++ "/ARMCM0/Include";
        cmsis_assembly_path = cmsis_rtos_root ++ "/RTX/Source/GCC/irq_armv6m.S";
    } else {
        cmsis_header_name = "";
        cmsis_header_path = "";
        cmsis_assembly_path = "";
    }

    const rte_components_h = b.addConfigHeader(.{
        .style = .{ .cmake = b.path("RTE_Components.h.in") },
    }, .{
        .CMSIS_DEVICE_HEADER_VALUE = cmsis_header_name,
    });

    lib.addConfigHeader(rte_components_h);

    // zig fmt: off
    // Includes
    const headers_paths = .{
        "",
        cmsis_header_path,
        cmsis_core_root ++ "/Include",
        cmsis_rtos_root ++ "/Include",
        cmsis_rtos_root ++ "/RTX/Include",
        cmsis_rtos_root ++ "/RTX/Config",
        cmsis_rtos_root ++ "/RTX/Source",
    };
    // zig fmt: on

    inline for (headers_paths) |header| {
        lib.addIncludePath(b.path(header));
        mod.addIncludePath(b.path(header));
    }

    // zig fmt: off
    const sources = .{
        "Source/os_systick.c",
        "RTX/Config/RTX_Config.c",
        "RTX/Source/rtx_delay.c",
        "RTX/Source/rtx_evflags.c",
        "RTX/Source/rtx_evr.c",
        "RTX/Source/rtx_kernel.c",
        "RTX/Source/rtx_lib.c",
        "RTX/Source/rtx_memory.c",
        "RTX/Source/rtx_mempool.c",
        "RTX/Source/rtx_msgqueue.c",
        "RTX/Source/rtx_mutex.c",
        "RTX/Source/rtx_semaphore.c",
        "RTX/Source/rtx_system.c",
        "RTX/Source/rtx_thread.c",
        "RTX/Source/rtx_timer.c",
    };
    // zig fmt: on

    inline for (sources) |name| {
        lib.addCSourceFile(.{
            .file = b.path(std.fmt.comptimePrint("{s}/{s}", .{ cmsis_rtos_root, name })),
            .flags = &.{"-std=c99"},
        });
    }

    lib.addAssemblyFile(b.path(cmsis_assembly_path));

    lib.want_lto = false; // -flto
    lib.link_data_sections = true; // -fdata-sections
    lib.link_function_sections = true; // -ffunction-sections
    lib.link_gc_sections = true; // -Wl,--gc-sections

    b.installArtifact(lib);
}
