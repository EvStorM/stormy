#pragma once
#import <Foundation/Foundation.h>

/// Pure state shared by the iOS bridge and native regression executable.
@interface StormyRewardTerminalState : NSObject
@property(nonatomic, readonly) BOOL isClosed;
@property(nonatomic, readonly) BOOL isRewardDelivered;
@property(nonatomic, readonly) BOOL isReleased;
@property(nonatomic, readonly) BOOL canRelease;
- (BOOL)beginClose;
- (BOOL)beginRewardDelivery;
- (BOOL)releaseResources;
@end

FOUNDATION_EXPORT BOOL StormyCanPresentHost(BOOL foreground, BOOL hasController,
                                           BOOL beingDismissed);
