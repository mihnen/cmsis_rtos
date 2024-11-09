# CMSIS RTOSv2 for Zig

A Zig build system for ARM CMSIS5 RTOSv2.

## Description

This allows the cmsis rtos to be built with the zig build system which can then either be used standlone to link
to other executables or integrated as a zig module to link to a zig application.

## Getting Started

### Dependencies

* Zig (https://ziglang.org/)

### Building Static Library

A static library can be built standalone which can then be linked to your project. Here is an
example of building with an ARM Cortex M7.

* `zig build -Dtarget=arm-freestanding-eabi -Dcpu=cortex_m7`

### Using with a Zig application

In your main build.zig file

```zig
const cmsis_rtos_dep = b.dependency("cmsis_rtos", .{
    .target = target,
    .optimize = optimize,
    // build configuration options
    .dynamic_mem_size = @as(u32, 16384),
    .tick_freq = @as(u32, 1000),
    .robin_timeout = @as(u32, 5),
    .stack_check = true,
    .stack_watermark = true,
});
exe.root_module.addImport("cmsis_rtos", cmsis_rtos_dep.module("cmsis_rtos"));
```

In your build.zig.zon file. This assumes you have cloned this repo under src/lib/cmsis-rtos. The source
code for cmsis is a git submodule so make sure you perform a `git submodule update --init --recursive` to
check out the c sources.

```zig
.dependencies = .{
    .cmsis_rtos = .{
        .path = "src/lib/cmsis-rtos",
    },
},
```

### Example application

```zig
const std = @import("std");
const regs = @import("registers.zig").devices.STM32H753x.peripherals;
const rtos = @import("cmsis_rtos");
const builtin = @import("builtin");

const EventFlags = enum(u32) {
    ToggleLedEvent = 0,
};

var blinkyStack = rtos.StackMem(4096).init();
var blinkyThreadId: rtos.osThreadId = undefined;

var coordinatorStack = rtos.StackMem(4096).init();
var coordinatorThreadId: rtos.osThreadId = undefined;

var evtFlagsMem = rtos.ControlBlockMem(rtos.OsEventFlagsCbSize).init();
var evtFlagsId: rtos.OsEventFlagsId = undefined;

fn coordinatorTask(_: ?*anyopaque) callconv(.C) noreturn {
    var flags = rtos.OsThreadFlags.initEmpty();

    std.log.info("thread name: {s}\n", .{rtos.osThreadGetName(coordinatorThreadId)});

    while (true) {
        rtos.osDelay(500) catch {};
        flags.set(@intFromEnum(EventFlags.ToggleLedEvent));
        _ = rtos.osThreadFlagsSet(blinkyThreadId, flags) catch unreachable;
    }
}

fn blinkyTask(_: ?*anyopaque) callconv(.C) noreturn {
    std.log.debug("Blinky Stack Size: {d}\n", .{blinkyStack.size});
    std.debug.assert(rtos.osThreadGetStackSize(blinkyThreadId) == blinkyStack.size);
    std.log.debug("stack space free: {d}\n", .{rtos.osThreadGetStackSpace(blinkyThreadId)});

    const thread_id = rtos.osThreadGetId();
    if (thread_id) |id| {
        std.log.info("thread name: {s}\n", .{rtos.osThreadGetName(id)});
    }

    std.log.debug("thread name: {s}\n", .{rtos.osThreadGetName(blinkyThreadId)});
    std.log.debug("state: {s}\n", .{@tagName(rtos.osThreadGetState(blinkyThreadId))});

    rtos.osThreadSetPriority(blinkyThreadId, rtos.OsThreadPriority.Normal) catch |err| {
        std.log.debug("error {s}\n", .{@errorName(err)});
    };

    std.debug.assert(rtos.osThreadGetPriority(blinkyThreadId) == rtos.OsThreadPriority.Normal);

    // Enable GPIOE clock
    regs.RCC.AHB4ENR.modify(.{ .GPIOBEN = 1 });

    // Setup red/green led as outputs
    regs.GPIOB.ODR.modify(.{ .OD14 = 0, .OD15 = 1 });
    regs.GPIOB.MODER.modify(.{ .MODE14 = 1, .MODE15 = 1 });

    while (true) {
        _ = rtos.osThreadFlagsWait(.{ .mask = 1 << @intFromEnum(EventFlags.ToggleLedEvent) }, rtos.OsFlagOptions.WaitAny, rtos.osWaitForever) catch unreachable;
        regs.GPIOB.ODR.toggle(.{ .OD14 = 1, .OD15 = 1 });
    }
}

pub fn main() void {
    std.log.info("Zig version: {s}\n", .{builtin.zig_version_string});

    rtosInfo();

    rtos.osKernelInitialize() catch |err| {
        std.log.err("error {s}\n", .{@errorName(err)});
    };

    blinkyThreadId = rtos.osThreadNew(blinkyTask, null, &.{
        .name = "blinky",
        .stack_mem = &blinkyStack.mem,
        .stack_size = blinkyStack.size,
    }) catch unreachable;

    coordinatorThreadId = rtos.osThreadNew(coordinatorTask, null, &.{
        .name = "coord",
        .stack_mem = &coordinatorStack.mem,
        .stack_size = coordinatorStack.size,
    }) catch unreachable;

    // Create some event flags
    evtFlagsId = rtos.osEventFlagsNew(&.{
        .name = "evtFlags",
        .cb_mem = &evtFlagsMem.mem,
        .cb_size = evtFlagsMem.size,
    }) catch unreachable;

    const status = rtos.osKernelGetState();

    switch (status) {
        rtos.OsKernelState.Ready => {
            rtos.osKernelStart() catch |err| {
                std.log.err("error {s}\n", .{@errorName(err)});
            };
        },
        else => {
            std.log.err("invalid kernel state: {s}!\n", .{@tagName(status)});
        },
    }

    unreachable;
}

pub fn rtosInfo() void {
    var buf = std.mem.zeroes([100]u8);
    if (rtos.osKernelGetInfo(&buf)) |ver| {
        std.log.info("Kernel Info: {s}\n", .{buf});
        std.log.info("Kernel Version: {d}\n", .{ver.kernel});
        std.log.info("Kernal API Version: {d}\n", .{ver.api});
    } else |err| {
        std.log.err("error {s}\n", .{@errorName(err)});
    }
}
```

### Limitations

* Currently on soft float targets are supported.
* Supported cores
    * Cortex M0
    * Cortex M0+
    * Cortex M3
    * Cortex M4
    * Cortex M7

## Authors

Contributors names and contact info

1. Matt Ihnen <mihnen@milwaukeeelectronics.com> <matt.ihnen@gmail.com>

## Version History

* 0.0.1
    * Initial Release
