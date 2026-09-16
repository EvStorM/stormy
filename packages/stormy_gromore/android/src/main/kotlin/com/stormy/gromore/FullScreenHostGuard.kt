package com.stormy.gromore

internal object FullScreenHostGuard {
    fun canShow(
        hostResumed: Boolean,
        hasActivity: Boolean,
        activityFinishing: Boolean,
        activityDestroyed: Boolean,
    ): Boolean =
        hostResumed && hasActivity && !activityFinishing && !activityDestroyed
}
