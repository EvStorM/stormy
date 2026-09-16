package com.stormy.gromore

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdDislike
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTDrawFeedAd
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.bytedance.sdk.openadsdk.TTNativeAd
import com.bytedance.sdk.openadsdk.TTNativeExpressAd
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import com.bytedance.sdk.openadsdk.mediation.ad.MediationExpressRenderListener
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.roundToInt

internal enum class GromoreViewKind(val wireName: String) {
    BANNER("banner"),
    FEED("feed"),
    DRAW_FEED("drawFeed"),
}

internal interface GromoreActivityAwareView {
    fun onHostPause()

    fun onHostResume(activity: Activity)

    fun onEngineDetached()
}

internal class GromoreViewFactory(
    private val plugin: StormyGromorePlugin,
    private val kind: GromoreViewKind,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val arguments = args as? Map<*, *> ?: emptyMap<Any, Any>()
        return if (kind == GromoreViewKind.BANNER) {
            GromoreBannerPlatformView(context, arguments, plugin)
        } else {
            GromoreNativePlatformView(context, arguments, plugin, kind)
        }
    }
}

private class GromoreBannerPlatformView(
    context: Context,
    private val arguments: Map<*, *>,
    private val plugin: StormyGromorePlugin,
) : PlatformView, GromoreActivityAwareView {
    private val container = FrameLayout(context)
    private val requestId = arguments.string("requestId")
    private val slotId = arguments.string("slotId")
    private var ad: TTNativeExpressAd? = null
    private var disposed = false
    private var hostResumed = plugin.isHostResumed()
    private var lifecycleRegistered = false
    private var rendered = false
    private var terminal = false

    init {
        if (requestId == null || slotId == null) {
            plugin.emit(
                "banner",
                "failed",
                requestId,
                mapOf("message" to "requestId and slotId are required."),
            )
        } else if (!plugin.isSdkReady()) {
            plugin.emit(
                "banner",
                "failed",
                requestId,
                mapOf(
                    "slotId" to slotId,
                    "message" to "Initialize GroMore before creating a banner view.",
                ),
            )
        } else {
            load(context)
        }
    }

    private fun load(context: Context) {
        val safeRequestId = requestId ?: return
        val safeSlotId = slotId ?: return
        val activity = plugin.currentActivity()
        if (activity == null) {
            plugin.emit(
                "banner",
                "failed",
                safeRequestId,
                mapOf(
                    "slotId" to safeSlotId,
                    "message" to "A foreground Activity is required to load a banner.",
                    "extra" to mapOf("errorCode" to "activity_unavailable"),
                ),
            )
            return
        }
        registerLifecycle()
        val width = arguments.number("width", 320.0)
        val height = arguments.number("height", 50.0)
        val density = context.resources.displayMetrics.density
        val mediationSlot = MediationAdSlot.Builder()
            .setBidNotify(arguments.boolean("bidNotify", false))
            .build()
        val slot = AdSlot.Builder()
            .setCodeId(safeSlotId)
            .setImageAcceptedSize(
                (width * density).roundToInt(),
                (height * density).roundToInt(),
            )
            .setExpressViewAcceptedSize(width.toFloat(), height.toFloat())
            .setMediationAdSlot(mediationSlot)
            .build()

        TTAdSdk.getAdManager()
            .createAdNative(activity)
            .loadBannerExpressAd(
                slot,
                object : TTAdNative.NativeExpressAdListener {
                    override fun onError(code: Int, message: String?) {
                        plugin.runOnMain {
                            if (disposed || terminal) return@runOnMain
                            terminal = true
                            plugin.emit(
                                "banner",
                                "failed",
                                safeRequestId,
                                notNullMap(
                                    "slotId" to safeSlotId,
                                    "code" to code,
                                    "message" to message,
                                ),
                            )
                            unregisterLifecycle()
                        }
                    }

                    override fun onNativeExpressAdLoad(ads: List<TTNativeExpressAd>?) {
                        plugin.runOnMain {
                            if (disposed || terminal) {
                                ads?.forEach(TTNativeExpressAd::destroy)
                                return@runOnMain
                            }
                            val loadedAd = ads?.firstOrNull()
                            if (loadedAd == null) {
                                terminal = true
                                plugin.emit(
                                    "banner",
                                    "failed",
                                    safeRequestId,
                                    mapOf(
                                        "slotId" to safeSlotId,
                                        "message" to "GroMore returned no banner creative.",
                                    ),
                                )
                                unregisterLifecycle()
                                return@runOnMain
                            }
                            ads.drop(1).forEach(TTNativeExpressAd::destroy)
                            val currentActivity = plugin.currentActivity()
                            if (currentActivity == null) {
                                loadedAd.destroy()
                                terminal = true
                                plugin.emit(
                                    "banner",
                                    "failed",
                                    safeRequestId,
                                    mapOf(
                                        "slotId" to safeSlotId,
                                        "message" to
                                            "The host Activity detached while loading the banner.",
                                        "extra" to mapOf(
                                            "errorCode" to "activity_unavailable",
                                        ),
                                    ),
                                )
                                unregisterLifecycle()
                                return@runOnMain
                            }
                            ad = loadedAd
                            configureAd(
                                loadedAd,
                                safeRequestId,
                                safeSlotId,
                                currentActivity,
                            )
                            plugin.emit(
                                "banner",
                                "loaded",
                                safeRequestId,
                                mapOf("slotId" to safeSlotId),
                            )
                            if (hostResumed) {
                                loadedAd.mediationManager?.onResume()
                                attachBanner(
                                    loadedAd,
                                    safeRequestId,
                                    safeSlotId,
                                )
                            } else {
                                loadedAd.mediationManager?.onPause()
                            }
                        }
                    }
                },
            )
    }

    private fun configureAd(
        loadedAd: TTNativeExpressAd,
        safeRequestId: String,
        safeSlotId: String,
        activity: Activity,
    ) {
        loadedAd.setExpressInteractionListener(
            object : TTNativeExpressAd.ExpressAdInteractionListener {
                override fun onAdClicked(view: View?, type: Int) {
                    if (!isCurrent(loadedAd)) return
                    plugin.emit(
                        "banner",
                        "clicked",
                        safeRequestId,
                        mapOf("slotId" to safeSlotId),
                    )
                }

                override fun onAdShow(view: View?, type: Int) {
                    if (!isCurrent(loadedAd)) return
                    plugin.emit(
                        "banner",
                        "shown",
                        safeRequestId,
                        mapOf("slotId" to safeSlotId) +
                            plugin.ecpmDetails(loadedAd.mediationManager),
                    )
                }

                override fun onRenderFail(view: View?, message: String?, code: Int) {
                    if (!isCurrent(loadedAd)) return
                    plugin.emit(
                        "banner",
                        "renderFailed",
                        safeRequestId,
                        notNullMap(
                            "slotId" to safeSlotId,
                            "code" to code,
                            "message" to message,
                        ),
                    )
                    plugin.runOnMain { releaseAd(loadedAd) }
                }

                override fun onRenderSuccess(view: View?, width: Float, height: Float) {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        if (!hostResumed) return@runOnMain
                        val adView = loadedAd.expressAdView ?: view
                        if (adView == null) {
                            plugin.emit(
                                "banner",
                                "renderFailed",
                                safeRequestId,
                                mapOf(
                                    "slotId" to safeSlotId,
                                    "message" to "Rendered banner view is unavailable.",
                                ),
                            )
                            releaseAd(loadedAd)
                            return@runOnMain
                        }
                        attachView(container, adView)
                        if (!rendered) {
                            rendered = true
                            plugin.emit(
                                "banner",
                                "rendered",
                                safeRequestId,
                                mapOf(
                                    "slotId" to safeSlotId,
                                    "extra" to mapOf(
                                        "width" to width.toDouble(),
                                        "height" to height.toDouble(),
                                    ),
                                ),
                            )
                        }
                    }
                }
            },
        )
        bindActivity(loadedAd, safeRequestId, safeSlotId, activity)
    }

    private fun bindActivity(
        loadedAd: TTNativeExpressAd,
        safeRequestId: String,
        safeSlotId: String,
        activity: Activity,
    ) {
        loadedAd.setDislikeCallback(
            activity,
            object : TTAdDislike.DislikeInteractionCallback {
                override fun onShow() = Unit

                override fun onSelected(position: Int, reason: String?, enforce: Boolean) {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        plugin.emit(
                            "banner",
                            "disliked",
                            safeRequestId,
                            notNullMap(
                                "slotId" to safeSlotId,
                                "extra" to notNullMap(
                                    "position" to position,
                                    "reason" to reason,
                                    "enforce" to enforce,
                                ),
                            ),
                        )
                        releaseAd(loadedAd)
                    }
                }

                override fun onCancel() = Unit
            },
        )
    }

    private fun attachBanner(
        loadedAd: TTNativeExpressAd,
        safeRequestId: String,
        safeSlotId: String,
    ) {
        if (!isCurrent(loadedAd) || !hostResumed) return
        val adView = loadedAd.expressAdView
        if (adView == null) {
            plugin.emit(
                "banner",
                "renderFailed",
                safeRequestId,
                mapOf(
                    "slotId" to safeSlotId,
                    "message" to "Banner view is unavailable.",
                ),
            )
            releaseAd(loadedAd)
            return
        }
        attachView(container, adView)
        if (!rendered) {
            rendered = true
            plugin.emit(
                "banner",
                "rendered",
                safeRequestId,
                mapOf("slotId" to safeSlotId),
            )
        }
    }

    private fun isCurrent(candidate: TTNativeExpressAd): Boolean =
        !disposed && ad === candidate

    private fun registerLifecycle() {
        if (lifecycleRegistered) return
        lifecycleRegistered = true
        plugin.registerPlatformView(this)
    }

    private fun unregisterLifecycle() {
        if (!lifecycleRegistered) return
        lifecycleRegistered = false
        plugin.unregisterPlatformView(this)
    }

    private fun releaseAd(candidate: TTNativeExpressAd? = ad) {
        val current = ad
        if (current == null) {
            terminal = true
            unregisterLifecycle()
            return
        }
        if (candidate != null && current !== candidate) return
        terminal = true
        ad = null
        container.removeAllViews()
        current.destroy()
        unregisterLifecycle()
    }

    override fun onHostPause() {
        hostResumed = false
        ad?.mediationManager?.onPause()
    }

    override fun onHostResume(activity: Activity) {
        hostResumed = true
        val current = ad ?: return
        val safeRequestId = requestId ?: return
        val safeSlotId = slotId ?: return
        current.mediationManager?.onResume()
        bindActivity(current, safeRequestId, safeSlotId, activity)
        attachBanner(current, safeRequestId, safeSlotId)
    }

    override fun onEngineDetached() {
        dispose()
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true
        releaseAd()
        if (requestId != null) {
            plugin.emit(
                "banner",
                "disposed",
                requestId,
                notNullMap("slotId" to slotId),
            )
        }
    }
}

private class GromoreNativePlatformView(
    context: Context,
    private val arguments: Map<*, *>,
    private val plugin: StormyGromorePlugin,
    private val kind: GromoreViewKind,
) : PlatformView, GromoreActivityAwareView {
    private val container = FrameLayout(context)
    private val requestId = arguments.string("requestId")
    private val slotId = arguments.string("slotId")
    private var ad: TTNativeAd? = null
    private var disposed = false
    private var hostResumed = plugin.isHostResumed()
    private var lifecycleRegistered = false
    private var pendingAdView: View? = null
    private var renderHeight = 0f
    private var rendered = false
    private var renderWidth = 0f
    private var renderRequested = false
    private var terminal = false

    init {
        if (requestId == null || slotId == null) {
            plugin.emit(
                kind.wireName,
                "failed",
                requestId,
                mapOf("message" to "requestId and slotId are required."),
            )
        } else if (!plugin.isSdkReady()) {
            plugin.emit(
                kind.wireName,
                "failed",
                requestId,
                mapOf(
                    "slotId" to slotId,
                    "message" to "Initialize GroMore before creating an ad view.",
                ),
            )
        } else {
            load(context)
        }
    }

    private fun load(context: Context) {
        val safeRequestId = requestId ?: return
        val safeSlotId = slotId ?: return
        val activity = plugin.currentActivity()
        if (activity == null) {
            plugin.emit(
                kind.wireName,
                "failed",
                safeRequestId,
                mapOf(
                    "slotId" to safeSlotId,
                    "message" to "A foreground Activity is required to load this ad view.",
                    "extra" to mapOf("errorCode" to "activity_unavailable"),
                ),
            )
            return
        }
        registerLifecycle()
        val width = arguments.number("width", 300.0)
        val height = arguments.number("height", 150.0)
        val density = context.resources.displayMetrics.density
        val slot = buildFeedAdSlot(
            slotId = safeSlotId,
            width = width,
            height = height,
            density = density,
            muted = arguments.boolean("muted", false),
            useSurfaceView = arguments.boolean("useSurfaceView", true),
            bidNotify = arguments.boolean("bidNotify", false),
        )
        val loader = TTAdSdk.getAdManager().createAdNative(activity)

        if (kind == GromoreViewKind.FEED) {
            loader.loadFeedAd(
                slot,
                object : TTAdNative.FeedAdListener {
                    override fun onError(code: Int, message: String?) {
                        reportLoadFailure(safeRequestId, safeSlotId, code, message)
                    }

                    override fun onFeedAdLoad(ads: List<TTFeedAd>?) {
                        acceptAds(ads, safeRequestId, safeSlotId)
                    }
                },
            )
        } else {
            loader.loadDrawFeedAd(
                slot,
                object : TTAdNative.DrawFeedAdListener {
                    override fun onError(code: Int, message: String?) {
                        reportLoadFailure(safeRequestId, safeSlotId, code, message)
                    }

                    override fun onDrawFeedAdLoad(ads: List<TTDrawFeedAd>?) {
                        acceptAds(ads, safeRequestId, safeSlotId)
                    }
                },
            )
        }
    }

    private fun reportLoadFailure(
        safeRequestId: String,
        safeSlotId: String,
        code: Int,
        message: String?,
    ) {
        plugin.runOnMain {
            if (disposed || terminal || ad != null) return@runOnMain
            terminal = true
            plugin.emit(
                kind.wireName,
                "failed",
                safeRequestId,
                notNullMap(
                    "slotId" to safeSlotId,
                    "code" to code,
                    "message" to message,
                ),
            )
            unregisterLifecycle()
        }
    }

    private fun acceptAds(
        ads: List<TTNativeAd>?,
        safeRequestId: String,
        safeSlotId: String,
    ) {
        plugin.runOnMain {
            if (disposed || terminal) {
                ads?.forEach(TTNativeAd::destroy)
                return@runOnMain
            }
            val loadedAd = ads?.firstOrNull()
            if (loadedAd == null) {
                terminal = true
                plugin.emit(
                    kind.wireName,
                    "failed",
                    safeRequestId,
                    mapOf(
                        "slotId" to safeSlotId,
                        "message" to "GroMore returned no native creative.",
                    ),
                )
                unregisterLifecycle()
                return@runOnMain
            }
            ads.drop(1).forEach(TTNativeAd::destroy)
            val activity = plugin.currentActivity()
            if (activity == null) {
                loadedAd.destroy()
                terminal = true
                plugin.emit(
                    kind.wireName,
                    "failed",
                    safeRequestId,
                    mapOf(
                        "slotId" to safeSlotId,
                        "message" to "The host Activity detached while loading the ad.",
                        "extra" to mapOf("errorCode" to "activity_unavailable"),
                    ),
                )
                unregisterLifecycle()
                return@runOnMain
            }
            if (loadedAd.mediationManager?.isExpress != true) {
                loadedAd.destroy()
                terminal = true
                plugin.emit(
                    kind.wireName,
                    "failed",
                    safeRequestId,
                    mapOf(
                        "slotId" to safeSlotId,
                        "message" to
                            "Self-rendered native creatives are not supported; " +
                            "configure this GroMore placement as template-rendered.",
                    ),
                )
                unregisterLifecycle()
                return@runOnMain
            }
            ad = loadedAd
            configureNativeAd(loadedAd, safeRequestId, safeSlotId, activity)
            plugin.emit(
                kind.wireName,
                "loaded",
                safeRequestId,
                mapOf("slotId" to safeSlotId),
            )
            if (hostResumed) {
                loadedAd.mediationManager?.onResume()
                renderRequested = true
                loadedAd.render()
            } else {
                loadedAd.mediationManager?.onPause()
            }
        }
    }

    private fun configureNativeAd(
        loadedAd: TTNativeAd,
        safeRequestId: String,
        safeSlotId: String,
        activity: Activity,
    ) {
        loadedAd.setExpressRenderListener(
            object : MediationExpressRenderListener {
                override fun onRenderSuccess(
                    view: View?,
                    width: Float,
                    height: Float,
                    isExpress: Boolean,
                ) {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        val adView = loadedAd.adView ?: view
                        if (adView == null) {
                            plugin.emit(
                                kind.wireName,
                                "renderFailed",
                                safeRequestId,
                                mapOf(
                                    "slotId" to safeSlotId,
                                    "message" to "Rendered native ad view is unavailable.",
                                ),
                            )
                            releaseAd(loadedAd)
                            return@runOnMain
                        }
                        pendingAdView = adView
                        renderWidth = width
                        renderHeight = height
                        if (hostResumed) {
                            attachRenderedNativeAd(
                                loadedAd,
                                safeRequestId,
                                safeSlotId,
                            )
                        }
                    }
                }

                override fun onRenderFail(view: View?, message: String?, code: Int) {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        plugin.emit(
                            kind.wireName,
                            "renderFailed",
                            safeRequestId,
                            notNullMap(
                                "slotId" to safeSlotId,
                                "code" to code,
                                "message" to message,
                            ),
                        )
                        releaseAd(loadedAd)
                    }
                }

                override fun onAdClick() {
                    reportClick(loadedAd, safeRequestId, safeSlotId)
                }

                override fun onAdShow() {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        plugin.emit(
                            kind.wireName,
                            "shown",
                            safeRequestId,
                            mapOf("slotId" to safeSlotId) +
                                plugin.ecpmDetails(loadedAd.mediationManager),
                        )
                    }
                }
            },
        )
        bindActivity(loadedAd, activity, safeRequestId, safeSlotId)
        if (loadedAd is TTFeedAd) {
            loadedAd.setVideoAdListener(
                object : TTFeedAd.VideoAdListener {
                    override fun onVideoLoad(ad: TTFeedAd?) = Unit

                    override fun onVideoError(code: Int, extraCode: Int) {
                        plugin.runOnMain {
                            if (!isCurrent(loadedAd)) return@runOnMain
                            plugin.emit(
                                kind.wireName,
                                "videoError",
                                safeRequestId,
                                mapOf(
                                    "slotId" to safeSlotId,
                                    "code" to code,
                                    "extra" to mapOf("extraCode" to extraCode),
                                ),
                            )
                        }
                    }

                    override fun onVideoAdStartPlay(ad: TTFeedAd?) {
                        emitVideoEvent(loadedAd, "videoStarted", safeRequestId, safeSlotId)
                    }

                    override fun onVideoAdPaused(ad: TTFeedAd?) {
                        emitVideoEvent(loadedAd, "videoPaused", safeRequestId, safeSlotId)
                    }

                    override fun onVideoAdContinuePlay(ad: TTFeedAd?) {
                        emitVideoEvent(loadedAd, "videoResumed", safeRequestId, safeSlotId)
                    }

                    override fun onProgressUpdate(current: Long, duration: Long) = Unit

                    override fun onVideoAdComplete(ad: TTFeedAd?) {
                        emitVideoEvent(loadedAd, "completed", safeRequestId, safeSlotId)
                    }
                },
            )
        }
        if (loadedAd is TTDrawFeedAd) {
            loadedAd.setDrawVideoListener(
                object : TTDrawFeedAd.DrawVideoListener {
                    override fun onClickRetry() = Unit

                    override fun onClick() {
                        reportClick(loadedAd, safeRequestId, safeSlotId)
                    }
                },
            )
        }
    }

    private fun bindActivity(
        loadedAd: TTNativeAd,
        activity: Activity,
        safeRequestId: String,
        safeSlotId: String,
    ) {
        loadedAd.setActivityForDownloadApp(activity)
        loadedAd.setDislikeCallback(
            activity,
            object : TTAdDislike.DislikeInteractionCallback {
                override fun onShow() = Unit

                override fun onSelected(position: Int, reason: String?, enforce: Boolean) {
                    plugin.runOnMain {
                        if (!isCurrent(loadedAd)) return@runOnMain
                        plugin.emit(
                            kind.wireName,
                            "disliked",
                            safeRequestId,
                            notNullMap(
                                "slotId" to safeSlotId,
                                "extra" to notNullMap(
                                    "position" to position,
                                    "reason" to reason,
                                    "enforce" to enforce,
                                ),
                            ),
                        )
                        releaseAd(loadedAd)
                    }
                }

                override fun onCancel() = Unit
            },
        )
    }

    private fun reportClick(loadedAd: TTNativeAd, safeRequestId: String, safeSlotId: String) {
        plugin.runOnMain {
            if (isCurrent(loadedAd)) {
                plugin.emit(
                    kind.wireName,
                    "clicked",
                    safeRequestId,
                    mapOf("slotId" to safeSlotId),
                )
            }
        }
    }

    private fun emitVideoEvent(
        loadedAd: TTNativeAd,
        event: String,
        safeRequestId: String,
        safeSlotId: String,
    ) {
        plugin.runOnMain {
            if (isCurrent(loadedAd)) {
                plugin.emit(
                    kind.wireName,
                    event,
                    safeRequestId,
                    mapOf("slotId" to safeSlotId),
                )
            }
        }
    }

    private fun attachRenderedNativeAd(
        loadedAd: TTNativeAd,
        safeRequestId: String,
        safeSlotId: String,
    ) {
        if (!isCurrent(loadedAd) || !hostResumed) return
        val adView = pendingAdView ?: return
        attachView(container, adView)
        if (!rendered) {
            rendered = true
            plugin.emit(
                kind.wireName,
                "rendered",
                safeRequestId,
                mapOf(
                    "slotId" to safeSlotId,
                    "extra" to mapOf(
                        "width" to renderWidth.toDouble(),
                        "height" to renderHeight.toDouble(),
                    ),
                ),
            )
        }
    }

    private fun isCurrent(candidate: TTNativeAd): Boolean =
        !disposed && ad === candidate

    private fun registerLifecycle() {
        if (lifecycleRegistered) return
        lifecycleRegistered = true
        plugin.registerPlatformView(this)
    }

    private fun unregisterLifecycle() {
        if (!lifecycleRegistered) return
        lifecycleRegistered = false
        plugin.unregisterPlatformView(this)
    }

    private fun releaseAd(candidate: TTNativeAd? = ad) {
        val current = ad
        if (current != null && candidate != null && current !== candidate) return
        terminal = true
        if (current != null && (candidate == null || current === candidate)) {
            ad = null
            pendingAdView = null
            rendered = false
            renderRequested = false
            container.removeAllViews()
            current.destroy()
        }
        unregisterLifecycle()
    }

    override fun onHostPause() {
        hostResumed = false
        ad?.mediationManager?.onPause()
    }

    override fun onHostResume(activity: Activity) {
        hostResumed = true
        val current = ad ?: return
        val safeRequestId = requestId ?: return
        val safeSlotId = slotId ?: return
        current.mediationManager?.onResume()
        bindActivity(current, activity, safeRequestId, safeSlotId)
        if (!renderRequested) {
            renderRequested = true
            current.render()
        }
        attachRenderedNativeAd(current, safeRequestId, safeSlotId)
    }

    override fun onEngineDetached() {
        dispose()
    }

    override fun getView(): View = container

    override fun dispose() {
        if (disposed) return
        disposed = true
        releaseAd()
        if (requestId != null) {
            plugin.emit(
                kind.wireName,
                "disposed",
                requestId,
                notNullMap("slotId" to slotId),
            )
        }
    }
}

private fun attachView(container: FrameLayout, view: View) {
    (view.parent as? ViewGroup)?.removeView(view)
    container.removeAllViews()
    container.addView(
        view,
        FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT,
        ),
    )
}

private fun Map<*, *>.string(key: String): String? =
    (this[key] as? String)?.takeIf(String::isNotBlank)

private fun Map<*, *>.boolean(key: String, fallback: Boolean): Boolean =
    this[key] as? Boolean ?: fallback

private fun Map<*, *>.number(key: String, fallback: Double): Double =
    (this[key] as? Number)?.toDouble() ?: fallback

private fun notNullMap(vararg values: Pair<String, Any?>): Map<String, Any> =
    buildMap {
        values.forEach { (key, value) ->
            if (value != null) put(key, value)
        }
    }
