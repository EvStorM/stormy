package com.stormy.gromore

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FullScreenHostGuardTest {
    @Test
    fun allowsOnlyResumedUsableActivity() {
        assertTrue(
            FullScreenHostGuard.canShow(
                hostResumed = true,
                hasActivity = true,
                activityFinishing = false,
                activityDestroyed = false,
            ),
        )
        assertFalse(
            FullScreenHostGuard.canShow(
                hostResumed = false,
                hasActivity = true,
                activityFinishing = false,
                activityDestroyed = false,
            ),
        )
        assertFalse(
            FullScreenHostGuard.canShow(
                hostResumed = true,
                hasActivity = false,
                activityFinishing = false,
                activityDestroyed = false,
            ),
        )
        assertFalse(
            FullScreenHostGuard.canShow(
                hostResumed = true,
                hasActivity = true,
                activityFinishing = true,
                activityDestroyed = false,
            ),
        )
        assertFalse(
            FullScreenHostGuard.canShow(
                hostResumed = true,
                hasActivity = true,
                activityFinishing = false,
                activityDestroyed = true,
            ),
        )
    }
}
