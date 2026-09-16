package com.stormy.gromore

import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import kotlin.math.roundToInt

internal fun buildFeedAdSlot(
    slotId: String,
    width: Double,
    height: Double,
    density: Float,
    muted: Boolean,
    useSurfaceView: Boolean,
    bidNotify: Boolean,
): AdSlot =
    AdSlot.Builder()
        .setCodeId(slotId)
        .setImageAcceptedSize(
            (width * density).roundToInt(),
            (height * density).roundToInt(),
        )
        .setExpressViewAcceptedSize(width.toFloat(), height.toFloat())
        .setAdCount(1)
        .setMediationAdSlot(
            MediationAdSlot.Builder()
                .setMuted(muted)
                .setUseSurfaceView(useSurfaceView)
                .setBidNotify(bidNotify)
                .build(),
        )
        .build()
