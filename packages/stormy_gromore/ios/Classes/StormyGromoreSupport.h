#pragma once
#import <Flutter/Flutter.h>
#import <BUAdSDK/BUAdSDK.h>
@interface StormyGromoreSupport : NSObject
- (void)runOnMain:(dispatch_block_t)block;
- (NSString *)requiredString:(NSDictionary *)arguments
                           key:(NSString *)key
                        result:(FlutterResult)result;
- (BOOL)boolValue:(NSDictionary *)arguments key:(NSString *)key fallback:(BOOL)fallback;
- (NSInteger)integerValue:(NSDictionary *)arguments
                        key:(NSString *)key
                   fallback:(NSInteger)fallback;
- (void)setValue:(id)value onObject:(id)object possibleKeys:(NSArray<NSString *> *)keys;
- (NSDictionary *)errorDetails:(NSError *)error slotId:(NSString *)slotId;
- (NSDictionary *)ecpmDetailsForMediation:(id)mediation;
- (void)destroyMediation:(id)mediation;
- (void)unknownAd:(NSString *)adType
          requestId:(NSString *)requestId
              result:(FlutterResult)result;
- (UIViewController *)topViewController;
@end
