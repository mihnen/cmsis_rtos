const std = @import("std");
pub const newlib = @import("gatz").newlib;

fn addBuildOptionCdefine(c: *std.Build.Step.Compile, opts: *std.Build.Step.Options, opt_name: []const u8, macro_name: []const u8, value: anytype) !void {
    var buf = [_]u8{0} ** 64;

    opts.addOption(@TypeOf(value), opt_name, value);

    switch (@typeInfo(@TypeOf(value))) {
        .Bool => {
            _ = try std.fmt.bufPrint(&buf, "{d}", .{@intFromBool(value)});
        },
        .Int => {
            _ = try std.fmt.bufPrint(&buf, "{d}", .{value});
        },
        else => {
            @compileError("unsupported type");
        },
    }

    c.defineCMacro(macro_name, &buf);
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const options = b.addOptions();

    // Kernel
    const dynamic_mem_size = b.option(u32, "dynamic_mem_size", "Global memory size (must be multiple of 8!)") orelse 32768;
    const tick_freq = b.option(u32, "tick_freq", "system tick frequency") orelse 1000;
    const robin_timeout = b.option(u32, "robin_timeout", "round robin timeout (in ticks) before tasks switch") orelse 5;
    const robin_enable = b.option(bool, "robin_enable", "Enable round robin task switching") orelse true;
    const isr_fifo_queue = b.option(u32, "isr_fifo_queue", "Size of isr fifo queue") orelse 16;
    // Threads
    const thread_obj_mem = b.option(bool, "thread_obj_mem", "Enable thread allocation from object specific memory pool") orelse false;
    const stack_check = b.option(bool, "stack_check", "Enable stack overflow checks when tasks switch") orelse false;
    const stack_watermark = b.option(bool, "stack_watermark", "Enables stack watermark for checking task stack usage") orelse false;
    const thread_num = b.option(u32, "thread_num", "Defines maximum number of user threads that can be active at the same time. Applies to user threads with system provided memory for control blocks.") orelse 1;
    const idle_thread_stack_size = b.option(u32, "idle_thread_stack_size", "Stack size of idle thread") orelse 512;
    // Timers
    const timer_obj_mem = b.option(bool, "timer_obj_mem", "Enable timer allocation from object specific memory pool") orelse false;
    const timer_num = b.option(u32, "timer_num", "Defines maximum number of objects that can be active at the same time. Applies to objects with system provided memory for control blocks.") orelse 1;
    const timer_thread_prio = b.option(u32, "timer_thread_pri", "Defines priority for timer thread. Default value is 40. Value range is [8-48], in multiples of 8. The numbers have the following priority correlation: 8=Low; 16=Below Normal; 24=Normal; 32=Above Normal; 40=High; 48=Realtime") orelse 40;
    const timer_stack_size = b.option(u32, "timer_stack_size", "Defines stack size for Timer thread. May be set to 0 when timers are not used. Default value is 512. Value range is [0-1073741824], in multiples of 8.") orelse 512;
    const timer_cb_queue = b.option(u32, "timer_cb_queue", "Number of concurrent active timer callback functions. May be set to 0 when timers are not used. Default value is 4. Value range is [0-256].") orelse 4;
    // Event flags
    const evflags_obj_mem = b.option(bool, "evflags_obj_mem", "Enable event flag allocation from object specific memory pool") orelse false;
    const evflags_num = b.option(u32, "evflags_num", "Defines maximum number of objects that can be active at the same time. Applies to objects with system provided memory for control blocks. Value range is [1-1000].") orelse 1;

    const lib = b.addStaticLibrary(.{
        .name = "cmsis_rtos_clib",
        .target = target,
        .optimize = optimize,
    });

    // Kernel options
    try addBuildOptionCdefine(lib, options, "dynamic_mem_size", "OS_DYNAMIC_MEM_SIZE", dynamic_mem_size);
    try addBuildOptionCdefine(lib, options, "tick_freq", "OS_TICK_FREQ", tick_freq);
    try addBuildOptionCdefine(lib, options, "isr_fifo_queue", "OS_ISR_FIFO_QUEUE", isr_fifo_queue);
    try addBuildOptionCdefine(lib, options, "robin_timeout", "OS_ROBIN_TIMEOUT", robin_timeout);
    try addBuildOptionCdefine(lib, options, "robin_enable", "OS_ROBIN_ENABLE", robin_enable);
    // Thread options
    try addBuildOptionCdefine(lib, options, "thread_obj_mem", "OS_THREAD_OBJ_MEM", thread_obj_mem);
    try addBuildOptionCdefine(lib, options, "thread_num", "OS_THREAD_NUM", thread_num);
    try addBuildOptionCdefine(lib, options, "idle_thread_stack_size", "OS_IDLE_THREAD_STACK_SIZE", idle_thread_stack_size);
    try addBuildOptionCdefine(lib, options, "stack_check", "OS_STACK_CHECK", stack_check);
    try addBuildOptionCdefine(lib, options, "stack_watermark", "OS_STACK_WATERMARK", stack_watermark);
    // Timer options
    try addBuildOptionCdefine(lib, options, "timer_obj_mem", "OS_TIMER_OBJ_MEM", timer_obj_mem);
    try addBuildOptionCdefine(lib, options, "timer_num", "OS_TIMER_NUM", timer_num);
    try addBuildOptionCdefine(lib, options, "timer_thread_pri", "OS_TIMER_THREAD_PRIO", timer_thread_prio);
    try addBuildOptionCdefine(lib, options, "timer_stack_size", "OS_TIMER_THREAD_STACK_SIZE", timer_stack_size);
    try addBuildOptionCdefine(lib, options, "timer_cb_queue", "OS_TIMER_CB_QUEUE", timer_cb_queue);
    // Event flags options
    try addBuildOptionCdefine(lib, options, "evflags_obj_mem", "OS_EVFLAGS_OBJ_MEM", evflags_obj_mem);
    try addBuildOptionCdefine(lib, options, "evflags_num", "OS_EVFLAGS_NUM", evflags_num);

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
