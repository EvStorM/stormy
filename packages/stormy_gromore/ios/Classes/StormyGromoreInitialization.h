#pragma once
#import "StormyGromoreSupport.h"
#import "StormyGromoreEvents.h"
@interface StormyGromoreInitialization : StormyGromoreSupport
@property(nonatomic, assign, readonly) BOOL ready;
@property(nonatomic, assign, readonly) NSTimeInterval rewardCallbackRetentionSeconds;
- (instancetype)initWithEvents:(StormyGromoreEvents *)events;
- (void)dispose;
- (void)initializeWithArguments:(NSDictionary *)arguments
                         result:(FlutterResult)result;
- (void)requestTrackingAuthorization:(FlutterResult)result;
- (void)requireReady:(FlutterResult)result action:(dispatch_block_t)action;
@end
