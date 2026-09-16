package com.stormy.gromore

import android.app.Activity
import android.app.Application
import android.content.Context
import android.os.Bundle
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ConcurrentHashMap

class StormyGromorePlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var applicationContext: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var events: GromoreEvents
    private lateinit var initialization: GromoreInitialization
    private lateinit var requests: GromoreAdRequests
    private lateinit var fullScreen: GromoreFullScreenAds
    private var activity: Activity? = null
    private var hostResumed = false
    private val platformViews = ConcurrentHashMap.newKeySet<GromoreActivityAwareView>()
    private val activityLifecycleCallbacks =
        object : Application.ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, state: Bundle?) = Unit

            override fun onActivityStarted(activity: Activity) = Unit

            override fun onActivityResumed(resumedActivity: Activity) {
                if (activity === resumedActivity) {
                    hostResumed = FullScreenHostGuard.canShow(
                        hostResumed = true,
                        hasActivity = true,
                        activityFinishing = resumedActivity.isFinishing,
                        activityDestroyed = resumedActivity.isDestroyed,
                    )
                    if (hostResumed) {
                        platformViews.toList().forEach { it.onHostResume(resumedActivity) }
                        fullScreen.showDeferredAutoSplashes()
                    } else {
                        platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
                    }
                }
            }

            override fun onActivityPaused(pausedActivity: Activity) {
                if (activity === pausedActivity) {
                    hostResumed = false
                    platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
                }
            }

            override fun onActivityStopped(activity: Activity) = Unit

            override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) = Unit

            override fun onActivityDestroyed(destroyedActivity: Activity) {
                if (activity === destroyedActivity) {
                    hostResumed = false
                    activity = null
                    platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
                    fullScreen.releaseShowingSplashes("The host Activity was destroyed.")
                    fullScreen.closeShowingRewarded("The host Activity was destroyed.")
                    fullScreen.releaseShowingInterstitials("The host Activity was destroyed.")
                }
            }
        }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        events = GromoreEvents()
        initialization = GromoreInitialization(applicationContext, events)
        requests = GromoreAdRequests(this)
        fullScreen = GromoreFullScreenAds(this, requests, initialization, events)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(events)
        (applicationContext as? Application)?.registerActivityLifecycleCallbacks(
            activityLifecycleCallbacks,
        )
        binding.platformViewRegistry.registerViewFactory(
            BANNER_VIEW,
            GromoreViewFactory(this, GromoreViewKind.BANNER),
        )
        binding.platformViewRegistry.registerViewFactory(
            FEED_VIEW,
            GromoreViewFactory(this, GromoreViewKind.FEED),
        )
        binding.platformViewRegistry.registerViewFactory(
            DRAW_FEED_VIEW,
            GromoreViewFactory(this, GromoreViewKind.DRAW_FEED),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        hostResumed = false
        activity = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        initialization.dispose()
        (applicationContext as? Application)?.unregisterActivityLifecycleCallbacks(
            activityLifecycleCallbacks,
        )
        platformViews.toList().forEach(GromoreActivityAwareView::onEngineDetached)
        platformViews.clear()
        fullScreen.dispose()
        events.dispose()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val arguments = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            when (call.method) {
                "initialize" -> initialization.initialize(arguments, result)
                "requestTrackingAuthorization" -> result.success("notSupported")
                "loadSplash" -> withReady(result) { fullScreen.loadSplash(arguments, result) }
                "showSplash" -> withReady(result) { fullScreen.showSplash(arguments, result) }
                "loadRewarded" -> withReady(result) { fullScreen.loadRewarded(arguments, result) }
                "showRewarded" -> withReady(result) { fullScreen.showRewarded(arguments, result) }
                "loadInterstitial" -> withReady(result) {
                    fullScreen.loadInterstitial(arguments, result)
                }
                "showInterstitial" -> withReady(result) {
                    fullScreen.showInterstitial(arguments, result)
                }
                "preloadAds" -> withReady(result) { requests.preloadAds(arguments, result) }
                "disposeAd" -> withReady(result) { fullScreen.disposeAd(arguments, result) }
                else -> result.notImplemented()
            }
        } catch (error: BridgeException) {
            result.error(error.code, error.message, null)
        } catch (error: Throwable) {
            result.error("native_error", error.message ?: "Unknown native error.", null)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        hostResumed = false
        platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        hostResumed = false
        activity = null
        platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
        fullScreen.releaseShowingSplashes("The host Activity changed configuration.")
        fullScreen.closeShowingRewarded("The host Activity changed configuration.")
        fullScreen.releaseShowingInterstitials("The host Activity changed configuration.")
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        hostResumed = false
        platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
    }

    override fun onDetachedFromActivity() {
        hostResumed = false
        activity = null
        platformViews.toList().forEach(GromoreActivityAwareView::onHostPause)
        fullScreen.releaseShowingSplashes("The host Activity detached.")
        fullScreen.closeShowingRewarded("The host Activity detached.")
        fullScreen.releaseShowingInterstitials("The host Activity detached.")
    }

    internal fun withReady(result: MethodChannel.Result, action: () -> Unit) {
        if (!TTAdSdk.isSdkReady()) {
            result.error(
                "not_initialized",
                "Initialize GroMore successfully before loading or showing ads.",
                null,
            )
            return
        }
        action()
    }

    internal fun currentActivity(): Activity? = activity

    internal fun isHostResumed(): Boolean = hostResumed

    internal fun isSdkReady(): Boolean = TTAdSdk.isSdkReady()

    internal fun registerPlatformView(view: GromoreActivityAwareView) {
        platformViews.add(view)
        val currentActivity = activity
        if (hostResumed && currentActivity != null) {
            view.onHostResume(currentActivity)
        } else {
            view.onHostPause()
        }
    }

    internal fun unregisterPlatformView(view: GromoreActivityAwareView) {
        platformViews.remove(view)
    }

    internal fun context(): Context = applicationContext
    internal fun emit(adType: String, event: String, requestId: String? = null,
                      details: Map<String, Any> = emptyMap()) = events.emit(adType, event, requestId, details)
    internal fun runOnMain(action: () -> Unit) = events.runOnMain(action)
    internal fun ecpmDetails(manager: MediationBaseManager?) = events.ecpmDetails(manager)
}
