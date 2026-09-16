#import "StormyRewardTerminalState.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
  @autoreleasepool {
    StormyRewardTerminalState *closeFirst = [StormyRewardTerminalState new];
    assert([closeFirst beginClose]);
    assert(!closeFirst.canRelease);
    assert([closeFirst beginRewardDelivery]);
    assert(closeFirst.canRelease);

    StormyRewardTerminalState *rewardFirst = [StormyRewardTerminalState new];
    assert([rewardFirst beginRewardDelivery]);
    assert(!rewardFirst.canRelease);
    assert([rewardFirst beginClose]);
    assert(rewardFirst.canRelease);

    assert(![rewardFirst beginRewardDelivery]);
    assert(![rewardFirst beginClose]);
    assert([rewardFirst releaseResources]);
    assert(![rewardFirst releaseResources]);

    StormyRewardTerminalState *timedOut = [StormyRewardTerminalState new];
    assert([timedOut beginClose]);
    assert([timedOut releaseResources]);
    assert(![timedOut beginRewardDelivery]);

    StormyRewardTerminalState *disposed = [StormyRewardTerminalState new];
    assert([disposed releaseResources]);
    assert(![disposed beginRewardDelivery]);
    assert(![disposed beginClose]);

    assert(StormyCanPresentHost(YES, YES, NO));
    assert(!StormyCanPresentHost(NO, YES, NO));
    assert(!StormyCanPresentHost(YES, NO, NO));
    assert(!StormyCanPresentHost(YES, YES, YES));
    puts("iOS native state: ordering, duplicates, timeout, disposal and host guards passed");
  }
  return 0;
}
