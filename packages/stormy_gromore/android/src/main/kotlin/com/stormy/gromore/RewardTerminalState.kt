package com.stormy.gromore

internal class RewardTerminalState {
    var isClosed: Boolean = false
        private set

    var isRewardDelivered: Boolean = false
        private set

    val canRelease: Boolean
        get() = isClosed && isRewardDelivered

    fun beginClose(): Boolean {
        if (isClosed) return false
        isClosed = true
        return true
    }

    fun beginRewardDelivery(): Boolean {
        if (isRewardDelivered) return false
        isRewardDelivered = true
        return true
    }
}
