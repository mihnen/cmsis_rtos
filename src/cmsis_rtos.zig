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

pub fn osKernelInitialize() OsStatus!void {
    return mapMaybeError(capi.osKernelInitialize());
}

pub fn osKernelStart() OsStatus!void {
    return mapMaybeError(capi.osKernelStart());
}

pub fn osThreadNew(func: osThreadFunc, arg: ?*anyopaque, attr: [*c]const osThreadAttr) OsStatus!osThreadId {
    const result = capi.osThreadNew(func, arg, attr);
    if (result == null) {
        return OsStatus.ErrorCreatingThread;
    }
    return result.?;
}

pub fn osKernelGetState() OsKernelState {
    return OsKernelState.mapFromApi(capi.osKernelGetState());
}

pub fn osDelay(ticks: u32) OsStatus!void {
    return mapMaybeError(capi.osDelay(ticks));
}

const OsVersion = capi.osVersion_t;

pub fn osKernelGetInfo(buf: []u8) OsStatus!OsVersion {
    var version: OsVersion = undefined;
    try mapMaybeError(capi.osKernelGetInfo(&version, buf.ptr, buf.len));
    return version;
}
