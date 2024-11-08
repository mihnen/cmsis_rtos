const std = @import("std");
pub const newlib = @import("gatz").newlib;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();

    const dynamic_mem_size = b.option(u32, "dynamic_mem_size", "Global memory size (must be multiple of 8!)") orelse 32768;
    const tick_freq = b.option(u32, "tick_freq", "system tick frequency") orelse 1000;
    const round_robin_to = b.option(u32, "round_robin_to", "round robin timeout (in ticks) before tasks switch") orelse 5;
    const enable_round_robin = b.option(bool, "enable_round_robin", "Enable round robin task switching") orelse true;
    const enable_stack_checks = b.option(bool, "enable_stack_checks", "Enable stack overflow checks when tasks switch") orelse false;
    const enable_stack_watermark = b.option(bool, "enable_stack_watermark", "Enables stack watermark for checking task stack usage") orelse false;
    const isr_queue_size = b.option(u32, "isr_queue_size", "Size of isr fifo queue") orelse 16;

    options.addOption(u32, "dynamic_mem_size", dynamic_mem_size);
    options.addOption(u32, "tick_freq", tick_freq);
    options.addOption(u32, "round_robin_to", round_robin_to);
    options.addOption(bool, "enable_round_robin", enable_round_robin);
    options.addOption(bool, "enable_stack_checks", enable_stack_checks);
    options.addOption(bool, "enable_stack_watermark", enable_stack_watermark);
    options.addOption(u32, "isr_queue_size", isr_queue_size);

    const lib = b.addStaticLibrary(.{
        .name = "cmsis_rtos_clib",
        .target = target,
        .optimize = optimize,
    });

    const dynamic_mem_size_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{dynamic_mem_size},
    );

    if (dynamic_mem_size_value) |value| {
        lib.defineCMacro("OS_DYNAMIC_MEM_SIZE", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const tick_freq_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{tick_freq},
    );

    if (tick_freq_value) |value| {
        lib.defineCMacro("OS_TICK_FREQ", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const round_robin_to_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{round_robin_to},
    );

    if (round_robin_to_value) |value| {
        lib.defineCMacro("OS_ROBIN_TIMEOUT", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const enable_stack_checks_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{@intFromBool(enable_stack_checks)},
    );

    if (enable_stack_checks_value) |value| {
        lib.defineCMacro("OS_STACK_CHECK", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const enable_stack_watermark_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{@intFromBool(enable_stack_watermark)},
    );

    if (enable_stack_watermark_value) |value| {
        lib.defineCMacro("OS_STACK_WATERMARK", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const isr_queue_size_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{isr_queue_size},
    );

    if (isr_queue_size_value) |value| {
        lib.defineCMacro("OS_ISR_FIFO_QUEUE", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

    const enable_round_robin_value = std.fmt.allocPrint(
        b.allocator,
        "{d}",
        .{@intFromBool(enable_round_robin)},
    );

    if (enable_round_robin_value) |value| {
        lib.defineCMacro("OS_ROBIN_ENABLE", value);
    } else |err| {
        std.debug.print("{s}\n", .{@errorName(err)});
    }

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
