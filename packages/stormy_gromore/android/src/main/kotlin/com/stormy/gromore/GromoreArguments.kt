package com.stormy.gromore

import android.os.Bundle
import com.bytedance.sdk.openadsdk.TTAdConstant

internal fun orientation(arguments: Map<*, *>): Int =
    if (integer(arguments, "orientation", 0) == 1) {
        TTAdConstant.HORIZONTAL
    } else {
        TTAdConstant.VERTICAL
    }

@Suppress("DEPRECATION")
internal fun bundleToMap(bundle: Bundle?): Map<String, Any> {
    if (bundle == null) return emptyMap()
    return buildMap {
        bundle.keySet().forEach { key ->
            val value = bundle.get(key)
            if (value != null) {
                put(
                    key,
                    when (value) {
                        is Boolean,
                        is Int,
                        is Long,
                        is Double,
                        is String,
                        is ByteArray,
                        is IntArray,
                        is LongArray,
                        is DoubleArray -> value
                        is Float -> value.toDouble()
                        else -> value.toString()
                    },
                )
            }
        }
    }
}

internal fun requiredString(arguments: Map<*, *>, key: String): String {
    val value = arguments[key] as? String
    if (value.isNullOrBlank()) {
        throw BridgeException("invalid_arguments", "$key must not be empty.")
    }
    return value
}

internal fun optionalString(arguments: Map<*, *>, key: String): String? =
    (arguments[key] as? String)?.takeIf { it.isNotBlank() }

internal fun boolean(arguments: Map<*, *>, key: String, fallback: Boolean): Boolean =
    arguments[key] as? Boolean ?: fallback

internal fun integer(arguments: Map<*, *>, key: String, fallback: Int): Int =
    (arguments[key] as? Number)?.toInt() ?: fallback

internal fun optionalInteger(arguments: Map<*, *>, key: String): Int? =
    (arguments[key] as? Number)?.toInt()

internal fun number(arguments: Map<*, *>, key: String, fallback: Double): Double =
    (arguments[key] as? Number)?.toDouble() ?: fallback

internal fun rewardCallbackRetention(arguments: Map<*, *>): Long {
    val raw = arguments[REWARD_CALLBACK_RETENTION_KEY]
        ?: return DEFAULT_REWARD_CALLBACK_RETENTION_MS
    val number = raw as? Number
        ?: throw BridgeException(
            "invalid_arguments",
            "$REWARD_CALLBACK_RETENTION_KEY must be an integer number of milliseconds.",
        )
    val value = number.toLong()
    if (number.toDouble() != value.toDouble() || value !in 1..MAX_CONFIG_DURATION_MS) {
        throw BridgeException(
            "invalid_arguments",
            "$REWARD_CALLBACK_RETENTION_KEY must be between 1 and $MAX_CONFIG_DURATION_MS.",
        )
    }
    return value
}

internal fun mapOfNotNull(vararg values: Pair<String, Any?>): Map<String, Any> =
    buildMap {
        values.forEach { (key, value) ->
            if (value != null) put(key, value)
        }
    }

internal class BridgeException(val code: String, message: String) : Exception(message)
const val METHOD_CHANNEL = "stormy_gromore/methods"
const val EVENT_CHANNEL = "stormy_gromore/events"
const val BANNER_VIEW = "stormy_gromore/banner"
const val FEED_VIEW = "stormy_gromore/feed"
const val DRAW_FEED_VIEW = "stormy_gromore/draw_feed"
const val MAX_PENDING_EVENTS = 100
const val MAX_PRELOAD_PLACEMENTS = 20
const val REWARD_CALLBACK_RETENTION_KEY = "rewardCallbackRetentionMs"
const val DEFAULT_REWARD_CALLBACK_RETENTION_MS = 6_000L
const val MAX_CONFIG_DURATION_MS = 0x7fffffffL
const val PRELOAD_WIFI_ONLY = "wifiOnly"
const val PRELOAD_ANY_NETWORK = "any"
