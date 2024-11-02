const std = @import("std");
pub const newlib = @import("gatz").newlib;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const library_name = "libcmsisrtx";

    const libcmsisrtx = b.addStaticLibrary(.{
        .name = library_name,
        .target = target,
        .optimize = optimize,
    });

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

    libcmsisrtx.addConfigHeader(rte_components_h);

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
        libcmsisrtx.installHeadersDirectory(b.path(header), "", .{});
        libcmsisrtx.addIncludePath(b.path(header));
    }

    // zig fmt: off
    const sources = .{
        "Source/os_systick.c",
        "RTX/Config/handlers.c",
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
        libcmsisrtx.addCSourceFile(.{
            .file = b.path(std.fmt.comptimePrint("{s}/{s}", .{ cmsis_rtos_root, name })),
            .flags = &.{"-std=c11"},
        });
    }

    // TODO: make this dependent on target
    libcmsisrtx.addAssemblyFile(b.path(cmsis_assembly_path));

    newlib.addIncludeHeadersAndSystemPathsTo(b, target, libcmsisrtx) catch |err| switch (err) {
        newlib.Error.CompilerNotFound => {
            std.log.err("Couldn't find arm-none-eabi-gcc compiler!\n", .{});
            unreachable;
        },
        newlib.Error.IncompatibleCpu => {
            std.log.err("Cpu: {s} isn't supported by gatz!\n", .{target.result.cpu.model.name});
            unreachable;
        },
    };

    libcmsisrtx.want_lto = false; // -flto
    libcmsisrtx.link_data_sections = true; // -fdata-sections
    libcmsisrtx.link_function_sections = true; // -ffunction-sections
    libcmsisrtx.link_gc_sections = true; // -Wl,--gc-sections

    // Create artifact for top level project to depend on
    b.getInstallStep().dependOn(&b.addInstallArtifact(libcmsisrtx, .{ .dest_dir = .{ .override = .{ .custom = "" } } }).step);
}
