#import "StormyRewardTerminalState.h"

@implementation StormyRewardTerminalState
- (BOOL)beginClose {
  if (_isClosed || _isReleased) return NO;
  _isClosed = YES;
  return YES;
}
- (BOOL)beginRewardDelivery {
  if (_isRewardDelivered || _isReleased) return NO;
  _isRewardDelivered = YES;
  return YES;
}
- (BOOL)canRelease { return _isClosed && _isRewardDelivered; }
- (BOOL)releaseResources {
  if (_isReleased) return NO;
  _isReleased = YES;
  return YES;
}
@end

BOOL StormyCanPresentHost(BOOL foreground, BOOL hasController, BOOL beingDismissed) {
  return foreground && hasController && !beingDismissed;
}
