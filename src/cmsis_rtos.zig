const std = @import("std");

pub const capi = @cImport({
    @cInclude("cmsis_os2.h");
});

pub const RtosError = error{
    MappingError,
};

pub const OsStatus = error{
    Error,
    ErrorTimeout,
    ErrorResource,
    ErrorParameter,
    ErrorNoMemory,
    ErrorIsr,
    ErrorCreatingThread,
};

// Must match definition in cmsis_os2.h
pub const LockState = enum(i32) {
    NotLocked = 0,
    Locked = 1,
};

// Must match definition in cmsis_os2.h
pub const OsThreadState = enum(i32) {
    Inactive = 0,
    Ready = 1,
    Running = 2,
    Blocked = 3,
    Terminated = 4,
    Error = -1,
};

// Must match definition in cmsis_os2.h
pub const OsThreadPriority = enum(i32) {
    None = 0,
    Idle = 1,
    Low = 8,
    Low1 = 8 + 1,
    Low2 = 8 + 2,
    Low3 = 8 + 3,
    Low4 = 8 + 4,
    Low5 = 8 + 5,
    Low6 = 8 + 6,
    Low7 = 8 + 7,
    BelowNormal = 16,
    BelowNormal1 = 16 + 1,
    BelowNormal2 = 16 + 2,
    BelowNormal3 = 16 + 3,
    BelowNormal4 = 16 + 4,
    BelowNormal5 = 16 + 5,
    BelowNormal6 = 16 + 6,
    BelowNormal7 = 16 + 7,
    Normal = 24,
    Normal1 = 24 + 1,
    Normal2 = 24 + 2,
    Normal3 = 24 + 3,
    Normal4 = 24 + 4,
    Normal5 = 24 + 5,
    Normal6 = 24 + 6,
    Normal7 = 24 + 7,
    AboveNormal = 32,
    AboveNormal1 = 32 + 1,
    AboveNormal2 = 32 + 2,
    AboveNormal3 = 32 + 3,
    AboveNormal4 = 32 + 4,
    AboveNormal5 = 32 + 5,
    AboveNormal6 = 32 + 6,
    AboveNormal7 = 32 + 7,
    High = 40,
    High1 = 40 + 1,
    High2 = 40 + 2,
    High3 = 40 + 3,
    High4 = 40 + 4,
    High5 = 40 + 5,
    High6 = 40 + 6,
    High7 = 40 + 7,
    Realtime = 48,
    Realtime1 = 48 + 1,
    Realtime2 = 48 + 2,
    Realtime3 = 48 + 3,
    Realtime4 = 48 + 4,
    Realtime5 = 48 + 5,
    Realtime6 = 48 + 6,
    Realtime7 = 48 + 7,
    ISR = 56,
    Error = -1,
};

pub const OsKernelState = enum {
    Inactive,
    Ready,
    Running,
    Locked,
    Suspended,
    Error,
    Unknown,

    pub fn mapFromApi(state: capi.osKernelState_t) OsKernelState {
        switch (state) {
            capi.osKernelInactive => {
                return OsKernelState.Inactive;
            },
            capi.osKernelReady => {
                return OsKernelState.Ready;
            },
            capi.osKernelRunning => {
                return OsKernelState.Running;
            },
            capi.osKernelLocked => {
                return OsKernelState.Locked;
            },
            capi.osKernelSuspended => {
                return OsKernelState.Suspended;
            },
            capi.osKernelError => {
                return OsKernelState.Error;
            },
            else => {
                return OsKernelState.Unknown;
            },
        }
    }
};

fn mapMaybeError(status: capi.osStatus_t) OsStatus!void {
    switch (status) {
        capi.osError => {
            return OsStatus.Error;
        },
        capi.osErrorTimeout => {
            return OsStatus.ErrorTimeout;
        },
        capi.osErrorResource => {
            return OsStatus.ErrorResource;
        },
        capi.osErrorParameter => {
            return OsStatus.ErrorParameter;
        },
        capi.osErrorNoMemory => {
            return OsStatus.ErrorNoMemory;
        },
        capi.osErrorISR => {
            return OsStatus.ErrorIsr;
        },
        else => {
            return;
        },
    }
}

pub const osThreadAttr = capi.osThreadAttr_t;
pub const osThreadFunc = capi.osThreadFunc_t;
pub const osThreadId = *anyopaque;

pub fn StackBuffer(comptime SizeInBytes: comptime_int) type {
    comptime std.debug.assert(SizeInBytes % @sizeOf(u64) == 0);
    return struct {
        const dwords = SizeInBytes / @sizeOf(u64);
        const Type = [SizeInBytes / @sizeOf(u64)]u64;

        pub fn init() Type {
            return std.mem.zeroes([dwords]u64);
        }
    };
}

pub fn osKernelInitialize() OsStatus!void {
    return mapMaybeError(capi.osKernelInitialize());
}

pub fn osKernelStart() OsStatus!void {
    return mapMaybeError(capi.osKernelStart());
}

pub fn osKernelLock() OsStatus!LockState {
    const status = try capi.osKernelLock();
    return @enumFromInt(status);
}

pub fn osKernelUnlock() OsStatus!LockState {
    const status = try capi.osKernelUnlock();
    return @enumFromInt(status);
}

pub fn osKernelRestoreLock(state: LockState) OsStatus!LockState {
    const status = try capi.osKernelRestoreLock(@intFromEnum(state));
    return @enumFromInt(status);
}

pub fn osKernelSuspend() u32 {
    return capi.osKernelSuspend();
}

pub fn osKernelResume(sleep_ticks: u32) void {
    capi.osKernelResume(sleep_ticks);
}

pub fn osKernelGetTickCount() u32 {
    return capi.osKernelGetTickCount();
}

pub fn osKernelGetTickFreq() u32 {
    return capi.osKernelGetTickFreq();
}

pub fn osKernelGetSysTimerCount() u32 {
    return capi.osKernelGetSysTimerCount();
}

pub fn osKernelGetSysTimerFreq() u32 {
    return capi.osKernelGetSysTimerFreq();
}

pub fn osKernelGetState() OsKernelState {
    return OsKernelState.mapFromApi(capi.osKernelGetState());
}

const OsVersion = capi.osVersion_t;

pub fn osKernelGetInfo(buf: []u8) OsStatus!OsVersion {
    var version: OsVersion = undefined;
    try mapMaybeError(capi.osKernelGetInfo(&version, buf.ptr, buf.len));
    return version;
}

pub fn osThreadNew(func: osThreadFunc, arg: ?*anyopaque, attr: [*c]const osThreadAttr) OsStatus!osThreadId {
    const result = capi.osThreadNew(func, arg, attr);
    if (result == null) {
        return OsStatus.ErrorCreatingThread;
    }
    return result.?;
}

pub fn osThreadGetName(thread: osThreadId) []const u8 {
    return std.mem.sliceTo(capi.osThreadGetName(thread), 0);
}

pub fn osThreadGetId() ?osThreadId {
    return capi.osThreadGetId();
}

pub fn osThreadGetState(thread_id: osThreadId) OsThreadState {
    return @enumFromInt(capi.osThreadGetState(thread_id));
}

pub fn osThreadSetPriority(thread_id: osThreadId, priority: OsThreadPriority) OsStatus!void {
    return mapMaybeError(capi.osThreadSetPriority(thread_id, @intFromEnum(priority)));
}

pub fn osDelay(ticks: u32) OsStatus!void {
    return mapMaybeError(capi.osDelay(ticks));
}
