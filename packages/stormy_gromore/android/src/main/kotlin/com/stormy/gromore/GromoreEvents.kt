package com.stormy.gromore

import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager
import io.flutter.plugin.common.EventChannel

internal class GromoreEvents : EventChannel.StreamHandler {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val pendingEvents = mutableListOf<Map<String, Any>>()
    private var disposed = false
    internal fun ecpmDetails(manager: MediationBaseManager?): Map<String, Any> {
        val info = manager?.showEcpm ?: return emptyMap()
        return mapOfNotNull(
            "ecpm" to info.ecpm,
            "adnName" to info.sdkName,
            "adnSlotId" to info.slotId,
            "networkRequestId" to info.requestId,
        )
    }

    internal fun emit(
        adType: String,
        event: String,
        requestId: String? = null,
        details: Map<String, Any> = emptyMap(),
    ) {
        if (disposed) return
        val payload = mapOfNotNull(
            "adType" to adType,
            "event" to event,
            "requestId" to requestId,
        ) + details
        runOnMain {
            if (disposed) return@runOnMain
            val sink = eventSink
            if (sink == null) {
                if (pendingEvents.size == MAX_PENDING_EVENTS) {
                    pendingEvents.removeAt(0)
                }
                pendingEvents.add(payload)
            } else {
                sink.success(payload)
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        pendingEvents.forEach(events::success)
        pendingEvents.clear()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    internal fun runOnMain(action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post(action)
        }
    }

    fun dispose() {
        disposed = true
        eventSink = null
        pendingEvents.clear()
        mainHandler.removeCallbacksAndMessages(null)
    }
}
