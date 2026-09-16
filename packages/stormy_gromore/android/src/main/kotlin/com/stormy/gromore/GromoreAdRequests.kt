package com.stormy.gromore

import android.app.Activity
import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.mediation.IMediationPreloadRequestInfo
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.MediationPreloadRequestInfo
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import io.flutter.plugin.common.MethodChannel

internal class GromoreAdRequests(private val host: StormyGromorePlugin) {
    private val applicationContext get() = host.context()
    private val activity get() = host.currentActivity()
    internal fun preloadAds(arguments: Map<*, *>, result: MethodChannel.Result) {
        val rawItems = arguments["items"] as? List<*>
            ?: throw BridgeException("invalid_arguments", "items must be a list.")
        if (rawItems.isEmpty() || rawItems.size > MAX_PRELOAD_PLACEMENTS) {
            throw BridgeException(
                "invalid_arguments",
                "items must contain between 1 and $MAX_PRELOAD_PLACEMENTS placements.",
            )
        }
        val intervalSeconds = integer(arguments, "intervalSeconds", 2)
        if (intervalSeconds !in 1..10) {
            throw BridgeException(
                "invalid_arguments",
                "intervalSeconds must be between 1 and 10.",
            )
        }
        val concurrent = integer(arguments, "concurrent", 2)
        if (concurrent !in 1..20) {
            throw BridgeException(
                "invalid_arguments",
                "concurrent must be between 1 and 20.",
            )
        }
        val networkPolicy = requiredString(arguments, "network")
        if (networkPolicy != PRELOAD_WIFI_ONLY && networkPolicy != PRELOAD_ANY_NETWORK) {
            throw BridgeException(
                "invalid_arguments",
                "network must be wifiOnly or any.",
            )
        }

        val placements = mutableSetOf<String>()
        val preloadInfos = mutableListOf<IMediationPreloadRequestInfo>()
        rawItems.forEach { rawItem ->
            val item = rawItem as? Map<*, *>
                ?: throw BridgeException("invalid_arguments", "Each preload item must be a map.")
            val adType = requiredString(item, "adType")
            val request = item["request"] as? Map<*, *>
                ?: throw BridgeException(
                    "invalid_arguments",
                    "Each preload item must include request parameters.",
                )
            val slotId = requiredString(request, "slotId")
            if (!placements.add("$adType/$slotId")) {
                throw BridgeException(
                    "invalid_arguments",
                    "Duplicate preload placement: $adType/$slotId.",
                )
            }
            val (nativeAdType, slot) = when (adType) {
                "splash" -> AdSlot.TYPE_SPLASH to buildSplashSlot(request)
                "rewarded" -> AdSlot.TYPE_REWARD_VIDEO to buildRewardedSlot(request)
                "interstitial" ->
                    AdSlot.TYPE_FULL_SCREEN_VIDEO to buildInterstitialSlot(request)
                "feed" -> AdSlot.TYPE_FEED to buildFeedSlot(request)
                else -> throw BridgeException(
                    "unsupported_preload_type",
                    "GroMore does not support first precaching for $adType.",
                )
            }
            preloadInfos += MediationPreloadRequestInfo(
                nativeAdType,
                slot,
                listOf(slotId),
            )
        }

        val skipped = preloadSkipReason(networkPolicy)
        if (skipped != null) {
            result.success(skipped)
            return
        }
        val currentActivity = activity
            ?: throw BridgeException(
                "activity_unavailable",
                "An attached Activity is required to preload GroMore ads.",
            )
        TTAdSdk.getMediationManager().preload(
            currentActivity,
            preloadInfos,
            concurrent,
            intervalSeconds,
        )
        result.success("requested")
    }

    internal fun preloadSkipReason(networkPolicy: String): String? {
        val connectivity = applicationContext.getSystemService(
            Context.CONNECTIVITY_SERVICE,
        ) as? ConnectivityManager ?: return "skippedNoNetwork"
        val activeNetwork = connectivity.activeNetwork ?: return "skippedNoNetwork"
        val capabilities = connectivity.getNetworkCapabilities(activeNetwork)
            ?: return "skippedNoNetwork"
        val connected = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
        if (!connected) return "skippedNoNetwork"
        if (
            networkPolicy == PRELOAD_WIFI_ONLY &&
            !capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
        ) {
            return "skippedNotWifi"
        }
        return null
    }

    internal fun buildSplashSlot(arguments: Map<*, *>): AdSlot =
        AdSlot.Builder()
            .setCodeId(requiredString(arguments, "slotId"))
            .setMediationAdSlot(
                MediationAdSlot.Builder()
                    .setMuted(boolean(arguments, "muted", true))
                    .setVolume(number(arguments, "volume", 1.0).toFloat())
                    .setSplashPreLoad(boolean(arguments, "preload", true))
                    .setSplashShakeButton(boolean(arguments, "shakeButton", true))
                    .setUseSurfaceView(boolean(arguments, "useSurfaceView", true))
                    .setBidNotify(boolean(arguments, "bidNotify", false))
                    .build(),
            )
            .build()

    @Suppress("DEPRECATION")
    internal fun buildRewardedSlot(arguments: Map<*, *>): AdSlot {
        val mediationBuilder = MediationAdSlot.Builder()
            .setMuted(boolean(arguments, "muted", false))
            .setUseSurfaceView(boolean(arguments, "useSurfaceView", true))
            .setBidNotify(boolean(arguments, "bidNotify", false))
        val slotBuilder = AdSlot.Builder()
            .setCodeId(requiredString(arguments, "slotId"))
            .setOrientation(orientation(arguments))

        optionalString(arguments, "userId")?.let(slotBuilder::setUserID)
        optionalString(arguments, "customData")?.let { customData ->
            mediationBuilder.setExtraObject(
                MediationConstant.KEY_GROMORE_EXTRA,
                customData,
            )
            slotBuilder.setMediaExtra(customData)
        }
        optionalString(arguments, "rewardName")?.let {
            mediationBuilder.setRewardName(it)
            slotBuilder.setRewardName(it)
        }
        optionalInteger(arguments, "rewardAmount")?.let {
            mediationBuilder.setRewardAmount(it)
            slotBuilder.setRewardAmount(it)
        }
        return slotBuilder
            .setMediationAdSlot(mediationBuilder.build())
            .build()
    }

    internal fun buildInterstitialSlot(arguments: Map<*, *>): AdSlot =
        AdSlot.Builder()
            .setCodeId(requiredString(arguments, "slotId"))
            .setOrientation(orientation(arguments))
            .setMediationAdSlot(
                MediationAdSlot.Builder()
                    .setMuted(boolean(arguments, "muted", false))
                    .setUseSurfaceView(boolean(arguments, "useSurfaceView", true))
                    .setBidNotify(boolean(arguments, "bidNotify", false))
                    .build(),
            )
            .build()

    internal fun buildFeedSlot(arguments: Map<*, *>): AdSlot =
        buildFeedAdSlot(
            slotId = requiredString(arguments, "slotId"),
            width = number(arguments, "width", 300.0),
            height = number(arguments, "height", 150.0),
            density = applicationContext.resources.displayMetrics.density,
            muted = boolean(arguments, "muted", false),
            useSurfaceView = boolean(arguments, "useSurfaceView", true),
            bidNotify = boolean(arguments, "bidNotify", false),
        )

}
