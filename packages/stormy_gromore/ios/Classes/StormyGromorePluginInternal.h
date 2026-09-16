#pragma once
#import "StormyGromorePlugin.h"
#import <BUAdSDK/BUAdSDK.h>
@interface StormyGromorePlugin (Internal)
@property(nonatomic, readonly) BOOL ready;
- (void)emitAdType:(NSString *)adType
              event:(NSString *)event
          requestId:(NSString *)requestId
            details:(NSDictionary *)details;
- (UIViewController *)topViewController;
- (NSDictionary *)ecpmDetailsForMediation:(id)mediation;
- (NSDictionary *)errorDetails:(NSError *)error slotId:(NSString *)slotId;
- (void)destroyMediation:(id)mediation;
- (void)runOnMain:(dispatch_block_t)block;
- (BUNativeAdsManager *)nativeAdsManagerWithArguments:
    (NSDictionary *)arguments;
@end
