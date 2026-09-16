package com.stormy.gromore

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RewardTerminalStateTest {
    @Test
    fun closeThenRewardReleasesOnlyAfterReward() {
        val state = RewardTerminalState()

        assertTrue(state.beginClose())
        assertFalse(state.canRelease)
        assertTrue(state.beginRewardDelivery())
        assertTrue(state.canRelease)
    }

    @Test
    fun rewardThenCloseReleasesOnlyAfterClose() {
        val state = RewardTerminalState()

        assertTrue(state.beginRewardDelivery())
        assertFalse(state.canRelease)
        assertTrue(state.beginClose())
        assertTrue(state.canRelease)
    }

    @Test
    fun duplicateCallbacksAreIgnored() {
        val state = RewardTerminalState()

        assertTrue(state.beginClose())
        assertFalse(state.beginClose())
        assertTrue(state.beginRewardDelivery())
        assertFalse(state.beginRewardDelivery())
    }
}
