const std = @import("std");

pub const capi = @cImport({
    @cInclude("cmsis_os2.h");
    // for osRtxXXXCbSize definitions
    @cInclude("rtx_os.h");
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
    ErrorCreatingEventFlags,
    ErrorCreatingTimer,
    ErrorCreatingMutex,
    ErrorCreatingMessageQueue,
    ErrorCreatingSemaphore,
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

pub fn StackMem(comptime SizeInBytes: comptime_int) type {
    return MemBlock(u64, SizeInBytes);
}

pub fn ControlBlockMem(comptime SizeInBytes: comptime_int) type {
    return MemBlock(u32, SizeInBytes);
}

pub fn MessageQueueMem(comptime T: type, comptime N: comptime_int) type {
    // There are 12 undocumented bytes in each item of the queue that RTX
    // uses so we need to account for that in each one of the entries.
    // see: https://github.com/ARM-software/CMSIS_5/issues/1063
    const size = capi.osRtxMessageQueueMemSize(N, @sizeOf(T));
    return MemBlock(u32, size);
}

pub fn MemBlock(comptime T: type, comptime N: comptime_int) type {
    return struct {
        const MemType = [N / @sizeOf(T)]T;

        mem: MemType = std.mem.zeroes(MemType),
        size: usize = N,

        pub fn init() @This() {
            comptime std.debug.assert(N % @sizeOf(T) == 0);
            return .{};
        }
    };
}

// ---- Kernel Management API -------------------------------------------------

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

// ---- Thread Management API -------------------------------------------------

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

pub fn osThreadGetStackSize(thread_id: osThreadId) u32 {
    return capi.osThreadGetStackSize(thread_id);
}

pub fn osThreadGetStackSpace(thread_id: osThreadId) u32 {
    return capi.osThreadGetStackSpace(thread_id);
}

pub fn osThreadSetPriority(thread_id: osThreadId, priority: OsThreadPriority) OsStatus!void {
    return mapMaybeError(capi.osThreadSetPriority(thread_id, @intFromEnum(priority)));
}

pub fn osThreadGetPriority(thread_id: osThreadId) OsThreadPriority {
    return @enumFromInt(capi.osThreadGetPriority(thread_id));
}

pub fn osThreadYield() OsStatus!void {
    return mapMaybeError(capi.osThreadYield());
}

pub fn osThreadSuspend(thread_id: osThreadId) OsStatus!void {
    return mapMaybeError(capi.osThreadSuspend(thread_id));
}

pub fn osThreadResume(thread_id: osThreadId) OsStatus!void {
    return mapMaybeError(capi.osThreadResume(thread_id));
}

pub fn osThreadDetach(thread_id: osThreadId) OsStatus!void {
    return mapMaybeError(capi.osThreadDetach(thread_id));
}

pub fn osThreadJoin(thread_id: osThreadId) OsStatus!void {
    return mapMaybeError(capi.osThreadJoin(thread_id));
}

pub fn osThreadTerminate(thread_id: osThreadId) OsStatus!void {
    return mapMaybeError(capi.osThreadTerminate(thread_id));
}

pub fn osThreadGetCount() u32 {
    return capi.osThreadGetCount();
}

// ---- Thread Flags API ------------------------------------------------------

pub const OsThreadFlags = std.bit_set.IntegerBitSet(32);

pub const OsFlagsError = error{
    Isr,
    Parameter,
    Resource,
    Timeout,
    Unknown,
};

pub const OsFlagOptions = enum(u32) {
    WaitAny = capi.osFlagsWaitAny,
    WaitAll = capi.osFlagsWaitAll,
    NoClear = capi.osFlagsNoClear,
};

fn mapMaybeOsFlagsError(status: u32) OsFlagsError!OsThreadFlags {
    switch (status) {
        capi.osFlagsErrorISR => {
            return OsFlagsError.Isr;
        },
        capi.osFlagsErrorParameter => {
            return OsFlagsError.Parameter;
        },
        capi.osFlagsErrorResource => {
            return OsFlagsError.Resource;
        },
        capi.osFlagsErrorTimeout => {
            return OsFlagsError.Timeout;
        },
        capi.osFlagsErrorUnknown => {
            return OsFlagsError.Unknown;
        },
        else => {
            return .{ .mask = status };
        },
    }
}

pub fn osThreadFlagsSet(thread_id: osThreadId, flags: OsThreadFlags) OsFlagsError!OsThreadFlags {
    const prev_flags = capi.osThreadFlagsSet(thread_id, flags.mask);
    return mapMaybeOsFlagsError(prev_flags);
}

pub fn osThreadFlagsClear(flags: OsThreadFlags) OsFlagsError!OsThreadFlags {
    const prev_flags = capi.osThreadFlagsClear(flags.mask);
    return mapMaybeOsFlagsError(prev_flags);
}

pub fn osThreadFlagsGet() OsThreadFlags {
    return .{ .mask = capi.osThreadFlagsGet() };
}

pub fn osThreadFlagsWait(flags: OsThreadFlags, options: OsFlagOptions, timeout: u32) OsFlagsError!OsThreadFlags {
    const prev_flags = capi.osThreadFlagsWait(flags.mask, @intFromEnum(options), timeout);
    return mapMaybeOsFlagsError(prev_flags);
}

// ---- Event Flags API -------------------------------------------------------

pub const OsEventFlagsAttr = capi.osEventFlagsAttr_t;
pub const OsEventFlagsId = *anyopaque;
pub const OsEventFlags = std.bit_set.IntegerBitSet(32);
pub const OsEventFlagsCbSize = capi.osRtxEventFlagsCbSize;

fn mapMaybeOsEventFlagsError(status: u32) OsFlagsError!OsEventFlags {
    switch (status) {
        capi.osFlagsErrorISR => {
            return OsFlagsError.Isr;
        },
        capi.osFlagsErrorParameter => {
            return OsFlagsError.Parameter;
        },
        capi.osFlagsErrorResource => {
            return OsFlagsError.Resource;
        },
        capi.osFlagsErrorTimeout => {
            return OsFlagsError.Timeout;
        },
        capi.osFlagsErrorUnknown => {
            return OsFlagsError.Unknown;
        },
        else => {
            return .{ .mask = status };
        },
    }
}

// osEventFlagsId_t osEventFlagsNew (const osEventFlagsAttr_t *attr);
pub fn osEventFlagsNew(attr: *const OsEventFlagsAttr) OsStatus!OsEventFlagsId {
    const result = capi.osEventFlagsNew(attr);
    if (result == null) {
        return OsStatus.ErrorCreatingEventFlags;
    }
    return result.?;
}

pub fn osEventFlagsGetName(ef_id: OsEventFlagsId) []const u8 {
    return std.mem.sliceTo(capi.osEventFlagsGetName(ef_id), 0);
}

pub fn osEventFlagsSet(ef_id: osThreadId, flags: OsEventFlags) OsFlagsError!OsEventFlags {
    const prev_flags = capi.osEventFlagsSet(ef_id, flags.mask);
    return mapMaybeOsEventFlagsError(prev_flags);
}

pub fn osEventFlagsClear(flags: OsEventFlagsId) OsFlagsError!OsEventFlags {
    const prev_flags = capi.osEventFlagsClear(flags.mask);
    return mapMaybeOsEventFlagsError(prev_flags);
}

pub fn osEventFlagsGet() OsEventFlags {
    return .{ .mask = capi.osEventFlagsGet() };
}

pub fn osEventFlagsWait(flags: OsEventFlags, options: OsFlagOptions, timeout: u32) OsFlagsError!OsEventFlags {
    const prev_flags = capi.osEventFlagsWait(flags.mask, @intFromEnum(options), timeout);
    return mapMaybeOsEventFlagsError(prev_flags);
}

pub fn osEventFlagsDelete(ef_id: OsEventFlagsId) OsStatus!void {
    return mapMaybeError(capi.osEventFlagsDelete(ef_id));
}

// ---- Timer API -------------------------------------------------------------

pub const OsTimerId = *anyopaque;
pub const OsTimerFunc = capi.osTimerFunc_t;
pub const OsTimerAttr = capi.osTimerAttr_t;
pub const OsTimerCbSize = capi.osRtxTimerCbSize;

pub const OsTimerType = enum(u32) {
    Once = capi.osTimerOnce,
    Periodic = capi.osTimerPeriodic,
};

pub fn osTimerNew(timer_type: OsTimerType, arg: ?*anyopaque, attr: *const OsTimerAttr, func: OsTimerFunc) OsStatus!OsTimerId {
    const result = capi.osTimerNew(func, @intFromEnum(timer_type), arg, attr);
    if (result == null) {
        return OsStatus.ErrorCreatingTimer;
    }
    return result.?;
}

pub fn osTimerGetName(timer_id: OsTimerId) []const u8 {
    return std.mem.sliceTo(capi.osTimerGetName(timer_id), 0);
}

pub fn osTimerStart(timer_id: OsTimerId, ticks: u32) OsStatus!void {
    return mapMaybeError(capi.osTimerStart(timer_id, ticks));
}

pub fn osTimerStop(timer_id: OsTimerId) OsStatus!void {
    return mapMaybeError(capi.osTimerStop(timer_id));
}

pub fn osTimerIsRunning(timer_id: OsTimerId) bool {
    return 0 != capi.osTimerIsRunning(timer_id);
}

pub fn osTimerDelete(timer_id: OsTimerId) OsStatus!void {
    return mapMaybeError(capi.osTimerDelete(timer_id));
}

// ---- Generic Wait Functions API --------------------------------------------

pub fn osDelay(ticks: u32) OsStatus!void {
    return mapMaybeError(capi.osDelay(ticks));
}

pub fn osDelayUntil(absolute_ticks: u32) OsStatus!void {
    return mapMaybeError(capi.osDelayUntil(absolute_ticks));
}

pub const osWaitForever = capi.osWaitForever;
pub const osTryOnce: u32 = 0;

// ---- Mutex API -------------------------------------------------------------

pub const OsMutexAttr = capi.osMutexAttr_t;
pub const OsMutexId = *anyopaque;
pub const OsMutexCbSize: usize = capi.osRtxMutexCbSize;

pub fn osMutexNew(attr: *const OsMutexAttr) OsStatus!OsMutexId {
    const result = capi.osMutexNew(attr);
    if (result == null) {
        return OsStatus.ErrorCreatingMutex;
    }
    return result.?;
}

pub fn osMutexGetName(mutex_id: OsMutexId) []const u8 {
    return std.mem.sliceTo(capi.osMutexGetName(mutex_id), 0);
}

pub fn osMutexAcquire(mutex_id: OsMutexId, timeout_ticks: u32) OsStatus!void {
    return try mapMaybeError(capi.osMutexAcquire(mutex_id, timeout_ticks));
}

pub fn osMutexRelease(mutex_id: OsMutexId) OsStatus!void {
    return try mapMaybeError(capi.osMutexRelease(mutex_id));
}

pub fn osMutexGetOwner(mutex_id: OsMutexId) ?osThreadId {
    return capi.osMutexGetOwner(mutex_id);
}

pub fn osMutexDelete(mutex_id: OsMutexId) OsStatus!void {
    return try mapMaybeError(capi.osMutexDelete(mutex_id));
}

// ---- Semaphore API ---------------------------------------------------------

pub const OsSemaphoreAttr = capi.osSemaphoreAttr_t;
pub const OsSemaphoreId = *anyopaque;
pub const OsSemaphoreCbSize: usize = capi.osRtxSemaphoreCbSize;

pub fn osSemaphoreNew(max_count: u32, initial_count: u32, attr: *const OsSemaphoreAttr) OsStatus!OsSemaphoreId {
    const result = capi.osSemaphoreNew(max_count, initial_count, attr);
    if (result == null) {
        return OsStatus.ErrorCreatingSemaphore;
    }
    return result.?;
}

pub fn osSemaphoreGetName(semaphore_id: OsSemaphoreId) []const u8 {
    return std.mem.sliceTo(capi.osSemaphoreGetName(semaphore_id), 0);
}

pub fn osSemaphoreAcquire(semaphore_id: OsSemaphoreId, timeout: u32) OsStatus!void {
    return try mapMaybeError(capi.osSemaphoreAcquire(semaphore_id, timeout));
}

pub fn osSemaphoreRelease(semaphore_id: OsSemaphoreId) OsStatus!void {
    return try mapMaybeError(capi.osSemaphoreRelease(semaphore_id));
}

pub fn osSemaphoreGetCount(semaphore_id: OsSemaphoreId) u32 {
    return capi.osSemaphoreGetCount(semaphore_id);
}

pub fn osSemaphoreDelete(semaphore_id: OsSemaphoreId) OsStatus!void {
    return try mapMaybeError(capi.osSemaphoreDelete(semaphore_id));
}

// ---- Message Queue API -----------------------------------------------------

pub const OsMessageQueueId = *anyopaque;
pub const OsMessageQueueAttr = capi.osMessageQueueAttr_t;
pub const OsMessageQueueCbSize: usize = capi.osRtxMessageQueueCbSize;

pub fn osMessageQueueNew(comptime T: type, msg_count: u32, attr: *const OsMessageQueueAttr) OsStatus!OsMessageQueueId {
    const result = capi.osMessageQueueNew(msg_count, @sizeOf(T), attr);
    if (result == null) {
        return OsStatus.ErrorCreatingMessageQueue;
    }
    return result.?;
}

pub fn osMessageQueueGetName(msgq_id: OsMessageQueueId) []const u8 {
    return std.mem.sliceTo(capi.osMessageQueueGetName(msgq_id), 0);
}

pub fn osMessageQueuePut(msgq_id: OsMessageQueueId, msg_ptr: *const anyopaque, msg_pri: u8, timeout: u32) OsStatus!void {
    return try mapMaybeError(capi.osMessageQueuePut(msgq_id, msg_ptr, msg_pri, timeout));
}

pub fn osMessageQueueGet(msgq_id: OsMessageQueueId, msg_ptr: *anyopaque, msg_pri: ?*u8, timeout: u32) OsStatus!void {
    return try mapMaybeError(capi.osMessageQueueGet(msgq_id, msg_ptr, msg_pri, timeout));
}

pub fn osMessageQueueGetCount(msgq_id: OsMessageQueueId) u32 {
    return capi.osMessageQueueGetCount(msgq_id);
}

pub fn osMessageQueueGetSpace(msgq_id: OsMessageQueueId) u32 {
    return capi.osMessageQueueGetSpace(msgq_id);
}

pub fn osMessageQueueGetCapacity(msgq_id: OsMessageQueueId) u32 {
    return capi.osMessageQueueGetCapacity(msgq_id);
}

pub fn osMessageQueueReset(msgq_id: OsMessageQueueId) OsStatus!void {
    return try mapMaybeError(capi.osMessageQueueReset(msgq_id));
}

pub fn osMessageQueueDelete(msgq_id: OsMessageQueueId) OsStatus!void {
    return try mapMaybeError(capi.osMessageQueueDelete(msgq_id));
}

// ---- Zig allocator wrapper for RTOS memory pools ---------------------------

const OsMemoryPoolId = ?*anyopaque;

pub const MemoryPoolConfig = struct {
    block_count: usize,
    block_size: usize,
    alloc_timeout: u32,
};

pub fn MemoryPool(comptime config: MemoryPoolConfig) type {
    return struct {
        const Self = @This();

        pool_id: OsMemoryPoolId = undefined,
        config: MemoryPoolConfig = config,
        control_block: ControlBlockMem(capi.osRtxMemoryPoolCbSize) = ControlBlockMem(capi.osRtxMemoryPoolCbSize).init(),
        mem: MemBlock(u32, config.block_count * config.block_size) = MemBlock(u32, config.block_count * config.block_size).init(),
        alloc_timeout: u32 = config.alloc_timeout,

        pub fn init() Self {
            var self: Self = .{};
            self.pool_id = capi.osMemoryPoolNew(config.block_count, config.block_size, &.{
                .cb_mem = &self.control_block.mem,
                .cb_size = self.control_block.size,
                .mp_mem = &self.mem.mem,
                .mp_size = self.mem.size,
            });

            return self;
        }

        pub fn deinit(self: *Self) void {
            _ = capi.osMemoryPoolDelete(self.pool_id);
        }

        fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            _ = ptr_align;
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(ctx));

            if (len > self.config.block_size) {
                return null;
            }

            const p = capi.osMemoryPoolAlloc(self.pool_id, self.config.alloc_timeout);
            return @ptrCast(@alignCast(p));
        }

        fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            _ = buf_align;
            _ = ret_addr;
            const self: *Self = @ptrCast(@alignCast(ctx));
            _ = capi.osMemoryPoolFree(self.pool_id, buf.ptr);
        }

        pub fn allocator(self: *const Self) std.mem.Allocator {
            return .{
                .ptr = @constCast(self),
                .vtable = &.{
                    .alloc = alloc,
                    .resize = std.mem.Allocator.noResize,
                    .free = free,
                },
            };
        }
    };
}
