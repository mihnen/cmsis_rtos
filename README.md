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
const libcmsisrtx = b.dependency("libcmsisrtx", .{ .target = target, .optimize = optimize }).artifact("libcmsisrtx");
exe.linkLibrary(libcmsisrtx);
```

In your build.zig.zon file. This assumes you have cloned this repo under src/lib/cmsis-rtos

```zig
.dependencies = .{
    .libcmsisrtx = .{
        .path = "src/lib/cmsis-rtos",
    },
},
```

## Authors

Contributors names and contact info

1. Matt Ihnen

## Version History

* 0.0.1
    * Initial Release
