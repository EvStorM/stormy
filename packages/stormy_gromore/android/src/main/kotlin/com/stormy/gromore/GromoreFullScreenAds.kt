package com.stormy.gromore

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.CSJAdError
import com.bytedance.sdk.openadsdk.CSJSplashAd
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTFullScreenVideoAd
import com.bytedance.sdk.openadsdk.TTRewardVideoAd
import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

internal class GromoreFullScreenAds(
    private val host: StormyGromorePlugin,
    private val requests: GromoreAdRequests,
    private val initialization: GromoreInitialization,
    private val events: GromoreEvents,
) {
    private enum class AdState {
        LOADING,
        READY,
        SHOWING,
    }

    private data class SplashRecord(
        val slotId: String,
        val autoShow: Boolean,
        var state: AdState = AdState.LOADING,
        var ad: CSJSplashAd? = null,
        var container: FrameLayout? = null,
    )

    private data class RewardRecord(
        val slotId: String,
        var state: AdState = AdState.LOADING,
        var ad: TTRewardVideoAd? = null,
        val terminalState: RewardTerminalState = RewardTerminalState(),
        var terminalRelease: Runnable? = null,
    )

    private data class InterstitialRecord(
        val slotId: String,
        var state: AdState = AdState.LOADING,
        var ad: TTFullScreenVideoAd? = null,
    )

    private val mainHandler = Handler(Looper.getMainLooper())
    private val splashAds = ConcurrentHashMap<String, SplashRecord>()
    private val rewardedAds = ConcurrentHashMap<String, RewardRecord>()
    private val interstitialAds = ConcurrentHashMap<String, InterstitialRecord>()
    private val applicationContext get() = host.context()
    private val activity get() = host.currentActivity()
    private val hostResumed get() = host.isHostResumed()
    private val rewardCallbackRetentionMs get() = initialization.rewardCallbackRetentionMs
    private fun runOnMain(action: () -> Unit) = events.runOnMain(action)
    private fun emit(adType: String, event: String, requestId: String? = null,
                     details: Map<String, Any> = emptyMap()) = events.emit(adType, event, requestId, details)
    private fun ecpmDetails(manager: MediationBaseManager?) = events.ecpmDetails(manager)
    internal fun loadSplash(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        ensureUnused(requestId)
        val slotId = requiredString(arguments, "slotId")
        val record = SplashRecord(
            slotId = slotId,
            autoShow = boolean(arguments, "autoShow", true),
        )
        splashAds[requestId] = record

        val slot = requests.buildSplashSlot(arguments)
        val timeoutMs = integer(arguments, "timeoutMs", 3500).coerceAtLeast(1)

        try {
            TTAdSdk.getAdManager()
                .createAdNative(activity ?: applicationContext)
                .loadSplashAd(
                    slot,
                    object : TTAdNative.CSJSplashAdListener {
                        override fun onSplashLoadSuccess(ad: CSJSplashAd) {
                            runOnMain {
                                val current = splashAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                emit(
                                    "splash",
                                    "loadSuccess",
                                    requestId,
                                    mapOf("slotId" to slotId),
                                )
                            }
                        }

                        override fun onSplashLoadFail(error: CSJAdError) {
                            runOnMain {
                                if (!splashAds.remove(requestId, record)) {
                                    return@runOnMain
                                }
                                record.ad?.mediationManager?.destroy()
                                record.ad = null
                                emitSdkFailure(
                                    "splash",
                                    requestId,
                                    slotId,
                                    error.code,
                                    error.msg,
                                )
                            }
                        }

                        override fun onSplashRenderSuccess(ad: CSJSplashAd) {
                            runOnMain {
                                val current = splashAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                current.state = AdState.READY
                                setSplashListener(requestId, current, ad)
                                emit(
                                    "splash",
                                    "loaded",
                                    requestId,
                                    mapOf("slotId" to slotId),
                                )
                                if (current.autoShow) {
                                    showSplashInternal(requestId, current, null)
                                }
                            }
                        }

                        override fun onSplashRenderFail(ad: CSJSplashAd, error: CSJAdError) {
                            runOnMain {
                                val removed = splashAds.remove(requestId, record)
                                if (record.ad !== ad) {
                                    record.ad?.mediationManager?.destroy()
                                }
                                ad.mediationManager?.destroy()
                                record.ad = null
                                if (removed) {
                                    emit(
                                        "splash",
                                        "renderFailed",
                                        requestId,
                                        mapOfNotNull(
                                            "slotId" to slotId,
                                            "code" to error.code,
                                            "message" to error.msg,
                                        ),
                                    )
                                }
                            }
                        }
                    },
                    timeoutMs,
                )
            result.success(requestId)
        } catch (error: Throwable) {
            splashAds.remove(requestId, record)
            record.ad?.mediationManager?.destroy()
            record.ad = null
            throw error
        }
    }

    internal fun showSplash(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        val record = splashAds[requestId]
            ?: throw BridgeException("unknown_ad", "Unknown splash request: $requestId")
        showSplashInternal(requestId, record, result)
    }

    private fun showSplashInternal(
        requestId: String,
        record: SplashRecord,
        result: MethodChannel.Result?,
    ) {
        if (record.state != AdState.READY) {
            result?.error("ad_not_ready", "Splash ad is not ready.", null)
            if (result == null) {
                emitShowFailure(
                    "splash",
                    requestId,
                    record.slotId,
                    "Splash ad is not ready.",
                )
            }
            return
        }
        val ad = record.ad
        if (ad == null) {
            result?.error("ad_not_ready", "Splash ad is not ready.", null)
            return
        }
        val currentActivity = foregroundActivity()
        if (currentActivity == null) {
            val message = "A foreground Activity is required to show a splash ad."
            result?.error("activity_unavailable", message, null)
            return
        }
        if (ad.mediationManager?.isReady == false) {
            val message = "Splash ad has expired or is not ready."
            emitShowFailure("splash", requestId, record.slotId, message)
            releaseSplash(requestId, emitDisposed = true)
            result?.error("ad_not_ready", message, null)
            return
        }
        val decor = currentActivity.window?.decorView as? ViewGroup
        if (decor == null) {
            result?.error("activity_unavailable", "Activity decor view is unavailable.", null)
            return
        }

        val container = FrameLayout(currentActivity).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        try {
            decor.addView(container)
            record.container = container
            record.state = AdState.SHOWING
            ad.showSplashView(container)
            result?.success(true)
        } catch (error: Throwable) {
            decor.removeView(container)
            record.container = null
            record.state = AdState.READY
            emitShowFailure(
                "splash",
                requestId,
                record.slotId,
                error.message ?: "Splash ad failed to show.",
            )
            result?.error("show_failed", error.message, null)
        }
    }

    private fun setSplashListener(
        requestId: String,
        record: SplashRecord,
        ad: CSJSplashAd,
    ) {
        ad.setSplashAdListener(
            object : CSJSplashAd.SplashAdListener {
                override fun onSplashAdShow(callbackAd: CSJSplashAd?) {
                    runOnMain {
                        if (splashAds[requestId] !== record || record.ad !== ad) {
                            return@runOnMain
                        }
                        emit(
                            "splash",
                            "shown",
                            requestId,
                            mapOf("slotId" to record.slotId) +
                                ecpmDetails(callbackAd?.mediationManager ?: ad.mediationManager),
                        )
                    }
                }

                override fun onSplashAdClick(callbackAd: CSJSplashAd?) {
                    runOnMain {
                        if (splashAds[requestId] === record && record.ad === ad) {
                            emit(
                                "splash",
                                "clicked",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                override fun onSplashAdClose(callbackAd: CSJSplashAd?, closeType: Int) {
                    runOnMain {
                        if (splashAds[requestId] !== record || record.ad !== ad) {
                            return@runOnMain
                        }
                        emit(
                            "splash",
                            "closed",
                            requestId,
                            mapOf(
                                "slotId" to record.slotId,
                                "closeReason" to closeType,
                            ),
                        )
                        releaseSplash(requestId, emitDisposed = true)
                    }
                }
            },
        )
    }

    internal fun loadRewarded(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        ensureUnused(requestId)
        val slotId = requiredString(arguments, "slotId")
        val record = RewardRecord(slotId)
        rewardedAds[requestId] = record
        val slot = requests.buildRewardedSlot(arguments)

        try {
            TTAdSdk.getAdManager()
                .createAdNative(activity ?: applicationContext)
                .loadRewardVideoAd(
                    slot,
                    object : TTAdNative.RewardVideoAdListener {
                        override fun onError(code: Int, message: String?) {
                            runOnMain {
                                if (!rewardedAds.remove(requestId, record)) {
                                    return@runOnMain
                                }
                                record.ad?.mediationManager?.destroy()
                                record.ad = null
                                emitSdkFailure(
                                    "rewarded",
                                    requestId,
                                    slotId,
                                    code,
                                    message,
                                )
                            }
                        }

                        override fun onRewardVideoAdLoad(ad: TTRewardVideoAd) {
                            runOnMain {
                                val current = rewardedAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                emit(
                                    "rewarded",
                                    "loadSuccess",
                                    requestId,
                                    mapOf("slotId" to slotId),
                                )
                            }
                        }

                        @Suppress("OVERRIDE_DEPRECATION")
                        override fun onRewardVideoCached() {
                            runOnMain { markRewardReady(requestId) }
                        }

                        override fun onRewardVideoCached(ad: TTRewardVideoAd) {
                            runOnMain {
                                val current = rewardedAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                markRewardReady(requestId)
                            }
                        }
                    },
                )
            result.success(requestId)
        } catch (error: Throwable) {
            rewardedAds.remove(requestId, record)
            record.ad?.mediationManager?.destroy()
            record.ad = null
            throw error
        }
    }

    internal fun markRewardReady(requestId: String) {
        val record = rewardedAds[requestId] ?: return
        if (record.state == AdState.LOADING && record.ad != null) {
            record.state = AdState.READY
            emit(
                "rewarded",
                "loaded",
                requestId,
                mapOf("slotId" to record.slotId),
            )
        }
    }

    internal fun showRewarded(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        val record = rewardedAds[requestId]
            ?: throw BridgeException("unknown_ad", "Unknown rewarded request: $requestId")
        val ad = record.ad
        val currentActivity = foregroundActivity()
        if (record.state != AdState.READY || ad == null) {
            throw BridgeException("ad_not_ready", "Rewarded ad is not ready.")
        }
        if (currentActivity == null) {
            throw BridgeException(
                "activity_unavailable",
                "A foreground Activity is required to show a rewarded ad.",
            )
        }
        if (ad.mediationManager?.isReady == false) {
            throw BridgeException("ad_not_ready", "Rewarded ad has expired or is not ready.")
        }

        ad.setRewardAdInteractionListener(
            object : TTRewardVideoAd.RewardAdInteractionListener {
                override fun onAdShow() {
                    runOnMain {
                        if (!isCurrentRewarded(requestId, record, ad)) return@runOnMain
                        emit(
                            "rewarded",
                            "shown",
                            requestId,
                            mapOf("slotId" to record.slotId) + ecpmDetails(ad.mediationManager),
                        )
                    }
                }

                override fun onAdVideoBarClick() {
                    runOnMain {
                        if (isCurrentRewarded(requestId, record, ad)) {
                            emit(
                                "rewarded",
                                "clicked",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                override fun onAdClose() {
                    runOnMain {
                        closeRewarded(requestId, record, ad)
                    }
                }

                override fun onVideoComplete() {
                    runOnMain {
                        if (isCurrentRewarded(requestId, record, ad)) {
                            emit(
                                "rewarded",
                                "completed",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                override fun onVideoError() {
                    runOnMain {
                        if (isCurrentRewarded(requestId, record, ad)) {
                            emit(
                                "rewarded",
                                "videoError",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                @Suppress("OVERRIDE_DEPRECATION")
                override fun onRewardVerify(
                    rewardVerify: Boolean,
                    rewardAmount: Int,
                    rewardName: String?,
                    errorCode: Int,
                    errorMessage: String?,
                ) = Unit

                override fun onRewardArrived(
                    rewardValid: Boolean,
                    rewardType: Int,
                    extraInfo: Bundle?,
                ) {
                    runOnMain {
                        reportReward(
                            requestId,
                            record,
                            rewardValid,
                            rewardType,
                            bundleToMap(extraInfo),
                        )
                    }
                }

                override fun onSkippedVideo() {
                    runOnMain {
                        if (isCurrentRewarded(requestId, record, ad)) {
                            emit(
                                "rewarded",
                                "skipped",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }
            },
        )

        try {
            record.state = AdState.SHOWING
            ad.showRewardVideoAd(currentActivity)
            result.success(true)
        } catch (error: Throwable) {
            record.state = AdState.READY
            emitShowFailure(
                "rewarded",
                requestId,
                record.slotId,
                error.message ?: "Rewarded ad failed to show.",
            )
            throw BridgeException(
                "show_failed",
                error.message ?: "Rewarded ad failed to show.",
            )
        }
    }

    private fun reportReward(
        requestId: String,
        record: RewardRecord,
        valid: Boolean,
        rewardType: Int?,
        details: Map<String, Any>,
    ) {
        if (!isCurrentRewarded(requestId, record, record.ad)) return
        if (!record.terminalState.beginRewardDelivery()) return
        emit(
            "rewarded",
            if (valid) "rewardEarned" else "rewardFailed",
            requestId,
            mapOfNotNull(
                "slotId" to record.slotId,
                "rewardValid" to valid,
                "rewardType" to rewardType,
                "rewardName" to details[TTRewardVideoAd.REWARD_EXTRA_KEY_REWARD_NAME],
                "rewardAmount" to details[TTRewardVideoAd.REWARD_EXTRA_KEY_REWARD_AMOUNT],
                "code" to details[TTRewardVideoAd.REWARD_EXTRA_KEY_ERROR_CODE],
                "message" to details[TTRewardVideoAd.REWARD_EXTRA_KEY_ERROR_MSG],
                "extra" to details,
            ),
        )
        if (record.terminalState.canRelease) {
            releaseRewarded(requestId, emitDisposed = true, expected = record)
        }
    }

    private fun closeRewarded(
        requestId: String,
        record: RewardRecord,
        ad: TTRewardVideoAd,
        message: String? = null,
    ) {
        if (!isCurrentRewarded(requestId, record, ad)) return
        if (record.terminalState.beginClose()) {
            emit(
                "rewarded",
                "closed",
                requestId,
                mapOfNotNull(
                    "slotId" to record.slotId,
                    "message" to message,
                ),
            )
        }
        if (record.terminalState.canRelease) {
            releaseRewarded(requestId, emitDisposed = true, expected = record)
        } else {
            scheduleRewardedRelease(requestId, record)
        }
    }

    private fun scheduleRewardedRelease(requestId: String, record: RewardRecord) {
        if (record.terminalRelease != null) return
        val release = Runnable {
            record.terminalRelease = null
            releaseRewarded(requestId, emitDisposed = true, expected = record)
        }
        record.terminalRelease = release
        mainHandler.postDelayed(release, rewardCallbackRetentionMs)
    }

    internal fun loadInterstitial(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        ensureUnused(requestId)
        val slotId = requiredString(arguments, "slotId")
        val record = InterstitialRecord(slotId)
        interstitialAds[requestId] = record
        val slot = requests.buildInterstitialSlot(arguments)

        try {
            TTAdSdk.getAdManager()
                .createAdNative(activity ?: applicationContext)
                .loadFullScreenVideoAd(
                    slot,
                    object : TTAdNative.FullScreenVideoAdListener {
                        override fun onError(code: Int, message: String?) {
                            runOnMain {
                                if (!interstitialAds.remove(requestId, record)) {
                                    return@runOnMain
                                }
                                record.ad?.mediationManager?.destroy()
                                record.ad = null
                                emitSdkFailure(
                                    "interstitial",
                                    requestId,
                                    slotId,
                                    code,
                                    message,
                                )
                            }
                        }

                        override fun onFullScreenVideoAdLoad(ad: TTFullScreenVideoAd) {
                            runOnMain {
                                val current = interstitialAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                emit(
                                    "interstitial",
                                    "loadSuccess",
                                    requestId,
                                    mapOf("slotId" to slotId),
                                )
                            }
                        }

                        @Suppress("OVERRIDE_DEPRECATION")
                        override fun onFullScreenVideoCached() {
                            runOnMain { markInterstitialReady(requestId) }
                        }

                        override fun onFullScreenVideoCached(ad: TTFullScreenVideoAd) {
                            runOnMain {
                                val current = interstitialAds[requestId]
                                if (current !== record) {
                                    ad.mediationManager?.destroy()
                                    return@runOnMain
                                }
                                if (current.ad !== ad) {
                                    current.ad?.mediationManager?.destroy()
                                }
                                current.ad = ad
                                markInterstitialReady(requestId)
                            }
                        }
                    },
                )
            result.success(requestId)
        } catch (error: Throwable) {
            interstitialAds.remove(requestId, record)
            record.ad?.mediationManager?.destroy()
            record.ad = null
            throw error
        }
    }

    internal fun markInterstitialReady(requestId: String) {
        val record = interstitialAds[requestId] ?: return
        if (record.state == AdState.LOADING && record.ad != null) {
            record.state = AdState.READY
            emit(
                "interstitial",
                "loaded",
                requestId,
                mapOf("slotId" to record.slotId),
            )
        }
    }

    internal fun showInterstitial(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        val record = interstitialAds[requestId]
            ?: throw BridgeException("unknown_ad", "Unknown interstitial request: $requestId")
        val ad = record.ad
        val currentActivity = foregroundActivity()
        if (record.state != AdState.READY || ad == null) {
            throw BridgeException("ad_not_ready", "Interstitial ad is not ready.")
        }
        if (currentActivity == null) {
            throw BridgeException(
                "activity_unavailable",
                "A foreground Activity is required to show an interstitial ad.",
            )
        }
        if (ad.mediationManager?.isReady == false) {
            throw BridgeException(
                "ad_not_ready",
                "Interstitial ad has expired or is not ready.",
            )
        }

        ad.setFullScreenVideoAdInteractionListener(
            object : TTFullScreenVideoAd.FullScreenVideoAdInteractionListener {
                override fun onAdShow() {
                    runOnMain {
                        if (!isCurrentInterstitial(requestId, record, ad)) return@runOnMain
                        emit(
                            "interstitial",
                            "shown",
                            requestId,
                            mapOf("slotId" to record.slotId) + ecpmDetails(ad.mediationManager),
                        )
                    }
                }

                override fun onAdVideoBarClick() {
                    runOnMain {
                        if (isCurrentInterstitial(requestId, record, ad)) {
                            emit(
                                "interstitial",
                                "clicked",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                override fun onAdClose() {
                    runOnMain {
                        if (!isCurrentInterstitial(requestId, record, ad)) {
                            return@runOnMain
                        }
                        emit(
                            "interstitial",
                            "closed",
                            requestId,
                            mapOf("slotId" to record.slotId),
                        )
                        releaseInterstitial(requestId, emitDisposed = true)
                    }
                }

                override fun onVideoComplete() {
                    runOnMain {
                        if (isCurrentInterstitial(requestId, record, ad)) {
                            emit(
                                "interstitial",
                                "completed",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }

                override fun onSkippedVideo() {
                    runOnMain {
                        if (isCurrentInterstitial(requestId, record, ad)) {
                            emit(
                                "interstitial",
                                "skipped",
                                requestId,
                                mapOf("slotId" to record.slotId),
                            )
                        }
                    }
                }
            },
        )

        try {
            record.state = AdState.SHOWING
            ad.showFullScreenVideoAd(currentActivity)
            result.success(true)
        } catch (error: Throwable) {
            record.state = AdState.READY
            emitShowFailure(
                "interstitial",
                requestId,
                record.slotId,
                error.message ?: "Interstitial ad failed to show.",
            )
            throw BridgeException(
                "show_failed",
                error.message ?: "Interstitial ad failed to show.",
            )
        }
    }

    internal fun disposeAd(arguments: Map<*, *>, result: MethodChannel.Result) {
        val requestId = requiredString(arguments, "requestId")
        when {
            splashAds.containsKey(requestId) -> releaseSplash(requestId, emitDisposed = true)
            rewardedAds.containsKey(requestId) -> releaseRewarded(requestId, emitDisposed = true)
            interstitialAds.containsKey(requestId) -> {
                releaseInterstitial(requestId, emitDisposed = true)
            }
            else -> Unit
        }
        result.success(null)
    }

    private fun isCurrentRewarded(
        requestId: String,
        record: RewardRecord,
        ad: TTRewardVideoAd?,
    ): Boolean = ad != null && rewardedAds[requestId] === record && record.ad === ad

    private fun isCurrentInterstitial(
        requestId: String,
        record: InterstitialRecord,
        ad: TTFullScreenVideoAd?,
    ): Boolean = ad != null && interstitialAds[requestId] === record && record.ad === ad

    internal fun releaseSplash(requestId: String, emitDisposed: Boolean) {
        val record = splashAds.remove(requestId) ?: return
        (record.container?.parent as? ViewGroup)?.removeView(record.container)
        record.container = null
        runCatching { record.ad?.mediationManager?.destroy() }
        record.ad = null
        if (emitDisposed) {
            emit("splash", "disposed", requestId, mapOf("slotId" to record.slotId))
        }
    }

    private fun releaseRewarded(
        requestId: String,
        emitDisposed: Boolean,
        expected: RewardRecord? = null,
    ) {
        val record = (if (expected == null) {
            rewardedAds.remove(requestId)
        } else if (rewardedAds.remove(requestId, expected)) {
            expected
        } else {
            null
        }) ?: return
        record.terminalRelease?.let(mainHandler::removeCallbacks)
        record.terminalRelease = null
        runCatching { record.ad?.mediationManager?.destroy() }
        record.ad = null
        if (emitDisposed) {
            emit("rewarded", "disposed", requestId, mapOf("slotId" to record.slotId))
        }
    }

    internal fun releaseInterstitial(requestId: String, emitDisposed: Boolean) {
        val record = interstitialAds.remove(requestId) ?: return
        runCatching { record.ad?.mediationManager?.destroy() }
        record.ad = null
        if (emitDisposed) {
            emit(
                "interstitial",
                "disposed",
                requestId,
                mapOf("slotId" to record.slotId),
            )
        }
    }

    internal fun disposeAllAds() {
        splashAds.keys.toList().forEach { releaseSplash(it, emitDisposed = false) }
        rewardedAds.keys.toList().forEach { releaseRewarded(it, emitDisposed = false) }
        interstitialAds.keys.toList().forEach {
            releaseInterstitial(it, emitDisposed = false)
        }
    }

    internal fun emitSdkFailure(
        adType: String,
        requestId: String,
        slotId: String,
        code: Int,
        message: String?,
    ) {
        emit(
            adType,
            "failed",
            requestId,
            mapOfNotNull(
                "slotId" to slotId,
                "code" to code,
                "message" to message,
            ),
        )
    }

    internal fun emitShowFailure(
        adType: String,
        requestId: String,
        slotId: String,
        message: String,
    ) {
        emit(
            adType,
            "showFailed",
            requestId,
            mapOf("slotId" to slotId, "message" to message),
        )
    }

    internal fun releaseShowingSplashes(message: String) {
        splashAds.entries.toList().forEach { (requestId, record) ->
            if (record.container != null) {
                emitShowFailure("splash", requestId, record.slotId, message)
                releaseSplash(requestId, emitDisposed = true)
            }
        }
    }

    internal fun closeShowingRewarded(message: String) {
        rewardedAds.entries.toList().forEach { (requestId, record) ->
            val ad = record.ad
            if (record.state == AdState.SHOWING && ad != null) {
                closeRewarded(requestId, record, ad, message)
            }
        }
    }

    internal fun releaseShowingInterstitials(message: String) {
        interstitialAds.entries.toList().forEach { (requestId, record) ->
            if (record.state == AdState.SHOWING) {
                emit(
                    "interstitial",
                    "closed",
                    requestId,
                    mapOf("slotId" to record.slotId, "message" to message),
                )
                releaseInterstitial(requestId, emitDisposed = true)
            }
        }
    }

    internal fun showDeferredAutoSplashes() {
        splashAds.entries.toList().forEach { (requestId, record) ->
            if (record.autoShow && record.state == AdState.READY) {
                showSplashInternal(requestId, record, null)
            }
        }
    }

    internal fun ensureUnused(requestId: String) {
        if (
            splashAds.containsKey(requestId) ||
            rewardedAds.containsKey(requestId) ||
            interstitialAds.containsKey(requestId)
        ) {
            throw BridgeException("duplicate_request", "Duplicate request ID: $requestId")
        }
    }

    internal fun foregroundActivity(): Activity? {
        val current = activity
        return current?.takeIf {
            FullScreenHostGuard.canShow(
                hostResumed = hostResumed,
                hasActivity = true,
                activityFinishing = it.isFinishing,
                activityDestroyed = it.isDestroyed,
            )
        }
    }

    fun dispose() {
        disposeAllAds()
        mainHandler.removeCallbacksAndMessages(null)
    }
}
