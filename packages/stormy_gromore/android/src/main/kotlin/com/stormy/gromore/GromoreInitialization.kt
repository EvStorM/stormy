package com.stormy.gromore

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTCustomController
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig
import io.flutter.plugin.common.MethodChannel

internal class GromoreInitialization(
    private val applicationContext: Context,
    private val events: GromoreEvents,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var initializationResult: MethodChannel.Result? = null
    var rewardCallbackRetentionMs = DEFAULT_REWARD_CALLBACK_RETENTION_MS
        private set
    private fun emit(adType: String, event: String, details: Map<String, Any> = emptyMap()) =
        events.emit(adType, event, details = details)
    internal fun initialize(arguments: Map<*, *>, result: MethodChannel.Result) {
        rewardCallbackRetentionMs = rewardCallbackRetention(arguments)
        if (TTAdSdk.isSdkReady()) {
            result.success(true)
            return
        }
        if (initializationResult != null) {
            result.error(
                "initialization_in_progress",
                "GroMore initialization is already in progress.",
                null,
            )
            return
        }

        val appId = requiredString(arguments, "appId")
        val appName = requiredString(arguments, "appName")
        val privacy = arguments["privacy"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val builder = TTAdConfig.Builder()
            .appId(appId)
            .appName(appName)
            .useMediation(boolean(arguments, "useMediation", true))
            .debug(boolean(arguments, "debug", false))
            .themeStatus(integer(arguments, "theme", 0))
            .allowShowNotify(boolean(arguments, "allowShowNotification", true))
            .supportMultiProcess(boolean(arguments, "supportMultiProcess", false))
            .customController(createPrivacyController(privacy))

        if (arguments.containsKey("isPaidApp")) {
            builder.paid(boolean(arguments, "isPaidApp", false))
        }

        initializationResult = result
        try {
            TTAdSdk.init(applicationContext, builder.build())
            TTAdSdk.start(
                object : TTAdSdk.Callback {
                    override fun success() {
                        mainHandler.post {
                            val callback = initializationResult ?: return@post
                            initializationResult = null
                            emit("sdk", "initialized")
                            callback.success(true)
                        }
                    }

                    override fun fail(code: Int, message: String?) {
                        mainHandler.post {
                            val callback = initializationResult ?: return@post
                            initializationResult = null
                            emit(
                                "sdk",
                                "failed",
                                details = mapOfNotNull(
                                    "code" to code,
                                    "message" to message,
                                ),
                            )
                            callback.error(
                                "initialization_failed",
                                message ?: "GroMore initialization failed.",
                                mapOf("code" to code),
                            )
                        }
                    }
                },
            )
        } catch (error: Throwable) {
            initializationResult = null
            throw error
        }
    }

    internal fun createPrivacyController(privacy: Map<*, *>): TTCustomController =
        object : TTCustomController() {
            override fun isCanUseLocation() = boolean(privacy, "canUseLocation", false)

            override fun isCanUsePhoneState() =
                boolean(privacy, "canUsePhoneState", false)

            override fun isCanUseWifiState() = boolean(privacy, "canUseWifiState", false)

            override fun isCanUseWriteExternal() =
                boolean(privacy, "canUseWriteExternalStorage", false)

            override fun isCanUseAndroidId() =
                boolean(privacy, "canUseAndroidId", false)

            override fun alist() = boolean(privacy, "canUseInstalledAppList", false)

            override fun isCanUsePermissionRecordAudio() =
                boolean(privacy, "canUseRecordAudio", false)

            override fun isCanUseMessage() = boolean(privacy, "canUseMessages", false)

            override fun userPrivacyConfig(): MutableMap<String, Any> =
                mutableMapOf(
                    "motion_info" to
                        if (boolean(privacy, "canUseSensors", false)) 1 else 0,
                )

            override fun getMediationPrivacyConfig(): MediationPrivacyConfig =
                object : MediationPrivacyConfig() {
                    override fun isCanUseOaid() = boolean(privacy, "canUseOaid", false)

                    override fun isLimitPersonalAds() =
                        boolean(privacy, "limitPersonalAds", true)

                    override fun isProgrammaticRecommend() =
                        !boolean(privacy, "limitProgrammaticAds", true)
                }
        }

    fun dispose() {
        initializationResult?.error("engine_detached", "Flutter engine detached during GroMore initialization.", null)
        initializationResult = null
        mainHandler.removeCallbacksAndMessages(null)
    }
}
