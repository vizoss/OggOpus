package com.thk.oggopus

import java.util.concurrent.atomic.AtomicBoolean

internal object NativeSession {
    private val busy = AtomicBoolean(false)
    fun acquire() = busy.compareAndSet(false, true)
    fun release() { busy.set(false) }
}
